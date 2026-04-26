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

/// Audio service handler sınıfı
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static AudioPlayer? _player;
  bool _wasPlayingBeforeInterruption = false;

  int _currentLogTrackId = -1;
  int _accumulatedListenSeconds = 0;
  DateTime? _lastPlayStartTime;
  Timer? _persistenceTimer;
  String? _currentLogTimestamp;

  List<Map<String, dynamic>> _pendingLogs = [];
  bool _isSendingLogs = false;

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsString = prefs.getString('listen_logs');
    if (logsString != null) {
      try {
        final List<dynamic> parsed = jsonDecode(logsString);
        for (var el in parsed) {
          final logMap = Map<String, dynamic>.from(el);
          if (logMap['status'] == 'current') {
            if ((logMap['listenDuration'] as int? ?? 0) >= 30) {
              logMap['status'] = 'completed';
              _pendingLogs.add(logMap);
            }
          } else {
            _pendingLogs.add(logMap);
          }
        }
      } catch (e) {}
    }
    await _saveLogsToPrefs();
    _checkAndSendPendingLogs();
  }

  Future<void> _saveLogsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> logsToSave = List.from(_pendingLogs);

    if (_currentLogTrackId != -1 && _accumulatedListenSeconds > 0) {
      logsToSave.add({
        'musicId': _currentLogTrackId,
        'listenDuration': _accumulatedListenSeconds,
        'timestamp': _currentLogTimestamp ??
            DateTime.now().toUtc().toIso8601String().split('.')[0] + "Z",
        'status': 'current'
      });
    }

    if (logsToSave.isEmpty) {
      await prefs.remove('listen_logs');
    } else {
      await prefs.setString('listen_logs', jsonEncode(logsToSave));
    }
  }

  void _updateAccumulatedTime() {
    if (_lastPlayStartTime != null) {
      _accumulatedListenSeconds +=
          DateTime.now().difference(_lastPlayStartTime!).inSeconds;
      _lastPlayStartTime = DateTime.now();
      _saveLogsToPrefs();
    }
  }

  Future<void> _checkAndSendPendingLogs() async {
    if (_isSendingLogs || _pendingLogs.isEmpty) return;
    _isSendingLogs = true;

    final logsToSend = List<Map<String, dynamic>>.from(_pendingLogs);

    for (var log in logsToSend) {
      bool success = await MusicApiService().sendListenLog(
        musicId: log['musicId'],
        listenDuration: log['listenDuration'],
        timestamp: log['timestamp'],
      );

      if (success) {
        _pendingLogs.removeWhere((l) =>
            l['timestamp'] == log['timestamp'] &&
            l['musicId'] == log['musicId']);
        await _saveLogsToPrefs(); // Gönderilen başarılı logu listeden çıkar ve kaydet
      }
    }

    _isSendingLogs = false;
  }

  void _finalizeLogForCurrentTrack() {
    _updateAccumulatedTime();
    _lastPlayStartTime = null;

    if (_accumulatedListenSeconds >= 30 && _currentLogTrackId != -1) {
      _pendingLogs.add({
        'musicId': _currentLogTrackId,
        'listenDuration': _accumulatedListenSeconds,
        'timestamp': _currentLogTimestamp ??
            DateTime.now().toUtc().toIso8601String().split('.')[0] + "Z",
        'status': 'completed',
      });
      _checkAndSendPendingLogs();
    }
    _accumulatedListenSeconds = 0;
    _currentLogTrackId = -1;
    _currentLogTimestamp = null;
    _saveLogsToPrefs();
  }

  MyAudioHandler() {
    _loadLogs();
    _init();
    _persistenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_player?.playing == true) {
        _updateAccumulatedTime();
      }
    });
  }

  Future<void> _init() async {
    _player = AudioPlayer();

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _wasPlayingBeforeInterruption = _player!.playing;
        await _player!.pause();
      } else {
        if (_wasPlayingBeforeInterruption) {
          await Future.delayed(const Duration(seconds: 1));
          await _player!.play();
        }
        _wasPlayingBeforeInterruption = false;
      }
    });

    // Player state değişikliklerini dinle
    _player!.playbackEventStream.listen(_broadcastState);

    // Position stream'i dinle
    _player!.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));

      // ProgressNotifier'ı güncelle
      AudioService.progressNotifier.value = ProgressBarState(
        current: position,
        buffered: _player!.bufferedPosition,
        total: _player!.duration ?? Duration.zero,
      );
    });

    _player!.bufferedPositionStream.listen((bufferedPosition) {
      final currentState = AudioService.progressNotifier.value;
      AudioService.progressNotifier.value = ProgressBarState(
        current: currentState.current,
        buffered: bufferedPosition,
        total: currentState.total,
      );
    });

    // Duration stream'i dinle - SADECE BU KISIM DEĞİŞTİ
    _player!.durationStream.listen((duration) {
      final newState = AudioService.progressNotifier.value;
      AudioService.progressNotifier.value = ProgressBarState(
        current: newState.current,
        buffered: newState.buffered,
        total: duration ?? Duration.zero,
      );

      // MediaItem'ı duration ile güncelle - BU SATIR EKLENDİ
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });

    // Current index değişikliklerini dinle
    _player!.currentIndexStream.listen((index) async {
      if (index != null &&
          queue.value.isNotEmpty &&
          index < queue.value.length) {
        final newTrackIdStr = queue.value[index].id;
        final newTrackId = int.tryParse(newTrackIdStr) ?? -1;

        if (newTrackId != _currentLogTrackId) {
          _finalizeLogForCurrentTrack();
          _currentLogTrackId = newTrackId;
          _currentLogTimestamp =
              DateTime.now().toUtc().toIso8601String().split('.')[0] + "Z";
          if (_player!.playing) {
            _lastPlayStartTime = DateTime.now();
          }
        }

        mediaItem.add(queue.value[index]);
        AudioService.setCurrentTrack(index);

        await Future.delayed(const Duration(milliseconds: 100));
        UI_support.changeImageAndEpigram();
      }
    });

    _player!.playingStream.listen((playing) {
      if (playing) {
        if (_lastPlayStartTime == null) {
          _lastPlayStartTime = DateTime.now();
        }
      } else {
        if (_lastPlayStartTime != null) {
          _updateAccumulatedTime();
          _lastPlayStartTime = null;
        }
      }
    });

    _player!.volumeStream.listen((volume) {
      AudioService.volumeNotifier.value = volume;
    });

    _player!.loopModeStream.listen((loopMode) {
      playbackState.add(playbackState.value.copyWith(
        repeatMode: _convertLoopMode(loopMode),
      ));
    });

    _player!.shuffleModeEnabledStream.listen((shuffleEnabled) {
      playbackState.add(playbackState.value.copyWith(
        shuffleMode: shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ));
      AudioService.isShuffleModeEnabledNotifier.value = shuffleEnabled;
    });

    await _player!.setShuffleModeEnabled(true);

    // Resim değişimlerini dinle ve bildirimi güncelle
    Degiskenler.currentImageNotifier.addListener(() {
      if (mediaItem.value != null) {
        String imageName = Degiskenler.currentImageNotifier.value;
        if (imageName.isNotEmpty) {
          mediaItem.add(mediaItem.value!.copyWith(
            artUri:
                Uri.parse("${Degiskenler.kaynakYolu}medya/atesiask/$imageName"),
          ));
        }
      }
    });
  }

  AudioServiceRepeatMode _convertLoopMode(LoopMode loopMode) {
    switch (loopMode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player!.playing;
    final processingState = _convertProcessingState(_player!.processingState);

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
      processingState: processingState,
      playing: playing,
      updatePosition: _player!.position,
      bufferedPosition: _player!.bufferedPosition,
      speed: _player!.speed,
      queueIndex: _player!.currentIndex,
    ));

    if (processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering) {
      AudioService.playButtonNotifier.value = ButtonState.loading;
    } else if (_player!.playing) {
      AudioService.playButtonNotifier.value = ButtonState.playing;
    } else {
      AudioService.playButtonNotifier.value = ButtonState.paused;
    }
  }

  AudioProcessingState _convertProcessingState(ProcessingState state) {
    switch (state) {
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

  @override
  Future<void> play() async {
    await _player!.play();
  }

  @override
  Future<void> pause() async {
    await _player!.pause();
  }

  @override
  Future<void> stop() async {
    _finalizeLogForCurrentTrack();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle, // Veya .completed
    ));
    mediaItem.add(null);
    await _player!.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player!.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _player!.seekToNext();
    await Future.delayed(const Duration(milliseconds: 700));
    await _player!.play();
  }

  @override
  Future<void> skipToPrevious() async {
    await _player!.seekToPrevious();
    await Future.delayed(const Duration(milliseconds: 700));
    await _player!.play();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player!.seek(Duration.zero, index: index);
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player!.position + const Duration(seconds: 10);
    final duration = _player!.duration ?? Duration.zero;
    await _player!.seek(newPosition < duration ? newPosition : duration);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player!.position - const Duration(seconds: 10);
    await _player!
        .seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player!.setLoopMode(LoopMode.off);
        AudioService.repeatButtonNotifier.value = RepeatState.off;
        break;
      case AudioServiceRepeatMode.one:
        await _player!.setLoopMode(LoopMode.one);
        AudioService.repeatButtonNotifier.value = RepeatState.on;
        break;
      case AudioServiceRepeatMode.all:
        await _player!.setLoopMode(LoopMode.all);
        AudioService.repeatButtonNotifier.value = RepeatState.off;
        break;
      case AudioServiceRepeatMode.group:
        await _player!.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player!.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
    AudioService.parca_listesi = newQueue;
  }

  Future<void> setAudioSource(ConcatenatingAudioSource source,
      {int? initialIndex}) async {
    await _player!.setAudioSource(source, initialIndex: initialIndex);
  }

  Future<void> setVolume(double volume) async {
    await _player?.setVolume(volume);
  }

  AudioPlayer? get player => _player;
}

