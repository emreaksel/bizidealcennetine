import 'dart:async';
import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rxdart/rxdart.dart';

import 'package:bizidealcennetine/services/log_service.dart';
import 'package:bizidealcennetine/yaveran/ui_support.dart';
// player burada global tanımlı
import 'package:bizidealcennetine/services/Notifier.dart';
import 'package:bizidealcennetine/services/audio/audio_service.dart';

// ══════════════════════════════════════════════════════════════
//  MediaBroadcastManager
//  ─────────────────────────────────────────────────────────────
//  Tüm OS/BT yayın (broadcast) sorumluluğunu üstlenir.
//
//  Çözdüğü sorunlar:
//    1. BT bağlandığında araç ekranı güncellenmiyor
//       → AudioSession output değişimini dinler, yeniden yayınlar.
//    2. Parça geçişinde "pause" görünmesi
//       → _intendedPlaying bayrağıyla "gerçek" niyeti izler;
//          loading/buffering sırasında playing=true yayınlar.
//    3. Tanı güçlüğü
//       → Her broadcast loglanır, böylece BT ekranının neden
//          yanlış gösterdiği trace edilebilir.
// ══════════════════════════════════════════════════════════════

class MediaBroadcastManager {
  // ── Bağımlılıklar ──────────────────────────────────────────
  final audio_svc.BaseAudioHandler _handler;
  final Player _player;
  final audio_svc.PlaybackState Function() _currentState;
  final BehaviorSubject<audio_svc.PlaybackState> _playbackState;
  final BehaviorSubject<audio_svc.MediaItem?> _mediaItem;

  // ── Niyet Bayrağı (Geçişlerde Pause Sorununu Çözer) ───────
  //
  // just_audio: setAudioSource → idle → loading → buffering → ready
  // Bu geçişler sırasında _player.playing = false olur.
  // _intendedPlaying = true tutarak BT'ye "aslında çalıyor" deriz.
  bool _intendedPlaying = false;
  bool _isCurrentlyLoading = false;
  bool _isStopped = false;

  // ── Dispose Koruyucusu ─────────────────────────────────────
  // dispose() çağrıldıktan sonra hiçbir broadcast ya da timer
  // callback'i tetiklenmesin diye bu bayrak kullanılır.
  bool _disposed = false;

  /// Dışarıdan (audio_service) broadcast manager'ın ölü olup olmadığını
  /// kontrol etmek için kullanılır. stop() → play() döngüsünde yeniden
  /// init kararı buna göre alınır.
  bool get isDisposed => _disposed;

