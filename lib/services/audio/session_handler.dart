import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioSessionHandler {
  bool _wasPlayingBeforeInterruption = false;
  bool _manuallyPaused = false; // Optional logic if needed

  Future<void> init(AudioPlayer player) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);

    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _wasPlayingBeforeInterruption = player.playing;
        await player.pause();
      } else {
        if (_wasPlayingBeforeInterruption && !_manuallyPaused) {
          await Future.delayed(const Duration(seconds: 1));
          // ✅ DEĞİŞİKLİK: Devam etmeden önce session'ı yeniden aktifleştir
          await session.setActive(true);
          await player.play();
        }
        _wasPlayingBeforeInterruption = false;
      }
    });

    // ✅ YENİ: Uygulama audio focus'u kaybederse (başka uygulama müzik açarsa)
    session.becomingNoisyEventStream.listen((_) async {
      // Kulaklık çıkarılırsa durdur
      await player.pause();
      _manuallyPaused = true;
    });
  }

  void setManuallyPaused(bool paused) {
    _manuallyPaused = paused;
  }
}
