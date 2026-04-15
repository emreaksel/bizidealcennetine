import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:app_links/app_links.dart';
import 'Degiskenler.dart';
import 'HttpService.dart';
import 'JsonHelper.dart';
import 'ui_support.dart';
import 'audio_service.dart' as app_audio;
import 'MusicApiService.dart';

final appLinks = AppLinks();

void arkaplanIslemleri() async {
  Degiskenler.hazirlaniyor = true;
  await Degiskenler.loadTheme();

  try {
    print("Initializing AudioService...");
    await app_audio.AudioService.init();
  } catch (e) {
    print("Error initializing AudioService: $e");
  }

  fetchData_jsonMenba("${Degiskenler.kaynakYolu}kaynak/menba.json");
  fetchData_jsonFotograflar("${Degiskenler.kaynakYolu}medya/images.json");
  fetchData_jsonSozler("${Degiskenler.kaynakYolu}kaynak/sozler.json");

  Degiskenler.hazirlaniyor = false;
  MusicApiService().syncInitialStatus();
}

Future<void> setPlaylist(data, {bool playNow = true}) async {
  print("setPlaylist called with ${data.length} items");

  List<dynamic> reversedData = data.reversed.toList();

  final existingList = Degiskenler.songListNotifier.value;
  for (var existingItem in existingList) {
    bool found = false;
    for (var newItem in reversedData) {
      if (existingItem['sira_no'].toString() == newItem['sira_no'].toString()) {
        found = true;
        break;
      }
    }
    if (!found) {
      reversedData.insert(0, existingItem);
    }
  }

  final degiskenler = Degiskenler();
  degiskenler.listDinle = reversedData;
  Degiskenler.songListNotifier.value = reversedData;

  List<AudioSource> playlist = [];
  for (var item in reversedData) {
    playlist.add(
      AudioSource.uri(
        Uri.parse(item['url']),
        tag: MediaItem(
            id: '${item['sira_no']}',
            album: item['parca_adi'],
            title: item['parca_adi'],
            artist: item['seslendiren']),
      ),
    );
  }

  await app_audio.AudioService.setPlaylist(playlist, playNow: playNow);

  if (Degiskenler.bekleyenHediyeLink != null &&
      Degiskenler.bekleyenHediyeId != null) {
    hediye_irtibat(
        Degiskenler.bekleyenHediyeLink, Degiskenler.bekleyenHediyeId);
    Degiskenler.bekleyenHediyeLink = null;
    Degiskenler.bekleyenHediyeId = null;
  }

  print("Playlist set successfully");
}

Future<void> initUniLinks(Function(String) handleLinkCallback) async {
  try {
    final initialLink = await appLinks.getInitialLink();
    print("initialLink $initialLink");

    if (initialLink != null) {
      handleLinkCallback(initialLink.toString());
    }

    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print("uriLinkStream $uri");
        handleLinkCallback(uri.toString());
      }
    });
  } catch (e) {
    print("Error in initUniLinks: $e");
  }
}

void handleLink(String? link) {
  if (link != null) {
    link =
        link.toString().replaceAll(RegExp(r"\s+"), "").replaceAll("&amp;", "&");
    print("replacedLink $link");

    if (link.contains('https://benolanben.com/dinle/')) {
      var hediye = link.replaceAll('https://benolanben.com/dinle/', '');
      var parts = hediye.split('&');
      if (parts.length >= 2) {
        var linkPart = parts[0];
        var idPart = parts[1];
        if (linkPart.isNotEmpty && idPart.isNotEmpty) {
          if (Degiskenler.listeYuklendi) {
            hediye_irtibat(linkPart, idPart);
          } else {
            Degiskenler.bekleyenHediyeLink = linkPart;
            Degiskenler.bekleyenHediyeId = idPart;
          }
        }
      }
    } else {
      Degiskenler.currentNoticeNotifier.value = link;
      Degiskenler.showDialogNotifier.value = true;
    }
  }
}

Future<void> fetchData_jsonDinlemeListesi(String url, String link,
    {bool playNow = true}) async {
  try {
    final Map<String, dynamic> jsonData = await compute(getirJsonData, url);
    List<dynamic> listDinle = jsonData["sesler"];
    await setPlaylist(listDinle, playNow: playNow);
  } catch (error) {
    print("Hata oluştu: $error");
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
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);
    jsonData.then((jsonData) {
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
    });
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

void bildirimKontrol(bildirim) async {
  String vakit1Str = bildirim["vakit1"];
  String vakit2Str = bildirim["vakit2"];

  DateTime parseDateTime(String dateStr) {
    List<String> parts = dateStr.split(" ");
    List<String> dateParts = parts[0].split("/");
    List<String> timeParts = parts[1].split(":");

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    return DateTime(year, month, day, hour, minute);
  }

  DateTime vakit1 = parseDateTime(vakit1Str);
  DateTime vakit2 = parseDateTime(vakit2Str);

  DateTime now = DateTime.now().toUtc();
  DateTime suAn = now.add(Duration(hours: 3));

  if (suAn.isAfter(vakit1) && suAn.isBefore(vakit2)) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? yanit = prefs.getString('bildirim') ?? "bos";

    if (yanit != bildirim["metin"]) {
      if (!Degiskenler.currentNoticeNotifier.value
          .contains('https://benolanben.com/dinle/')) {
        Degiskenler.currentNoticeNotifier.value = bildirim["metin"];
        Degiskenler.showDialogNotifier.value = true;
      }
    }
  }
}

void hediye_irtibat(link, id) {
  bool found = false;
  for (var item in Degiskenler().listDinle) {
    if (item['sira_no'].toString() == id.toString()) {
      found = true;
      break;
    }
  }

  if (found) {
    app_audio.AudioService.playAtId(int.parse(id.toString()));
    Degiskenler.hediyeninIndex = int.parse(id.toString());
  } else {
    compute(getirJsonData, "${Degiskenler.kaynakYolu}kaynak/$link.json")
        .then((data) {
      List<dynamic> listDinle = data["sesler"];

      for (var item in listDinle) {
        if (item['sira_no'].toString() == id.toString()) {
          app_audio.AudioService.playApplinkTrack(item['parca_adi'],
              item['seslendiren'], item['url'], item['sira_no']);
          Degiskenler.hediyeninIndex = int.parse(item['sira_no'].toString());
          break;
        }
      }
    });
  }
}
