import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/services/HttpService.dart';
import 'package:bizidealcennetine/services/JsonHelper.dart';
import 'package:bizidealcennetine/yaveran/ui_support.dart';
import 'package:bizidealcennetine/services/audio/audio_service.dart'
    as app_audio;
import 'package:bizidealcennetine/services/MusicApiService.dart';
import 'package:bizidealcennetine/services/log_service.dart';

final appLinks = AppLinks();

// AppLink çift tetiklenmeyi engellemek için
String? _lastHandledLink;
DateTime? _lastHandleTime;

Future<void> arkaplanIslemleri() async {
  LogService().info("Arkaplan işlemleri başlıyor, link kontrolü bekleniyor...",
      tag: "Logic");

  // Burası 'complete()' komutu gelene kadar akışı durdurur (ama uygulamayı dondurmaz)
  await Degiskenler.linkKontrolCompleter.future;

  // Artık link kontrolü bitti, bekleyen bir hediye varsa 'Degiskenler' içine yazıldı.
  // Gönül rahatlığıyla veri çekmeye devam edebiliriz.
  LogService()
      .info("Link kontrolü tamamlandı, veriler çekiliyor...", tag: "Logic");
  Degiskenler.hazirlaniyor = true;

  // ✅ YENİ: Splash kapandığında loader'ın gözükmesi için bu notifier'ı aktif et
  app_audio.AudioService.playlistLoadingNotifier.value = true;

  await Degiskenler.loadTheme();

  try {
    LogService().info("Ses servisi başlatılıyor...", tag: "Logic");
    await app_audio.AudioService.init();
    await app_audio.AudioService.loadVolume();
  } catch (e) {
    print("Error initializing AudioService: $e");
  }

  // Tek bir istek ile tüm verileri alıyoruz
  try {
    final combinedData = await MusicApiService().fetchAtesiAskSub();
    if (combinedData.containsKey("isaretler")) {
      final isaretler = combinedData["isaretler"];

      // 1. Menba İşlemleri
      if (isaretler.containsKey("menba")) {
        processMenbaData(isaretler["menba"]);
      }

      // 2. Fotoğraf İşlemleri
      if (isaretler.containsKey("resimler")) {
        processImagesData(isaretler["resimler"]);
      }

      // 3. Söz İşlemleri
      if (isaretler.containsKey("sozler")) {
        processSozlerData(isaretler["sozler"]);
      }
    }
  } catch (e) {
    print("Combined fetch error: $e");
    // Hata durumunda eski usul devam etsin (yedek plan)
    await fetchData_jsonMenba("${Degiskenler.kaynakYolu}kaynak/menba.json");
    fetchData_jsonFotograflar("${Degiskenler.kaynakYolu}medya/images.json");
    fetchData_jsonSozler("${Degiskenler.kaynakYolu}kaynak/sozler.json");
  }

  Degiskenler.hazirlaniyor = false;
  MusicApiService().syncInitialStatus();
}

void processMenbaData(Map<String, dynamic> jsonData) {
  int dinlemeListesiID = jsonData["aktifliste"]["dinlemeListesiID"];
  List<dynamic> dinlemeListeleri = jsonData["dinlemeListeleri"];
  for (var item in dinlemeListeleri) {
    int id = item["id"];
    String link = item["link"];
    String caption = item["caption"];
    if (id == dinlemeListesiID) {
      Degiskenler.liste_adi = caption;
      Degiskenler.liste_link = link;
      fetchData_jsonDinlemeListesi(
          "${Degiskenler.kaynakYolu}kaynak/$link.json", link,
          playNow: false);
    }
  }

  Map<String, dynamic> bildirim = jsonData["bildirim"];
  bildirimKontrol(bildirim);

  final degiskenler = Degiskenler();
  degiskenler.versionMenba = jsonData["versiyon"];
  Degiskenler.dinlemeListeleriNotifier.value = dinlemeListeleri;
}

void processImagesData(List<dynamic> fotograflarListesi) {
  if (fotograflarListesi.isNotEmpty) {
    final degiskenler = Degiskenler();
    degiskenler.listFotograflar = fotograflarListesi;
    UI_support.changeImage();
  }
}

void processSozlerData(List<dynamic> sozlerListesi) {
  if (sozlerListesi.isNotEmpty) {
    final degiskenler = Degiskenler();
    degiskenler.listSozler = sozlerListesi;
    UI_support.changeEpigram();
  }
}

Future<void> setPlaylist(data, {bool playNow = true}) async {
  print("setPlaylist called with ${data.length} items");

  // Veri dönüşümünü (tersine çevirme + filtreleme) izolatta yap — main thread serbest kalır
  final List<dynamic> reversedData =
      await compute(_preparePlaylistData, List<dynamic>.from(data));

  final degiskenler = Degiskenler();
  degiskenler.listDinle = reversedData;
  Degiskenler.songListNotifier.value = reversedData;

  await app_audio.AudioService.setMainList(reversedData, playNow: playNow);

  print("Playlist set successfully");
}

