import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { info, warning, error, debug }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
  });

  @override
  String toString() {
    final timeStr = DateFormat('HH:mm:ss.SSS').format(timestamp);
    final levelStr = level.toString().split('.').last.toUpperCase();
    final tagStr = tag != null ? '[$tag] ' : '';
    return '$timeStr [$levelStr] $tagStr$message';
  }
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier<List<LogEntry>>([]);
  final int maxLogs = 1000;

  void log(String message, {LogLevel level = LogLevel.info, String? tag}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
    );
    
    // Add to list and notify
    final currentLogs = List<LogEntry>.from(logsNotifier.value);
    currentLogs.add(entry);
    
    if (currentLogs.length > maxLogs) {
      currentLogs.removeAt(0);
    }
    
    logsNotifier.value = currentLogs;
    
    // Also print to console for development
    if (kDebugMode) {
      print(entry.toString());
    }
  }

  void info(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  void warn(String message, {String? tag}) => log(message, level: LogLevel.warning, tag: tag);
  void error(String message, {String? tag}) => log(message, level: LogLevel.error, tag: tag);
  void debug(String message, {String? tag}) => log(message, level: LogLevel.debug, tag: tag);

  void clear() {
    logsNotifier.value = [];
  }
}
