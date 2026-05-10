import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;

import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/services/Notifier.dart';
import 'package:bizidealcennetine/services/MusicApiService.dart';
import 'package:bizidealcennetine/services/audio/playlist_manager.dart';
import 'package:bizidealcennetine/services/log_service.dart';
import 'package:bizidealcennetine/yaveran/ui_support.dart';

import 'package:bizidealcennetine/services/audio/log_manager.dart';
import 'package:bizidealcennetine/services/audio/session_handler.dart';
import 'package:bizidealcennetine/services/audio/sleep_timer_manager.dart';
import 'package:bizidealcennetine/services/audio/volume_manager.dart';

// ══════════════════════════════════════════════════════════════
//  MyAudioHandler
//  ─────────────────────────────────────────────────────────────
//  Gerçek ses motorunu (just_audio) ve OS bildirimini (audio_service)
//  yöneten handler. Tüm stream dinleyicileri burada kurulur;
//  dışarıya hiçbir stream sızdırılmaz — yalnızca AudioService
//  üzerinden iletişim kurulur.
// ══════════════════════════════════════════════════════════════
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ── Çekirdek Bileşenler ────────────────────────────────────
  late final AudioPlayer _player;
  final PlaylistManager _playlistManager = PlaylistManager();
  final ListenLogManager _logManager = ListenLogManager();
  final AudioSessionHandler _sessionHandler = AudioSessionHandler();

  // Başlatma tamamlanana kadar operasyonları bekletir
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  // ── Durum Bayrakları ───────────────────────────────────────
  bool _isStopping = false; // stop() akışı devam ediyor mu?

  // Web uyumluluğu için indeks takibi (Aynı geçişin tekrarını önler)
  int _lastProcessedIndex = 0;

  // Race Condition engelleme: Her oynatma isteği için benzersiz ID
  int _activeRequestId = 0;

  // ══════════════════════════════════════════════════════════
  //  CONSTRUCTOR
  // ══════════════════════════════════════════════════════════

  MyAudioHandler() {
    _init();
    _logManager.loadPersistedLogs();
  }

  // ══════════════════════════════════════════════════════════
  //  BAŞLATMA
  // ══════════════════════════════════════════════════════════

  Future<void> _init() async {
    try {
      _player = AudioPlayer();

      // AudioSession'ı yapılandır ve kesintileri (telefon araması vs.) yönet
      await _sessionHandler.init(_player);

      // Parça bitişini veya geçişini yakala
      // Sliding Window (2 parça) mantığıyla otomatik geçişleri yönetiyoruz.
      _player.currentIndexStream.listen((index) {
        if (index != null && index > 0 && !_isStopping) {
          _handleTrackTransition(index);
        }
      });

      // Genel playback event'i → OS bildirimini güncelle
      _player.playbackEventStream.listen(_broadcastState);

      // Parça biterse ve otomatik geçiş olmazsa devreye gir
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed && !_isStopping) {
          LogService()
              .info("Parça bitti, yedek geçiş tetikleniyor", tag: "Audio");
          if (_playlistManager.isRepeatOne) {
            _player.seek(Duration.zero).then((_) => _player.play());
          } else {
            skipToNext();
          }
        }
      });

      // Konum akışı → UI progress bar
      _player.positionStream.listen((position) {
        playbackState
            .add(playbackState.value.copyWith(updatePosition: position));
        AudioService.progressNotifier.value = ProgressBarState(
          current: position,
          buffered: _player.bufferedPosition ?? Duration.zero,
          total: _player.duration ?? Duration.zero,
        );
      });

      // Buffer durumu
      _player.bufferedPositionStream.listen((buffered) {
        final cur = AudioService.progressNotifier.value;
        AudioService.progressNotifier.value = ProgressBarState(
          current: cur.current,
          buffered: buffered ?? Duration.zero,
          total: cur.total,
        );
      });

      // Duration → progress bar'ın total değerini ve mediaItem'ı güncelle
      _player.durationStream.listen((duration) {
        final cur = AudioService.progressNotifier.value;
        AudioService.progressNotifier.value = ProgressBarState(
          current: cur.current,
          buffered: cur.buffered,
          total: duration ?? Duration.zero,
        );
        final item = mediaItem.value;
        if (duration != null && item != null) {
          mediaItem.add(item.copyWith(duration: duration));
        }
      });

      // Oynatma/duraklatma → log zamanlayıcısını senkronize et
      _player.playingStream.listen((playing) {
        if (playing) {
          _logManager.onPlay();
        } else {
          _logManager.onPause();
        }
      });

      // Ses seviyesi → UI notifier
      _player.volumeStream.listen((v) => AudioService.volumeNotifier.value = v);

      // Resim değişince OS bildirimindeki artwork'ü güncelle
      Degiskenler.currentImageNotifier.addListener(_syncArtwork);

      _ready.complete();
      LogService().info("AudioHandler başarıyla başlatıldı", tag: "Audio");
    } catch (e, st) {
      if (!_ready.isCompleted) _ready.completeError(e, st);
      LogService().error("_init hatası: $e\n$st", tag: "Audio");
    }
  }

  // ══════════════════════════════════════════════════════════
  //  STATE BROADCASTING  →  OS bildirimi
  // ══════════════════════════════════════════════════════════

  void _broadcastState(PlaybackEvent _) {
    if (_isStopping) return;

    final playing = _player.playing;
    final procState = _toProcessingState(_player.processingState);

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: procState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition ?? Duration.zero,
      speed: _player.speed,
      queueIndex: 0,
    ));

    // UI play butonunu güncelle
    AudioService.playButtonNotifier.value = switch (procState) {
      AudioProcessingState.loading => ButtonState.loading,
      AudioProcessingState.buffering => ButtonState.loading,
      _ => playing ? ButtonState.playing : ButtonState.paused,
    };
  }

  AudioProcessingState _toProcessingState(ProcessingState s) => switch (s) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  void _syncArtwork() {
    final item = mediaItem.value;
    if (item == null) return;
    final name = Degiskenler.currentImageNotifier.value;
    if (name.isNotEmpty) {
      mediaItem.add(item.copyWith(
        artUri: Uri.parse('${Degiskenler.kaynakYolu}medya/atesiask/$name'),
      ));
    }
  }

  // ══════════════════════════════════════════════════════════
  //  OVERRIDE: TEMEL KONTROLLER
  // ══════════════════════════════════════════════════════════

  @override
  Future<void> play() async {
    await ready;
    _sessionHandler.setManuallyPaused(false);

    // Liste yoksa sistemi yeniden uyandır
    if (!Degiskenler.listeYuklendi &&
        !Degiskenler.hazirlaniyor &&
        !AudioService.playlistLoadingNotifier.value) {
      LogService().info("Liste yüklü değil, sistem yenileniyor", tag: "Audio");
      Degiskenler.showSplashNotifier.value = true;
      return;
    }

    // Player idle ise (cold start / stop sonrası) son parçayı yeniden yükle
    if (_player.processingState == ProcessingState.idle) {
      LogService()
          .info("Player idle — son parçayı yeniden yüklüyorum", tag: "Audio");
      final siraNo = _playlistManager.currentSiraNo;
      final song = siraNo != -1
          ? _playlistManager.findBySiraNo(siraNo)
          : _playlistManager.randomSong();
      if (song != null) await _playTrackInternal(song);
      return;
    }

    await _player.play();
  }

  @override
  Future<void> pause() async {
    _sessionHandler.setManuallyPaused(true);
    await _player.pause();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final isRepeat = repeatMode == AudioServiceRepeatMode.one;
    _playlistManager.isRepeatOne = isRepeat;
    _player.setLoopMode(isRepeat ? LoopMode.one : LoopMode.off);

    AudioService.repeatButtonNotifier.value =
        isRepeat ? RepeatState.on : RepeatState.off;

    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));

    LogService().info(
        "Tekrar modu değişti: ${isRepeat ? 'TEK PARÇA' : 'KAPALI'}",
        tag: "Audio");

    if (!isRepeat) {
      _prepareNextTrack();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final isEnabled = shuffleMode == AudioServiceShuffleMode.all;
    _playlistManager.isShuffleEnabled = isEnabled;
    AudioService.isShuffleModeEnabledNotifier.value = isEnabled;

    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));

    LogService().info(
        "Karıştırma modu değişti: ${isEnabled ? 'AÇIK' : 'KAPALI'}",
        tag: "Audio");
  }

  @override
  Future<void> stop() async {
    _isStopping = true;
    _logManager.finalizeCurrentLog();
    _logManager.dispose();

    // Bildirimi ve kuyruğu temizle
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [],
    ));
    mediaItem.add(null);
    queue.add([]);

    await _player.stop();

    // Uygulama durumunu tamamen sıfırla
    Degiskenler.listeYuklendi = false;
    Degiskenler.parcaIndex = -1;
    Degiskenler.songListNotifier.value = [];
    Degiskenler().listDinle = [];
    AudioService.currentSongTitleNotifier.value = '...';
    AudioService.currentSongSubTitleNotifier.value = '...';

    await super.stop();
    LogService().info("Servis tamamen durduruldu ve sıfırlandı", tag: "Audio");
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_shouldWakeSystem()) return;

    // Web stabilite kuralı: Manuel geçişlerde her zaman _playTrackInternal kullan.
    // Bu sayede RequestId devreye girer ve çakışmaları (race condition) önler.
    final next = _playlistManager.calculateNext();
    if (next != null) await _playTrackInternal(next);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_shouldWakeSystem()) return;
    final prev = _playlistManager.calculatePrevious();
    if (prev != null) {
      _playlistManager.rewindHistory();
      // Geri giderken sliding window'u sıfırlamak için hard-load yapıyoruz
      await _playTrackInternal(prev, isRewind: true);
    }
  }

  @override
  Future<void> fastForward() async {
    final pos = _player.position + const Duration(seconds: 10);
    final max = _player.duration ?? Duration.zero;
    await _player.seek(pos < max ? pos : max);
  }

  @override
  Future<void> rewind() async {
    final pos = _player.position - const Duration(seconds: 10);
    await _player.seek(pos > Duration.zero ? pos : Duration.zero);
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  // ══════════════════════════════════════════════════════════
  //  CORE: PARÇA OYNATMA
  //  ─────────────────────────────────────────────────────────
  //  Bu metot uygulamanın kalbidir. Her parça değişimi buradan
  //  geçer. Sıra şu şekildedir:
  //    1. URL doğrula
  //    2. Önceki log'u kapat
  //    3. Navigasyon geçmişini güncelle
  //    4. MediaItem oluştur ve OS bildirimini güncelle
  //    5. AudioSource'u yükle
  //    6. Yeni log'u başlat
  //    7. Oynat + UI tetikle
  // ══════════════════════════════════════════════════════════

  Future<void> _playTrackInternal(
    Map<String, dynamic> song, {
    bool isRewind = false,
  }) async {
    // 1. Yeni bir ID oluştur ve bu fonksiyonun yerel değişkenine ata
    final int requestId = ++_activeRequestId;

    final url = song['url']?.toString();
    if (url == null || url.isEmpty) {
      LogService()
          .warn("Parça URL'si boş, oynatma iptal edildi: $song", tag: "Audio");
      AudioService.playlistLoadingNotifier.value = false;
      return;
    }

    try {
      await ready;
      // Eğer bu noktada başka bir şarkıya basılmışsa dur
      if (requestId != _activeRequestId) return;

      _isStopping = false;
      AudioService.playlistLoadingNotifier.value = true;

      // 1. Önceki parçanın log'unu kapat
      _logManager.finalizeCurrentLog();

      // 2. Meta bilgileri
      final siraNoStr = song['sira_no'].toString();
      final title = song['parca_adi'].toString();
      final artist = (song['seslendiren'] ?? '...').toString();
      final isGift = song['_isGift'] == true;

      final item = MediaItem(
        id: siraNoStr,
        title: title,
        artist: artist,
        artUri:
            Uri.parse('${Degiskenler.kaynakYolu}medya/atesiask/bahar11.jpg'),
        extras: {
          if (isGift) 'isApplink': true,
          'songData': song, // Geçiş anında kullanmak üzere ham veriyi sakla
        },
      );

      // 3. Ses kaynağını ve "Sliding Window" için ConcatenatingAudioSource'u hazırla
      final source = _createAudioSource(song, item);
      final concatenatingSource = ConcatenatingAudioSource(children: [source]);

      // Web tarafındaki çakışmayı önlemek için player'ı tamamen durdurup resetliyoruz
      await _player.stop();
      if (requestId != _activeRequestId) return;

      // DEĞİŞİKLİK: Yeni liste başlatıldığı için takip indeksini sıfırla
      _lastProcessedIndex = 0;

      // 4. ÖNCE KAYNAĞI YÜKLE (İnternet hızına göre burası zaman alabilir)
      await _player.setAudioSource(concatenatingSource,
          initialIndex: 0, initialPosition: Duration.zero);

      // EĞER BU AWAIT BİTTİĞİNDE KULLANICI BAŞKA ŞARKIYA BASMIŞSA BURADAN SONRASINI ÇALIŞTIRMA!
      if (requestId != _activeRequestId) {
        LogService().info(
            "Eski istek ($requestId) iptal edildi, yeni bir şarkı istenmiş.",
            tag: "Audio");
        return;
      }

      // 5. YÜKLEME BAŞARILIYSA DURUMU VE UI'I GÜNCELLE
      if (!isRewind) _playlistManager.recordNavigation(song);
      await updateQueue([item]);
      mediaItem.add(item);
      AudioService.setCurrentTrackData(siraNoStr, title, artist, isGift);

      _logManager.startNewLog(siraNoStr);
      AudioService.playlistLoadingNotifier.value = false;

      await _player.play();

      // 8. Sonraki parçayı pre-load et (Gapless geçiş için)
      _prepareNextTrack();

      // Kısa bir gecikmeyle resim/söz değişimini tetikle
      Future.delayed(
        const Duration(milliseconds: 120),
        UI_support.changeImageAndEpigram,
      );

      LogService().info(
          "▶ Oynatılıyor: '$title' — '$artist' (Request ID: $requestId)",
          tag: "Audio");
    } catch (e, st) {
      if (requestId == _activeRequestId) {
        LogService().error("_playTrackInternal hatası: $e\n$st", tag: "Audio");
      }
    } finally {
      if (requestId == _activeRequestId) {
        AudioService.playlistLoadingNotifier.value = false;
      }
    }
  }

  /// Sliding window'daki otomatik geçişi yönetir.
  void _handleTrackTransition(int index) async {
    final sequence = _player.sequence;
    if (sequence == null || sequence.length <= index) return;

    // Aynı şarkının geçişini tekrar tekrar tetiklemeyi (veya geri gidince tetiklenmesini) önle
    if (index <= _lastProcessedIndex) return;
    _lastProcessedIndex = index;

    // Yeni çalan parçanın bilgilerini MediaItem tag'inden al
    final currentItem = sequence[index].tag as MediaItem;
    final songData = currentItem.extras?['songData'] as Map<String, dynamic>?;

    if (songData != null) {
      LogService().info(
          "Geçiş tetiklendi: ${currentItem.title} (Index: $index)",
          tag: "Audio");

      // 1. Önceki parçanın log'unu kapat
      _logManager.finalizeCurrentLog();

      // 2. PlaylistManager navigasyonunu güncelle
      _playlistManager.recordNavigation(songData);

      // 3. UI Notifier'ları güncelle
      AudioService.setCurrentTrackData(
        currentItem.id,
        currentItem.title,
        currentItem.artist ?? '...',
        currentItem.extras?['isApplink'] == true,
      );

      // KRİTİK: Eski parçayı kuyruktan ÇIKARMIYORUZ (removeAt YOK).
      // Kuyruk ileriye doğru (1, 2, 3...) büyüyecek, böylece Web motoru
      // index kayması yaşayıp çökmeyecektir.

      // 4. Yeni log başlat
      _logManager.startNewLog(currentItem.id);

      // 5. Resim/Söz değişimini tetikle
      UI_support.changeImageAndEpigram();

      // 6. Bir sonraki parçayı kuyruğun sonuna ekle
      _prepareNextTrack();
    }
  }

  /// Bir sonraki parçayı hesaplar ve sessizce kuyruğa ekler.
  void _prepareNextTrack() {
    if (_playlistManager.isRepeatOne) return;

    // Eğer kuyrukta zaten 1'den fazla parça varsa (yani sonraki parça hazırsa) tekrar ekleme
    final sequence = _player.sequence;
    if (sequence != null && sequence.length > 1) return;

    final nextSong = _playlistManager.calculateNext();
    if (nextSong != null) {
      final title = nextSong['parca_adi'].toString();
      final artist = (nextSong['seslendiren'] ?? '...').toString();
      final isGift = nextSong['_isGift'] == true;

      final item = MediaItem(
        id: nextSong['sira_no'].toString(),
        title: title,
        artist: artist,
        artUri:
            Uri.parse('${Degiskenler.kaynakYolu}medya/atesiask/bahar11.jpg'),
        extras: {
          if (isGift) 'isApplink': true,
          'songData': nextSong,
        },
      );

      final source = _createAudioSource(nextSong, item);

      // DEĞİŞİKLİK BURADA: Oynatıcıdaki playlist'i alıp ona ekliyoruz.
      final currentPlaylist = _player.audioSource as ConcatenatingAudioSource?;
      currentPlaylist?.add(source);

      LogService().info("Sonraki parça pre-load edildi: $title", tag: "Audio");
    }
  }

  AudioSource _createAudioSource(Map<String, dynamic> song, MediaItem item) {
    return AudioSource.uri(
      Uri.parse(song['url'].toString()),
      headers: AudioService._defaultHeaders,
      tag: item,
    );
  }

  /// Liste yüklü değilse splash'i tetikler ve true döner.
  bool _shouldWakeSystem() {
    if (!Degiskenler.listeYuklendi &&
        !Degiskenler.hazirlaniyor &&
        !AudioService.playlistLoadingNotifier.value) {
      Degiskenler.showSplashNotifier.value = true;
      return true;
    }
    return false;
  }

  // ── Getter'lar ─────────────────────────────────────────────
  PlaylistManager get playlistManager => _playlistManager;
  AudioPlayer get player => _player;

  // ── Playlist Yönetimi (Proxy) ─────────────────────────────
  void setMainList(List<dynamic> list) => _playlistManager.setMainList(list);
  void setDokunanlarList(List<dynamic> list) =>
      _playlistManager.setDokunanlarList(list);
  void switchToMainList() => _playlistManager.switchToMainList();
  void switchToDokunanlar() => _playlistManager.switchToDokunanlar();

  Future<void> setVolume(double v) => _player.setVolume(v);

  Future<void> disposeAll() async {
    _logManager.dispose();
    Degiskenler.currentImageNotifier.removeListener(_syncArtwork);
    _logManager.finalizeCurrentLog();
    await _player.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
//  AudioService
//  ─────────────────────────────────────────────────────────────
//  Uygulamanın geri kalanının ses ile konuştuğu tek kapı.
//  Tüm metodlar statik; handler null kontrolü _require() ile
//  merkezi olarak yapılır.
// ══════════════════════════════════════════════════════════════
class AudioService {
  AudioService._();

  // ── İç Handler ────────────────────────────────────────────
  static MyAudioHandler? _handler;

  // HTTP isteklerinde tarayıcı gibi görün — bazı CDN'ler bot block yapar
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
  };

  // ── Parça Bilgisi ──────────────────────────────────────────
  static String _parcaAdi = '...';
  static String _seslendiren = '...';
  static String get parcaAdi => _parcaAdi;
  static String get seslendiren => _seslendiren;

  // ── Notifier'lar (UI bu değerleri dinler) ─────────────────
  static final progressNotifier = ProgressNotifier();
  static final playButtonNotifier =
      ValueNotifier<ButtonState>(ButtonState.paused);
  static final repeatButtonNotifier = RepeatButtonNotifier();
  static final playlistLoadingNotifier = PlaylistLoadingNotifier();
  static final currentSongTitleNotifier = ValueNotifier<String>('...');
  static final currentSongSubTitleNotifier = ValueNotifier<String>('...');
  static final playlistNotifier = ValueNotifier<List<String>>([]);
  static final isShuffleModeEnabledNotifier = ValueNotifier<bool>(false);
  static final isShareableNotifier = ValueNotifier<bool>(true);
  static final volumeNotifier = ValueNotifier<double>(1.0);

  // ══════════════════════════════════════════════════════════
  //  BAŞLATMA
  // ══════════════════════════════════════════════════════════

  static Future<void> init() async {
    if (_handler != null) return; // Zaten başlatılmış, tekrar çalıştırma

    _handler = MyAudioHandler();

    await audio_svc.AudioService.init(
      builder: () => _handler!,
      config: const audio_svc.AudioServiceConfig(
        androidNotificationChannelId: 'com.ea.bizidealcennetine.channel.audio',
        androidNotificationChannelName: 'Aşk Olsun',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );

    LogService().info("AudioService başlatıldı", tag: "Audio");
  }

  // ══════════════════════════════════════════════════════════
  //  PLAYLİST YÖNETİMİ
  // ══════════════════════════════════════════════════════════

  static Future<void> setMainList(
    List<dynamic> data, {
    bool playNow = true,
  }) async {
    _require();
    await _handler!.ready;

    _handler!.playlistManager.setMainList(data);
    Degiskenler.listeYuklendi = true;

    if (!playNow) {
      playlistLoadingNotifier.value = false;
      return;
    }

    // Bekleyen hediye parça var mı?
    final hediyeId = Degiskenler.bekleyenHediyeId;
    final hediyeLink = Degiskenler.bekleyenHediyeLink;

    if (hediyeId != null) {
      Degiskenler.bekleyenHediyeId = null;
      Degiskenler.bekleyenHediyeLink = null;

      // Önce mevcut liste içinde ara
      final inPlaylist =
          _handler!.playlistManager.findBySiraNo(int.tryParse(hediyeId) ?? -1);

      if (inPlaylist != null) {
        await _handler!._playTrackInternal(inPlaylist);
      } else if (hediyeLink != null) {
        // Listede yok, API'den çek
        await playGiftTrack(hediyeLink, hediyeId);
      } else {
        await _playRandom();
      }
    } else {
      await _playRandom();
    }
  }

  static Future<void> _playRandom() async {
    final song = _handler!.playlistManager.randomSong();
    if (song != null) {
      await _handler!._playTrackInternal(song);
    } else {
      playlistLoadingNotifier.value = false;
    }
  }

  static Future<void> switchToMainList({bool playNow = false}) async {
    _require();
    await _handler!.ready;
    _handler!.switchToMainList();
    if (playNow) await _playRandom();
  }

  static Future<void> switchToDokunanlar(List<dynamic> likesData,
      {bool playNow = false}) async {
    _require();
    await _handler!.ready;
    _handler!
      ..setDokunanlarList(likesData)
      ..switchToDokunanlar();
    if (playNow) await _playRandom();
  }

  /// Parça değiştiğinde tüm UI notifier'larını tek seferde günceller.
  static void setCurrentTrackData(
      String idStr, String title, String artist, bool isGift) {
    Degiskenler.parcaIndex = int.tryParse(idStr) ?? -1;
    _parcaAdi = title;
    _seslendiren = artist;
    currentSongTitleNotifier.value = title;
    currentSongSubTitleNotifier.value = artist;
    playlistNotifier.value = [title];
    isShareableNotifier.value = !isGift;
  }

  /// Sira_no ile belirli bir parçayı oynat.
  // AudioService içindeki playSong metodu:
  static Future<void> playSong(int siraNo) async {
    _require();
    final currentSira = _handler!.playlistManager.currentSiraNo;
    LogService()
        .info("playSong isteği: $siraNo (Şu anki: $currentSira)", tag: "Audio");

    // Oynatıcı idle (boşta) değilse ve aynı parçaysa sadece devam ettir.
    // Eğer boştaysa (hata almış veya tamamen durmuşsa) yeniden yüklesin.
    if (currentSira == siraNo &&
        _handler!.player.processingState != ProcessingState.idle) {
      LogService().info("Aynı parça tıklandı, oynatılıyor.", tag: "Audio");
      await play();
      return;
    }

    final song = _handler!.playlistManager.findBySiraNo(siraNo);
    if (song != null) {
      LogService().info("Parça bulundu: ${song['parca_adi']}, yükleniyor.",
          tag: "Audio");
      await _handler!._playTrackInternal(song);
    } else {
      LogService().error("HATA: Liste içerisinde sira_no=$siraNo bulunamadı!",
          tag: "Audio");
    }
  }

  /// Deep link / hediye parçasını oynat.
  static Future<void> playGiftTrack(String link, String id) async {
    _require();
    await _handler!.ready;

    LogService().info("playGiftTrack: link=$link, id=$id", tag: "Audio");

    // Zaten bu parça çalıyorsa sadece devam et
    if (_handler!.playlistManager.currentSiraNo.toString() == id) {
      await play();
      return;
    }

    // Ana listede varsa oradan oynat
    final inMain =
        _handler!.playlistManager.findBySiraNoInMain(int.tryParse(id) ?? -1);
    if (inMain != null) {
      _handler!.playlistManager.switchToMainList();
      await _handler!._playTrackInternal(inMain);
      return;
    }

    // API'den tek parça olarak çek
    Degiskenler.hazirlaniyor = true;
    try {
      final response = await MusicApiService().fetchAtesiAskLink(link, id);
      if (response != null && response.containsKey('isaretler')) {
        final item = Map<String, dynamic>.from(response['isaretler'] as Map)
          ..['_isGift'] = true;
        await _handler!._playTrackInternal(item);
      }
    } catch (e, st) {
      LogService().error("playGiftTrack API hatası: $e\n$st", tag: "Audio");
    } finally {
      Degiskenler.hazirlaniyor = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  TEMEL KONTROLLER
  // ══════════════════════════════════════════════════════════

  static Future<void> play() async => _handler?.play();
  static Future<void> pause() async => _handler?.pause();

  static Future<void> playPause() async {
    (_handler?.player.playing ?? false) ? await pause() : await play();
  }

  static Future<void> next() async => _handler?.skipToNext();
  static Future<void> previous() async => _handler?.skipToPrevious();
  static Future<void> seek(Duration position) async => _handler?.seek(position);
  static Future<void> stop() async => _handler?.stop();

  static Future<void> repeat() async {
    await _handler?.setRepeatMode(
      repeatButtonNotifier.value == RepeatState.on
          ? AudioServiceRepeatMode.none
          : AudioServiceRepeatMode.one,
    );
  }

  static Future<void> toggleShuffle() async {
    final enabled = _handler?.playlistManager.isShuffleEnabled ?? false;
    await _handler?.setShuffleMode(
      enabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SES SEVİYESİ (Facade to VolumeManager)
  // ══════════════════════════════════════════════════════════

  static Future<void> setVolume(double volume) async =>
      await VolumeManager.setVolume(volume);

  static Future<void> toggleMute() async => await VolumeManager.toggleMute();

  static Future<void> loadVolume() async => await VolumeManager.loadVolume();

  // ══════════════════════════════════════════════════════════
  //  UYKU ZAMANLAYICISI (Facade to SleepTimerManager)
  // ══════════════════════════════════════════════════════════

  static void startSleepTimer(int minutes) => SleepTimerManager.start(minutes);

  static void cancelSleepTimer() => SleepTimerManager.cancel();

  // ══════════════════════════════════════════════════════════
  //  DISPOSE
  // ══════════════════════════════════════════════════════════

  static Future<void> dispose() async {
    cancelSleepTimer();
    await _handler?.disposeAll();
    await _handler?.stop();
    _handler = null;
  }

  // ══════════════════════════════════════════════════════════
  //  GETTER'LAR
  // ══════════════════════════════════════════════════════════

  static MyAudioHandler? get audioHandler => _handler;
  static bool get isPlaying => _handler?.player.playing ?? false;
  static Duration get currentPosition =>
      _handler?.player.position ?? Duration.zero;
  static Duration get totalDuration =>
      _handler?.player.duration ?? Duration.zero;
  static bool get isShuffleEnabled =>
      _handler?.playlistManager.isShuffleEnabled ?? false;
  static String getCurrentTrackName() => _parcaAdi;
  static String getCurrentTrackArtist() => _seslendiren;

  // ── Yardımcı ───────────────────────────────────────────────
  static void _require() {
    if (_handler == null) {
      throw StateError('AudioService.init() çağrılmadan kullanılamaz.');
    }
  }
}
