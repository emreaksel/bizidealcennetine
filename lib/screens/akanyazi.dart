import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

class AkanYazi extends StatefulWidget {
  final String? text;
  AkanYazi([this.text]);

  @override
  _AkanYaziState createState() => _AkanYaziState();
}

class _AkanYaziState extends State<AkanYazi> {
  String _lastText = "";
  String _formattedText = "";
  double _lastFontSize = 0;
  double _lastScreenWidth = 0;

  String _getFormattedText(
      String text, double fontSize, double screenWidth, double screenHeight) {
    if (text == _lastText &&
        fontSize == _lastFontSize &&
        screenWidth == _lastScreenWidth) {
      return _formattedText;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();

    double textWidth = painter.width;
    int targetLength = (textWidth / 3.34).toInt();

    if (screenWidth > textWidth) {
      _formattedText = text + ' ' * (screenWidth / 3.9).toInt();
    } else {
      int spacesToAdd = targetLength - text.length;
      _formattedText = text + ' ' * (spacesToAdd > 0 ? spacesToAdd : 0);
    }

    _lastText = text;
    _lastFontSize = fontSize;
    _lastScreenWidth = screenWidth;

    return _formattedText;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double yaziBoyutu = screenHeight * 0.019;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 1),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(0.45),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
              left: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
              right: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: Degiskenler.currentEpigramNotifier,
            builder: (_, title, __) {
              // PERFORMANS ÇÖZÜMÜ: RepaintBoundary eklendi
              return RepaintBoundary(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.17, 0.83, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Material(
                    type: MaterialType.transparency,
                    child: TextScroll(
                      _getFormattedText(
                          title, yaziBoyutu, screenWidth, screenHeight),
                      mode: TextScrollMode.endless,
                      // HIZ OPTİMİZASYONU: Alt-piksel titremesini azaltmak için hafifçe artırıldı
                      velocity: const Velocity(pixelsPerSecond: Offset(60, 0)), 
                      delayBefore: const Duration(milliseconds: 1000),
                      numberOfReps: 99999,
                      pauseBetween: const Duration(milliseconds: 100),
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.9),
                        fontSize: yaziBoyutu,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.right,
                      selectable: false,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}