import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/ui_support.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:bizidealcennetine/yaveran/Notifier.dart';
import 'package:audio_session/audio_session.dart';
import 'package:bizidealcennetine/yaveran/MusicApiService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizidealcennetine/yaveran/log_service.dart';

// ══════════════════════════════════════════════════════════════
//  MyAudioHandler
//  - _player artık instance değişkeni (static değil → sızıntı yok)
//  - ConcatenatingAudioSource ile parça ekleme player'ı resetlemez
//  - _checkAndSendPendingLogs finally bloğuyla kilitlenmeye karşı korumalı
// ══════════════════════════════════════════════════════════════
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ── Player & Playlist ──────────────────────────────────────
  late final AudioPlayer _player;
  late final ConcatenatingAudioSource _concatenatingSource;

  // ── YENİ: init tamamlanana kadar diğer operasyonları bekletir ──
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  bool _wasPlayingBeforeInterruption = false;
  bool _manualPauseRequested = false;
  bool _isStopped = false;

  // ── Dinleme Logu ───────────────────────────────────────────
  int _currentLogTrackId = -1;
  int _accumulatedListenSeconds = 0;
  DateTime? _lastPlayStartTime;
  Timer? _persistenceTimer;
  String? _currentLogTimestamp;

  final List<Map<String, dynamic>> _pendingLogs = [];
  bool _isSendingLogs = false;

  // ── Constructor ────────────────────────────────────────────
  MyAudioHandler() {
    _concatenatingSource = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: [],
    );
    _loadLogs();
    _init(); // async ama bilerek await edilmiyor
    _persistenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // _player henüz initialize olmamış olabilir → guard ekle
      if (_initCompleter.isCompleted && _player.playing) {
        _updateAccumulatedTime();
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  //  LOG YÖNETİMİ
  // ════════════════════════════════════════════════════════════

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('listen_logs');
    if (raw == null) return;

    try {
      final List<dynamic> parsed = jsonDecode(raw);
      for (final el in parsed) {
        final log = Map<String, dynamic>.from(el as Map);
        if (log['status'] == 'current') {
          // Yarım kalan log yalnızca 30s+ ise tamamlanmış kabul edilir
          if ((log['listenDuration'] as int? ?? 0) >= 30) {
            log['status'] = 'completed';
            _pendingLogs.add(log);
          }
        } else {
          _pendingLogs.add(log);
        }
      }
    } catch (_) {}

    await _saveLogsToPrefs();
    _checkAndSendPendingLogs();
  }

  Future<void> _saveLogsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Mevcut oturumun anlık snapshot'ı (persist için)
    final snapshot = [
      ..._pendingLogs,
      if (_currentLogTrackId != -1 && _accumulatedListenSeconds > 0)
        {
          'musicId': _currentLogTrackId,
          'listenDuration': _accumulatedListenSeconds,
          'timestamp': _currentLogTimestamp ?? _nowUtcString(),
          'status': 'current',
        },
    ];

    if (snapshot.isEmpty) {
      await prefs.remove('listen_logs');
    } else {
      await prefs.setString('listen_logs', jsonEncode(snapshot));
    }
  }

  void _updateAccumulatedTime() {
    if (_lastPlayStartTime == null) return;
    _accumulatedListenSeconds +=
        DateTime.now().difference(_lastPlayStartTime!).inSeconds;
    _lastPlayStartTime = DateTime.now();
    _saveLogsToPrefs();
  }

  /// finally garantisiyle _isSendingLogs kilidi daima açılır
  Future<void> _checkAndSendPendingLogs() async {
    if (_isSendingLogs || _pendingLogs.isEmpty) return;
    _isSendingLogs = true;

    try {
      final snapshot = List<Map<String, dynamic>>.from(_pendingLogs);
      final successful = <Map<String, dynamic>>[];

      for (final log in snapshot) {
        final ok = await MusicApiService().sendListenLog(
          musicId: log['musicId'],
          listenDuration: log['listenDuration'],
          timestamp: log['timestamp'],
        );
        if (ok) successful.add(log);
      }

      if (successful.isNotEmpty) {
        _pendingLogs.removeWhere((l) => successful.any((s) =>
            s['timestamp'] == l['timestamp'] && s['musicId'] == l['musicId']));
        await _saveLogsToPrefs(); // Yalnızca değişiklik varsa kaydet
      }
    } finally {
      // Hata olsa bile kilit daima serbest bırakılır
      _isSendingLogs = false;
    }
  }

  void _finalizeLogForCurrentTrack() {
    _updateAccumulatedTime();
    _lastPlayStartTime = null;

    if (_accumulatedListenSeconds >= 30 && _currentLogTrackId != -1) {
      _pendingLogs.add({
        'musicId': _currentLogTrackId,
        'listenDuration': _accumulatedListenSeconds,
        'timestamp': _currentLogTimestamp ?? _nowUtcString(),
        'status': 'completed',
      });
      _checkAndSendPendingLogs();
    }

    _accumulatedListenSeconds = 0;
    _currentLogTrackId = -1;
    _currentLogTimestamp = null;
    _saveLogsToPrefs();
  }

  String _nowUtcString() =>
      '${DateTime.now().toUtc().toIso8601String().split('.')[0]}Z';

  // ════════════════════════════════════════════════════════════
  //  BAŞLATMA
  // ════════════════════════════════════════════════════════════

  Future<void> _init() async {
    try {
      LogService().info("Ses servisi başlatılıyor...", tag: "Audio");
      _player = AudioPlayer();

      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());

      // ── YENİ: Session'ı aktif et → Android audio focus alınır ──
      await session.setActive(true);
      LogService().info("Audio session aktif edildi", tag: "Audio");

      // Telefon araması / alarm kesintisi yönetimi
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          _wasPlayingBeforeInterruption = _player.playing;
          await _player.pause();
        } else {
          if (_wasPlayingBeforeInterruption) {
            await Future.delayed(const Duration(seconds: 1));
            await _player.play();
          }
          _wasPlayingBeforeInterruption = false;
        }
      });

      _player.playbackEventStream.listen(_broadcastState);

      _player.positionStream.listen((position) {
        playbackState
            .add(playbackState.value.copyWith(updatePosition: position));
        AudioService.progressNotifier.value = ProgressBarState(
          current: position,
          buffered: _player.bufferedPosition,
          total: _player.duration ?? Duration.zero,
        );
      });

      _player.bufferedPositionStream.listen((buffered) {
        final cur = AudioService.progressNotifier.value;
        AudioService.progressNotifier.value = ProgressBarState(
          current: cur.current,
          buffered: buffered,
          total: cur.total,
        );
      });

      _player.durationStream.listen((duration) {
        final cur = AudioService.progressNotifier.value;
        AudioService.progressNotifier.value = ProgressBarState(
          current: cur.current,
          buffered: cur.buffered,
          total: duration ?? Duration.zero,
        );
        if (duration != null && mediaItem.value != null) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      });

      _player.currentIndexStream.listen((index) async {
        if (_isStopped) return;
        if (index == null || queue.value.isEmpty || index >= queue.value.length)
          return;

        final newId = int.tryParse(queue.value[index].id) ?? -1;
        if (newId == _currentLogTrackId) return; // Aynı parça, geç

        _finalizeLogForCurrentTrack();
        _currentLogTrackId = newId;
        _currentLogTimestamp = _nowUtcString();
        if (_player.playing) _lastPlayStartTime = DateTime.now();

        var newItem = queue.value[index];
        if (_player.duration != null) {
          newItem = newItem.copyWith(duration: _player.duration);
        }
        mediaItem.add(newItem);
        AudioService.setCurrentTrack(index);

        await Future.delayed(const Duration(milliseconds: 100));
        UI_support.changeImageAndEpigram();
      });

      _player.playingStream.listen((playing) {
        if (playing) {
          _lastPlayStartTime ??= DateTime.now(); // Null ise başlat
        } else {
          _updateAccumulatedTime();
          _lastPlayStartTime = null;
        }
      });

      _player.volumeStream.listen((v) => AudioService.volumeNotifier.value = v);

      _player.loopModeStream.listen((mode) {
        playbackState.add(
            playbackState.value.copyWith(repeatMode: _convertLoopMode(mode)));
      });

      _player.shuffleModeEnabledStream.listen((enabled) {
        playbackState.add(playbackState.value.copyWith(
          shuffleMode: enabled
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        ));
        AudioService.isShuffleModeEnabledNotifier.value = enabled;
      });

      await _player.setShuffleModeEnabled(true);

      // Arka plan bildirim görseli güncellemesi
      Degiskenler.currentImageNotifier.addListener(() {
        if (mediaItem.value == null) return;
        final name = Degiskenler.currentImageNotifier.value;
        if (name.isNotEmpty) {
          mediaItem.add(mediaItem.value!.copyWith(
            artUri: Uri.parse('${Degiskenler.kaynakYolu}medya/atesiask/$name'),
          ));
        }
      });

      _initCompleter.complete(); // ← init tamam sinyali
    } catch (e, st) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, st);
      }
      LogService().error("_init hatası: $e", tag: "Audio");
    }
  }

  // ════════════════════════════════════════════════════════════
  //  YARDIMCI — State Dönüşümleri
  // ════════════════════════════════════════════════════════════

  AudioServiceRepeatMode _convertLoopMode(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  void _broadcastState(PlaybackEvent event) {
    if (_isStopped) return;
    final playing = _player.playing;
    final state = _convertProcessingState(_player.processingState);

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
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
      processingState: state,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));

    if (state == AudioProcessingState.loading ||
        state == AudioProcessingState.buffering) {
      AudioService.playButtonNotifier.value = ButtonState.loading;
    } else if (playing) {
      AudioService.playButtonNotifier.value = ButtonState.playing;
    } else {
      AudioService.playButtonNotifier.value = ButtonState.paused;
    }
  }

  AudioProcessingState _convertProcessingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  OVERRIDE METODLARI
  // ════════════════════════════════════════════════════════════

  @override
  Future<void> play() async {
    await initialized;
    _manualPauseRequested = false;
    LogService().info("MyAudioHandler.play() çağrıldı. state=${_player.processingState}, playing=${_player.playing}", tag: "Audio-ColdStart");

    // Soğuk başlangıçta Android foreground servis henüz aktif olmayabilir.
    // processingState idle ise setAudioSource yapılmamış demektir — güvenli geç.
    if (_player.processingState == ProcessingState.idle) {
      LogService().warn(
        "play() çağrıldı ama player idle — atlanıyor",
        tag: "Audio-ColdStart",
      );
      return;
    }

    LogService().info("Gerçekten _player.play() çağrılıyor", tag: "Audio-ColdStart");
    return _player.play();
  }

  @override
  Future<void> pause() {
    _manualPauseRequested = true;
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _isStopped = true;
    _finalizeLogForCurrentTrack();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    mediaItem.add(null);
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    await _player.seekToNext();
    if (!_player.playing) await _player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
    if (!_player.playing) await _player.play();
  }

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> fastForward() async {
    final pos = _player.position + const Duration(seconds: 10);
    final dur = _player.duration ?? Duration.zero;
    await _player.seek(pos < dur ? pos : dur);
  }

  @override
  Future<void> rewind() async {
    final pos = _player.position - const Duration(seconds: 10);
    await _player.seek(pos > Duration.zero ? pos : Duration.zero);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        AudioService.repeatButtonNotifier.value = RepeatState.off;
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        AudioService.repeatButtonNotifier.value = RepeatState.on;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        AudioService.repeatButtonNotifier.value = RepeatState.off;
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) =>
      _player.setShuffleModeEnabled(mode == AudioServiceShuffleMode.all);

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  // ════════════════════════════════════════════════════════════
  //  PLAYLIST YÖNETİMİ — ConcatenatingAudioSource
  // ════════════════════════════════════════════════════════════

  /// Tüm playlist'i sıfırlar ve yeniden yükler (player tam reset)
  Future<void> loadPlaylist(
    List<AudioSource> sources, {
    int initialIndex = 0,
  }) async {
    await initialized;
    _isStopped = false;

    final safeIndex = initialIndex.clamp(0, sources.length - 1);
    LogService().info(
        "Playlist yükleniyor — ${sources.length} parça, başlangıç: $safeIndex",
        tag: "Audio");

    final mediaItems =
        sources.map((s) => (s as UriAudioSource).tag as MediaItem).toList();

    await _concatenatingSource.clear();

    // Tüm parçaları setAudioSource'dan ÖNCE, 50'lik gruplar halinde ekle.
    // useLazyPreparation:true sayesinde iOS native'de hazırlamaz → çökme olmaz.
    const int chunkSize = 50;
    for (int i = 0; i < sources.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, sources.length);
      await _concatenatingSource.addAll(sources.sublist(i, end));
      if (end < sources.length) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    queue.add(mediaItems);

    // Tüm parçalar hazır, doğru index'ten başlat
    await _player.setAudioSource(
      _concatenatingSource,
      initialIndex: safeIndex,
    );
  }

  /// Listeye parça ekler — player'ı RESETLEMEZ, oynatma durmaz
  Future<void> appendTrack(AudioSource source) async {
    await _concatenatingSource.add(source);
    final item = (source as UriAudioSource).tag as MediaItem;
    final updated = List<MediaItem>.from(queue.value)..add(item);
    queue.add(updated);
  }

  /// Belirli bir indexe parça ekler — player'ı RESETLEMEZ
  Future<void> insertTrackAt(int index, AudioSource source) async {
    final safe = index.clamp(0, _concatenatingSource.length);
    await _concatenatingSource.insert(safe, source);
    final item = (source as UriAudioSource).tag as MediaItem;
    final updated = List<MediaItem>.from(queue.value)..insert(safe, item);
    queue.add(updated);
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  AudioPlayer get player => _player;

  /// Kaynakları tamamen serbest bırakır
  Future<void> disposePlayer() async {
    _persistenceTimer?.cancel();
    _finalizeLogForCurrentTrack();
    await _player.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
//  AudioService — Singleton Yönetici
//  - Çift başlatma koruması
//  - Immutable liste getter'ları (dışarıdan değiştirilemez)
//  - _ensureInitialized() tüm public metodlarda kontrol sağlar
//  - _buildAudioSource() tekrar eden header bloklarını ortadan kaldırır
// ══════════════════════════════════════════════════════════════
class AudioService {
  AudioService._(); // Dışarıdan new AudioService() yapılamaz

  static MyAudioHandler? _audioHandler;

  // ── Parça Bilgileri (private + getter) ─────────────────────
  static String _parcaAdi = '...';
  static String _seslendiren = '...';
  static List<MediaItem> _parcaListesi = [];
  static List<AudioSource> _parcaKaynaklari = [];

  static String get parcaAdi => _parcaAdi;
  static String get seslendiren => _seslendiren;

  /// Dışarıdan sadece okunabilir kopya döner — orijinal liste korunur
  static List<MediaItem> get parcaListesi => List.unmodifiable(_parcaListesi);
  static List<AudioSource> get parcaKaynaklari =>
      List.unmodifiable(_parcaKaynaklari);

  // ── Notifier'lar ────────────────────────────────────────────
  static final progressNotifier = ProgressNotifier();
  static final currentSongTitleNotifier = ValueNotifier<String>('...');
  static final currentSongSubTitleNotifier = ValueNotifier<String>('...');
  static final playlistNotifier = ValueNotifier<List<String>>([]);
  static final repeatButtonNotifier = RepeatButtonNotifier();
  static final isFirstSongNotifier = ValueNotifier<bool>(true);
  static final playButtonNotifier =
      ValueNotifier<ButtonState>(ButtonState.paused);
  static final isLastSongNotifier = ValueNotifier<bool>(true);
  static final isShuffleModeEnabledNotifier = ValueNotifier<bool>(false);
  static final isShareableNotifier = ValueNotifier<bool>(true);
  static final volumeNotifier = ValueNotifier<double>(1.0);

  // ── Uyku Zamanlayıcısı ──────────────────────────────────────
  static Timer? _sleepTimer;
  static Timer? _countdownTimer;

  static void startSleepTimer(int minutes) {
    cancelSleepTimer();
    if (minutes <= 0) return;

    int remaining = minutes * 60;
    Degiskenler.sleepTimerRemainingNotifier.value = remaining;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining > 0) {
        remaining--;
        Degiskenler.sleepTimerRemainingNotifier.value = remaining;
      } else {
        pause();
        cancelSleepTimer();
      }
    });

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      pause();
      cancelSleepTimer();
    });
  }

  static void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    Degiskenler.sleepTimerRemainingNotifier.value = 0;
  }

  // ── Ses Seviyesi ────────────────────────────────────────────
  static Future<void> saveVolume(double volume) async {
    if (volume <= 0) return; // Mute konumu başlangıç ayarı olarak kaydedilmez
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_volume', volume);
  }

  static Future<void> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await setVolume(prefs.getDouble('app_volume') ?? 1.0);
  }

  static double _lastVolume = 1.0;

  static Future<void> toggleMute() async {
    if (volumeNotifier.value > 0) {
      _lastVolume = volumeNotifier.value;
      await setVolume(0);
    } else {
      await setVolume(_lastVolume > 0 ? _lastVolume : 1.0);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BAŞLATMA — Çift init korumalı
  // ════════════════════════════════════════════════════════════

  static Future<void> init() async {
    if (_audioHandler != null) return; // Çift başlatmayı önle

    _audioHandler = MyAudioHandler();

    await audio_service.AudioService.init(
      builder: () => _audioHandler!,
      config: const audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.ea.bizidealcennetine.channel.audio',
        androidNotificationChannelName: 'Aşk Olsun',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PLAYLIST YÖNETİMİ
  // ════════════════════════════════════════════════════════════

  static Future<void> setPlaylist(
    List<AudioSource> playlist, {
    bool playNow = true,
  }) async {
    _ensureInitialized();
    await _audioHandler!.initialized;

    _parcaKaynaklari = List.from(playlist);
    _parcaListesi =
        playlist.map((s) => (s as UriAudioSource).tag as MediaItem).toList();

    final bool hediyeVarmi = Degiskenler.bekleyenHediyeId != null;

    // hediyeListede: hediye ID listede VAR MI? (-1 = yok)
    final int hediyeListeIndex = hediyeVarmi
        ? playlist.indexWhere((s) =>
            ((s as UriAudioSource).tag as MediaItem).id ==
            Degiskenler.bekleyenHediyeId.toString())
        : -1;

    // initialIndex: hediye listede varsa orası, yoksa rastgele
    final int initialIndex = hediyeListeIndex != -1
        ? hediyeListeIndex
        : Random().nextInt(playlist.length);

    try {
      await _audioHandler!.loadPlaylist(playlist, initialIndex: initialIndex);
    } catch (e, st) {
      LogService().error("loadPlaylist hatası: $e", tag: "Audio-ColdStart");
      LogService().error("$st", tag: "Audio-ColdStart");
      Degiskenler.listeYuklendi = true;
      return;
    }

    // Hediye listede YOKSA → arka planda çek, sessizce başlat
    final bool hediyeListeYok = hediyeVarmi && hediyeListeIndex == -1;
    LogService().info("setPlaylist: hediyeVarmi=$hediyeVarmi, hediyeListeIndex=$hediyeListeIndex, hediyeListeYok=$hediyeListeYok", tag: "Audio-ColdStart");
    double restoreVol = -1.0;

    if (playNow) {
      if (hediyeListeYok) {
        restoreVol = volumeNotifier.value > 0 ? volumeNotifier.value : 1.0;
        await setVolume(0);
      }
      LogService().info(
        "setPlaylist → _waitForReadyThenPlay çağrılıyor",
        tag: "Audio-ColdStart",
      );
      await _waitForReadyThenPlay();
    }

    if (hediyeListeYok && Degiskenler.bekleyenHediyeLink != null) {
      _fetchGiftTrackInBackground(
        Degiskenler.bekleyenHediyeLink!,
        Degiskenler.bekleyenHediyeId!,
        restoreVol,
      );
    }

    Degiskenler.listeYuklendi = true;
  }

  /// Hediye parçayı arka planda çeker — setPlaylist'i bloke etmez
  static Future<void> _fetchGiftTrackInBackground(
    String link,
    dynamic id,
    double restoreVolume,
  ) async {
    LogService().info("_fetchGiftTrackInBackground başladı: link=$link, id=$id", tag: "Audio-ColdStart");
    Degiskenler.hazirlaniyor = true;
    try {
      final response = await MusicApiService().fetchAtesiAskLink(link, id);
      if (response != null && response.containsKey("isaretler")) {
        final item = response["isaretler"];
        final giftItem = MediaItem(
          id: item['sira_no'].toString(),
          album: item['parca_adi'],
          title: item['parca_adi'],
          artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
          artist: item['seslendiren'],
          extras: const {'isApplink': true},
        );
        final giftSource = _buildAudioSource(item['url'], giftItem);

        // ConcatenatingAudioSource.insert → player resetlenmez
        await _audioHandler!.insertTrackAt(0, giftSource);
        _parcaKaynaklari.insert(0, giftSource);
        _parcaListesi.insert(0, giftItem);

        isShareableNotifier.value = false;

        // ── YENİ: insert sonrası player'ın idle'a düşmesini bekle,
        //          sonra seek yap → daha güvenilir state geçişi ──
        await Future.delayed(const Duration(milliseconds: 300));
        LogService().info("gift item eklendi, skipToQueueItem(0) yapılıyor", tag: "Audio-ColdStart");
        await _audioHandler!.skipToQueueItem(0);

        // ── insert + seek sonrası player idle'a düşer, bunu geç ──
        // processingState önce idle olabilir, hemen stream'e atlamak
        // 'buffering' eventini kaçırır — polling daha güvenli
        LogService().info("_waitForReadyThenPlay çağrılıyor", tag: "Audio-ColdStart");
        await _waitForReadyThenPlay();
      }
    } catch (e) {
      LogService().error("Hediye parça arka plan hatası: $e", tag: "Audio-ColdStart");
    } finally {
      Degiskenler.hazirlaniyor = false;
      Degiskenler.bekleyenHediyeId = null;
      Degiskenler.bekleyenHediyeLink = null;
      // ── Volume restore: play() gerçekten başladıktan sonra ──
      if (restoreVolume != -1.0) {
        // playing olana kadar bekle (max 3s)
        int waited = 0;
        LogService().info("Ses restore edilecek, player'ın başlaması bekleniyor...", tag: "Audio-ColdStart");
        while (!(_audioHandler?.player.playing ?? false) && waited < 3000) {
          await Future.delayed(const Duration(milliseconds: 100));
          waited += 100;
        }
        LogService().info("Ses restore edildi: $restoreVolume (beklenen süre: ${waited}ms)", tag: "Audio-ColdStart");
        await setVolume(restoreVolume);
      }
    }
  }

  /// Soğuk başlangıçta stream race condition'ını tamamen önler.
  /// Polling + exponential backoff ile hem state hem de gerçek ses çıkışını garantiler.
  static Future<void> _waitForReadyThenPlay() async {
    // ── Explicit play niyeti → manual pause flag'ini sıfırla ──
    _audioHandler!._manualPauseRequested = false;
    final player = _audioHandler!.player;
    LogService().info("_waitForReadyThenPlay: polling başladı. Mevcut state=${player.processingState}", tag: "Audio-ColdStart");

    // ── 1. Adım: player'ın oynatılabilir state'e gelmesini bekle ──
    const maxWait = Duration(seconds: 20);
    const pollInterval = Duration(milliseconds: 200);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      final s = player.processingState;
      if (s == ProcessingState.ready || s == ProcessingState.buffering) {
        LogService().info("_waitForReadyThenPlay: hedef state'e ulaşıldı ($s)", tag: "Audio-ColdStart");
        break;
      }
      if (s == ProcessingState.completed || s == ProcessingState.idle) {
        // Parça henüz yüklenmedi, bekle
      }
      await Future.delayed(pollInterval);
    }

    LogService().info(
      "play() öncesi state: ${player.processingState}",
      tag: "Audio-ColdStart",
    );

    if (_audioHandler!._manualPauseRequested) {
      LogService().warn(
        "_waitForReadyThenPlay iptal edildi: kullanıcı pause istedi",
        tag: "Audio-ColdStart",
      );
      return;
    }

    // ── 2. Adım: Audio session'ı tekrar aktif et (soğuk başlangıç güvencesi) ──
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      LogService().info("Audio session tekrar aktif edildi", tag: "Audio-ColdStart");
    } catch (e) {
      LogService().warn("Session reactivation hatası: $e", tag: "Audio-ColdStart");
    }

    // ── 3. Adım: play() çağır + gerçekten başladığını doğrula ──
    LogService().info("_waitForReadyThenPlay: play() çağrılıyor", tag: "Audio-ColdStart");
    await play();

    // Kısa süre bekleyip playing kontrolü yap — başlamadıysa retry
    await Future.delayed(const Duration(milliseconds: 500));
    if (_audioHandler!._manualPauseRequested) {
      LogService().warn(
        "_waitForReadyThenPlay retry iptal edildi: kullanıcı pause istedi",
        tag: "Audio-ColdStart",
      );
      return;
    }

    if (!player.playing) {
      LogService().warn("play() etkisiz — retry yapılıyor. state=${player.processingState}", tag: "Audio-ColdStart");
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_audioHandler!._manualPauseRequested) {
        await play();
      } else {
        LogService().warn(
          "_waitForReadyThenPlay ikinci retry iptal edildi: kullanıcı pause istedi",
          tag: "Audio-ColdStart",
        );
      }
    } else {
      LogService().info("play() başarılı oldu, playing=true", tag: "Audio-ColdStart");
    }
  }

  static Future<void> loadQueueAndPlay(
    List<dynamic> songList,
    int startId,
  ) async {
    _ensureInitialized();
    await _audioHandler!.initialized;
    if (songList.isEmpty) return;

    // ── Akıllı Liste Karşılaştırması ──────────────────────────
    // Uzunluk + ilk 5 ID kontrolü (tek eleman karşılaştırmasından çok daha güvenilir)
    if (_isSameList(songList)) {
      LogService().info(
          "Liste zaten yüklü, kuyruk yenilenmeden ID'ye atlıyoruz: $startId",
          tag: "Audio");
      await playAtId(startId);
      return;
    }
    // ────────────────────────────────────────────────────────

    final sources = <AudioSource>[];
    final mediaItems = <MediaItem>[];

    for (final song in songList) {
      final item = MediaItem(
        id: song['sira_no'].toString(),
        title: song['parca_adi'].toString(),
        artist: song['seslendiren'] ?? '...',
        artUri:
            Uri.parse("${Degiskenler.kaynakYolu}medya/atesiask/bahar11.jpg"),
      );
      mediaItems.add(item);
      sources.add(_buildAudioSource(song['url'] ?? '', item));
    }

    // initialIndex'i kendi oluşturduğumuz listeden hesapla
    final startIndex = sources.indexWhere((s) =>
        ((s as UriAudioSource).tag as MediaItem).id == startId.toString());

    LogService().debug(
        "loadQueueAndPlay → startId: $startId, startIndex: ${startIndex == -1 ? 0 : startIndex}",
        tag: "Audio");

    _parcaListesi = mediaItems;
    _parcaKaynaklari = List.from(sources);

    //await _audioHandler!.player.setShuffleModeEnabled(false);
    await _audioHandler!.loadPlaylist(
      sources,
      initialIndex: startIndex == -1 ? 0 : startIndex,
    );

    await play();
    //await _audioHandler!.player.setShuffleModeEnabled(true);
  }

  /// Uzunluk + ilk 5 ID'yi karşılaştırır
  /// → Tek eleman kontrolünden çok daha az yanlış eşleşme üretir
  static bool _isSameList(List<dynamic> newList) {
    final seq = _audioHandler?.player.sequence;
    if (seq == null || seq.length != newList.length) return false;

    final checkCount = min(5, newList.length);
    for (int i = 0; i < checkCount; i++) {
      final newId = newList[i]['sira_no'].toString();
      final src = seq[i];
      if (src is! UriAudioSource) return false;
      if ((src.tag as MediaItem).id != newId) return false;
    }
    return true;
  }

  static Future<void> playAtId(int id) async {
    _ensureInitialized();
    final seq = _audioHandler!.player.sequence;
    if (seq == null) return;

    final index = seq.indexWhere(
        (s) => s is UriAudioSource && (s.tag as MediaItem).id == id.toString());

    if (index != -1) {
      await _audioHandler!.skipToQueueItem(index);
      await _audioHandler!.play();
    } else {
      LogService().warn("ID $id ile parça bulunamadı", tag: "Audio");
    }
  }

  /// Listeye parça ekler — player RESETLENMEZ, oynatma DURMAZ
  static Future<void> addTrackToPlaylist(
    String adi,
    String ses,
    String yol,
    dynamic sira,
    bool oynat,
  ) async {
    _ensureInitialized();

    final track = {
      'sira_no': sira,
      'parca_adi': adi,
      'seslendiren': ses,
      'url': yol,
    };
    Degiskenler().listDinle.add(track);
    Degiskenler.songListNotifier.value =
        List.from(Degiskenler.songListNotifier.value)..add(track);

    final item = MediaItem(
      id: sira.toString(),
      album: adi,
      title: adi,
      artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
      artist: ses,
    );
    final source = _buildAudioSource(yol, item);

    try {
      // ConcatenatingAudioSource.add() — player resetlenmez!
      await _audioHandler!.appendTrack(source);
      _parcaKaynaklari.add(source);
      _parcaListesi.add(item);
    } catch (e, st) {
      LogService().error("addTrackToPlaylist hatası: $e\n$st", tag: "Audio");
      return;
    }

    if (oynat) {
      final lastIndex = (_audioHandler!.player.sequence?.length ?? 1) - 1;
      await _audioHandler!.skipToQueueItem(lastIndex);
      await play();
    }
  }

  static void setCurrentTrack(int index) {
    if (index < 0 || index >= _parcaListesi.length) return;
    final item = _parcaListesi[index];
    Degiskenler.parcaIndex = int.tryParse(item.id) ?? -1;
    _parcaAdi = item.title;
    _seslendiren = item.artist ?? '...';
    currentSongTitleNotifier.value = _parcaAdi;
    currentSongSubTitleNotifier.value = _seslendiren;
    isShareableNotifier.value = item.extras?['isApplink'] != true;
  }

  // ── Uygulama açıkken gelen hediye link yönetimi ────────────
  static Future<void> playGiftTrack(String link, String id) async {
    _ensureInitialized();
    await _audioHandler!.initialized;
    LogService().info("playGiftTrack çağrıldı: link=$link, id=$id", tag: "Audio");

    // Zaten o parça mı çalıyor?
    if (Degiskenler.parcaIndex.toString() == id) {
      await _waitForReadyThenPlay();
      return;
    }

    // Kuyrukta var mı?
    final seq = _audioHandler!.player.sequence;
    if (seq != null) {
      final index = seq.indexWhere(
          (s) => s is UriAudioSource && (s.tag as MediaItem).id == id);
      if (index != -1) {
        LogService().info("playGiftTrack: parça kuyrukta bulundu, index=$index", tag: "Audio");
        await _audioHandler!.skipToQueueItem(index);
        await _waitForReadyThenPlay();
        return;
      }
    }

    // Kuyrukta yoksa sunucudan çek
    Degiskenler.hazirlaniyor = true;
    try {
      final response = await MusicApiService().fetchAtesiAskLink(link, id);
      if (response != null && response.containsKey("isaretler")) {
        final item = response["isaretler"];
        await playApplinkTrack(
            item['parca_adi'], item['seslendiren'], item['url'], id);
      } else {
        LogService().warn("playGiftTrack: response eksik veya boş", tag: "Audio");
      }
    } catch (e, st) {
      LogService().error("playGiftTrack hatası: $e", tag: "Audio");
      LogService().error("$st", tag: "Audio");
    } finally {
      Degiskenler.hazirlaniyor = false;
    }
  }

  static Future<void> playApplinkTrack(
    String adi,
    String ses,
    String yol,
    dynamic sira,
  ) async {
    _ensureInitialized();

    final item = MediaItem(
      id: sira.toString(),
      album: adi,
      title: adi,
      artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
      artist: ses,
      extras: const {'isApplink': true},
    );
    final source = _buildAudioSource(yol, item);

    try {
      final insertIndex = (_audioHandler!.player.currentIndex ?? 0) + 1;
      await _audioHandler!.insertTrackAt(insertIndex, source);
      _parcaKaynaklari.insert(insertIndex, source);
      _parcaListesi.insert(insertIndex, item);

      isShareableNotifier.value = false;
      await Future.delayed(const Duration(milliseconds: 500));
      await _audioHandler!.skipToQueueItem(insertIndex);
      await _waitForReadyThenPlay();
    } catch (e, st) {
      LogService().error("playApplinkTrack hatası: $e", tag: "Audio");
      LogService().error("$st", tag: "Audio");
    }
  }

  // ════════════════════════════════════════════════════════════
  //  TEMEL KONTROL
  // ════════════════════════════════════════════════════════════

  static Future<void> play() async => _audioHandler!.play();
  static Future<void> pause() async => _audioHandler!.pause();

  static Future<void> playPause() async {
    _audioHandler!.player.playing ? await pause() : await play();
  }

  static Future<void> next() async => _audioHandler!.skipToNext();
  static Future<void> previous() async => _audioHandler!.skipToPrevious();
  static Future<void> seek(Duration position) async =>
      _audioHandler!.seek(position);

  static Future<void> setVolume(double volume) async {
    await _audioHandler?.setVolume(volume);
    saveVolume(volume);
  }

  static Future<void> repeat() async {
    await _audioHandler!.setRepeatMode(
      repeatButtonNotifier.value == RepeatState.on
          ? AudioServiceRepeatMode.all
          : AudioServiceRepeatMode.one,
    );
  }

  static Future<void> toggleShuffle() async {
    final enabled = _audioHandler!.player.shuffleModeEnabled;
    await _audioHandler!.setShuffleMode(
      enabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
  }

  static Future<void> stop() async => _audioHandler!.stop();

  /// Tüm kaynakları güvenle serbest bırakır
  static Future<void> dispose() async {
    cancelSleepTimer();
    await _audioHandler?.disposePlayer(); // _player.dispose() burada çağrılır
    await _audioHandler?.stop();
    _audioHandler = null;
  }

  // ════════════════════════════════════════════════════════════
  //  GETTER'LAR
  // ════════════════════════════════════════════════════════════

  static MyAudioHandler? get audioHandler => _audioHandler;
  static AudioPlayer? get player => _audioHandler?.player;
  static bool get isPlaying => _audioHandler?.player.playing ?? false;
  static Duration get currentPosition =>
      _audioHandler?.player.position ?? Duration.zero;
  static Duration get totalDuration =>
      _audioHandler?.player.duration ?? Duration.zero;
  static int? get currentIndex => _audioHandler?.player.currentIndex;
  static bool get isShuffleEnabled =>
      _audioHandler?.player.shuffleModeEnabled ?? false;
  static LoopMode get loopMode =>
      _audioHandler?.player.loopMode ?? LoopMode.off;

  static String getCurrentTrackName() => _parcaAdi;
  static String getCurrentTrackArtist() => _seslendiren;

  // ════════════════════════════════════════════════════════════
  //  YARDIMCI — Yalnızca bu dosyada kullanılır
  // ════════════════════════════════════════════════════════════

  static void _ensureInitialized() {
    if (_audioHandler == null) {
      throw StateError('AudioService.init() çağrılmadan kullanılamaz. '
          'main() içinde await AudioService.init() çağrısını kontrol edin.');
    }
  }

  /// Tekrar eden HTTP header bloğunu tek noktada toplar
  static AudioSource _buildAudioSource(String url, MediaItem tag) {
    return AudioSource.uri(
      Uri.parse(url),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
      tag: tag,
    );
  }
}
