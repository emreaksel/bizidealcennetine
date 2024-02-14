import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:bizidealcennetine/main.dart';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'Notifier.dart';

class AudioService {
  static AudioPlayer? _player;
  static BehaviorSubject<Duration>? _positionSubject;
  static String parca_adi="...";
  static String seslendiren="...";
  static List<MediaItem> parca_listesi=[];

  static final progressNotifier  = ProgressNotifier();
  static final currentSongTitleNotifier = ValueNotifier<String>('...');
  static final currentSongSubTitleNotifier = ValueNotifier<String>('...');
  //final currentSongTitleNotifier = ValueNotifier<String>('');
  static final playlistNotifier = ValueNotifier<List<String>>([]);
  //final progressNotifier = ProgressNotifier();
  static final repeatButtonNotifier = RepeatButtonNotifier();
  static final isFirstSongNotifier = ValueNotifier<bool>(true);
  static final playButtonNotifier = PlayButtonNotifier();
  static final isLastSongNotifier = ValueNotifier<bool>(true);
  static final isShuffleModeEnabledNotifier = ValueNotifier<bool>(false);
  static bool _initialized = false;
  UI_support uiSupport = UI_support();

  AudioPlayer get player {
    if (_player == null) {
      throw Exception("AudioService has not been initialized.");
    }
    return _player!;
  }
  BehaviorSubject<Duration> get positionSubject {
    if (_positionSubject == null) {
      throw Exception("AudioService has not been initialized.");
    }
    return _positionSubject!;
  }
  Future<void> init() async {
    if (!_initialized) {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      );
      _player = AudioPlayer();
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _positionSubject = BehaviorSubject<Duration>();

      _player!.playbackEventStream.listen((event) {
        if (event.processingState == ProcessingState.completed) {
          // Handle playback completion
        }
        _positionSubject!.add(event.updatePosition);
      }, onError: (Object e, StackTrace stackTrace) {
        print('A stream error occurred: $e');
      });

      player.currentIndexStream.listen((index) {

        setCurrentTrack(index);
        print('--- player.currentIndexStream $index');
      });
      player.playerStateStream.listen((playerState) {

        final isPlaying = playerState.playing;
        final processingState = playerState.processingState;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          playButtonNotifier.value = ButtonState.loading;
        }
        else if (!isPlaying) {
          playButtonNotifier.value = ButtonState.paused;
        }
        else if (processingState != ProcessingState.completed) {
          playButtonNotifier.value = ButtonState.playing;
        }
        else {
          player.seek(Duration.zero);
          player.pause();
        }
        //print("TEST playerStateStream: ${isPlaying} ${playButtonNotifier.value}");
      });
      player.positionStream.listen((position) {
        final oldState = progressNotifier.value;
        progressNotifier.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total,
        );
      });
      player.durationStream.listen((totalDuration) {
        final oldState = progressNotifier.value;
        progressNotifier.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: totalDuration ?? Duration.zero,
        );
      });
      player.bufferedPositionStream.listen((bufferedPosition) {
        final oldState = progressNotifier.value;
        progressNotifier.value = ProgressBarState(
          current: oldState.current,
          buffered: bufferedPosition,
          total: oldState.total,
        );
      });
      final shuffleEnabled = player.shuffleModeEnabled;
      player.setShuffleModeEnabled(!shuffleEnabled);
      _initialized = true;
    }
  }

  Future<void> setPlaylist(List<AudioSource> sources) async {
    // Check if the list of sources is not empty
    if (sources.isEmpty) {
      throw ArgumentError("The list of sources cannot be empty.");
    }
    final Random random = Random();
    final int initialIndex = random.nextInt(sources.length);

    try {
      if (player.audioSource != null) {
        //await player.stop();
        //init();
      }
        // If no audio source is set, set the new playlist
        await player.setAudioSource(
          ConcatenatingAudioSource(children: sources, useLazyPreparation: true),
          initialIndex: initialIndex,
          initialPosition: Duration.zero,
        );

    } catch (e) {
      // Handle any errors that may occur during the process
      print("Error setting playlist: $e");
    }
  }
  Future<void> addTrackToPlaylist(adi,ses,yol,sira,oynat) async {
    // 1. Yeni parçayı songListNotifier değişkenine ekle
    Degiskenler.songListNotifier.value.add(
      {'sira_no': sira, 'parca_adi': adi, 'seslendiren': ses, 'url': yol}
    );
    // 2. Değişikliği bildirmek için ValueNotifier'ın value özelliğini güncelle
    //Degiskenler.songListNotifier.notifyListeners();

    AudioSource newSource=AudioSource.uri(
      Uri.parse(yol),
      tag: MediaItem(
        id: sira.toString(),
        album: adi,
        title: adi,
        artUri: Uri.parse(
          "${Degiskenler.kaynakYolu}/atesiask/bahar11.jpg",
        ),
        artist: ses,
      ),
    );

    try {
      // Mevcut çalma listesini al
      var currentSources = (player.audioSource as ConcatenatingAudioSource).children;
      // Yeni parçayı çalma listesine ekle
      currentSources.add(newSource);
      // Yeni çalma listesini ayarla
      //await player.setAudioSource(ConcatenatingAudioSource(children: currentSources));
      await player.setAudioSource(ConcatenatingAudioSource(children: currentSources),initialIndex: currentSources.length-1, initialPosition: Duration.zero);

    } catch (e, stackTrace) {
      print("Error adding track to playlist: $e");
      print(stackTrace);
    }

    if (oynat) play();
  }

  setCurrentTrack(index){
    if (index != null) {
      parca_adi = degiskenler.listDinle[index]["parca_adi"];
      seslendiren = degiskenler.listDinle[index]["seslendiren"];
      currentSongTitleNotifier.value = parca_adi;
      currentSongSubTitleNotifier.value = seslendiren;
      Degiskenler.parcaIndex=degiskenler.listDinle[index]["sira_no"];
    }
  }
  Future<void> play() async {
    //print("TEST play: ${player.playing}");
    await player.play();
  }
  Future<void> pause() async {
    //print("TEST pause: ${player.playing}");
    await player.pause();

  }
  Future<void> play_pause() async {
    //print("TEST play_pause: ${player.playing}");
    if(player.playing) await pause();
    else await play();
  }
  Future<void> next() async {
    uiSupport.changeImage();
    uiSupport.changeEpigram();
    await player.seekToNext();
  }
  Future<void> previous() async {
    await player.seekToPrevious();
  }
  Future<void> seek(Duration position) async {
    player.seek(position);
  }
  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= player.audioSource!.sequence.length) {
      print("Invalid index: $index");
      return;
    }

    await player.seek(Duration.zero, index: index);
    await play();
  }
  Future<void> playAtId(int id) async {
    /*if (id < 0 || id > player.audioSource!.sequence.length) {
      print("Invalid index: $id");
      return;
    }*/
    print("playAtId: $id");
    var songid=-1;

    /*for (var item in Degiskenler.songListNotifier.value){
      //print(item);
      if(item['sira_no']==id) {
        songid=id;
        print(songid);
        break;
      }
    }*/
    for (int index = 0; index < Degiskenler.songListNotifier.value.length; index++) {
      var item = Degiskenler.songListNotifier.value[index];
      if (item['sira_no'] == id) {
        print("Eşleşen indeks: $index");
        songid=index;
        // Burada istediğiniz işlemleri gerçekleştirebilirsiniz
        break; // Eşleşen öğeyi bulduktan sonra döngüden çık
      }
    }


    if(songid==-1) return;
    await player.seek(Duration.zero, index: songid);
    await play();
  }
  Future<void> repeat() async {
    if (repeatButtonNotifier.value == RepeatState.on) {
      await player.setLoopMode(LoopMode.all);
      repeatButtonNotifier.value = RepeatState.off;
    }
    else {
      await player.setLoopMode(LoopMode.one);
      repeatButtonNotifier.value = RepeatState.on;
    }
  }
  Future<void> hediye() async {
    await player.seekToNext();
  }


  dynamic getCurrentTrackName() {
    print("Dinleniyor: ${parca_adi}");
    return parca_adi;
  }
  dynamic getCurrentTrackName2() {
    print("Dinleniyor: ${seslendiren}");
    return seslendiren;
  }

  void dispose() {
    _player?.dispose();
    _positionSubject?.close();
    _initialized = false;
  }

  void onRepeatButtonPressed() {
    // TODO
  }

  void onPreviousSongButtonPressed() {
    // TODO
  }

  void onNextSongButtonPressed() {
    // TODO
  }

  void onShuffleButtonPressed() async {
    // TODO
  }
}

