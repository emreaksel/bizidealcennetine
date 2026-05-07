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
// ══════════════════════════════════════════════════════════════
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ── Player & Playlist ──────────────────────────────────────
  late final AudioPlayer _player;
  late ConcatenatingAudioSource _concatenatingSource;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  bool _wasPlayingBeforeInterruption = false;
  bool _manualPauseRequested = false;
  bool _isStopped = false;
  DateTime? _suppressIndexEventsUntil;

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
    _loadLogs();
    _init(); // async ama bilerek await edilmiyor
    _persistenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
        await _saveLogsToPrefs();
      }
    } finally {
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
      await session.setActive(true);
      LogService().info("Audio session aktif edildi", tag: "Audio");

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
        // Yükleme sırasında ara index emitlerini yoksay
        if (AudioService.playlistLoadingNotifier.value) return;

        // loadPlaylist sonrası kısa süre sahte event'leri bastır
        if (_suppressIndexEventsUntil != null &&
            DateTime.now().isBefore(_suppressIndexEventsUntil!)) return;

        if (index == null || queue.value.isEmpty || index >= queue.value.length)
          return;

        final newId = int.tryParse(queue.value[index].id) ?? -1;
        if (newId == _currentLogTrackId) return;

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
          _lastPlayStartTime ??= DateTime.now();
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

      Degiskenler.currentImageNotifier.addListener(() {
        if (mediaItem.value == null) return;
        final name = Degiskenler.currentImageNotifier.value;
        if (name.isNotEmpty) {
          mediaItem.add(mediaItem.value!.copyWith(
            artUri: Uri.parse('${Degiskenler.kaynakYolu}medya/atesiask/$name'),
          ));
        }
      });

      _initCompleter.complete();
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

    if (!Degiskenler.listeYuklendi &&
        !Degiskenler.hazirlaniyor &&
        !AudioService.playlistLoadingNotifier.value) {
      LogService().info(
          "Oynat tuşuna basıldı ancak liste yüklü değil, sistem yenileniyor...",
          tag: "Audio");
      Degiskenler.showSplashNotifier.value = true;
      return;
    }

    LogService().info(
        "MyAudioHandler.play() çağrıldı. state=${_player.processingState}, playing=${_player.playing}",
        tag: "Audio-ColdStart");

    if (_player.processingState == ProcessingState.idle) {
      LogService().warn(
        "play() çağrıldı ama player idle — atlanıyor",
        tag: "Audio-ColdStart",
      );
      return;
    }

    LogService()
        .info("Gerçekten _player.play() çağrılıyor", tag: "Audio-ColdStart");
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

    LogService().info("Ses servisi durduruluyor ve sistem sıfırlanıyor...",
        tag: "Audio");

    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [],
    ));
    mediaItem.add(null);
    queue.add([]); // Kuyruğu temizle

    // Player'ı durdur
    await _player.stop();

    // Sistem durumunu sıfırla
    Degiskenler.listeYuklendi = false;
    Degiskenler.parcaIndex = -1;
    Degiskenler.songListNotifier.value = [];
    Degiskenler().listDinle = [];

    // UI'daki şarkı isimlerini sıfırla
    AudioService.currentSongTitleNotifier.value = '...';
    AudioService.currentSongSubTitleNotifier.value = '...';

    await super.stop();

    LogService().info(
        "Sistem tamamen sıfırlandı, yeni bir işlem yapıldığında yenilenecek.",
        tag: "Audio");
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (!Degiskenler.listeYuklendi &&
        !Degiskenler.hazirlaniyor &&
        !AudioService.playlistLoadingNotifier.value) {
      Degiskenler.showSplashNotifier.value = true;
      return;
    }
    await _player.seekToNext();
    if (!_player.playing) await _player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!Degiskenler.listeYuklendi &&
        !Degiskenler.hazirlaniyor &&
        !AudioService.playlistLoadingNotifier.value) {
      Degiskenler.showSplashNotifier.value = true;
      return;
    }
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
  //  PLAYLIST YÖNETİMİ
  // ════════════════════════════════════════════════════════════

  Future<void> loadPlaylist(
    List<AudioSource> sources, {
    int initialIndex = 0,
  }) async {
    AudioService.playlistLoadingNotifier.value = true;
    await Future.delayed(const Duration(milliseconds: 50));

    final effectiveIndex = initialIndex.clamp(0, sources.length - 1);

    try {
      await initialized;
      _isStopped = false;

      // ✅ Sadece 1 parçayla başlat — index ne olursa olsun hızlı
      final newSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: [sources[effectiveIndex]],
      );
      _concatenatingSource = newSource;

      final firstItem =
          (sources[effectiveIndex] as UriAudioSource).tag as MediaItem;
      queue.add([firstItem]);

      // 1. DÜZELTME: setAudioSource çağrılmadan HEMEN ÖNCE event'leri bastır.
      // Yoksa setAudioSource "0" indeksini fırlatır ve arayüz listedeki ilk parçayı gösterir.
      _suppressIndexEventsUntil =
          DateTime.now().add(const Duration(milliseconds: 800));

      await _player.setAudioSource(_concatenatingSource, initialIndex: 0);

      // ✅ Arka planda sırayı koruyarak ekle
      Future.microtask(() async {
        const chunkSize = 50;

        if (effectiveIndex > 0) {
          for (int i = 0; i < effectiveIndex; i += chunkSize) {
            final end = (i + chunkSize).clamp(0, effectiveIndex);
            final chunk = sources.sublist(i, end);
            await _concatenatingSource.insertAll(i, chunk);
            final newItems = chunk
                .map((s) => (s as UriAudioSource).tag as MediaItem)
                .toList();
            final current = List<MediaItem>.from(queue.value);
            current.insertAll(i, newItems);
            queue.add(current);
            await Future.delayed(Duration.zero);
          }
        }

        final afterStart = effectiveIndex + 1;
        if (afterStart < sources.length) {
          for (int i = afterStart; i < sources.length; i += chunkSize) {
            final end = (i + chunkSize).clamp(0, sources.length);
            final chunk = sources.sublist(i, end);
            await _concatenatingSource.addAll(chunk);
            final newItems = chunk
                .map((s) => (s as UriAudioSource).tag as MediaItem)
                .toList();
            queue.add(List<MediaItem>.from(queue.value)..addAll(newItems));
            await Future.delayed(Duration.zero);
          }
        }

        // ✅ Tüm yükleme tamamlandı, artık gerçek index güvenli
        AudioService.setCurrentTrack(effectiveIndex);
      });
    } finally {
      _suppressIndexEventsUntil =
          DateTime.now().add(const Duration(milliseconds: 600));
      AudioService.playlistLoadingNotifier.value = false;

      // finally anında queue'da sadece 1 eleman var, player index kesinlikle 0
      if (queue.value.isNotEmpty) {
        const currentIndexNow = 0;
        mediaItem.add(queue.value[currentIndexNow]);

        // 2. DÜZELTME: currentIndexNow (0) yerine, asıl çalınacak olan parçanın
        // tam listedeki (full list) doğru sırasını temsil eden effectiveIndex'i kullanıyoruz.
        AudioService.setCurrentTrack(effectiveIndex);

        _currentLogTrackId =
            int.tryParse(queue.value[currentIndexNow].id) ?? -1;
        _currentLogTimestamp = _nowUtcString();
      }
    }
  }

  Future<void> appendTrack(AudioSource source) async {
    await _concatenatingSource.add(source);
    final item = (source as UriAudioSource).tag as MediaItem;
    final updated = List<MediaItem>.from(queue.value)..add(item);
    queue.add(updated);
  }

  Future<void> insertTrackAt(int index, AudioSource source) async {
    final safe = index.clamp(0, _concatenatingSource.length);
    await _concatenatingSource.insert(safe, source);
    final item = (source as UriAudioSource).tag as MediaItem;
    final updated = List<MediaItem>.from(queue.value)..insert(safe, item);
    queue.add(updated);
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  AudioPlayer get player => _player;

  Future<void> disposePlayer() async {
    _persistenceTimer?.cancel();
    _finalizeLogForCurrentTrack();
    await _player.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
//  AudioService — Singleton Yönetici
// ══════════════════════════════════════════════════════════════
class AudioService {
  AudioService._();

  static MyAudioHandler? _audioHandler;

  static String _parcaAdi = '...';
  static String _seslendiren = '...';
  static List<MediaItem> _parcaListesi = [];
  static List<AudioSource> _parcaKaynaklari = [];

  static String get parcaAdi => _parcaAdi;
  static String get seslendiren => _seslendiren;

  static List<MediaItem> get parcaListesi => List.unmodifiable(_parcaListesi);
  static List<AudioSource> get parcaKaynaklari =>
      List.unmodifiable(_parcaKaynaklari);

  // ── Notifier'lar ────────────────────────────────────────────
  static final progressNotifier = ProgressNotifier();
  static final currentSongTitleNotifier = ValueNotifier<String>('...');
  static final currentSongSubTitleNotifier = ValueNotifier<String>('...');
  static final playlistNotifier = ValueNotifier<List<String>>([]);

  // YENİ: Liste yükleme durumunu bildiren notifier.
  static final playlistLoadingNotifier = PlaylistLoadingNotifier();

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
    if (volume <= 0) return;
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
  //  BAŞLATMA
  // ════════════════════════════════════════════════════════════

  static Future<void> init() async {
    if (_audioHandler != null) return;

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

    final bool hediyeVarmi = Degiskenler.bekleyenHediyeId != null;
    int initialIndex = -1;

    if (hediyeVarmi) {
      final hediyeIdStr = Degiskenler.bekleyenHediyeId.toString();

      // 1. Önce hediye parça mevcut listede var mı kontrol et
      final int mevcutIndex = playlist.indexWhere((s) {
        final tag = (s as UriAudioSource).tag;
        return tag is MediaItem && tag.id == hediyeIdStr;
      });

      if (mevcutIndex != -1) {
        // 2. Parça zaten listede varsa, fetch yapma ve başlangıç indeksini ayarla
        initialIndex = mevcutIndex;
        LogService().info(
            "Hediye parça zaten listede mevcut (index: $mevcutIndex), fetch edilmeyecek. sira_no: $hediyeIdStr",
            tag: "Audio-ColdStart");

        // İşlem tamamlandığı için bekleyen hediye state'lerini temizle
        Degiskenler.bekleyenHediyeId = null;
        Degiskenler.bekleyenHediyeLink = null;
      } else {
        // 3. Parça listede YOKSA fetch işlemini başlat
        final giftSource = await _fetchGiftTrack(
          Degiskenler.bekleyenHediyeLink!,
          Degiskenler.bekleyenHediyeId!,
        );

        if (giftSource != null) {
          playlist.insert(0, giftSource);
          initialIndex = 0;
        }
      }
    }

    // Hediye yoksa veya hiçbir şekilde bulunamadıysa rastgele başlat
    if (initialIndex == -1) {
      initialIndex = Random().nextInt(playlist.length);
    }

    // Nihai listeyi state değişkenlerine ata
    _parcaKaynaklari = List.from(playlist);
    _parcaListesi =
        playlist.map((s) => (s as UriAudioSource).tag as MediaItem).toList();

    try {
      await _audioHandler!.loadPlaylist(playlist, initialIndex: initialIndex);
    } catch (e, st) {
      LogService().error("loadPlaylist hatası: $e", tag: "Audio-ColdStart");
      LogService().error("$st", tag: "Audio-ColdStart");
      Degiskenler.listeYuklendi = true;
      return;
    }

    Degiskenler.listeYuklendi = true;

    if (playNow) {
      LogService().info(
        "setPlaylist → _waitForReadyThenPlay çağrılıyor",
        tag: "Audio-ColdStart",
      );
      await _waitForReadyThenPlay();
    }
  }

  // Artık arka planda çalışan bir void değil, AudioSource dönen asenkron bir fonksiyon
  static Future<AudioSource?> _fetchGiftTrack(String link, dynamic id) async {
    LogService().info("_fetchGiftTrack başladı: link=$link, id=$id",
        tag: "Audio-ColdStart");
    Degiskenler.hazirlaniyor = true;

    try {
      final response = await MusicApiService().fetchAtesiAskLink(link, id);
      if (response != null && response.containsKey("isaretler")) {
        final item = response["isaretler"];

        // Hata ayıklama ve doğrulama için log yapısına sira_no dahil edildi
        LogService().info(
            "Hediye parça API'den başarıyla çekildi, sira_no: ${item['sira_no']}",
            tag: "Audio-ColdStart");

        final giftItem = MediaItem(
          id: item['sira_no'].toString(),
          album: item['parca_adi'],
          title: item['parca_adi'],
          artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
          artist: item['seslendiren'],
          extras: const {'isApplink': true},
        );

        return _buildAudioSource(item['url'], giftItem);
      }
    } catch (e) {
      LogService().error(
          "Hediye parça çekme hatası: $e, beklenen sira_no/id: $id",
          tag: "Audio-ColdStart");
    } finally {
      isShareableNotifier.value = false;
      Degiskenler.hazirlaniyor = false;
      Degiskenler.bekleyenHediyeId = null;
      Degiskenler.bekleyenHediyeLink = null;
    }

    return null; // Başarısız olursa null dönüyoruz, setPlaylist fallback uyguluyor
  }

  static Future<void> _waitForReadyThenPlay() async {
    _audioHandler!._manualPauseRequested = false;
    final player = _audioHandler!.player;

    // ✅ Polling yerine stream — event gelince uyanır, CPU kullanmaz
    await player.processingStateStream
        .where((s) =>
            s == ProcessingState.ready ||
            s == ProcessingState.buffering ||
            s == ProcessingState.completed ||
            s == ProcessingState.idle)
        .first
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => ProcessingState.idle,
        );

    if (_audioHandler!._manualPauseRequested) return;

    final s = player.processingState;
    if (s == ProcessingState.ready || s == ProcessingState.buffering) {
      await _audioHandler!.play();
    }
  }

  static Future<void> loadQueueAndPlay(
    List<dynamic> songList,
    int startId,
  ) async {
    _ensureInitialized();
    await _audioHandler!.initialized;
    if (songList.isEmpty) return;

    if (_isSameList(songList)) {
      LogService().info(
          "Liste zaten yüklü, kuyruk yenilenmeden ID'ye atlıyoruz: $startId",
          tag: "Audio");
      await playAtId(startId);
      return;
    }

    final sources = <AudioSource>[];
    final mediaItems = <MediaItem>[];

    // Optimize: Sabit resmi bir kere parse et
    final defaultArtUri =
        Uri.parse("${Degiskenler.kaynakYolu}medya/atesiask/bahar11.jpg");

    // Optimize: Listeyi chunk'lar halinde işleyerek UI frame'ine izin ver
    const int chunkSize = 100;
    for (int i = 0; i < songList.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, songList.length);
      for (int j = i; j < end; j++) {
        final song = songList[j];
        final item = MediaItem(
          id: song['sira_no'].toString(),
          title: song['parca_adi'].toString(),
          artist: song['seslendiren'] ?? '...',
          artUri: defaultArtUri,
        );
        mediaItems.add(item);
        sources.add(_buildAudioSource(song['url'] ?? '', item));
      }
      // Main thread'in kilitlenmesini önler, süreyi uzatmaz
      await Future.delayed(Duration.zero);
    }

    final startIndex = sources.indexWhere((s) =>
        ((s as UriAudioSource).tag as MediaItem).id == startId.toString());

    LogService().debug(
        "loadQueueAndPlay → startId: $startId, startIndex: ${startIndex == -1 ? 0 : startIndex}",
        tag: "Audio");

    _parcaListesi = mediaItems;
    _parcaKaynaklari = List.from(sources);

    await _audioHandler!.loadPlaylist(
      sources,
      initialIndex: startIndex == -1 ? 0 : startIndex,
    );

    await play();
  }

  static bool _isSameList(List<dynamic> newList) {
    if (_parcaListesi.isEmpty || _parcaListesi.length != newList.length) {
      return false;
    }
    final checkCount = min(5, newList.length);
    for (int i = 0; i < checkCount; i++) {
      if (_parcaListesi[i].id != newList[i]['sira_no'].toString()) {
        return false;
      }
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

  static Future<void> playGiftTrack(String link, String id) async {
    _ensureInitialized();
    await _audioHandler!.initialized;

    // Loglarda sira_no standardını koruyoruz
    LogService().info(
        "playGiftTrack süreci başlatıldı: link=$link, sira_no=$id",
        tag: "Audio");

    // 1. DÜZELTME: Şu an aktif olan parça zaten bu hediye mi?
    // Degiskenler.parcaIndex (index) yerine doğrudan mevcut MediaItem'ın ID'sine bakmak en güvenlisidir.
    final currentMediaItem = _audioHandler!.mediaItem.value;
    if (currentMediaItem != null && currentMediaItem.id == id) {
      LogService().info(
          "Bu parça zaten aktif: sira_no=$id, player başlatılıyor",
          tag: "Audio");
      await _waitForReadyThenPlay();
      return;
    }

    // 2. Parça kuyrukta var mı? (Gereksiz API isteğini engelliyor, harika bir mantık)
    final seq = _audioHandler!.player.sequence;
    if (seq != null) {
      final index = seq.indexWhere(
          (s) => s is UriAudioSource && (s.tag as MediaItem).id == id);
      if (index != -1) {
        LogService().info(
            "Parça mevcut kuyrukta bulundu, index=$index (sira_no=$id). Oraya atlanıyor.",
            tag: "Audio");
        await _audioHandler!.skipToQueueItem(index);
        await _waitForReadyThenPlay();
        return;
      }
    }

    // 3. Kuyrukta yok, API'den çekeceğiz
    LogService().info(
        "Parça kuyrukta yok, API'den link çözülüyor... sira_no=$id",
        tag: "Audio");
    Degiskenler.hazirlaniyor = true;
    try {
      final response = await MusicApiService().fetchAtesiAskLink(link, id);
      if (response != null && response.containsKey("isaretler")) {
        final item = response["isaretler"];
        LogService().info(
            "API Yanıtı başarılı: ${item['parca_adi']} (sira_no: ${item['sira_no']})",
            tag: "Audio");

        // playApplinkTrack'in listenin ilk sırasına (veya sonuna) ekleyip çaldırdığını varsayıyoruz
        await playApplinkTrack(
            item['parca_adi'], item['seslendiren'], item['url'], id);
      } else {
        LogService()
            .warn("API yanıtı boş veya geçersiz: sira_no=$id", tag: "Audio");
      }
    } catch (e, st) {
      LogService().error("playGiftTrack API hatası: $e", tag: "Audio");
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
    LogService().info("playApplinkTrack: Yeni parça kuyruğa ekleniyor: $adi",
        tag: "Audio");

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
      LogService()
          .debug("Parça index $insertIndex konumuna ekleniyor", tag: "Audio");

      await _audioHandler!.insertTrackAt(insertIndex, source);
      _parcaKaynaklari.insert(insertIndex, source);
      _parcaListesi.insert(insertIndex, item);

      isShareableNotifier.value = false;

      LogService()
          .info("Parça eklendi, 500ms sonra geçiş yapılacak", tag: "Audio");
      await Future.delayed(const Duration(milliseconds: 500));

      await _audioHandler!.skipToQueueItem(insertIndex);
      LogService()
          .info("Yeni parçaya geçildi, oynatma bekleniyor", tag: "Audio");
      await _waitForReadyThenPlay();
    } catch (e, st) {
      LogService()
          .error("playApplinkTrack ekleme/oynatma hatası: $e", tag: "Audio");
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

  static Future<void> dispose() async {
    cancelSleepTimer();
    await _audioHandler?.disposePlayer();
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
  //  YARDIMCI
  // ════════════════════════════════════════════════════════════

  static void _ensureInitialized() {
    if (_audioHandler == null) {
      throw StateError('AudioService.init() çağrılmadan kullanılamaz. ');
    }
  }

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