/// Ses hizmetlerini yöneten statik sınıf
class AudioService {
  static MyAudioHandler? _audioHandler;

  static String parca_adi = "...";
  static String seslendiren = "...";
  static List<MediaItem> parca_listesi = [];

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

  static Future<void> saveVolume(double volume) async {
    if (volume <= 0) return; // Sessiz konumu başlangıç ayarı olarak kaydetme
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_volume', volume);
  }

  static Future<void> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    double vol = prefs.getDouble('app_volume') ?? 1.0;
    await setVolume(vol);
  }

  static Timer? _sleepTimer;
  static Timer? _countdownTimer;

  static void startSleepTimer(int minutes) {
    cancelSleepTimer();
    if (minutes <= 0) return;

    int remainingSeconds = minutes * 60;
    Degiskenler.sleepTimerRemainingNotifier.value = remainingSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        Degiskenler.sleepTimerRemainingNotifier.value = remainingSeconds;
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

  static Future<void> init() async {
    _audioHandler = MyAudioHandler();

    await audio_service.AudioService.init(
      builder: () => _audioHandler!,
      config: audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.ea.bizidealcennetine.channel.audio',
        androidNotificationChannelName: 'Aşk Olsun',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  static Future<void> setPlaylist(List<AudioSource> playlist,
      {bool playNow = true}) async {
    if (_audioHandler == null) {
      throw Exception('AudioService başlatılmadı');
    }

    // MediaItem listesi oluştur
    final mediaItems = playlist.map((source) {
      if (source is UriAudioSource) {
        return source.tag as MediaItem;
      }
      throw Exception('Desteklenmeyen AudioSource tipi');
    }).toList();


    await _audioHandler!.updateQueue(mediaItems);

    bool hediyeVarmi = Degiskenler.bekleyenHediyeId != null;

    // --- HEDİYE PARÇA KONTROL VE BEKLEME MEKANİZMASI ---
    int initialIndex = -1;
    if (hediyeVarmi) {
      // 1. Önce yüklenen listede ara (Eşleştirme)
      initialIndex = playlist.indexWhere((source) {
        if (source is UriAudioSource) {
          return (source.tag as MediaItem).id ==
              Degiskenler.bekleyenHediyeId.toString();
        }
        return false;
      });

      // 2. Listede yoksa sunucudan bekle (Uzak sunucu kontrolü)
      if (initialIndex == -1 && Degiskenler.bekleyenHediyeLink != null) {
        print("Hediye listede yok, sunucudan yanıt bekleniyor...");
        Degiskenler.hazirlaniyor = true;
        try {
          final response = await MusicApiService().fetchAtesiAskLink(
              Degiskenler.bekleyenHediyeLink!, Degiskenler.bekleyenHediyeId!);

          if (response != null && response.containsKey("isaretler")) {
            final item = response["isaretler"];
            final mediaItem = MediaItem(
              id: item['sira_no'].toString(),
              album: item['parca_adi'],
              title: item['parca_adi'],
              artUri:
                  Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
              artist: item['seslendiren'],
              extras: const {'isApplink': true},
            );

            // Gelen parçayı listenin en başına koy ki oradan başlasın
            playlist.insert(
                0, AudioSource.uri(Uri.parse(item['url']), tag: mediaItem));
            mediaItems.insert(0, mediaItem);
            initialIndex = 0;
            isShareableNotifier.value = false;
          }
        } catch (e) {
          print("Hediye beklenirken hata: $e");
        } finally {
          Degiskenler.hazirlaniyor = false;
        }
      }
    }

    // Eğer hediye yoksa veya çekilemediyse rastgele bir parça seç
    if (initialIndex == -1) {
      final Random random = Random();
      initialIndex = random.nextInt(playlist.length);
    }
    // --------------------------------------------------

    if (playlist.isEmpty) {
      print("Error: Playlist is empty");
      return;
    }

    await _audioHandler!.updateQueue(mediaItems);

    await _audioHandler!.setAudioSource(
      ConcatenatingAudioSource(children: playlist, useLazyPreparation: true),
      initialIndex: initialIndex >= 0 && initialIndex < playlist.length ? initialIndex : 0,
    );

    // Hediye varsa playNow false olsa bile (soğuk açılış) çalmaya başla
    if (playNow || hediyeVarmi) {
      await Future.delayed(const Duration(milliseconds: 500));
      await play();
    }

    Degiskenler.listeYuklendi = true;
    Degiskenler.bekleyenHediyeId = null;
    Degiskenler.bekleyenHediyeLink = null;
  }

  /// Uygulama açıkken gelen linkleri yönetmek için
  static Future<void> playGiftTrack(String link, String id) async {
    if (_audioHandler == null) return;

    // 1. Zaten o an çalıyor mu?
    if (Degiskenler.parcaIndex.toString() == id.toString()) {
      await play();
      return;
    }

    // 2. Mevcut oynatma listesinde (kuyrukta) var mı?
    int index = _audioHandler!.player!.sequence!.indexWhere((source) {
      if (source is UriAudioSource) {
        return (source.tag as MediaItem).id == id.toString();
      }
      return false;
    });

    if (index != -1) {
      await _audioHandler!.skipToQueueItem(index);
      await Future.delayed(const Duration(milliseconds: 500));
      await play();
    } else {
      // 3. Kuyrukta yoksa sunucudan iste
      Degiskenler.hazirlaniyor = true;
      try {
        final response = await MusicApiService().fetchAtesiAskLink(link, id);
        if (response != null && response.containsKey("isaretler")) {
          final item = response["isaretler"];
          await playApplinkTrack(
              item['parca_adi'], item['seslendiren'], item['url'], id);
        }
      } catch (e) {
        print("PlayGiftTrack Error: $e");
      } finally {
        Degiskenler.hazirlaniyor = false;
      }
    }
  }

  static Future<void> playAtId(int id) async {
    if (_audioHandler == null) {
      throw Exception('AudioService başlatılmadı');
    }

    int index = _audioHandler!.player!.sequence!.indexWhere(
      (source) {
        if (source is UriAudioSource) {
          return (source.tag as MediaItem).id == id.toString();
        }
        return false;
      },
    );

    if (index != -1) {
      await _audioHandler!.skipToQueueItem(index);
      await _audioHandler!.play();
    } else {
      print('ID $id ile parça bulunamadı');
    }
  }

  static Future<void> loadQueueAndPlay(
      List<dynamic> songList, int startId) async {
    if (_audioHandler == null) return;

    List<AudioSource> sources = [];
    List<MediaItem> mediaItems = [];

    for (var song in songList) {
      final mItem = MediaItem(
        id: song['sira_no'].toString(),
        title: song['parca_adi'].toString(),
        artist: song['seslendiren'] ?? '...',
        artUri:
            Uri.parse("${Degiskenler.kaynakYolu}medya/atesiask/bahar11.jpg"),
      );

      mediaItems.add(mItem);
      sources.add(AudioSource.uri(
        Uri.parse(song['url'] ?? ""),
        tag: mItem,
      ));
    }

    AudioService.parca_listesi = mediaItems;
    await _audioHandler!.updateQueue(mediaItems);

    int startIndex = songList
        .indexWhere((s) => s['sira_no'].toString() == startId.toString());
    if (startIndex == -1) startIndex = 0;

    await _audioHandler!.setAudioSource(
      ConcatenatingAudioSource(children: sources, useLazyPreparation: true),
      initialIndex: startIndex,
    );

    await _audioHandler!.play();
  }

  static Future<void> addTrackToPlaylist(adi, ses, yol, sira, oynat) async {
    final newTrack = {
      'sira_no': sira,
      'parca_adi': adi,
      'seslendiren': ses,
      'url': yol
    };
    Degiskenler().listDinle.add(newTrack);
    Degiskenler.songListNotifier.value =
        List.from(Degiskenler.songListNotifier.value)..add(newTrack);

    final mediaItem = MediaItem(
      id: sira.toString(),
      album: adi,
      title: adi,
      artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
      artist: ses,
    );

    AudioSource newSource = AudioSource.uri(
      Uri.parse(yol),
      tag: mediaItem,
    );

    try {
      var currentSources =
          (_audioHandler!.player!.audioSource as ConcatenatingAudioSource)
              .children;

      currentSources.add(newSource);

      final currentQueue = List<MediaItem>.from(parca_listesi);
      currentQueue.add(mediaItem);
      await _audioHandler!.updateQueue(currentQueue);

      await _audioHandler!.setAudioSource(
        ConcatenatingAudioSource(children: currentSources),
        initialIndex: currentSources.length - 1,
      );
    } catch (e, stackTrace) {
      print("Error adding track to playlist: $e");
      print(stackTrace);
    }

    if (oynat) play();
  }

  static setCurrentTrack(index) {
    if (index != null && index < parca_listesi.length) {
      final mediaItem = parca_listesi[index];
      Degiskenler.parcaIndex = int.tryParse(mediaItem.id) ?? -1;
      parca_adi = mediaItem.title;
      seslendiren = mediaItem.artist ?? "...";
      currentSongTitleNotifier.value = parca_adi;
      currentSongSubTitleNotifier.value = seslendiren;
      isShareableNotifier.value = mediaItem.extras?['isApplink'] != true;
    }
  }

  static Future<void> playApplinkTrack(adi, ses, yol, sira) async {
    final mediaItem = MediaItem(
      id: sira.toString(),
      album: adi,
      title: adi,
      artUri: Uri.parse("${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg"),
      artist: ses,
      extras: const {'isApplink': true},
    );

    AudioSource newSource = AudioSource.uri(
      Uri.parse(yol),
      tag: mediaItem,
    );

    try {
      var currentSources = List<AudioSource>.from(
          (_audioHandler!.player!.audioSource as ConcatenatingAudioSource)
              .children);

      int insertIndex = _audioHandler!.player!.currentIndex != null
          ? _audioHandler!.player!.currentIndex! + 1
          : currentSources.length;

      if (insertIndex > currentSources.length)
        insertIndex = currentSources.length;

      currentSources.insert(insertIndex, newSource);

      final currentQueue = List<MediaItem>.from(parca_listesi);
      currentQueue.insert(insertIndex, mediaItem);
      await _audioHandler!.updateQueue(currentQueue);

      await _audioHandler!.setAudioSource(
        ConcatenatingAudioSource(children: currentSources),
        initialIndex: insertIndex,
      );
      isShareableNotifier.value = false;
      await Future.delayed(const Duration(milliseconds: 500));
      await play();
    } catch (e) {
      print("Error playing applink track: $e");
    }
  }

  static Future<void> play() async {
    await _audioHandler!.play();
  }

  static Future<void> setVolume(double volume) async {
    await _audioHandler?.setVolume(volume);
    saveVolume(volume);
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

  static Future<void> pause() async {
    await _audioHandler!.pause();
  }

  static Future<void> playPause() async {
    if (_audioHandler!.player!.playing) {
      await pause();
    } else {
      await play();
    }
  }

  static Future<void> next() async {
    await _audioHandler!.skipToNext();
  }

  static Future<void> previous() async {
    await _audioHandler!.skipToPrevious();
  }

  static Future<void> seek(Duration position) async {
    await _audioHandler!.seek(position);
  }

  static Future<void> repeat() async {
    if (repeatButtonNotifier.value == RepeatState.on) {
      await _audioHandler!.setRepeatMode(AudioServiceRepeatMode.all);
    } else {
      await _audioHandler!.setRepeatMode(AudioServiceRepeatMode.one);
    }
  }

  static Future<void> toggleShuffle() async {
    final shuffleEnabled = _audioHandler!.player!.shuffleModeEnabled;
    await _audioHandler!.setShuffleMode(shuffleEnabled
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all);
  }

  static String getCurrentTrackName() {
    print("Dinleniyor: $parca_adi");
    return parca_adi;
  }

  static String getCurrentTrackArtist() {
    print("Dinleniyor: $seslendiren");
    return seslendiren;
  }

  static Future<void> dispose() async {
    _audioHandler?._persistenceTimer?.cancel();
    await _audioHandler?.stop();
    _audioHandler = null;
  }

  static Future<void> stop() async {
    await _audioHandler!.stop();
  }

  static MyAudioHandler? get audioHandler => _audioHandler;
  static AudioPlayer? get player => _audioHandler?.player;
  static bool get isPlaying => _audioHandler?.player?.playing ?? false;
  static Duration get currentPosition =>
      _audioHandler?.player?.position ?? Duration.zero;
  static Duration get totalDuration =>
      _audioHandler?.player?.duration ?? Duration.zero;
  static int? get currentIndex => _audioHandler?.player?.currentIndex;
  static bool get isShuffleEnabled =>
      _audioHandler?.player?.shuffleModeEnabled ?? false;
  static LoopMode get loopMode =>
      _audioHandler?.player?.loopMode ?? LoopMode.off;
}
