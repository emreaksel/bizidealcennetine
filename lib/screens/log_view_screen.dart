import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../yaveran/log_service.dart';
import '../yaveran/Degiskenler.dart';

class LogViewScreen extends StatefulWidget {
  const LogViewScreen({super.key});

  @override
  State<LogViewScreen> createState() => _LogViewScreenState();
}

class _LogViewScreenState extends State<LogViewScreen> {
  LogLevel? _filterLevel;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScroll) _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Degiskenler.currentThemeNotifier.value;
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text('Sistem Logları', style: TextStyle(color: theme.textColor)),
        backgroundColor: theme.cardColor.withOpacity(0.8),
        iconTheme: IconThemeData(color: theme.textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: theme.textColor),
            onPressed: () {
              final allLogs = LogService().logsNotifier.value.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loglar panoya kopyalandı')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: theme.textColor),
            onPressed: () {
              LogService().clear();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(theme),
          Expanded(
            child: ValueListenableBuilder<List<LogEntry>>(
              valueListenable: LogService().logsNotifier,
              builder: (context, logs, _) {
                final filteredLogs = _filterLevel == null
                    ? logs
                    : logs.where((l) => l.level == _filterLevel).toList();

                if (_autoScroll && logs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildLogItem(log, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: _autoScroll ? theme.accentColor : Colors.grey,
        onPressed: () {
          setState(() {
            _autoScroll = !_autoScroll;
          });
        },
        child: Icon(
          _autoScroll ? Icons.arrow_downward : Icons.pause,
          color: theme.textColor,
        ),
      ),
    );
  }

  Widget _buildFilters(dynamic theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: theme.cardColor.withOpacity(0.1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, 'Hepsi', theme),
            _filterChip(LogLevel.info, 'Info', theme),
            _filterChip(LogLevel.warning, 'Warning', theme),
            _filterChip(LogLevel.error, 'Error', theme),
            _filterChip(LogLevel.debug, 'Debug', theme),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(LogLevel? level, String label, dynamic theme) {
    final isSelected = _filterLevel == level;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? theme.textColor : theme.textColor.withOpacity(0.6))),
        selected: isSelected,
        selectedColor: theme.accentColor,
        backgroundColor: theme.cardColor.withOpacity(0.2),
        onSelected: (selected) {
          setState(() {
            _filterLevel = selected ? level : null;
          });
        },
      ),
    );
  }

  Widget _buildLogItem(LogEntry log, dynamic theme) {
    Color levelColor;
    switch (log.level) {
      case LogLevel.info:
        levelColor = Colors.blue;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        break;
      case LogLevel.debug:
        levelColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.textColor.withOpacity(0.1), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              DateFormat('HH:mm:ss').format(log.timestamp),
              style: TextStyle(fontSize: 10, color: theme.textColor.withOpacity(0.5)),
            ),
          ),
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            color: levelColor,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.tag != null)
                  Text(
                    '[${log.tag}]',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                SelectableText(
                  log.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
