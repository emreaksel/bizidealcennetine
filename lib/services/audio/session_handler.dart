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
        // Telefon çaldı ya da başka ses geldi → duraklat
        _wasPlayingBeforeInterruption = player.playing;
        await player.pause();
      } else {
        // Kesinti bitti → kullanıcı manuel duraklatmadıysa devam et
        if (_wasPlayingBeforeInterruption && !_manuallyPaused) {
          await Future.delayed(const Duration(seconds: 1));
          await player.play();
        }
        _wasPlayingBeforeInterruption = false;
      }
    });
  }

  void setManuallyPaused(bool paused) {
    _manuallyPaused = paused;
  }
}
