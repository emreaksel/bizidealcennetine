import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static var altEkranBoyutNotifier = ValueNotifier<int>(20);
  static var ustEkranBoyutNotifier = ValueNotifier<int>(80);
  static var ustEkranIndexNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<AppTheme> currentThemeNotifier = ValueNotifier(AppTheme.darkTeal());

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

class AppTheme {
  final String name;
  final Color backgroundColor;
  final Color cardColor;
  final Color accentColor;
  final Color textColor;
  final Color subTextColor;

  AppTheme({
    required this.name,
    required this.backgroundColor,
    required this.cardColor,
    required this.accentColor,
    required this.textColor,
    required this.subTextColor,
  });

  factory AppTheme.darkTeal() {
    return AppTheme(
      name: "Sükun",
      backgroundColor: Color(0xFF2B3C43),
      cardColor: Color(0xFF223238),
      accentColor: Color(0xFFE56A54),
      textColor: Colors.white,
      subTextColor: Colors.white.withOpacity(0.7),
    );
  }

  factory AppTheme.midnight() {
    return AppTheme(
      name: "Gece",
      backgroundColor: Color(0xFF1A1A2E),
      cardColor: Color(0xFF16213E),
      accentColor: Color(0xFFE94560),
      textColor: Colors.white,
      subTextColor: Colors.white.withOpacity(0.6),
    );
  }

  factory AppTheme.desert() {
    return AppTheme(
      name: "Vaha",
      backgroundColor: Color(0xFF3D2B1F),
      cardColor: Color(0xFF2D1F16),
      accentColor: Color(0xFFD4A373),
      textColor: Color(0xFFFAEDCD),
      subTextColor: Color(0xFFFAEDCD).withOpacity(0.6),
    );
  }

  factory AppTheme.rose() {
    return AppTheme(
      name: "Gül",
      backgroundColor: Color(0xFF4A1C2C),
      cardColor: Color(0xFF3B1623),
      accentColor: Color(0xFFFF85A1),
      textColor: Color(0xFFFDE2E4),
      subTextColor: Color(0xFFFDE2E4).withOpacity(0.6),
    );
  }

  factory AppTheme.emerald() {
    return AppTheme(
      name: "Zümrüt",
      backgroundColor: Color(0xFF1B3022),
      cardColor: Color(0xFF132017),
      accentColor: Color(0xFF4E937A),
      textColor: Color(0xFFE9F5EB),
      subTextColor: Color(0xFFE9F5EB).withOpacity(0.6),
    );
  }

  factory AppTheme.amber() {
    return AppTheme(
      name: "Kehribar",
      backgroundColor: Color(0xFF3E2723),
      cardColor: Color(0xFF2E1C1A),
      accentColor: Color(0xFFFFB300),
      textColor: Color(0xFFFFF8E1),
      subTextColor: Color(0xFFFFF8E1).withOpacity(0.6),
    );
  }

  factory AppTheme.lavender() {
    return AppTheme(
      name: "Lale",
      backgroundColor: Color(0xFF2D2438),
      cardColor: Color(0xFF231B2D),
      accentColor: Color(0xFFBB86FC),
      textColor: Color(0xFFF3E5F5),
      subTextColor: Color(0xFFF3E5F5).withOpacity(0.6),
    );
  }

  factory AppTheme.sky() {
    return AppTheme(
      name: "Sema",
      backgroundColor: Color(0xFF1E3A5F),
      cardColor: Color(0xFF142841),
      accentColor: Color(0xFF81D4FA),
      textColor: Color(0xFFE1F5FE),
      subTextColor: Color(0xFFE1F5FE).withOpacity(0.6),
    );
  }

  factory AppTheme.amethyst() {
    return AppTheme(
      name: "Mor",
      backgroundColor: Color(0xFF311B92),
      cardColor: Color(0xFF2A167D),
      accentColor: Color(0xFFB39DDB),
      textColor: Color(0xFFEDE7F6),
      subTextColor: Color(0xFFEDE7F6).withOpacity(0.6),
    );
  }

  factory AppTheme.terracotta() {
    return AppTheme(
      name: "Toprak",
      backgroundColor: Color(0xFF4E342E),
      cardColor: Color(0xFF3E2723),
      accentColor: Color(0xFFFFAB91),
      textColor: Color(0xFFEFEBE9),
      subTextColor: Color(0xFFEFEBE9).withOpacity(0.6),
    );
  }

