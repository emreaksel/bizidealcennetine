import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreenWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration displayDuration;
  final Duration animationDuration;

  const SplashScreenWidget({
    Key? key,
    this.onComplete,
    this.displayDuration = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  _SplashScreenWidgetState createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _startSplashSequence();
  }

  void _startSplashSequence() {
    _fadeController.forward();
    _scaleController.forward();

    _displayTimer = Timer(widget.displayDuration, () {
      _startExitAnimation();
    });
  }

  void _startExitAnimation() {
    _fadeController.reverse().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });

    _scaleController.animateTo(1.2, curve: Curves.easeInBack);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _displayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Center(
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(104, 131, 127, 127),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/atesiask.jpg',
                        width: MediaQuery.of(context).size.width * 0.81,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: MediaQuery.of(context).size.width * 0.6,
                            height: MediaQuery.of(context).size.width * 0.6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white.withOpacity(0.5),
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
