import 'dart:async';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/services/audio/audio_service.dart';

class SleepTimerManager {
  static Timer? _sleepTimer;
  static Timer? _sleepCountdown;

  static void start(int minutes) {
    cancel();
    if (minutes <= 0) return;

    int remaining = minutes * 60;
    Degiskenler.sleepTimerRemainingNotifier.value = remaining;

    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining--;
      Degiskenler.sleepTimerRemainingNotifier.value = remaining;
      if (remaining <= 0) {
        AudioService.pause();
        cancel();
      }
    });

    // Geri sayım hata yapsa bile ana zamanlayıcı garantiyle çalışır
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      AudioService.pause();
      cancel();
    });
  }

  static void cancel() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepCountdown?.cancel();
    _sleepCountdown = null;
    Degiskenler.sleepTimerRemainingNotifier.value = 0;
  }
}
