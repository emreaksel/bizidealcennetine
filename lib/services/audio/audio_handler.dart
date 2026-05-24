import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:rxdart/rxdart.dart';

import 'package:bizidealcennetine/services/audio/playlist_manager.dart';
import 'package:bizidealcennetine/services/audio/log_manager.dart';
import 'package:bizidealcennetine/services/audio/media_broadcast_manager.dart';
import 'package:bizidealcennetine/services/audio/audio_service.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/services/log_service.dart';
import 'package:bizidealcennetine/services/MusicApiService.dart';
import 'package:bizidealcennetine/services/Notifier.dart';

// A global player instance. This can be accessed from anywhere in the app.
final player = media_kit.Player();

/// An [AudioHandler] that bridges [audio_service] and [media_kit].
/// This is a generic and robust implementation designed to be reusable.
class GenericAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _queue = BehaviorSubject<List<MediaItem>>.seeded([]);
  late final StreamSubscription<void> _playerStateSubscription;

  final playlistManager = PlaylistManager();
  final logManager = ListenLogManager();
  late MediaBroadcastManager _broadcastManager;

  @override
  BehaviorSubject<List<MediaItem>> get queue => _queue;

  GenericAudioHandler() {
    // Merge multiple streams into one to react to any state change.
    _playerStateSubscription = Rx.merge([
      player.stream.playing,
      player.stream.completed,
      player.stream.buffering,
      player.stream.error,
      player.stream.playlist,
      player.stream.position, // Listen to position changes to catch seeks.
    ]).listen((_) => _broadcastState());

    // BT ve Bildirim yönetimi için BroadcastManager'ı başlat
    _broadcastManager = MediaBroadcastManager(
      handler: this,
      player: player,
      playbackState: playbackState,
      mediaItem: mediaItem,
      currentState: () => playbackState.value,
    );
    _broadcastManager.init();

    // Listen for the current playing item to complete to handle skipToNext.
    player.stream.completed.listen((completed) {
      if (completed) {
        skipToNext();
      }
    });

    // ProgressNotifier senkronizasyonu
    player.stream.position.listen((pos) {
      AppAudioService.progressNotifier.value = ProgressBarState(
        current: pos,
        buffered: player.state.buffer,
        total: player.state.duration,
      );
    });

    // Loglama senkronizasyonu
    player.stream.playing.listen((playing) {
      if (playing) {
        logManager.onPlay();
      } else {
        logManager.onPause();
      }
    });

    logManager.loadPersistedLogs();
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    // 1. Broadcast manager'a niyeti bildir → _isStopped=true → idle yayınlanır
    _broadcastManager.setIntendedPaused();

    // 2. Oynatıcıyı durdur
    await player.stop();

    // 3. idle state'i garanti için doğrudan yaz
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
      controls: [],
    ));

    logManager.finalizeCurrentLog();

    // 4. audio_service'e "foreground servisi kapat" sinyali ver
    await super.stop();

    // DISPOSE/RECREATE YOK — _isStopped bayrağı yeterli
    // Bir sonraki play() → setIntendedPlaying() → _isStopped=false → her şey normale döner
  }

  @override
  Future<void> skipToNext() async {
    final nextSong = playlistManager.calculateNext();
    if (nextSong != null) await _playTrackInternal(nextSong);
  }

  @override
  Future<void> skipToPrevious() async {
    final prevSong = playlistManager.calculatePrevious();
    if (prevSong != null) {
      playlistManager.rewindHistory();
      await _playTrackInternal(prevSong);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // PlaylistManager üzerinden index bazlı çalma gerekirse burası güncellenebilir
    super.skipToQueueItem(index);
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final sourceUrl = item.extras?['url'] as String? ?? item.id;

    if (sourceUrl.isEmpty) {
      print("Error: MediaItem has no playable URL.");
      return;
    }

    _broadcastManager.setIntendedPlaying();
    try {
      await player.open(media_kit.Media(sourceUrl), play: true);
      _broadcastManager.refreshMediaItem(item);
    } catch (e) {
      print("Error opening media with media_kit: $e");
    }
  }

  // --- Uygulamaya Özel Playlist Metodları ---

  Future<void> initializeMainList(List<dynamic> data,
      {bool playNow = true}) async {
    playlistManager.setMainList(data);
    Degiskenler.listeYuklendi = true;

    if (playNow) {
      await _playRandom();
    } else {
      // Rastgele bir parça seç ve hazırla, ama çalma
      final song = playlistManager.randomSong();
      if (song != null) {
        await _stageTrack(song);
      } else {
        AppAudioService.playlistLoadingNotifier.value = false;
      }
    }
  }

  /// Parçayı player'a yükler ama başlatmaz.
  /// playNow:false ile açılışta ilk parçayı hazır tutmak için kullanılır.
  Future<void> _stageTrack(Map<String, dynamic> song) async {
    AppAudioService.playlistLoadingNotifier.value = true;
    final siraNo = int.tryParse(song['sira_no']?.toString() ?? '') ?? -1;
    Degiskenler.parcaIndex = siraNo;

    final mItem = MediaItem(
      id: song['sira_no'].toString(),
      album: Degiskenler.liste_adi ?? "",
      title: song['parca_adi'] ?? "Bilinmeyen Parça",
      artist: song['seslendiren'] ?? "Ben Olan Ben",
      artUri: Uri.parse(
          "${Degiskenler.kaynakYolu}medya/atesiask/${Degiskenler.currentImageNotifier.value}"),
      extras: {'url': song['url']},
    );

    playlistManager.recordNavigation(song);

    // mediaItem'ı güncelle — UI başlık/sanatçı görebilsin
    mediaItem.add(mItem);
    AppAudioService.currentSongTitleNotifier.value = mItem.title;
    AppAudioService.currentSongSubTitleNotifier.value = mItem.artist ?? "";

    // Player'a yükle ama play:false → hazır bekle
    final sourceUrl = mItem.extras?['url'] as String? ?? mItem.id;
    if (sourceUrl.isNotEmpty) {
      try {
        await player.open(media_kit.Media(sourceUrl), play: false);
        _broadcastManager.refreshMediaItem(mItem);
      } catch (e) {
        LogService().warn("[stageTrack] player.open hatası: $e", tag: "Audio");
      }
    }

    AppAudioService.playlistLoadingNotifier.value = false;
  }

  Future<void> playSong(int siraNo) async {
    final song = playlistManager.findBySiraNo(siraNo);
    if (song != null) await _playTrackInternal(song);
  }

  Future<void> switchToMainList() async => playlistManager.switchToMainList();

  Future<void> switchToDokunanlar(List<dynamic> songList) async {
    playlistManager.setDokunanlarList(songList);
    playlistManager.switchToDokunanlar();
  }

  Future<void> playGiftTrack(String link, String id) async {
    final response = await MusicApiService().fetchAtesiAskLink(link, id);
    if (response != null && response.containsKey('isaretler')) {
      final item = Map<String, dynamic>.from(response['isaretler'] as Map)
        ..['_isGift'] = true;
      await _playTrackInternal(item);
    }
  }

  Future<void> _playRandom() async {
    final song = playlistManager.randomSong();
    if (song != null) await _playTrackInternal(song);
  }

  Future<void> _playTrackInternal(Map<String, dynamic> song) async {
    AppAudioService.playlistLoadingNotifier.value = true;
    final siraNo = int.tryParse(song['sira_no']?.toString() ?? '') ?? -1;
    Degiskenler.parcaIndex = siraNo;

    final mItem = MediaItem(
      id: song['sira_no'].toString(),
      album: Degiskenler.liste_adi ?? "",
      title: song['parca_adi'] ?? "Bilinmeyen Parça",
      artist: song['seslendiren'] ?? "Ben Olan Ben",
      artUri: Uri.parse(
          "${Degiskenler.kaynakYolu}medya/atesiask/${Degiskenler.currentImageNotifier.value}"),
      extras: {'url': song['url']},
    );

    playlistManager.recordNavigation(song);
    logManager.startNewLog(siraNo.toString());

    await playMediaItem(mItem);

    AppAudioService.currentSongTitleNotifier.value = mItem.title;
    AppAudioService.currentSongSubTitleNotifier.value = mItem.artist ?? "";
    AppAudioService.playlistLoadingNotifier.value = false;
  }

  /// Ses seviyesini ayarlar. media_kit 0-100 arası beklediği için 100 ile çarpılır.
  Future<void> setVolume(double volume) async {
    await player.setVolume(volume * 100.0);
    AppAudioService.volumeNotifier.value = volume;
  }

  // --- Queue Management Methods ---

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    final newQueue = queue.value..add(item);
    queue.add(newQueue);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem item) async {
    final newQueue = queue.value..insert(index, item);
    queue.add(newQueue);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final newQueue = queue.value..removeAt(index);
    queue.add(newQueue);
  }

  void _broadcastState() {
    // BroadcastManager zaten dinliyor ve yayın yapıyor.
    // İhtiyaç duyulursa burada ek hamleler yapılabilir.
  }

  PlaybackState _transformEvent(media_kit.PlayerState playerState) {
    AudioProcessingState processingState;

    if (playerState.buffering) {
      processingState = AudioProcessingState.buffering;
    } else if (playerState.completed) {
      processingState = AudioProcessingState.completed;
    } else if (!playerState.playing) {
      processingState = mediaItem.value == null
          ? AudioProcessingState.idle
          : AudioProcessingState.ready;
    } else {
      processingState = AudioProcessingState.ready;
    }

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playerState.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playerState.playing,
      updatePosition: playerState.position,
      bufferedPosition: playerState.buffer,
      speed: playerState.rate,
    );
  }

  @override
  Future<void> onTaskRemoved() {
    stop();
    player.dispose();
    _playerStateSubscription.cancel();
    return super.onTaskRemoved();
  }
}