  // ── Debounce (Hızlı State Fırtınasını Önler) ──────────────
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 80);

  // ── Abonelikler ────────────────────────────────────────────
  final List<StreamSubscription> _subs = [];

  // ── Tanı Sayacı ────────────────────────────────────────────
  int _broadcastCount = 0;

  // ══════════════════════════════════════════════════════════
  //  CONSTRUCTOR
  // ══════════════════════════════════════════════════════════

  MediaBroadcastManager({
    required audio_svc.BaseAudioHandler handler,
    required Player player,
    required BehaviorSubject<audio_svc.PlaybackState> playbackState,
    required BehaviorSubject<audio_svc.MediaItem?> mediaItem,
    required audio_svc.PlaybackState Function() currentState,
  })  : _handler = handler,
        _player = player,
        _playbackState = playbackState,
        _mediaItem = mediaItem,
        _currentState = currentState;

  // ══════════════════════════════════════════════════════════
  //  BAŞLATMA
  // ══════════════════════════════════════════════════════════

  Future<void> init() async {
    // 1. Oynatma durumu değişimleri
    _subs.add(_player.stream.playing.listen((playing) {
      // Stop edilmişken media_kit'in playing=true yayması _intendedPlaying'i bozmasın
      if (playing && !_isStopped) {
        _intendedPlaying = true;
      }
      _updateUIPlayButton();
      _scheduleBroadcast();
    }));

    // 2. Buffering (Yüklenme) durumu
    _subs.add(_player.stream.buffering.listen((_) {
      _updateUIPlayButton();
      _scheduleBroadcast();
    }));

    // 3. Pozisyon değişimleri (BT ekranı için periyodik)
    _subs.add(_player.stream.position.listen((_) {
      _scheduleBroadcast();
    }));

    // 3. BT / Ses Çıkışı Değişimi → Yeniden Yayın
    //    Araç ekranı yeni bir session bağlantısıyla gelir; mevcut
    //    mediaItem + playbackState'i hemen yeniden göndermemiz gerekir.
    final session = await AudioSession.instance;
    _subs.add(session.devicesChangedEventStream.listen((event) {
      _onAudioOutputChanged(event);
    }));

    LogService().info("MediaBroadcastManager başlatıldı", tag: "BT");
  }

  // ══════════════════════════════════════════════════════════
  //  NİYET BAYRAĞI KONTROLÜ
  //  MyAudioHandler bunları çağırır.
  // ══════════════════════════════════════════════════════════

  /// Oynatma başlamadan önce çağrılır (play / _playTrackInternal).
  void setIntendedPlaying() {
    _intendedPlaying = true;
    _isStopped = false; // ← ekle
    LogService().info("[Broadcast] _intendedPlaying = true", tag: "BT");
    _scheduleBroadcast(immediate: true);
  }

  /// Kullanıcı manuel olarak durdurduğunda çağrılır (pause / stop).
  void setIntendedPaused() {
    _intendedPlaying = false;
    _isStopped = true; // ← ekle
    LogService().info("[Broadcast] _intendedPlaying = false", tag: "BT");
    if (!_disposed) _scheduleBroadcast(immediate: true);
  }

  // ══════════════════════════════════════════════════════════
  //  BROADCAST ÇEKİRDEĞİ
  // ══════════════════════════════════════════════════════════

  /// Debounce ile broadcast zamanlar; immediate=true ise hemen gönderir.
  void _scheduleBroadcast({bool immediate = false}) {
    if (_disposed) return; // Dispose sonrası hiçbir şey gönderilmez
    _debounceTimer?.cancel();
    if (immediate) {
      _doBroadcast();
    } else {
      _debounceTimer = Timer(_debounceDuration, () {
        if (!_disposed) _doBroadcast();
      });
    }
  }

  void _doBroadcast() {
    _broadcastCount++;
    _updateUIPlayButton();

    final procState = _deriveProcessingState();
    final actualPlaying = _player.state.playing;

    // Geçiş sırasında player henüz metadata/alınma sürecindeyse ve niyet
    // çalma yönündeyse, idle state yerine loading yayarak foreground
    // servisin kapanmasını engelleriz.
    if (procState == audio_svc.AudioProcessingState.idle &&
        _intendedPlaying &&
        !_isStopped &&
        _mediaItem.value != null) {
      LogService().info(
          "[Broadcast #$_broadcastCount] idle geçişten loading'e çevrildi.",
          tag: "BT");
      // procState'i loading olarak düşerek bildirim kapanmasının önüne geç
      _playbackState.add(_currentState().copyWith(
        controls: [
          audio_svc.MediaControl.skipToPrevious,
          audio_svc.MediaControl.pause,
          audio_svc.MediaControl.skipToNext,
          audio_svc.MediaControl.stop,
        ],
        systemActions: const {
          audio_svc.MediaAction.seek,
          audio_svc.MediaAction.skipToNext,
          audio_svc.MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audio_svc.AudioProcessingState.loading,
        playing: true,
        updatePosition: _player.state.position,
        bufferedPosition: _player.state.buffer,
        speed: _player.state.rate,
      ));
      return;
    }

    // idle state'i ASLA engelleme — foreground servis bu state'e muhtaç
    if (procState == audio_svc.AudioProcessingState.idle) {
      _playbackState.add(_currentState().copyWith(
        controls: [],
        processingState: audio_svc.AudioProcessingState.idle,
        playing: false,
      ));
      LogService().info("[Broadcast #$_broadcastCount] idle state yayınlandı.",
          tag: "BT");
      return;
    }

    // Erken çıkış: sadece idle/completed/ready'de ve niyet=false + player=false ise
    if (!_intendedPlaying && !actualPlaying) {
      final isStillLoading =
          procState == audio_svc.AudioProcessingState.loading ||
              procState == audio_svc.AudioProcessingState.buffering;
      if (!isStillLoading) {
        LogService().info(
            "[Broadcast #$_broadcastCount] Oyuncu durdu + niyet=false → yayın atlandı.",
            tag: "BT");
        return;
      }
    }

    // ── Niyet bayrağını uygula ────────────────────────────
    final bool broadcastPlaying;
    if (_intendedPlaying) {
      // Geçiş sırasında state ne olursa olsun playing=true yayınla
      // androidStopForegroundOnPause:true bunu görünce bildirimi kapatmaz
      broadcastPlaying = true;
    } else {
      broadcastPlaying = actualPlaying;
    }

    _playbackState.add(_currentState().copyWith(
      controls: [
        audio_svc.MediaControl.skipToPrevious,
        broadcastPlaying
            ? audio_svc.MediaControl.pause
            : audio_svc.MediaControl.play,
        audio_svc.MediaControl.skipToNext,
        audio_svc.MediaControl.stop,
      ],
      systemActions: const {
        audio_svc.MediaAction.seek,
        audio_svc.MediaAction.skipToNext,
        audio_svc.MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: procState,
      playing: broadcastPlaying,
      updatePosition: _player.state.position,
      bufferedPosition: _player.state.buffer,
      speed: _player.state.rate,
    ));
  }

  /// UI'daki play/pause butonunu gecikmesiz günceller.
  void _updateUIPlayButton() {
    final isBuffering = _player.state.buffering;
    final playing = _player.state.playing;

    // ── LOG: Yükleme Durumu Takibi ───────────────────────
    if (isBuffering && !_isCurrentlyLoading) {
      _isCurrentlyLoading = true;
      LogService().info("⏳ Parça yüklenmeye başlandı...", tag: "Audio");
    } else if (!isBuffering && _isCurrentlyLoading) {
      _isCurrentlyLoading = false;
      LogService().info("✅ Parça yükleme tamamlandı.", tag: "Audio");
    }

    if (isBuffering) {
      AppAudioService.playButtonNotifier.value = ButtonState.loading;
    } else {
      AppAudioService.playButtonNotifier.value =
          playing ? ButtonState.playing : ButtonState.paused;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BT / SES ÇIKIŞI DEĞİŞİMİ
  // ══════════════════════════════════════════════════════════

  void _onAudioOutputChanged(AudioDevicesChangedEvent event) {
    final added = event.devicesAdded.map((d) => d.name).join(', ');
    final removed = event.devicesRemoved.map((d) => d.name).join(', ');

    LogService().info(
      "[BT] Ses çıkışı değişti → Eklenen: [$added] | Çıkarılan: [$removed]",
      tag: "BT",
    );

    if (event.devicesAdded.isNotEmpty) {
      // Yeni cihaz bağlandı (araç, kulaklık vb.)
      // Kısa gecikme: BT stack bağlantıyı tamamlasın.
      Timer(const Duration(milliseconds: 600), () {
        LogService().info(
            "[BT] Yeni cihaz bağlandı, mediaItem + state yeniden yayınlanıyor",
            tag: "BT");
        _forceRefresh();
      });
    }
  }

  /// mediaItem ve playbackState'i sıfırdan yeniden gönderir.
  /// BT bağlandığında araç head unit'inin "boş session" sorununu çözer.
  void _forceRefresh() {
    final item = _mediaItem.value;
    if (item != null) {
      // MediaItem'ı yeniden yayınla — araç ekranı bunu "yeni şarkı" olarak alır
      _mediaItem.add(item);
      LogService()
          .info("[BT] mediaItem yeniden yayınlandı: ${item.title}", tag: "BT");
    } else {
      LogService()
          .warn("[BT] Yenileme isteği geldi ama mediaItem null!", tag: "BT");
    }

    // State'i hemen gönder
    _scheduleBroadcast(immediate: true);
  }

  /// Dışarıdan (parça değişiminde) mediaItem'ı günceller ve yayınlar.
  void refreshMediaItem(audio_svc.MediaItem item) {
    LogService().info(
        "[BT] refreshMediaItem çağrıldı: ${item.title} - ${item.artist}",
        tag: "BT");
    _mediaItem.add(item);
    _scheduleBroadcast(immediate: true);
    UI_support.changeImageAndEpigram(); // Parça değiştiğinde görsel ve özdeyiş de değişsin
  }

  // ══════════════════════════════════════════════════════════
  //  DÖNÜŞTÜRÜCÜ
  // ══════════════════════════════════════════════════════════

  audio_svc.AudioProcessingState _deriveProcessingState() {
    if (_isStopped) return audio_svc.AudioProcessingState.idle;
    if (_player.state.buffering)
      return audio_svc.AudioProcessingState.buffering;
    if (_player.state.completed)
      return audio_svc.AudioProcessingState.completed;
    if (_player.state.duration == Duration.zero)
      return audio_svc.AudioProcessingState.idle;
    return audio_svc.AudioProcessingState.ready;
  }

  // ══════════════════════════════════════════════════════════
  //  DISPOSE
  // ══════════════════════════════════════════════════════════

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Timer'ı önce iptal et — aksi hâlde 80ms sonra bir broadcast daha atılabilir
    _debounceTimer?.cancel();
    _debounceTimer = null;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    LogService().info(
        "[BT] MediaBroadcastManager dispose edildi. Toplam broadcast: $_broadcastCount",
        tag: "BT");
  }
}
