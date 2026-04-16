import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'dart:io' show Platform; // Sadece mobile/desktop için
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
      return 'web';
    }
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Cihaz için kalıcı ve benzersiz bir UID oluşturur/getirir ve detaylı bilgileri döner
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String? uid = await storage.read(key: 'device_uid');
    if (uid == null) {
      uid = const Uuid().v4();
      await storage.write(key: 'device_uid', value: uid);
    }

    Map<String, dynamic> detail = {
      'uid': uid,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'platform': _getDevicePlatform(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        detail['browser'] = webInfo.browserName.name;
        detail['language'] = webInfo.language;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        detail['model'] = androidInfo.model;
        detail['brand'] = androidInfo.brand;
        detail['osVersion'] = androidInfo.version.release;
        detail['sdkVersion'] = androidInfo.version.sdkInt;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        detail['model'] = iosInfo.utsname.machine;
        detail['osVersion'] = iosInfo.systemVersion;
        detail['name'] = iosInfo.name;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        detail['computerName'] = winInfo.computerName;
        detail['osVersion'] = winInfo.releaseId;
      }
    } catch (e) {
      print('Cihaz bilgileri alınırken hata: $e');
    }

    return detail;
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
      final deviceInfo = await _getDeviceInfo();

      // Platform, UID ve Device (model + os) alanlarını ayırıyoruz
      final String uid = deviceInfo['uid'] ?? 'unknown';
      final String platform = deviceInfo['platform'] ?? 'unknown';
      
      String model = deviceInfo['model'] ?? deviceInfo['browser'] ?? 'Unknown Device';
      String os = deviceInfo['osVersion'] ?? 'Unknown OS';
      String deviceString = "$model - $os";

      final payload = {
        'musicId': musicId.toString(),
        'listenDuration': listenDuration,
        'uid': uid,
        'platform': platform,
        'device': deviceString,
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
