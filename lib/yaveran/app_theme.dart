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

  // Genel Sabitler
  static const Color _mainText = Colors.white;
  static Color _subText = Colors.white.withOpacity(0.7);

  // ═══════════════════════════════════════
  //  KLASİK & NÖTR
  // ═══════════════════════════════════════

  factory AppTheme.sukun() => AppTheme(
        name: "Sükun",
        backgroundColor: const Color(0xFF2B3C43),
        cardColor: const Color(0xFF223238),
        accentColor: const Color(0xFFE56A54),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.gece() => AppTheme(
        name: "Gece",
        backgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF16213E),
        accentColor: const Color(0xFFE94560),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.uzay() => AppTheme(
        name: "Uzay",
        backgroundColor: const Color(0xFF0D0D11),
        cardColor: const Color(0xFF14141A),
        accentColor: const Color(0xFFC5CAE9),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.zifiri() => AppTheme(
        name: "Zifiri",
        backgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF0A0A0A),
        accentColor: const Color(0xFFE0E0E0),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kul() => AppTheme(
        name: "Kül",
        backgroundColor: const Color(0xFF141415),
        cardColor: const Color(0xFF1E1E1E),
        accentColor: const Color(0xFFA1A1AA),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  KIRMIZI & PEMBE
  // ═══════════════════════════════════════

  factory AppTheme.yakut() => AppTheme(
        name: "Yakut",
        backgroundColor: const Color(0xFF1D0B0B),
        cardColor: const Color(0xFF291313),
        accentColor: const Color(0xFFEF4444),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.gul() => AppTheme(
        name: "Gül",
        backgroundColor: const Color(0xFF4A1C2C),
        cardColor: const Color(0xFF3B1623),
        accentColor: const Color(0xFFFF85A1),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kiraz() => AppTheme(
        name: "Kiraz",
        backgroundColor: const Color(0xFF210101),
        cardColor: const Color(0xFF1A0000),
        accentColor: const Color(0xFFFF5252),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.bordo() => AppTheme(
        name: "Bordo",
        backgroundColor: const Color(0xFF140808),
        cardColor: const Color(0xFF1E0C0C),
        accentColor: const Color(0xFFE63946),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.fusya() => AppTheme(
        name: "Fuşya",
        backgroundColor: const Color(0xFF1C0C14),
        cardColor: const Color(0xFF28141E),
        accentColor: const Color(0xFFEC4899),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kirmizi() => AppTheme(
        name: "Kırmızı",
        backgroundColor: const Color(0xFF2C0A0A),
        cardColor: const Color(0xFF1A0505),
        accentColor: const Color(0xFFFF3333),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  TURUNCU & KAHVERENGİ
  // ═══════════════════════════════════════

  factory AppTheme.vaha() => AppTheme(
        name: "Vaha",
        backgroundColor: const Color(0xFF3D2B1F),
        cardColor: const Color(0xFF2D1F16),
        accentColor: const Color(0xFFD4A373),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.toprak() => AppTheme(
        name: "Toprak",
        backgroundColor: const Color(0xFF4E342E),
        cardColor: const Color(0xFF3E2723),
        accentColor: const Color(0xFFFFAB91),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.safak() => AppTheme(
        name: "Şafak",
        backgroundColor: const Color(0xFF1E120A),
        cardColor: const Color(0xFF2A1C12),
        accentColor: const Color(0xFFF97316),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.mercan() => AppTheme(
        name: "Mercan",
        backgroundColor: const Color(0xFF1E0F0A),
        cardColor: const Color(0xFF2A1812),
        accentColor: const Color(0xFFFF7F50),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.kahve() => AppTheme(
        name: "Kahve",
        backgroundColor: const Color(0xFF171310),
        cardColor: const Color(0xFF221D1A),
        accentColor: const Color(0xFFCFA07C),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  SARI & ALTIN
  // ═══════════════════════════════════════

  factory AppTheme.kehribar() => AppTheme(
        name: "Kehribar",
        backgroundColor: const Color(0xFF1D160B),
        cardColor: const Color(0xFF292013),
        accentColor: const Color(0xFFDEB543),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.altin() => AppTheme(
        name: "Altın",
        backgroundColor: const Color(0xFF1D190B),
        cardColor: const Color(0xFF292513),
        accentColor: const Color(0xFFF1C40F),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  YEŞİL
  // ═══════════════════════════════════════

  factory AppTheme.zumrut() => AppTheme(
        name: "Zümrüt",
        backgroundColor: const Color(0xFF1B3022),
        cardColor: const Color(0xFF132017),
        accentColor: const Color(0xFF4E937A),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.cinar() => AppTheme(
        name: "Çınar",
        backgroundColor: const Color(0xFF0D1A13),
        cardColor: const Color(0xFF16261D),
        accentColor: const Color(0xFF2ECC71),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.hazan() => AppTheme(
        name: "Hazan",
        backgroundColor: const Color(0xFF161C0C),
        cardColor: const Color(0xFF202814),
        accentColor: const Color(0xFFB4C84E),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.adacayi() => AppTheme(
        name: "Adaçayı",
        backgroundColor: const Color(0xFF141612),
        cardColor: const Color(0xFF1E201C),
        accentColor: const Color(0xFFC5D8A4),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  MAVİ & TURKUAZ
  // ═══════════════════════════════════════

  factory AppTheme.derya() => AppTheme(
        name: "Derya",
        backgroundColor: const Color(0xFF0B121D),
        cardColor: const Color(0xFF131B29),
        accentColor: const Color(0xFF60A5FA),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.sema() => AppTheme(
        name: "Sema",
        backgroundColor: const Color(0xFF1E3A5F),
        cardColor: const Color(0xFF142841),
        accentColor: const Color(0xFF81D4FA),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.isik() => AppTheme(
        name: "Işık",
        backgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF0A1022),
        accentColor: const Color(0xFF67E8F9),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.ayaz() => AppTheme(
        name: "Ayaz",
        backgroundColor: const Color(0xFF004D40),
        cardColor: const Color(0xFF003D33),
        accentColor: const Color(0xFF80CBC4),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.turkuaz() => AppTheme(
        name: "Turkuaz",
        backgroundColor: const Color(0xFF0C1C19),
        cardColor: const Color(0xFF152724),
        accentColor: const Color(0xFF1ABC9C),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  MOR & LAVANTA
  // ═══════════════════════════════════════

  factory AppTheme.lale() => AppTheme(
        name: "Lale",
        backgroundColor: const Color(0xFF2D2438),
        cardColor: const Color(0xFF231B2D),
        accentColor: const Color(0xFFBB86FC),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.leylak() => AppTheme(
        name: "Leylak",
        backgroundColor: const Color(0xFF100B1D),
        cardColor: const Color(0xFF1A1329),
        accentColor: const Color(0xFFA78BFA),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.murdum() => AppTheme(
        name: "Mürdüm",
        backgroundColor: const Color(0xFF181013),
        cardColor: const Color(0xFF221A1D),
        accentColor: const Color(0xFFC39BD3),
        textColor: _mainText,
        subTextColor: _subText,
      );

  // ═══════════════════════════════════════
  //  MİSTİK
  // ═══════════════════════════════════════

  factory AppTheme.mehtap() => AppTheme(
        name: "Mehtap",
        backgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        accentColor: const Color(0xFFFDE047),
        textColor: _mainText,
        subTextColor: _subText,
      );

  factory AppTheme.ney() => AppTheme(
        name: "Ney",
        backgroundColor: const Color(0xFF292524),
        cardColor: const Color(0xFF44403C),
        accentColor: const Color(0xFFFDBA74),
        textColor: _mainText,
        subTextColor: _subText,
      );

  static List<AppTheme> themes = [
    AppTheme.sukun(),
    AppTheme.gece(),
    AppTheme.uzay(),
    AppTheme.zifiri(),
    AppTheme.kul(),
    AppTheme.mehtap(),
    AppTheme.ney(),
    AppTheme.yakut(),
    AppTheme.gul(),
    AppTheme.kiraz(),
    AppTheme.bordo(),
    AppTheme.fusya(),
    AppTheme.kirmizi(),
    AppTheme.vaha(),
    AppTheme.toprak(),
    AppTheme.safak(),
    AppTheme.mercan(),
    AppTheme.kahve(),
    AppTheme.kehribar(),
    AppTheme.altin(),
    AppTheme.zumrut(),
    AppTheme.cinar(),
    AppTheme.hazan(),
    AppTheme.adacayi(),
    AppTheme.derya(),
    AppTheme.sema(),
    AppTheme.isik(),
    AppTheme.ayaz(),
    AppTheme.turkuaz(),
    AppTheme.lale(),
    AppTheme.leylak(),
    AppTheme.murdum(),
  ];
}
