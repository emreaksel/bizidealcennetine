import 'dart:math';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';

class UI_support {
  static final Degiskenler _degiskenler = Degiskenler();
  
  // Son çağrılma zamanlarını tutan statik map
  static final Map<String, DateTime> _lastCallTimes = {};
  
  // Debounce süresi (milisaniye)
  static const int _debounceDurationMs = 700;
  
  // Fonksiyon çağrısının debounce kontrolünü yapan statik metod
  static bool _shouldExecute(String functionName) {
    final now = DateTime.now();
    final lastCall = _lastCallTimes[functionName];
    
    if (lastCall == null) {
      _lastCallTimes[functionName] = now;
      return true;
    }
    
    final timeDifference = now.difference(lastCall).inMilliseconds;
    
    if (timeDifference >= _debounceDurationMs) {
      _lastCallTimes[functionName] = now;
      return true;
    }
    
    print("$functionName fonksiyonu ${timeDifference}ms önce çağrıldı, debounce nedeniyle atlandı");
    return false;
  }

  static void changeImage() {
    if (!_shouldExecute('changeImage')) return;
    
    if (_degiskenler.listFotograflar.isNotEmpty) {
      final Random random = Random();
      final int randomIndex = random.nextInt(_degiskenler.listFotograflar.length);
      final String secilen = _degiskenler.listFotograflar[randomIndex]['path'];
      Degiskenler.currentImageNotifier.value = secilen;
      print("Rastgele Seçilen fotograf: $secilen");
    }
  }

  static void changeEpigram() {
    if (!_shouldExecute('changeEpigram')) return;
    
    if (_degiskenler.listSozler.isNotEmpty) {
      final Random random = Random();
      final int randomIndex = random.nextInt(_degiskenler.listSozler.length);
      final String secilenSoz = _degiskenler.listSozler[randomIndex];
      Degiskenler.currentEpigramNotifier.value = secilenSoz;
      print("Rastgele Seçilen Söz: $secilenSoz");
    }
  }

  static void changeImageAndEpigram() {
    if (!_shouldExecute('changeImageAndEpigram')) return;
    
    // Resim değiştir
    if (_degiskenler.listFotograflar.isNotEmpty) {
      final Random random = Random();
      final int randomIndex = random.nextInt(_degiskenler.listFotograflar.length);
      final String secilen = _degiskenler.listFotograflar[randomIndex]['path'];
      Degiskenler.currentImageNotifier.value = secilen;
      print("Rastgele Seçilen fotograf: $secilen");
    }

    // Söz değiştir
    if (_degiskenler.listSozler.isNotEmpty) {
      final Random random = Random();
      final int randomIndex = random.nextInt(_degiskenler.listSozler.length);
      final String secilenSoz = _degiskenler.listSozler[randomIndex];
      Degiskenler.currentEpigramNotifier.value = secilenSoz;
      print("Rastgele Seçilen Söz: $secilenSoz");
    }
  }
  
  // Debug için - son çağrılma zamanlarını görmek istersen
  static void printLastCallTimes() {
    print("Son çağrılma zamanları:");
    _lastCallTimes.forEach((functionName, time) {
      print("$functionName: $time");
    });
  }
  
  // Belirli bir fonksiyonun son çağrılma zamanını sıfırlamak için
  static void resetFunctionTimer(String functionName) {
    _lastCallTimes.remove(functionName);
    print("$functionName için timer sıfırlandı");
  }
  
  // Tüm timerleri sıfırlamak için
  static void resetAllTimers() {
    _lastCallTimes.clear();
    print("Tüm timerlar sıfırlandı");
  }
}
