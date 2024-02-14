import 'dart:convert';

class JsonHelper {
  static Map<String, dynamic> parseJson(String jsonStr) {
    return jsonDecode(jsonStr);
  }
}
