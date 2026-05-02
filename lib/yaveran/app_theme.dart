import 'package:flutter/material.dart';

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

  static const Color _mainText = Colors.white;
  static Color _subText = Colors.white.withOpacity(0.7);
  static const Color _darkText = Color(0xFF2C3E50);
  static Color _darkSubText = Color(0xFF2C3E50).withOpacity(0.6);

  // ═══════════════════════════════════════
  //  'S' ve 'Ş' HARFİYLE BAŞLAYANLAR
  // ═══════════════════════════════════════

  factory AppTheme.sukun() => AppTheme(
        name: "Sükun",
        backgroundColor: const Color(0xFF1E242B),
        cardColor: const Color(0xFF2B343E),
        accentColor: const Color(0xFF8DA9C4),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.suveyda() => AppTheme(
        name: "Süveyda",
        backgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF111111),
        accentColor: const Color(0xFF9E9E9E),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.mest() => AppTheme(
        name: "Mest",
        backgroundColor: const Color(0xFF130E24),
        cardColor: const Color(0xFF21183D),
        accentColor: const Color(0xFF6F52D9),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.isk() => AppTheme(
        name: "Işk",
        backgroundColor: const Color(0xFF222414),
        cardColor: const Color(0xFF373A22),
        accentColor: const Color(0xFFFFF700),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.senlik() => AppTheme(
        name: "Şenlik",
        backgroundColor: const Color(0xFF1A0F00),
        cardColor: const Color(0xFF2E1C00),
        accentColor: const Color(0xFFFF8C00),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  DİĞER TEMALAR (ALFABETİK SIRALI)
  // ═══════════════════════════════════════

  factory AppTheme.dilruba() => AppTheme(
        name: "Dilruba",
        backgroundColor: const Color(0xFF2E0F1C),
        cardColor: const Color(0xFF4A1A2D),
        accentColor: const Color(0xFFFF69B4),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sifa() => AppTheme(
        name: "Şifa",
        backgroundColor: const Color(0xFF162118),
        cardColor: const Color(0xFF253828),
        accentColor: const Color(0xFF4C9A2A),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.taze() => AppTheme(
        name: "Taze",
        backgroundColor: const Color(0xFF1E2620),
        cardColor: const Color(0xFF2F3D33),
        accentColor: const Color(0xFF729B63),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sevda() => AppTheme(
        name: "Sevda",
        backgroundColor: const Color(0xFF1F0D23),
        cardColor: const Color(0xFF36183D),
        accentColor: const Color(0xFFC842FF),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sir() => AppTheme(
        name: "Sır",
        backgroundColor: const Color(0xFF200B26),
        cardColor: const Color(0xFF33123D),
        accentColor: const Color(0xFFD13693),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.feza() => AppTheme(
        name: "Feza",
        backgroundColor: const Color(0xFF100822),
        cardColor: const Color(0xFF1B1133),
        accentColor: const Color(0xFFFFD700),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.ahenk() => AppTheme(
        name: "Ahenk",
        backgroundColor: const Color(0xFF052426),
        cardColor: const Color(0xFF0A3B3E),
        accentColor: const Color(0xFF40E0D0),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.hayal() => AppTheme(
        name: "Hayal",
        backgroundColor: const Color(0xFF2D1B22),
        cardColor: const Color(0xFF432933),
        accentColor: const Color(0xFFFEA3AA),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kabul() => AppTheme(
        name: "Kabul",
        backgroundColor: const Color(0xFF23394D),
        cardColor: const Color(0xFF324D66),
        accentColor: const Color(0xFF89CFF0),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.saril() => AppTheme(
        name: "Sarıl",
        backgroundColor: const Color(0xFF141200),
        cardColor: const Color(0xFF262200),
        accentColor: const Color(0xFFFDEE54),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.soz() => AppTheme(
        name: "Söz",
        backgroundColor: const Color(0xFF1B4D54),
        cardColor: const Color(0xFF24666F),
        accentColor: const Color(0xFFD4AF37),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.bade() => AppTheme(
        name: "Bade",
        backgroundColor: const Color(0xFF1A1515),
        cardColor: const Color(0xFF2E2626),
        accentColor: const Color(0xFFE63946),
        textColor: _mainText,
        subTextColor: _subText,
      );


  // Eski adıyla Ateş
  factory AppTheme.tendecan() => AppTheme(
        name: "Tendecan",
        backgroundColor: const Color(0xFF331400),
        cardColor: const Color(0xFF4D2200),
        accentColor: const Color(0xFFFF4500),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.atespare() => AppTheme(
        name: "Ateşpâre",
        backgroundColor: const Color(0xFF1A0206),
        cardColor: const Color(0xFF2B040B),
        accentColor: const Color(0xFFE0115F),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.leyl() => AppTheme(
        name: "Leyl",
        backgroundColor: const Color(0xFF090A0F),
        cardColor: const Color(0xFF161925),
        accentColor: const Color(0xFF00FFCC),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.mehtap() => AppTheme(
        name: "Mehtap",
        backgroundColor: const Color(0xFF111827),
        cardColor: const Color(0xFF1F2937),
        accentColor: const Color(0xFFFACC15),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.mey() => AppTheme(
        name: "Mey",
        backgroundColor: const Color(0xFF24060A),
        cardColor: const Color(0xFF3D0C14),
        accentColor: const Color(0xFFE3242B),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.duru() => AppTheme(
        name: "Duru",
        backgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF282846),
        accentColor: const Color(0xFFFF7E67),
        textColor: _mainText,
        subTextColor: _subText,
      );



  factory AppTheme.ferah() => AppTheme(
        name: "Ferah",
        backgroundColor: const Color(0xFF001F24),
        cardColor: const Color(0xFF003840),
        accentColor: const Color(0xFFB0E0E6),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.anka() => AppTheme(
        name: "Anka",
        backgroundColor: const Color(0xFF022115),
        cardColor: const Color(0xFF043824),
        accentColor: const Color(0xFF50C878),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  TÜM TEMALAR LİSTESİ (Sıralı)
  // ═══════════════════════════════════════
  static List<AppTheme> themes = [
    AppTheme.ahenk(), // Ahenk
    AppTheme.anka(), // Anka
    AppTheme.atespare(), // Ateşpâre
    AppTheme.bade(), // Bade
    AppTheme.dilruba(), // Dilruba
    AppTheme.duru(), // Duru
    AppTheme.ferah(), // Ferah
    AppTheme.feza(), // Feza
    AppTheme.hayal(), // Hayal
    AppTheme.isk(), // Işk
    AppTheme.kabul(), // Kabul
    AppTheme.leyl(), // Leyl
    AppTheme.mehtap(), // Mehtap
    AppTheme.mest(), // Mest
    AppTheme.mey(), // Mey
    AppTheme.saril(), // Sarıl
    AppTheme.sevda(), // Sevda
    AppTheme.sir(), // Sır
    AppTheme.soz(), // Söz
    AppTheme.sukun(), // Sükun
    AppTheme.suveyda(), // Süveyda
    AppTheme.senlik(), // Şenlik
    AppTheme.sifa(), // Şifa
    AppTheme.taze(), // Taze
    AppTheme.tendecan(), // Tendecan
  ];
}
