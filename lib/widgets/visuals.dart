import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kenburns_nullsafety/kenburns_nullsafety.dart';
import 'package:text_scroll/text_scroll.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';
import '../yaveran/HttpService.dart';
import 'kus_taklaci.dart';

import 'dart:async';
import 'dart:math' as math;

class SpiritualLoader extends StatefulWidget {
  final bool isLoading;

  const SpiritualLoader({Key? key, required this.isLoading}) : super(key: key);

  @override
  _SpiritualLoaderState createState() => _SpiritualLoaderState();
}

class _SpiritualLoaderState extends State<SpiritualLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;

  bool _renderOverlay = false;
  bool _isVisible = false;
  Timer? _delayTimer;

  final int _waveCount = 7;

  @override
  void initState() {
    super.initState();
    _renderOverlay = widget.isLoading;
    _isVisible = widget.isLoading;

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void didUpdateWidget(SpiritualLoader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading && !oldWidget.isLoading) {
      _delayTimer?.cancel();
      setState(() {
        _renderOverlay = true;
        _isVisible = true;
      });
    } else if (!widget.isLoading && oldWidget.isLoading) {
      setState(() {
        _isVisible = false;
      });
      _delayTimer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) {
          setState(() {
            _renderOverlay = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderOverlay) return const SizedBox.shrink();

    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return IgnorePointer(
          ignoring: !_isVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: _isVisible ? 1.0 : 0.0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: theme.backgroundColor.withOpacity(0.2),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: _buildRipples(theme.accentColor),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRipples(Color baseColor) {
    return List.generate(_waveCount, (index) {
      final double phase =
          (_rippleController.value + (index / _waveCount)) % 1.0;
      final double easeOutPhase = Curves.easeOut.transform(phase);
      final double currentSize = easeOutPhase * 200;

      double opacity = 0.0;
      if (easeOutPhase < 0.15) {
        opacity = easeOutPhase / 0.15;
      } else {
        opacity = 1.0 - ((easeOutPhase - 0.15) / 0.85);
      }

      return Container(
        width: currentSize,
        height: currentSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: baseColor.withOpacity(opacity * 0.4),
            width: 1.0 + (opacity * 1.5),
          ),
        ),
      );
    });
  }
}

class KenBurnsViewWidget extends StatefulWidget {
  final Widget backWidget;
  KenBurnsViewWidget({required this.backWidget});

  @override
  _KenBurnsViewWidgetState createState() => _KenBurnsViewWidgetState();
}

class _KenBurnsViewWidgetState extends State<KenBurnsViewWidget> {
  final GlobalKey<BirdFlightOverlayState> _birdKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) => _birdKey.currentState
                ?.spawnBirds(count: 6, position: details.localPosition),
            child: KenBurns(
                minAnimationDuration: const Duration(milliseconds: 10000),
                maxAnimationDuration: const Duration(milliseconds: 13000),
                maxScale: 1.3,
                child: Base64ImageWidget()),
          ),
          BirdFlightOverlay(key: _birdKey),
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
              return ShaderMask(
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
                    selectable: false,
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
        final theme = Degiskenler.currentThemeNotifier.value;
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
                : _buildThemedLoadingPlaceholder(context, theme);
          } else {
            return _buildThemedLoadingPlaceholder(context, theme);
          }
        }
      },
    );
  }

  Widget _buildThemedLoadingPlaceholder(BuildContext context, AppTheme theme) {
    return Container(
      color: theme.backgroundColor.withOpacity(0.5),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.accentColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
