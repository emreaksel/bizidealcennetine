import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../MusicApiService.dart';

class ListenLogManager {
  final List<Map<String, dynamic>> _pendingLogs = [];
  bool _sendingLogs = false;
  int _activeLogTrackId = -1;
  int _accumulatedSeconds = 0;
  DateTime? _playStartedAt;
  String? _logTimestamp;
  Timer? _persistenceTimer;

  ListenLogManager() {
    // 30 saniyede bir o anki dinlemeyi diske yazar
    _persistenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _snapAccumulatedTime();
    });
  }

  void dispose() {
    _persistenceTimer?.cancel();
  }

  Future<void> loadPersistedLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('listen_logs');
    if (raw == null) return;

    try {
      final List<dynamic> list = jsonDecode(raw);
      for (final el in list) {
        final log = Map<String, dynamic>.from(el as Map);
        // Önceki açılıştaki 'current' logu tamamlanmış say (>=30s ise)
        if (log['status'] == 'current') {
          if ((log['listenDuration'] as int? ?? 0) >= 30) {
            _pendingLogs.add({...log, 'status': 'completed'});
          }
        } else {
          _pendingLogs.add(log);
        }
      }
    } catch (_) {}

    await _writeLogs();
    _flushPendingLogs();
  }

  void startNewLog(String idStr) {
    finalizeCurrentLog();
    _activeLogTrackId = int.tryParse(idStr) ?? -1;
    _logTimestamp = _nowUtc();
    _playStartedAt = DateTime.now();
  }

  void onPlay() {
    _playStartedAt ??= DateTime.now();
  }

  void onPause() {
    _snapAccumulatedTime();
    _playStartedAt = null;
  }

  void _snapAccumulatedTime() {
    if (_playStartedAt == null) return;
    _accumulatedSeconds += DateTime.now().difference(_playStartedAt!).inSeconds;
    _playStartedAt = DateTime.now();
    _writeLogs();
  }

  void finalizeCurrentLog() {
    _snapAccumulatedTime();
    _playStartedAt = null;

    if (_activeLogTrackId != -1 && _accumulatedSeconds >= 30) {
      _pendingLogs.add({
        'musicId': _activeLogTrackId,
        'listenDuration': _accumulatedSeconds,
        'timestamp': _logTimestamp ?? _nowUtc(),
        'status': 'completed',
      });
      _flushPendingLogs();
    }

    _accumulatedSeconds = 0;
    _activeLogTrackId = -1;
    _logTimestamp = null;
    _writeLogs();
  }

  Future<void> _writeLogs() async {
    final prefs = await SharedPreferences.getInstance();

    final snapshot = [
      ..._pendingLogs,
      if (_activeLogTrackId != -1 && _accumulatedSeconds > 0)
        {
          'musicId': _activeLogTrackId,
          'listenDuration': _accumulatedSeconds,
          'timestamp': _logTimestamp ?? _nowUtc(),
          'status': 'current',
        },
    ];

    if (snapshot.isEmpty) {
      await prefs.remove('listen_logs');
    } else {
      await prefs.setString('listen_logs', jsonEncode(snapshot));
    }
  }

  Future<void> _flushPendingLogs() async {
    if (_sendingLogs || _pendingLogs.isEmpty) return;
    _sendingLogs = true;

    try {
      final snapshot = List<Map<String, dynamic>>.from(_pendingLogs);
      final sent = <Map<String, dynamic>>[];

      for (final log in snapshot) {
        final ok = await MusicApiService().sendListenLog(
          musicId: log['musicId'],
          listenDuration: log['listenDuration'],
          timestamp: log['timestamp'],
        );
        if (ok) sent.add(log);
      }

      if (sent.isNotEmpty) {
        _pendingLogs.removeWhere((l) => sent.any((s) =>
            s['timestamp'] == l['timestamp'] && s['musicId'] == l['musicId']));
        await _writeLogs();
      }
    } finally {
      _sendingLogs = false;
    }
  }

  String _nowUtc() =>
      '${DateTime.now().toUtc().toIso8601String().split('.')[0]}Z';
}