class UI_support {
  final Duration _debounceDuration = Duration(seconds: 5);
  static Timer? _debouncer;
  static Timer? _debouncer2;

  void changeImage() {
    if (_debouncer == null) {
      if (degiskenler.listFotograflar.isEmpty) {
        print('degiskenler.listFotograflar boş.');
      } else {
        _debouncer = Timer(Duration(seconds: 1), () {});
        print('degiskenler.listFotograflar _debouncer == goto. ==> _changeImage();');
        _changeImage();
      }
    }
    else if (!_debouncer!.isActive) {
      _debouncer = Timer(_debounceDuration, () {
        _changeImage();
      });
    }
  }
  void changeEpigram() {
    if (_debouncer2 == null) {
      if (degiskenler.listSozler.isEmpty) {
          print('degiskenler.listSozler boş.');
        } else {
        _debouncer2 = Timer(Duration(seconds: 1), () {});
        _changeEpigram();
        }
      }
      else if (!_debouncer2!.isActive) {
        _debouncer2 = Timer(_debounceDuration, () {
          _changeEpigram();
        });
      }
  }

  void _changeImage(){
    final Random random = Random();
    final int randomIndex = random.nextInt(degiskenler.listFotograflar.length);
    final String secilen = degiskenler.listFotograflar[randomIndex]['path'];
    Degiskenler.currentImageNotifier.value = secilen;
    print("Rastgele Fotograf: $secilen");
  }
  void _changeEpigram(){
    final Random random = Random();
    final int randomIndex = random.nextInt(degiskenler.listSozler.length);
    final String secilen = degiskenler.listSozler[randomIndex];
    Degiskenler.currentEpigramNotifier.value = secilen;
    print("Rastgele Söz: $secilen");
  }
}


