import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizidealcennetine/services/audio/audio_service.dart';

class VolumeManager {
  static double _lastVolume = 1.0;

  static Future<void> setVolume(double volume) async {
    await AppAudioService.audioHandler?.setVolume(volume);
    // Sıfırı kaydetme (mute geçici olmalı)
    if (volume > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('player_volume', volume);
    }
  }

  static Future<void> toggleMute() async {
    if (AppAudioService.volumeNotifier.value > 0) {
      _lastVolume = AppAudioService.volumeNotifier.value;
      await setVolume(0);
    } else {
      await setVolume(_lastVolume > 0 ? _lastVolume : 1.0);
    }
  }

  static Future<void> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await setVolume(prefs.getDouble('player_volume') ?? 1.0);
  }
}
