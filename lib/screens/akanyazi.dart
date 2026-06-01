import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AkanYazi extends StatelessWidget {
  final String? text;

  const AkanYazi([this.text, Key? key]) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              // ValueKey forces full dispose+recreate when text changes
              // guaranteeing animation restarts from scratch.
              return _AkanYaziScroller(
                key: ValueKey<String>(title),
                text: title.isNotEmpty ? title : " ",
                theme: theme,
              );
            },
          ),
        );
      },
    );
  }
}

class _AkanYaziScroller extends StatefulWidget {
  final String text;
  final AppTheme theme;

  const _AkanYaziScroller({
    required Key key,
    required this.text,
    required this.theme,
  }) : super(key: key);

  @override
  State<_AkanYaziScroller> createState() => _AkanYaziScrollerState();
}

class _AkanYaziScrollerState extends State<_AkanYaziScroller>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _offset = 0.0;
  double _textWidth = 0.0;
  double _containerWidth = 0.0;
  double _totalCycleDistance = 0.0;
  bool _measured = false;

  // Pixels per second — adjusted for screen size
  double _velocity = 27.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_measured || _totalCycleDistance <= 0) return;

    setState(() {
      final double totalPixels =
          (elapsed.inMicroseconds / 1000000.0) * _velocity;
      _offset = totalPixels % _totalCycleDistance;
    });
  }

  void _measureAndStart(double containerWidth, TextStyle style) {
    _containerWidth = containerWidth;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    _textWidth = textPainter.width;

    // Total cycle: text starts at left → scrolls fully off screen left →
    // gap (container width) → text reappears from right
    _totalCycleDistance = _textWidth + _containerWidth;

    // Scale velocity: ~30px/s base on 360px screen
    _velocity = (containerWidth / 360.0).clamp(0.8, 2.5) * 30.0;

    _measured = true;

    // ALWAYS start scrolling — short or long, doesn't matter
    if (!_ticker.isActive) {
      _ticker.start();
    }

    // Trigger rebuild so we switch from placeholder to scrolling render
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Responsive font size
    final double baseFontSize = screenHeight * 0.019;
    final double minFontSize = screenWidth * 0.028;
    final double maxFontSize = screenWidth * 0.045;
    final double yaziBoyutu = baseFontSize.clamp(minFontSize, maxFontSize);

    final textStyle = TextStyle(
      color: widget.theme.textColor.withOpacity(0.9),
      fontSize: yaziBoyutu,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    );

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
        child: SizedBox(
          height: yaziBoyutu * 1.5,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Measure and start animation on first layout
              if (!_measured) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _measureAndStart(constraints.maxWidth, textStyle);
                  }
                });

                // Placeholder while waiting for first measurement (invisible)
                return Opacity(
                  opacity: 0.0,
                  child: Text(
                    widget.text,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                );
              }

              // Scrolling — always, for all text lengths
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: _containerWidth - _offset,
                      top: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.text, style: textStyle, maxLines: 1),
                          // Gap between repeats = full container width
                          SizedBox(width: _containerWidth),
                          Text(widget.text, style: textStyle, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
