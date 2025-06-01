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
  bool _wasPlayingBeforeInterruption =
      false; // Ses kesintisi öncesi oynatma durumu

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    _player = AudioPlayer();

    // Audio session ayarları
    // Bu, Android ve iOS için gerekli ses odaklama ve kesinti yönetimini sağlar
    // Başka uygulamalarla çakışmayı önlemek için veya telefon görüşmesi sırasında müziği duraklatmak için
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
    // Audio focus değişikliklerini dinle
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        // TÜM kesinti tiplerinde çalışır (pause, duck, unknown)
        _wasPlayingBeforeInterruption = _player!.playing;
        await _player!.pause(); // ASENKRON DURAKLATMA
      } else {
        // Kesinti bittiğinde
        if (_wasPlayingBeforeInterruption) {
          await Future.delayed(const Duration(seconds: 1)); // 1 SANİYE BEKLE
          await _player!.play(); // ASENKRON OYNATMA
        }
        _wasPlayingBeforeInterruption = false;
      }
    });

    // Player state değişikliklerini dinle
    _player!.playbackEventStream.listen(_broadcastState);

    // Position stream'i dinle
    _player!.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));

      // ProgressNotifier'ı güncelle (EK)
      AudioService.progressNotifier.value = ProgressBarState(
        current: position,
        buffered: _player!.bufferedPosition,
        total: _player!.duration ?? Duration.zero,
      );
    });
    // MyAudioHandler sınıfına ekleme:
    _player!.bufferedPositionStream.listen((bufferedPosition) {
      final currentState = AudioService.progressNotifier.value;
      AudioService.progressNotifier.value = ProgressBarState(
        current: currentState.current,
        buffered: bufferedPosition,
        total: currentState.total,
      );
    });
    // Duration stream'i dinle
    // MyAudioHandler sınıfındaki durationStream dinleyicisi:
    _player!.durationStream.listen((duration) {
      final newState = AudioService.progressNotifier.value;
      AudioService.progressNotifier.value = ProgressBarState(
        current: newState.current,
        buffered: newState.buffered,
        total: duration ?? Duration.zero,
      );
    });

    // Current index değişikliklerini dinle
    _player!.currentIndexStream.listen((index) async {
      if (index != null &&
          queue.value.isNotEmpty &&
          index < queue.value.length) {
        mediaItem.add(queue.value[index]);
        AudioService.setCurrentTrack(index);

        // UI SUPPORT ÇAĞRISI - ŞARKI DEĞİŞTİĞİNDE
        // UI güncellemeleri için kısa gecikme
        await Future.delayed(const Duration(milliseconds: 100));
        UI_support.changeImageAndEpigram();
      }
    });

    // Loop mode değişikliklerini dinle
    _player!.loopModeStream.listen((loopMode) {
      playbackState.add(playbackState.value.copyWith(
        repeatMode: _convertLoopMode(loopMode),
      ));
    });

    // Shuffle mode değişikliklerini dinle
    _player!.shuffleModeEnabledStream.listen((shuffleEnabled) {
      playbackState.add(playbackState.value.copyWith(
        shuffleMode: shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ));
      AudioService.isShuffleModeEnabledNotifier.value = shuffleEnabled;
    });

    // Başlangıçta shuffle'ı aktif et
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

    // AudioService notifier'larını güncelle
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
    await _player!.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player!.seek(position);
    _broadcastState(_player!.playbackEvent);
  }

  @override
  Future<void> skipToNext() async {
    bool wasPlaying = _player!
        .playing; // diğer cihazlarla çalınıyorsa önlem için öncekii durum kaydediliyor.
    await _player!.seekToNext();
    if (wasPlaying) await _player!.play(); // Önceden çalıyorsa devam et
  }

  @override
  Future<void> skipToPrevious() async {
    bool wasPlaying = _player!
        .playing; // diğer cihazlarla çalınıyorsa önlem için öncekii durum kaydediliyor.
    await _player!.seekToPrevious();
    if (wasPlaying) await _player!.play();
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

  /// Oynatma durumunu bildiren ValueNotifier
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

  /// AudioService'i başlatır
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

  /// Çalma listesini ayarlar
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

    // Queue'yu güncelle
    await _audioHandler!.updateQueue(mediaItems);

    final Random random = Random();
    final int initialIndex = random.nextInt(playlist.length);

    await _audioHandler!.setAudioSource(
      ConcatenatingAudioSource(children: playlist, useLazyPreparation: true),
      initialIndex: initialIndex,
    );
  }

  /// Belirtilen ID'ye sahip parçayı çalar
  static Future<void> playAtId(int id) async {
    if (_audioHandler == null) {
      throw Exception('AudioService başlatılmadı');
    }

    // Çalma listesindeki parçanın indeksini bul
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
    // 1. Yeni parçayı songListNotifier değişkenine ekle
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
      // Mevcut çalma listesini al
      var currentSources =
          (_audioHandler!.player!.audioSource as ConcatenatingAudioSource)
              .children;

      // Yeni parçayı çalma listesine ekle
      currentSources.add(newSource);

      // Queue'yu güncelle
      final currentQueue = List<MediaItem>.from(parca_listesi);
      currentQueue.add(mediaItem);
      await _audioHandler!.updateQueue(currentQueue);

      // Yeni çalma listesini ayarla
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

  /// Mevcut parça bilgilerini ayarlar
  static setCurrentTrack(index) {
    if (index != null) {
      // degiskenler.listDinle'den bilgileri al
      parca_adi = Degiskenler().listDinle[index]["parca_adi"];
      seslendiren = Degiskenler().listDinle[index]["seslendiren"];
      currentSongTitleNotifier.value = parca_adi;
      currentSongSubTitleNotifier.value = seslendiren;
      Degiskenler.parcaIndex = Degiskenler().listDinle[index]["sira_no"];
    }
  }

  /// Müziği çalar
  static Future<void> play() async {
    await _audioHandler!.play();
  }

  /// Müziği duraklatır
  static Future<void> pause() async {
    await _audioHandler!.pause();
  }

  /// Play/Pause toggle
  static Future<void> playPause() async {
    if (_audioHandler!.player!.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Sonraki parçaya geç
  static Future<void> next() async {
    await _audioHandler!.skipToNext();
  }

  /// Önceki parçaya geç
  static Future<void> previous() async {
    await _audioHandler!.skipToPrevious();
  }

  /// Belirtilen pozisyona git
  static Future<void> seek(Duration position) async {
    await _audioHandler!.seek(position);
  }

  /// Repeat modu değiştir
  static Future<void> repeat() async {
    if (repeatButtonNotifier.value == RepeatState.on) {
      await _audioHandler!.setRepeatMode(AudioServiceRepeatMode.all);
    } else {
      await _audioHandler!.setRepeatMode(AudioServiceRepeatMode.one);
    }
  }

  /// Shuffle modu değiştir
  static Future<void> toggleShuffle() async {
    final shuffleEnabled = _audioHandler!.player!.shuffleModeEnabled;
    await _audioHandler!.setShuffleMode(shuffleEnabled
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all);
  }

  /// Mevcut parça adını döndür
  static String getCurrentTrackName() {
    print("Dinleniyor: $parca_adi");
    return parca_adi;
  }

  /// Mevcut sanatçı adını döndür
  static String getCurrentTrackArtist() {
    print("Dinleniyor: $seslendiren");
    return seslendiren;
  }

  /// AudioService'i temizler
  static Future<void> dispose() async {
    await _audioHandler?.stop();
    _audioHandler = null;
  }

  /// Müziği durdurur
  static Future<void> stop() async {
    await _audioHandler!.stop();
  }

  /// AudioHandler'a erişim
  static MyAudioHandler? get audioHandler => _audioHandler;

  /// Player'a erişim
  static AudioPlayer? get player => _audioHandler?.player;

  /// Mevcut çalma durumu
  static bool get isPlaying => _audioHandler?.player?.playing ?? false;

  /// Mevcut pozisyon
  static Duration get currentPosition =>
      _audioHandler?.player?.position ?? Duration.zero;

  /// Toplam süre
  static Duration get totalDuration =>
      _audioHandler?.player?.duration ?? Duration.zero;

  /// Mevcut parça indeksi
  static int? get currentIndex => _audioHandler?.player?.currentIndex;

  /// Shuffle modu aktif mi
  static bool get isShuffleEnabled =>
      _audioHandler?.player?.shuffleModeEnabled ?? false;

  /// Loop modu
  static LoopMode get loopMode =>
      _audioHandler?.player?.loopMode ?? LoopMode.off;
}
