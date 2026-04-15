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

  factory AppTheme.sukut() => AppTheme(
        name: "Sükut",
        backgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF111111),
        accentColor: const Color(0xFFFFFFFF),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sema() => AppTheme(
        name: "Sema",
        backgroundColor: const Color(0xFF102A43),
        cardColor: const Color(0xFF243B53),
        accentColor: const Color(0xFF9FB3C8),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.serap() => AppTheme(
        name: "Serap",
        backgroundColor: const Color(0xFF2C1E16),
        cardColor: const Color(0xFF402E24),
        accentColor: const Color(0xFFF4A460),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sumbul() => AppTheme(
        name: "Sümbül",
        backgroundColor: const Color(0xFF130E24),
        cardColor: const Color(0xFF21183D),
        accentColor: const Color(0xFF6F52D9),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sems() => AppTheme(
        name: "Şems",
        backgroundColor: const Color(0xFF222414),
        cardColor: const Color(0xFF373A22),
        accentColor: const Color(0xFFFFF700),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  DİĞER TEMALAR (ALFABETİK SIRALI)
  // ═══════════════════════════════════════

  factory AppTheme.ahter() => AppTheme(
        name: "Ahter",
        backgroundColor: const Color(0xFF2E0F1C),
        cardColor: const Color(0xFF4A1A2D),
        accentColor: const Color(0xFFFF69B4),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.cinar() => AppTheme(
        name: "Çınar",
        backgroundColor: const Color(0xFF162118),
        cardColor: const Color(0xFF253828),
        accentColor: const Color(0xFF4C9A2A),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.defne() => AppTheme(
        name: "Defne",
        backgroundColor: const Color(0xFF1E2620),
        cardColor: const Color(0xFF2F3D33),
        accentColor: const Color(0xFF729B63),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.efsun() => AppTheme(
        name: "Efsun",
        backgroundColor: const Color(0xFF1F0D23),
        cardColor: const Color(0xFF36183D),
        accentColor: const Color(0xFFC842FF),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.erguvan() => AppTheme(
        name: "Erguvan",
        backgroundColor: const Color(0xFF200B26),
        cardColor: const Color(0xFF33123D),
        accentColor: const Color(0xFFD13693),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.fecir() => AppTheme(
        name: "Fecir",
        backgroundColor: const Color(0xFF1B1423),
        cardColor: const Color(0xFF2D2338),
        accentColor: const Color(0xFFFF8C00),
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

  factory AppTheme.firuze() => AppTheme(
        name: "Firuze",
        backgroundColor: const Color(0xFF052426),
        cardColor: const Color(0xFF0A3B3E),
        accentColor: const Color(0xFF40E0D0),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.hazan() => AppTheme(
        name: "Hazan",
        backgroundColor: const Color(0xFF2A2A15),
        cardColor: const Color(0xFF424222),
        accentColor: const Color(0xFFDAA520),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.hicran() => AppTheme(
        name: "Hicran",
        backgroundColor: const Color(0xFF1A1515),
        cardColor: const Color(0xFF2E2626),
        accentColor: const Color(0xFFE63946),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // Eski adıyla Nur
  factory AppTheme.katre() => AppTheme(
        name: "Katre",
        backgroundColor: const Color(0xFF0E1A24),
        cardColor: const Color(0xFF1A2E40),
        accentColor: const Color(0xFF62B8F6),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kehribar() => AppTheme(
        name: "Kehribar",
        backgroundColor: const Color(0xFF2E1C04),
        cardColor: const Color(0xFF452A06),
        accentColor: const Color(0xFFFFBF00),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // Eski adıyla Ateş
  factory AppTheme.koz() => AppTheme(
        name: "Köz",
        backgroundColor: const Color(0xFF331400),
        cardColor: const Color(0xFF4D2200),
        accentColor: const Color(0xFFFF4500),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kul() => AppTheme(
        name: "Kül",
        backgroundColor: const Color(0xFF2C2C2C),
        cardColor: const Color(0xFF3D3D3D),
        accentColor: const Color(0xFFB2BEB5),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.lal() => AppTheme(
        name: "Lâl",
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

  factory AppTheme.nar() => AppTheme(
        name: "Nar",
        backgroundColor: const Color(0xFF24060A),
        cardColor: const Color(0xFF3D0C14),
        accentColor: const Color(0xFFE3242B),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.ney() => AppTheme(
        name: "Ney",
        backgroundColor: const Color(0xFF252221),
        cardColor: const Color(0xFF3D3836),
        accentColor: const Color(0xFFE5AA70),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.telve() => AppTheme(
        name: "Telve",
        backgroundColor: const Color(0xFF1A0F0A),
        cardColor: const Color(0xFF2D1A11),
        accentColor: const Color(0xFFC48B62),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.turab() => AppTheme(
        name: "Turab",
        backgroundColor: const Color(0xFF2C221B),
        cardColor: const Color(0xFF3E3127),
        accentColor: const Color(0xFF8B5A2B),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.ufuk() => AppTheme(
        name: "Ufuk",
        backgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF282846),
        accentColor: const Color(0xFFFF7E67),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.umman() => AppTheme(
        name: "Umman",
        backgroundColor: const Color(0xFF001A33),
        cardColor: const Color(0xFF002F5C),
        accentColor: const Color(0xFF00BFFF),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.vuslat() => AppTheme(
        name: "Vuslat",
        backgroundColor: const Color(0xFF2E1528),
        cardColor: const Color(0xFF47213E),
        accentColor: const Color(0xFFFFB6C1),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.zemheri() => AppTheme(
        name: "Zemheri",
        backgroundColor: const Color(0xFF001F24),
        cardColor: const Color(0xFF003840),
        accentColor: const Color(0xFFB0E0E6),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.zumrut() => AppTheme(
        name: "Zümrüt",
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
    // S ve Ş
    AppTheme.sukun(),
    AppTheme.sukut(),
    AppTheme.sema(),
    AppTheme.serap(),
    AppTheme.sumbul(),
    AppTheme.sems(),

    // Alfabetik devamı
    AppTheme.ahter(),
    AppTheme.cinar(),
    AppTheme.defne(),
    AppTheme.efsun(),
    AppTheme.erguvan(),
    AppTheme.fecir(),
    AppTheme.feza(),
    AppTheme.firuze(),
    AppTheme.hazan(),
    AppTheme.hicran(),
    AppTheme.katre(),
    AppTheme.kehribar(),
    AppTheme.koz(),
    AppTheme.kul(),
    AppTheme.lal(),
    AppTheme.leyl(),
    AppTheme.mehtap(),
    AppTheme.nar(),
    AppTheme.ney(),
    AppTheme.telve(),
    AppTheme.turab(),
    AppTheme.ufuk(),
    AppTheme.umman(),
    AppTheme.vuslat(),
    AppTheme.zemheri(),
    AppTheme.zumrut(),
  ];
}
