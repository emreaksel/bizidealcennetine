import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:bizidealcennetine/services/audio/audio_handler.dart';
import 'package:bizidealcennetine/services/log_service.dart';
import 'package:bizidealcennetine/services/audio/volume_manager.dart';

import 'dart:async';
import 'package:bizidealcennetine/services/Notifier.dart';
import 'package:bizidealcennetine/services/audio/sleep_timer_manager.dart';

/// 1. APPAUDIOSERVICE: STATIC PROXY BRIDGE FOR THE UI
class AppAudioService {
  static late GenericAudioHandler _handler;
  static final ValueNotifier<bool> playlistLoadingNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<double> volumeNotifier =
      ValueNotifier<double>(1.0);
  static final playButtonNotifier = PlayButtonNotifier();
  static final progressNotifier = ProgressNotifier();
  static final shuffleRepeatNotifier = ShuffleRepeatNotifier();
  static final currentSongTitleNotifier = ValueNotifier<String>("");
  static final currentSongSubTitleNotifier = ValueNotifier<String>("");
  static final isShareableNotifier = ValueNotifier<bool>(true);

  static GenericAudioHandler? get audioHandler => _handler;

  static Future<void> init() async {
    LogService()
        .info("AudioService ve Arkaplan Handler başlatılıyor...", tag: "Audio");

    // Introduce the player to the operating system
    _handler = await AudioService.init(
      builder: () => GenericAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ea.atesi_ask.audio',
        androidNotificationChannelName: 'Atesi Ask',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  static Future<void> loadVolume() async {
    await VolumeManager.loadVolume();
  }

  static Future<void> setMainList(List<dynamic> items,
      {bool playNow = true}) async {
    playlistLoadingNotifier.value = true;
    LogService()
        .info("Playlist oluşturuluyor. Parça: ${items.length}", tag: "Audio");
    await _handler.initializeMainList(items, playNow: playNow);
  }

  static Future<void> playGiftTrack(String linkPart, String idPart) async {
    await _handler.playGiftTrack(linkPart, idPart);
  }

  // --- Static Proxy Methods ---
  static Future<void> play() => _handler.play();
  static Future<void> pause() => _handler.pause();
  static Future<void> stop() => _handler.stop();
  static Future<void> skipToNext() => _handler.skipToNext();
  static Future<void> skipToPrevious() => _handler.skipToPrevious();
  static Future<void> seek(Duration position) => _handler.seek(position);

  // Alias for UI consistency
  static Future<void> next() => skipToNext();
  static Future<void> previous() => skipToPrevious();
  static void toggleShuffleRepeat() => shuffleRepeatNotifier.nextState();

  // --- List Transitions & Playing ---
  static Future<void> switchToMainList() => _handler.switchToMainList();
  static Future<void> switchToDokunanlar(List<dynamic> songList) =>
      _handler.switchToDokunanlar(songList);
  static Future<void> playSong(int siraNo) => _handler.playSong(siraNo);

  // --- Volume and Timer ---
  static void startSleepTimer(int minutes) => SleepTimerManager.start(minutes);
  static void cancelSleepTimer() => SleepTimerManager.cancel();
  static Future<void> setVolume(double volume) =>
      VolumeManager.setVolume(volume);
  static Future<void> toggleMute() => VolumeManager.toggleMute();
}
