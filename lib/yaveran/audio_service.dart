import 'dart:math';

import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/ui_support.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:bizidealcennetine/yaveran/Notifier.dart';
import 'package:audio_session/audio_session.dart';

/// Audio service handler sınıfı
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static AudioPlayer? _player;
  bool _wasPlayingBeforeInterruption = false;

  MyAudioHandler() {
    _init();
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
        mediaItem.add(queue.value[index]);
        AudioService.setCurrentTrack(index);

        await Future.delayed(const Duration(milliseconds: 100));
        UI_support.changeImageAndEpigram();
      }
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
        MediaAction.seekForward,
        MediaAction.seekBackward,
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

  static Future<void> init() async {
    _audioHandler = MyAudioHandler();

    await audio_service.AudioService.init(
      builder: () => _audioHandler!,
      config: audio_service.AudioServiceConfig(
        androidNotificationChannelId: 'com.ea.bizidealcennetine.channel.audio',
        androidNotificationChannelName: 'Aşk Olsun',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  static Future<void> setPlaylist(List<AudioSource> playlist) async {
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

    final Random random = Random();
    final int initialIndex = random.nextInt(playlist.length);

    await _audioHandler!.setAudioSource(
      ConcatenatingAudioSource(children: playlist, useLazyPreparation: true),
      initialIndex: initialIndex,
    );
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

  static Future<void> addTrackToPlaylist(adi, ses, yol, sira, oynat) async {
    Degiskenler.songListNotifier.value.add(
        {'sira_no': sira, 'parca_adi': adi, 'seslendiren': ses, 'url': yol});

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
    if (index != null) {
      parca_adi = Degiskenler().listDinle[index]["parca_adi"];
      seslendiren = Degiskenler().listDinle[index]["seslendiren"];
      currentSongTitleNotifier.value = parca_adi;
      currentSongSubTitleNotifier.value = seslendiren;
      Degiskenler.parcaIndex = Degiskenler().listDinle[index]["sira_no"];
    }
  }

  static Future<void> play() async {
    await _audioHandler!.play();
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
