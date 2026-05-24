import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kenburns_nullsafety/kenburns_nullsafety.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';
import 'package:bizidealcennetine/services/HttpService.dart';
import 'dart:async';
import 'package:bizidealcennetine/widgets/kus.dart';

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

    if (widget.isLoading != oldWidget.isLoading) {
      _delayTimer?.cancel();
      if (widget.isLoading) {
        setState(() {
          _renderOverlay = true;
          _isVisible = true;
        });
      } else {
        setState(() {
          _isVisible = false;
        });
        _delayTimer?.cancel();
        _delayTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted && !widget.isLoading) {
            setState(() {
              _renderOverlay = false;
            });
          }
        });
      }
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
  final GlobalKey<BirdOverlayState> _birdKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          KenBurns(
              minAnimationDuration: const Duration(milliseconds: 10000),
              maxAnimationDuration: const Duration(milliseconds: 13000),
              maxScale: 1.3,
              child: Base64ImageWidget()),
          IgnorePointer(child: BirdOverlay(key: _birdKey)),
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

class Base64ImageWidget extends StatefulWidget {
  @override
  _Base64ImageWidgetState createState() => _Base64ImageWidgetState();
}

class _Base64ImageWidgetState extends State<Base64ImageWidget>
    with SingleTickerProviderStateMixin {
  Uint8List? _imageBytes;
  Uint8List? _oldImageBytes;
  String? _currentImageUrl;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage(imageUrl) async {
    final HttpService _httpService = HttpService();
    try {
      final responseBytes = await _httpService
          .fetchBytes("${Degiskenler.kaynakYolu}medya/atesiask/$imageUrl");

      if (mounted) {
        setState(() {
          _oldImageBytes = _imageBytes;
          _imageBytes = responseBytes;
          _currentImageUrl = imageUrl;
        });
        _fadeController.forward(from: 0.0);
      }
    } catch (e) {
      print('Resim indirme hatası: $e');
      try {
        final responseBytes = await _httpService.fetchBytes(
            "https://raw.githubusercontent.com/benolanben/atesiask/main/fotograflar/$imageUrl");
        if (mounted) {
          setState(() {
            _oldImageBytes = _imageBytes;
            _imageBytes = responseBytes;
            _currentImageUrl = imageUrl;
          });
          _fadeController.forward(from: 0.0);
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

        if (_currentImageUrl != imageUrl &&
            (imageUrl.contains(".jpg") || imageUrl.contains(".png"))) {
          _downloadImage(imageUrl);
        }

        if (_imageBytes == null) {
          return _buildThemedLoadingPlaceholder(context, theme);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (_oldImageBytes != null)
              FadeTransition(
                // Eski resim: 1.0 -> 0.0 (Yavaşça kaybolur)
                opacity:
                    _fadeAnimation.drive(Tween<double>(begin: 1.0, end: 0.0)),
                child: Image.memory(
                  _oldImageBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 800,
                ),
              ),
            FadeTransition(
              // Yeni resim: 0.0 -> 1.0 (Yavaşça belirir)
              opacity: _fadeAnimation,
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 800,
              ),
            ),
          ],
        );
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
