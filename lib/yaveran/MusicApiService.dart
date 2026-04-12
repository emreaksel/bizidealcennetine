import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'dart:io' show Platform; // Sadece mobile/desktop için
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';

class MusicApiService {
  final storage = const FlutterSecureStorage();
  String get baseUrl => Degiskenler.WEBSITE_URL;

  // ─────────────────────────────────────────────────────────────────────────────
  // YARDIMCI METOT: Token'ı Kasadan Alıp Header Oluşturur
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');

    if (token == null) {
      throw Exception('Oturum bulunamadı. Lütfen cihaz kodunuzla giriş yapın.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getOptionalHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _getDevicePlatform() {
    if (kIsWeb) {
      return 'web-debug';
    }
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
  // ─────────────────────────────────────────────────────────────────────────────
  // 1. CİHAZ EŞLEŞTİRME & OTURUM İŞLEMLERİ
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> exchangeCodeWithServer(String pairingCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/music/auth/exchange-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': pairingCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final token = data['token'];

        // Token'ı iOS Keychain / Android Keystore'a güvenle kaydet
        await storage.write(key: 'jwt_token', value: token);
        Degiskenler.isSyncedNotifier.value = true;
        return true;
      } else {
        print('Eşleştirme başarısız: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Ağ hatası: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
    Degiskenler.isSyncedNotifier.value = false;
  }

  Future<void> syncInitialStatus() async {
    final token = await storage.read(key: 'jwt_token');
    Degiskenler.isSyncedNotifier.value = token != null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. DOKUNANLAR (LIKE / UNLIKE) İŞLEMLERİ
  // ─────────────────────────────────────────────────────────────────────────────

  /// Müziğe dokun veya zaten dokunulduysa geri al (Toggle Like)
  Future<bool> toggleLike(int musicId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/music/like'),
        headers: headers,
        body: jsonEncode({'musicId': musicId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('Dokunma işlemi başarılı: $data');
        return true;
      } else {
        print('Dokunma işlemi başarısız: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Ağ hatası (toggleLike): $e');
      return false;
    }
  }

  /// Kullanıcının bu müziğe şu an dokunup dokunmadığını kontrol et
  Future<bool> checkLikeStatus(int musicId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/music/like/status/$musicId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // Backend "isLiked" veya "liked" gibi bir boolean dönüyorsa ona göre ayarlayın
        return data['liked'] ?? false;
      }
      return false;
    } catch (e) {
      print('Ağ hatası (checkLikeStatus): $e');
      return false;
    }
  }

  /// Müziğin global dokunma (beğeni) sayısını getir
  Future<int> getGlobalLikeCount(int musicId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/music/likes/count/$musicId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Ağ hatası (getGlobalLikeCount): $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. LİSTELEME İŞLEMLERİ
  // ─────────────────────────────────────────────────────────────────────────────

  /// Sadece kullanıcının kendi dokunduğu (beğendiği) müzikleri getir
  Future<List<dynamic>> fetchMyLikes({int limit = 10}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/music/likes/me?limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['likes'] ?? []; // Sunucunun döndüğü müzik dizisi
      }
      return [];
    } catch (e) {
      print('Ağ hatası (fetchMyLikes): $e');
      return [];
    }
  }

  /// Global popüler listesini (en çok dokunulanları) getir
  Future<List<dynamic>> fetchGlobalTop({int limit = 10}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/music/likes/all?limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['musics'] ?? [];
      }
      return [];
    } catch (e) {
      print('Ağ hatası (fetchGlobalTop): $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. MÜZİK DİNLEME LOGU GÖNDERME
  // ─────────────────────────────────────────────────────────────────────────────
  Future<bool> sendListenLog({
    required int musicId,
    required int listenDuration,
    String? timestamp,
  }) async {
    try {
      final headers = await _getOptionalHeaders();
      final device = _getDevicePlatform(); // ✅ artık web'de de çalışır

      final payload = {
        'musicId': musicId.toString(),
        'listenDuration': listenDuration,
        'device': device,
      };

      if (timestamp != null) {
        payload['timestamp'] = timestamp;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/music/listen'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Dinleme logu başarılı ($musicId - ${listenDuration}s)');
        return true;
      } else {
        print(
            'Dinleme logu başarısız: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Ağ hatası (sendListenLog): $e');
      return false;
    }
  }
}
