import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';
import 'package:bizidealcennetine/services/MusicApiService.dart';

class SyncDialog {
  static final MusicApiService _apiService = MusicApiService();

  static Future<void> show(BuildContext context, {VoidCallback? onSyncSuccess}) async {
    final TextEditingController codeController = TextEditingController();
    bool isDialogLoading = false;
    String? errorMessage;
    final theme = Degiskenler.currentThemeNotifier.value;

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.backgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.important_devices_rounded,
                      color: theme.accentColor),
                  const SizedBox(width: 12),
                  Text('Cihaz Eşleştirme',
                      style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStep(
                      1,
                      InkWell(
                        onTap: () async {
                          final url =
                              Uri.parse('https://benolanben.com/atesiask');
                          try {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          } catch (e) {
                            debugPrint('URL açılamadı: $url, Hata: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.accentColor.withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.open_in_browser_rounded,
                                  color: theme.accentColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                    'benolanben.com/atesiask\nAdresine gitmek için Tıklayın',
                                    style: TextStyle(
                                        color: theme.accentColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      theme,
                    ),
                    _buildStep(
                      2,
                      Text(
                          'Tarayıcıda açılan sayfada sağ üstten Apple veya Google hesabınızla giriş yapın.',
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4)),
                      theme,
                    ),
                    _buildStep(
                      3,
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4),
                          children: [
                            TextSpan(
                                text: 'Ekranda sol üstteki senkronizasyon ('),
                            WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(Icons.cloud_sync_rounded,
                                    size: 18,
                                    color: theme.textColor.withOpacity(0.9))),
                            TextSpan(text: ') simgesine dokunun.'),
                          ],
                        ),
                      ),
                      theme,
                    ),
                    _buildStep(
                      4,
                      Text(
                          'Ekranda beliren 6 haneli cihaz kodunu aşağıdaki alana girin.',
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4)),
                      theme,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 6,
                      style: TextStyle(
                          color: theme.textColor,
                          fontSize: 32,
                          letterSpacing: 14,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle:
                            TextStyle(color: theme.textColor.withOpacity(0.1)),
                        errorText: errorMessage,
                        counterText: "",
                        filled: true,
                        fillColor: theme.textColor.withOpacity(0.03),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: theme.textColor.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: theme.accentColor, width: 2)),
                      ),
                    ),
                    if (isDialogLoading)
                      Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                                color: theme.accentColor)),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                      isDialogLoading ? null : () => Navigator.pop(context),
                  child: Text('İptal',
                      style: TextStyle(
                          color: theme.textColor.withOpacity(0.5),
                          fontSize: 15)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(
                                () => errorMessage = 'Kod 6 haneli olmalıdır.');
                            return;
                          }
                          setDialogState(() {
                            isDialogLoading = true;
                            errorMessage = null;
                          });
                          final success =
                              await _apiService.exchangeCodeWithServer(code);
                          if (success) {
                            Navigator.pop(context);
                            if (onSyncSuccess != null) {
                              onSyncSuccess();
                            }
                          } else {
                            setDialogState(() {
                              isDialogLoading = false;
                              errorMessage = 'Hatalı kod veya sunucu hatası.';
                            });
                          }
                        },
                  child: Text('Doğrula',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            );
          });
        });
  }

  static Widget _buildStep(int number, Widget content, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(
                top: 2), // Metinle hizalamak için ufak pay
            decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.15),
                shape: BoxShape.circle),
            child: Center(
              child: Text('$number',
                  style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: content),
        ],
      ),
    );
  }
}