  factory AppTheme.glacier() {
    return AppTheme(
      name: "Buzul",
      backgroundColor: Color(0xFF004D40),
      cardColor: Color(0xFF003D33),
      accentColor: Color(0xFF80CBC4),
      textColor: Color(0xFFE0F2F1),
      subTextColor: Color(0xFFE0F2F1).withOpacity(0.6),
    );
  }

  factory AppTheme.deepForest() {
    return AppTheme(
      name: "Orman",
      backgroundColor: Color(0xFF001F1F),
      cardColor: Color(0xFF001414),
      accentColor: Color(0xFF4CAF50),
      textColor: Color(0xFFE8F5E9),
      subTextColor: Color(0xFFE8F5E9).withOpacity(0.6),
    );
  }

  factory AppTheme.cherry() {
    return AppTheme(
      name: "Kiraz",
      backgroundColor: Color(0xFF210101),
      cardColor: Color(0xFF130000),
      accentColor: Color(0xFFFF5252),
      textColor: Color(0xFFFFEBEE),
      subTextColor: Color(0xFFFFEBEE).withOpacity(0.6),
    );
  }

  factory AppTheme.space() {
    return AppTheme(
      name: "Uzay",
      backgroundColor: Color(0xFF0D0D11),
      cardColor: Color(0xFF050508),
      accentColor: Color(0xFFC5CAE9),
      textColor: Color(0xFFE8EAF6),
      subTextColor: Color(0xFFE8EAF6).withOpacity(0.6),
    );
  }

  factory AppTheme.neon() {
    return AppTheme(
      name: "Aura",
      backgroundColor: Color(0xFF0F172A),
      cardColor: Color(0xFF020617),
      accentColor: Color(0xFF22D3EE),
      textColor: Color(0xFFF1F5F9),
      subTextColor: Color(0xFFF1F5F9).withOpacity(0.6),
    );
  }

  factory AppTheme.pitchBlack() {
    return AppTheme(
      name: "Zifiri",
      backgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF0A0A0A),
      accentColor: const Color(0xFFE0E0E0),
      textColor: Colors.white,
      subTextColor: Colors.white.withOpacity(0.6),
    );
  }

  factory AppTheme.milk() {
    return AppTheme(
      name: "Süt",
      backgroundColor: const Color(0xFFF2F2EC),
      cardColor: const Color(0xFFFAF9F5),
      accentColor: const Color(0xFF6B6B70),
      textColor: const Color(0xFF2C2C2E),
      subTextColor: const Color(0xFF2C2C2E).withOpacity(0.6),
    );
  }

  factory AppTheme.beach() {
    return AppTheme(
      name: "Kumsal",
      backgroundColor: const Color(0xFFF1E4D1),
      cardColor: const Color(0xFFF7EEE0),
      accentColor: const Color(0xFFC49363),
      textColor: const Color(0xFF4D3B2F),
      subTextColor: const Color(0xFF4D3B2F).withOpacity(0.6),
    );
  }

  factory AppTheme.cloud() {
    return AppTheme(
      name: "Bulut",
      backgroundColor: const Color(0xFFE5ECF2),
      cardColor: const Color(0xFFF0F5FA),
      accentColor: const Color(0xFF5A9BD5),
      textColor: const Color(0xFF2C3E50),
      subTextColor: const Color(0xFF2C3E50).withOpacity(0.6),
    );
  }

  factory AppTheme.spring() {
    return AppTheme(
      name: "Bahar",
      backgroundColor: const Color(0xFFE9F1DF),
      cardColor: const Color(0xFFF3F7EE),
      accentColor: const Color(0xFF7CB342),
      textColor: const Color(0xFF33691E),
      subTextColor: const Color(0xFF33691E).withOpacity(0.6),
    );
  }

  static List<AppTheme> themes = [
    AppTheme.darkTeal(),
    AppTheme.midnight(),
    AppTheme.desert(),
    AppTheme.rose(),
    AppTheme.emerald(),
    AppTheme.amber(),
    AppTheme.lavender(),
    AppTheme.sky(),
    AppTheme.amethyst(),
    AppTheme.terracotta(),
    AppTheme.glacier(),
    AppTheme.deepForest(),
    AppTheme.cherry(),
    AppTheme.space(),
    AppTheme.neon(),
    AppTheme.pitchBlack(),
    AppTheme.milk(),
    AppTheme.beach(),
    AppTheme.cloud(),
    AppTheme.spring(),
  ];
}
