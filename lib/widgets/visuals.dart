import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kenburns_nullsafety/kenburns_nullsafety.dart';
import 'package:text_scroll/text_scroll.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/HttpService.dart';

class LoadingWidget extends StatefulWidget {
  @override
  _LoadingWidgetState createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: theme.backgroundColor.withOpacity(0.9),
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // Atmospheric Shimmering Layer
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.width * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.accentColor.withOpacity(
                                (0.3 * (1.0 - (_shimmerAnimation.value - 0.5).abs())).clamp(0.0, 1.0)),
                            theme.backgroundColor.withOpacity(0.0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Moving Essence Ring
                  Center(
                    child: Transform.scale(
                      scale: 1.0 + (_shimmerAnimation.value * 0.2),
                      child: Opacity(
                        opacity: (1.0 - (_shimmerAnimation.value - 0.5).abs()).clamp(0.0, 1.0),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.accentColor.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Core Breathing Light
                  Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accentColor,
                        boxShadow: [
                          BoxShadow(
                            color: theme.accentColor,
                            blurRadius: 20 * (1.1 + (_shimmerAnimation.value * 0.1)),
                            spreadRadius: 5,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class KenBurnsViewWidget extends StatefulWidget {
  final Widget backWidget;
  KenBurnsViewWidget({required this.backWidget});

  @override
  _KenBurnsViewWidgetState createState() => _KenBurnsViewWidgetState();
}

class _KenBurnsViewWidgetState extends State<KenBurnsViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          KenBurns(
              minAnimationDuration: Duration(milliseconds: 10000),
              maxAnimationDuration: Duration(milliseconds: 13000),
              maxScale: 1.3,
              child: Base64ImageWidget()),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: widget.backWidget,
          ),
        ],
      ),
    );
  }
}

class AkanYazi extends StatelessWidget {
  final String text;

  AkanYazi(this.text);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double yaziBoyutu = screenHeight * 0.019;

    String setEpigram(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: yaziBoyutu)),
        textDirection: TextDirection.ltr,
      )..layout();

      double textWidth = painter.width;
      int targetLength = (textWidth / 3.34).toInt();
      String finalText;
      if (screenWidth > textWidth) {
        finalText = text + ' ' * (screenWidth / 3.9).toInt();
      } else {
        int spacesToAdd = targetLength - text.length;
        finalText = text + ' ' * spacesToAdd;
      }
      return finalText;
    }

    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(0.45),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(color: theme.textColor.withOpacity(0.1), width: 0.5),
              left: BorderSide(color: theme.textColor.withOpacity(0.1), width: 0.5),
              right: BorderSide(color: theme.textColor.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: Degiskenler.currentEpigramNotifier,
            builder: (_, title, __) {
              return TextScroll(
                setEpigram(title),
                mode: TextScrollMode.endless,
                velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
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
                selectable: true,
              );
            },
          ),
        );
      },
    );
  }
}

class Base64ImageWidget extends StatefulWidget {
  @override
  _Base64ImageWidgetState createState() => _Base64ImageWidgetState();
}

class _Base64ImageWidgetState extends State<Base64ImageWidget> {
  Uint8List? _imageBytes;
  String? _currentImageUrl;

  Future<void> _downloadImage(imageUrl) async {
    final HttpService _httpService = HttpService();
    try {
      final responseBytes = await _httpService
          .fetchBytes("${Degiskenler.kaynakYolu}medya/atesiask/$imageUrl");
      if (mounted) {
        setState(() {
          _imageBytes = responseBytes;
          _currentImageUrl = imageUrl;
        });
      }
    } catch (e) {
      print('Resim indirme hatası: $e');
      try {
        final responseBytes = await _httpService.fetchBytes(
            "https://raw.githubusercontent.com/benolanben/atesiask/main/fotograflar/$imageUrl");
        if (mounted) {
          setState(() {
            _imageBytes = responseBytes;
            _currentImageUrl = imageUrl;
          });
        }
      } catch (e) {
        print('Resim indirme hatası: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Degiskenler.currentImageNotifier,
      builder: (context, imageUrl, child) {
        if (_currentImageUrl == imageUrl && _imageBytes != null) {
          return Image.memory(
            _imageBytes!,
            fit: BoxFit.cover,
          );
        } else {
          if (imageUrl.contains(".jpg") || imageUrl.contains(".png")) {
            _downloadImage(imageUrl);
            return _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/images/loading.gif',
                    height: MediaQuery.of(context).size.height * 0.05,
                  );
          } else
            return Image.asset(
              'assets/images/loading.gif',
              height: MediaQuery.of(context).size.height * 0.05,
            );
        }
      },
    );
  }
}
