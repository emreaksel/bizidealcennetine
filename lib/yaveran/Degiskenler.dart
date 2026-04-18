import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ConfettiTriggerData {
  final Offset position;
  final int? particleCount;
  ConfettiTriggerData(this.position, {this.particleCount});
}

class Degiskenler {
  static final Degiskenler _instance = Degiskenler._internal();
  int versionMenba = 0;

  static var hazirlaniyor = false;
  static var kaynakYolu =
      "https://raw.githubusercontent.com/benolanben/atesiask/main/";
  static var WEBSITE_URL = "https://benolanben.com";
  static var parcaIndex = -1;
  static var hediyeninIndex = -1;
  static var liste_link = "baska";
  static var liste_adi = "baska";

  static var listeYuklendi = false;
  static String? bekleyenHediyeLink;
  static String? bekleyenHediyeId;

  static var currentEpigramNotifier = ValueNotifier<String>('...');
  static var currentImageNotifier = ValueNotifier<String>('');
  static var songListNotifier = ValueNotifier<List<dynamic>>([]);
  static var myLikesNotifier = ValueNotifier<List<dynamic>>([]);
  static var dinlemeListeleriNotifier = ValueNotifier<List<dynamic>>([
    {
      "id": 1,
      "caption": "Liste 1",
      "link": "link1",
      "explanation": "Açıklama 1"
    }
  ]);
  static var currentNoticeNotifier =
      ValueNotifier<String>('Hoşgeldin Güzeller Güzelim...');
  static var showDialogNotifier = ValueNotifier<bool>(false);
  static var isSyncedNotifier = ValueNotifier<bool>(false);
  static var confettiTriggerNotifier = ValueNotifier<ConfettiTriggerData?>(null);
  static var birdTriggerNotifier = ValueNotifier<bool>(false);

  static var altEkranBoyutNotifier = ValueNotifier<int>(25);
  static var ustEkranBoyutNotifier = ValueNotifier<int>(75);
  static var ustEkranIndexNotifier = ValueNotifier<int>(0);
  static var sleepTimerRemainingNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<AppTheme> currentThemeNotifier =
      ValueNotifier(AppTheme.sukun());

  static Future<void> saveTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_name', theme.name);
  }

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme_name');
    if (themeName != null) {
      try {
        final theme = AppTheme.themes.firstWhere((t) => t.name == themeName);
        currentThemeNotifier.value = theme;
      } catch (e) {
        // Tema bulunamazsa varsayılan kalır
      }
    }
  }

  List<dynamic> listSozler = [];
  List<dynamic> listDinle = [];
  List<dynamic> listFotograflar = [];

  factory Degiskenler() {
    return _instance;
  }

  Degiskenler._internal();
}
