import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';
import '../yaveran/ui_support.dart';
import '../yaveran/logic.dart';

class CustomDialog extends StatelessWidget {
  final String buttonText;
  final String icerik;

  CustomDialog({
    required this.icerik,
  }) : buttonText = icerik.contains('https://benolanben.com/dinle/')
            ? 'Dinle'
            : 'Teşekkürler';

  double calculateFontSize(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double fontSize =
        screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100) * 0.11;
    return fontSize;
  }

  void closeDialog() {
    Future.delayed(Duration.zero, () {
      UI_support.ekranboyut_ana(0);
      Degiskenler.showDialogNotifier.value = false;
    });
  }

  void hediye() {
    var hediye = icerik.replaceAll('https://benolanben.com/dinle/', '');
    var link = hediye.split('&')[0];
    var id = hediye.split('&')[1];
    if (link.isNotEmpty && id.isNotEmpty) {
      print('Link: $link');
      print('ID: $id');
      hediye_irtibat(link, id);
    } else {
      print('Link or ID is empty.');
    }
    closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    String noticeText = icerik.contains('https://benolanben.com/dinle/')
        ? 'Dinle!\nHediyeyi Duyacaksın..'
        : icerik;
    
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        if (Degiskenler.showDialogNotifier.value) {
          Future.delayed(Duration.zero, () {
            UI_support.ekranboyut_minik(0);
          });
        }

        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28.0),
              color: theme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 2,
                )
              ],
              border: Border.all(
                color: theme.textColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SelectableText(
                  noticeText,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: calculateFontSize(context) * 0.9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (icerik.contains('https://benolanben.com/dinle/')) {
                        hediye();
                      } else {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString('bildirim', icerik);
                        closeDialog();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: closeDialog,
                  child: Text(
                    "Kapat",
                    style: TextStyle(color: theme.textColor.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