/// Compute izolat'ında çalışır — tersine çevirir ve URL'siz öğeleri filtreler.
/// Top-level (veya static) olmak zorunda.
List<dynamic> _preparePlaylistData(List<dynamic> data) {
  return data.reversed.where((item) {
    final url = item['url'];
    return url != null && (url as String).isNotEmpty;
  }).toList();
}

Future<void> initUniLinks(Function(String) handleLinkCallback) async {
  try {
    // iOS için senin eklediğin o kritik bekleme
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final initialLink = await appLinks.getInitialLink();
    LogService()
        .info("Açılış linki kontrol ediliyor: $initialLink", tag: "Link");

    if (initialLink != null) {
      handleLinkCallback(initialLink.toString());
    }

    // Yeni gelen linkleri dinlemeye devam et
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        LogService().info("Yeni link alındı: $uri", tag: "Link");
        handleLinkCallback(uri.toString());
      }
    });
  } catch (e) {
    LogService().error("Link yakalama hatası: $e", tag: "Link");
  } finally {
    // 🚩 İŞTE BURASI KRİTİK:
    // Link gelse de gelmese de, hata olsa da olmasa da
    // "Link kontrol aşaması bitti" diyoruz.
    if (!Degiskenler.linkKontrolCompleter.isCompleted) {
      Degiskenler.linkKontrolCompleter.complete();
    }
  }
}

void handleLink(String? link) {
  if (link != null) {
    LogService().info("Link işleme başladı: $link", tag: "Link");

    // Çift tetiklenme kontrolü (2 saniye içinde aynı link gelirse reddet)
    final now = DateTime.now();
    if (_lastHandledLink == link &&
        _lastHandleTime != null &&
        now.difference(_lastHandleTime!) < const Duration(seconds: 2)) {
      LogService().warn(
          "Aynı link kısa süre içinde tekrar geldi, yoksayılıyor: $link",
          tag: "Link");
      return;
    }
    _lastHandledLink = link;
    _lastHandleTime = now;

    link =
        link.toString().replaceAll(RegExp(r"\s+"), "").replaceAll("&amp;", "&");
    LogService().debug("Link normalize edildi: $link", tag: "Link");

    if (link.contains('https://benolanben.com/dinle/')) {
      LogService().info("Hediye (Applink) parça tespit edildi", tag: "Link");
      var hediye = link.replaceAll('https://benolanben.com/dinle/', '');
      var parts = hediye.split('&');

      if (parts.length >= 2) {
        var linkPart = parts[0];
        var idPart = parts[1];
        LogService().info(
            "Hediye detayları: linkPart=$linkPart, idPart=$idPart",
            tag: "Link");

        if (linkPart.isNotEmpty && idPart.isNotEmpty) {
          if (Degiskenler.listeYuklendi) {
            LogService().info("Liste yüklü, doğrudan oynatılıyor", tag: "Link");
            app_audio.AudioService.playGiftTrack(linkPart, idPart);
          } else {
            LogService().info(
                "Liste henüz yüklenmedi, hediye sıraya alındı ve sistem uyandırılıyor",
                tag: "Link");
            Degiskenler.bekleyenHediyeLink = linkPart;
            Degiskenler.bekleyenHediyeId = idPart;

            // Sistem durdurulmuşsa (liste yüklü değilse) tekrar uyandır
            Degiskenler.showSplashNotifier.value = true;
          }
        } else {
          LogService().error(
              "Hediye linki veya ID boş: linkPart='$linkPart', idPart='$idPart'",
              tag: "Link");
        }
      } else {
        LogService().error(
            "Hediye linki ayrıştırılamadı (parts.length < 2): $link",
            tag: "Link");
      }
    } else {
      LogService().info("Bildirim/Duyuru linki tespit edildi", tag: "Link");
      Degiskenler.currentNoticeNotifier.value = link;
      Degiskenler.showDialogNotifier.value = true;
    }
  } else {
    LogService().warn("handleLink null link ile çağrıldı", tag: "Link");
  }
}

Future<void> fetchData_jsonDinlemeListesi(String url, String link,
    {bool playNow = true}) async {
  try {
    final Map<String, dynamic> jsonData = await compute(getirJsonData, url);
    List<dynamic> listDinle = jsonData["sesler"];
    if (Degiskenler.bekleyenHediyeLink != null ||
        Degiskenler.bekleyenHediyeId != null) {
      playNow = true;
      LogService().info(
        "Hediye link bekleniyor, json dinleme listesi playNow=true ile yüklenecek",
        tag: "Logic",
      );
    }
    await setPlaylist(listDinle, playNow: playNow);
  } catch (error) {
    print("Hata oluştu: $error");
    // Hata durumunda loader'ı kapat ki UI asılı kalmasın
    app_audio.AudioService.playlistLoadingNotifier.value = false;
  }
}

