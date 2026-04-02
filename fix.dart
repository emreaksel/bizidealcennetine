import "dart:io";
import "dart:convert";

void main() {
  var file = File("lib/yaveran/app_theme.dart");
  var content = file.readAsStringSync();
  
  // Fix the duplicated textColor/subTextColor lines
  content = content.replaceAll(RegExp(r"textColor:.*?,"), "textColor: Colors.white,");
  content = content.replaceAll(RegExp(r"subTextColor:.*?,"), "subTextColor: Colors.white.withOpacity(0.7),");
  
  // Fix garbled text
  content = content.replaceAll("SÃ¼kun", "Sükun");
  content = content.replaceAll("KÃ¼l", "Kül");
  content = content.replaceAll("GÃ¼l", "Gül");
  content = content.replaceAll("Fuşya", "Fuşya");
  content = content.replaceAll("Fuşya".replaceAll("ş", "Å\u0178"), "Fuşya");
  content = content.replaceAll("Å\u017E", "Ş"); // Åž = Ş
  content = content.replaceAll("Ã‡", "Ç");
  content = content.replaceAll("Ã§", "ç");
  content = content.replaceAll("Ã¶", "ö");
  content = content.replaceAll("Ã¼", "ü");
  content = content.replaceAll("ÄŸ", "ğ");
  content = content.replaceAll("Ä°", "İ");
  content = content.replaceAll("Ä±", "ı");
  content = content.replaceAll("ÅŸ", "ş");
  content = content.replaceAll("Åž", "Ş");
  content = content.replaceAll("Ã–", "Ö");
  content = content.replaceAll("Ãœ", "Ü");
  content = content.replaceAll("IÅŸÄ±k", "Işık");
  content = content.replaceAll("KÄ±rmÄ±zÄ±", "Kırmızı");
  content = content.replaceAll("â•", "\u2550");
  content = content.replaceAll("\u2550 ", "\u2550");

  file.writeAsStringSync(content);
}

