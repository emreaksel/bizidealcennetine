import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';

class HeartConfettiWidget extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Duration animationDuration;
  final Color heartColor;

  const HeartConfettiWidget({
    Key? key,
    required this.child,
    this.particleCount = 30,
    this.animationDuration = const Duration(seconds: 3),
    this.heartColor = Colors.red,
  }) : super(key: key);

  @override
  _HeartConfettiWidgetState createState() => _HeartConfettiWidgetState();
}

class _HeartConfettiWidgetState extends State<HeartConfettiWidget>
    with TickerProviderStateMixin {
  List<HeartParticle> particles = [];
  late AnimationController _animationController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            particles.clear();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startConfetti(Offset position) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    if (mounted) {
      setState(() {
        _isAnimating = true;
        particles.clear();

        final random = Random();

        for (int i = 0; i < widget.particleCount; i++) {
          final angle =
              (math.pi + (math.pi / 3)) + (random.nextDouble() * (math.pi / 3));
          final speed = 200.0 + random.nextDouble() * 300.0;

          final initialVelocityX = math.cos(angle) * speed;
          final initialVelocityY = math.sin(angle) * speed;

          particles.add(HeartParticle(
            startPosition: position,
            size: 4.0 + random.nextDouble() * 9.0,
            initialVelocity: Offset(initialVelocityX, initialVelocityY),
            rotationSpeedX: -10.0 + random.nextDouble() * 50.0,
            rotationSpeedY: -10.0 + random.nextDouble() * 50.0,
            rotationSpeedZ: -10.0 + random.nextDouble() * 50.0,
            gravity: 700.0 + random.nextDouble() * 400.0,
            color: widget.heartColor,
          ));
        }
      });
    }

    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (details) {
            _startConfetti(details.localPosition);
          },
          child: widget.child,
        ),
        if (_isAnimating && particles.isNotEmpty)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: HeartConfettiPainter(
                  particles: particles,
                  progress: _animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
      ],
    );
  }
}

class HeartParticle {
  final Offset startPosition;
  final double size;
  final Offset initialVelocity;
  final double rotationSpeedX;
  final double rotationSpeedY;
  final double rotationSpeedZ;
  final double gravity;
  final Color color;

  HeartParticle({
    required this.startPosition,
    required this.size,
    required this.initialVelocity,
    required this.rotationSpeedX,
    required this.rotationSpeedY,
    required this.rotationSpeedZ,
    required this.gravity,
    required this.color,
  });

  Offset getPosition(double time) {
    final x = startPosition.dx + initialVelocity.dx * time;
    final y = startPosition.dy +
        initialVelocity.dy * time +
        0.5 * gravity * time * time;
    return Offset(x, y);
  }

  double getRotationX(double time) => rotationSpeedX * time;
  double getRotationY(double time) => rotationSpeedY * time;
  double getRotationZ(double time) => rotationSpeedZ * time;

  double getOpacity(double progress) {
    if (progress < 0.7) {
      return 1.0;
    } else {
      return 1.0 - (progress - 0.7) / 0.3;
    }
  }

  double getScale(double progress) {
    if (progress < 0.1) {
      return progress / 0.1;
    } else if (progress > 0.9) {
      return 1.0 - (progress - 0.9) / 0.1;
    }
    return 1.0;
  }
}

class HeartConfettiPainter extends CustomPainter {
  final List<HeartParticle> particles;
  final double progress;

  HeartConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 3.0;

    for (final particle in particles) {
      final position = particle.getPosition(time);

      if (position.dx < -50 ||
          position.dx > size.width + 50 ||
          position.dy > size.height + 50 ||
          position.dy < -100) {
        continue;
      }

      final rotationX = particle.getRotationX(time);
      final rotationY = particle.getRotationY(time);
      final rotationZ = particle.getRotationZ(time);
      final opacity = particle.getOpacity(progress);
      final scale = particle.getScale(progress);

      if (opacity <= 0 || scale <= 0) continue;

      final perspectiveScale = (math.cos(rotationY).abs() * 0.5 + 0.5) * scale;
      final skewX = math.sin(rotationY) * 0.3;
      final skewY = math.sin(rotationX) * 0.2;

      final colorIntensity = (math.cos(rotationX) + 1) / 2;
      final heartColor = Color.lerp(
        particle.color.withOpacity(0.8),
        particle.color.withOpacity(0.4),
        colorIntensity,
      )!;

      final paint = Paint()
        ..color = heartColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotationZ);
      canvas.scale(perspectiveScale, scale);
      canvas.skew(skewX, skewY);

      _drawMathematicalHeart(canvas, particle.size, paint);

      canvas.restore();
    }
  }

  void _drawMathematicalHeart(Canvas canvas, double size, Paint paint) {
    final path = Path();
    bool isFirst = true;
    const int steps = 100;

    for (int i = 0; i <= steps; i++) {
      final t = (i * 2 * math.pi) / steps;
      final x = 16 * math.pow(math.sin(t), 3);
      final y = 13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t);

      final scaledX = x * size / 32.0;
      final scaledY = -y * size / 32.0;

      if (isFirst) {
        path.moveTo(scaledX, scaledY);
        isFirst = false;
      } else {
        path.lineTo(scaledX, scaledY);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ImprovedConfettiDemo extends StatelessWidget {
  final Widget child;
  const ImprovedConfettiDemo({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return HeartConfettiWidget(
          particleCount: 29,
          animationDuration: const Duration(seconds: 4),
          heartColor: theme.accentColor,
          child: child,
        );
      }
    );
  }
}