Future<void> fetchData_jsonFotograflar(String url) async {
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);

    jsonData.then((jsonDataMap) {
      if (jsonDataMap.containsKey("isaretler")) {
        final List<dynamic> fotograflarListesi = jsonDataMap["isaretler"];
        if (fotograflarListesi.isNotEmpty) {
          final degiskenler = Degiskenler();
          degiskenler.listFotograflar = fotograflarListesi;
          UI_support.changeImage();
        } else {
          print("fotograf listesi boş.");
        }
      }
    });
  } catch (error) {
    print("Hata oluştu: $error");
  }
}

Future<void> fetchData_jsonMenba(String url) async {
  try {
    final Map<String, dynamic> jsonData = await compute(getirJsonData, url);
    int dinlemeListesiID = jsonData["aktifliste"]["dinlemeListesiID"];
    List<dynamic> dinlemeListeleri = jsonData["dinlemeListeleri"];
    for (var item in dinlemeListeleri) {
      int id = item["id"];
      String link = item["link"];
      String caption = item["caption"];
      if (id == dinlemeListesiID) {
        Degiskenler.liste_adi = caption;
        Degiskenler.liste_link = link;
        await fetchData_jsonDinlemeListesi(
            "${Degiskenler.kaynakYolu}kaynak/$link.json", link,
            playNow: false);
      }
    }

    Map<String, dynamic> bildirim = jsonData["bildirim"];
    bildirimKontrol(bildirim);

    final degiskenler = Degiskenler();
    degiskenler.versionMenba = jsonData["versiyon"];
    Degiskenler.dinlemeListeleriNotifier.value = dinlemeListeleri;
  } catch (error) {
    print("Hata oluştu: $error");
  }
}

Future<void> fetchData_jsonSozler(String url) async {
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);
    jsonData.then((jsonData) {
      if (jsonData["sozler"] == null || jsonData["sozler"] == false) {
        return;
      }

      if (jsonData.containsKey("sozler")) {
        final List<dynamic> sozlerListesi = jsonData["sozler"];
        if (sozlerListesi.isNotEmpty) {
          final degiskenler = Degiskenler();
          degiskenler.listSozler = sozlerListesi;
          UI_support.changeEpigram();
        } else {
          print("Söz listesi boş.");
        }
      } else {
        print("Verilerde 'sozler' anahtarı bulunamadı.");
      }
    });
  } catch (error) {
    print("Hata oluştu: $error");
  }
}

Future<Map<String, dynamic>> getirJsonData(String yol) async {
  final HttpService _httpService = HttpService();
  print("getirJsonData $yol");

  try {
    final jsonStr = await _httpService.fetchData(yol);
    final jsonDataList = JsonHelper.parseJson(jsonStr);
    return jsonDataList;
  } catch (error) {
    print('Veri çekilirken bir hata oluştu: $error');
    return {};
  }
}

void bildirimKontrol(Map<String, dynamic> bildirim) async {
  try {
    // 1. Platform Kontrolü
    final String targetPlatformStr =
        (bildirim["platform"] ?? "all").toString().toLowerCase();
    if (targetPlatformStr != "all") {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          targetPlatformStr != "ios") return;
      if (defaultTargetPlatform == TargetPlatform.android &&
          targetPlatformStr != "android") return;
    }

    // 2. Zaman Aralığı Kontrolü (ISO 8601 Formatı)
    String? baslangicStr = bildirim["baslangic"];
    String? bitisStr = bildirim["bitis"];
    if (baslangicStr == null || bitisStr == null) return;

    DateTime baslangic = DateTime.parse(baslangicStr);
    DateTime bitis = DateTime.parse(bitisStr);

    // Türkiye saati (UTC+3) kontrolü
    DateTime suAn = DateTime.now().toUtc().add(const Duration(hours: 3));

    if (suAn.isAfter(baslangic) && suAn.isBefore(bitis)) {
      final String gosterim = bildirim["gosterim"] ?? "H";
      final String metin = bildirim["metin"] ?? "";

      if (metin.isEmpty) return;

      if (gosterim == "T") {
        // "T" (Tek seferlik): Daha önce gösterilip onaylanmış mı?
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? kaydedilenMetin = prefs.getString('bildirim');

        if (kaydedilenMetin != metin) {
          Degiskenler.currentNoticeNotifier.value = metin;
          Degiskenler.showDialogNotifier.value = true;
        }
      } else {
        // "H" (Her açılışta): Her zaman göster
        Degiskenler.currentNoticeNotifier.value = metin;
        Degiskenler.showDialogNotifier.value = true;
      }
    }
  } catch (e) {
    // Tarih formatı hatalıysa veya veri eksikse hatayı logla ancak uygulamayı çökertme
    LogService().error("Bildirim kontrol hatası: $e", tag: "Logic");
  }
}
