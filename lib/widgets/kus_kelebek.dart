import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';

enum ButterflyState { flying, gliding }

// ═══════════════════════════════════════════════════════════════════════════
//  KELEBEK AYARLARI (Zarif ve Organik Değerler)
// ═══════════════════════════════════════════════════════════════════════════
class _SpawnConfig {
  const _SpawnConfig();
  final int triggerCount = 20;
  final int maxLimit = 60;
  final int initialCount = 0;
  final int waitSec = 10;
  final int removalIntervalSec = 1;
  final double spawnXY = 250.0;
  final double spawnZMin = -100.0;
  final double spawnZMax = 600.0;
  final double spawnVelocity = 1.0;
}

class _PhysicsConfig {
  const _PhysicsConfig();
  final double maxSpeed = 2.0;
  final double turnSpeed = 0.08; // Çok daha yumuşak dönüşler
  final double wanderStrength = 0.3;
  final double flapLiftForce = 0.45; // Çırpınca yukarı sekme hissi
  final double gravity = 0.12;

  final double separationDist = 90.0;
  final double separationForce = 0.04;

  final double areaRadius = 800.0;
  final double boundaryForce = 1.0;

  final double repelRadius = 150.0;
  final double repelStrength = 3.0;
  final double focalLength = 500.0;
}

class _BehaviorConfig {
  const _BehaviorConfig();
  final double glideProbability = 0.25;
  final int glideMinFrames = 30;
  final int glideRangeFrames = 60;
  final int flyMinFrames = 40;
  final int flyRangeFrames = 50;
}

class _VisualConfig {
  const _VisualConfig();
  final double wingFlapSpeed = 0.55;
  final double wingFlapAmplitude = 0.8;
  final double glideWingRatio = 0.4;

  final double pitchSmooth = 0.08;
  final double yawSmooth = 0.10;
  final double bankSmooth = 0.12;

  final double zFadeRange = 500.0;
  final double alphaMin = 0.1;
}

class ButterflyConfig {
  static const spawn = _SpawnConfig();
  static const physics = _PhysicsConfig();
  static const behavior = _BehaviorConfig();
  static const visual = _VisualConfig();
}

// ── 3D VEKTÖR MATEMATİĞİ ──────────────────────────────────────────────────
class Vec3 {
  double x, y, z;
  Vec3([this.x = 0, this.y = 0, this.z = 0]);
  Vec3 clone() => Vec3(x, y, z);
  void set(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void add(Vec3 v) {
    x += v.x;
    y += v.y;
    z += v.z;
  }

  void sub(Vec3 v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
  }

  void scale(double s) {
    x *= s;
    y *= s;
    z *= s;
  }

  void divScale(double s) {
    if (s != 0) {
      x /= s;
      y /= s;
      z /= s;
    }
  }

  double get len => sqrt(x * x + y * y + z * z);
  double dst(Vec3 v) {
    final dx = x - v.x, dy = y - v.y, dz = z - v.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  void normalize() => divScale(len);
}

// ── KELEBEK ORGANİK KANAT ÇİZİMLERİ (YEPYENİ) ─────────────────────────────
// X ekseni gövdedir (Kafa +X yönünde). Y ekseni kanatların açıldığı yöndür.
// Origami gibi tek parça değil, Üst ve Alt kanat boğumları oluşturuldu.
final Path _leftWingPath = Path()
  ..moveTo(6, 0) // Başlangıç: Baş kısmı
  ..cubicTo(10, -15, 5, -30, -5, -35) // Üst kanat ucu (Forewing)
  ..cubicTo(-12, -35, -15, -22, -8,
      -12) // Orta kanat çentiği (Vücuda doğru giren kıvrım)
  ..cubicTo(-18, -18, -25, -10, -20,
      0) // Alt kanat ucu (Hindwing) ve kuyruğa birleşme
  ..close();

final Path _rightWingPath = Path()
  ..moveTo(6, 0)
  ..cubicTo(10, 15, 5, 30, -5, 35)
  ..cubicTo(-12, 35, -15, 22, -8, 12)
  ..cubicTo(-18, 18, -25, 10, -20, 0)
  ..close();

// ── 3D KELEBEK ORGANİK UÇUŞ FİZİĞİ ───────────────────────────────────────
class ButterflyBoid {
  final Vec3 pos = Vec3();
  final Vec3 vel = Vec3();
  final Vec3 accel = Vec3();
  final Random _rng = Random();

  ButterflyState state = ButterflyState.flying;
  int stateTimer = 0;
  double wanderTheta = 0.0;
  double wanderPhi = 0.0;
  double phase = 0.0;

  double w = 400, h = 400;
  double get d => ButterflyConfig.physics.areaRadius;

  void run(List<ButterflyBoid> flock, Size screenSize) {
    w = screenSize.width / 2;
    h = screenSize.height / 2;

    _updateState();
    _wander();
    _separate(flock);
    _boundary();
    _applyLiftAndGravity();
    _move();
  }

  void _updateState() {
    if (stateTimer > 0) {
      stateTimer--;
      return;
    }
    if (state == ButterflyState.flying) {
      if (_rng.nextDouble() < ButterflyConfig.behavior.glideProbability) {
        state = ButterflyState.gliding;
        stateTimer = ButterflyConfig.behavior.glideMinFrames +
            _rng.nextInt(ButterflyConfig.behavior.glideRangeFrames);
      } else {
        stateTimer = ButterflyConfig.behavior.flyMinFrames +
            _rng.nextInt(ButterflyConfig.behavior.flyRangeFrames);
      }
    } else {
      state = ButterflyState.flying;
      stateTimer = ButterflyConfig.behavior.flyMinFrames +
          _rng.nextInt(ButterflyConfig.behavior.flyRangeFrames);
    }
  }

  void _wander() {
    wanderTheta +=
        (_rng.nextDouble() - 0.5) * ButterflyConfig.physics.turnSpeed;
    wanderPhi += (_rng.nextDouble() - 0.5) * ButterflyConfig.physics.turnSpeed;

    final wanderForce = Vec3(cos(wanderTheta) * cos(wanderPhi), sin(wanderPhi),
        sin(wanderTheta) * cos(wanderPhi))
      ..scale(ButterflyConfig.physics.wanderStrength);

    accel.add(wanderForce);
  }

  void _applyLiftAndGravity() {
    if (state == ButterflyState.flying) {
      phase = (phase + ButterflyConfig.visual.wingFlapSpeed) % (pi * 2);
      if (sin(phase) < -0.2) {
        accel.add(Vec3(0, -ButterflyConfig.physics.flapLiftForce, 0));
      } else {
        accel.add(Vec3(0, ButterflyConfig.physics.gravity, 0));
      }
    } else {
      accel.add(Vec3(0, ButterflyConfig.physics.gravity * 0.5, 0));
    }
  }

  void _separate(List<ButterflyBoid> flock) {
    for (final b in flock) {
      if (b == this) continue;
      final dist = pos.dst(b.pos);
      if (dist > 0 && dist < ButterflyConfig.physics.separationDist) {
        final push = Vec3(pos.x - b.pos.x, pos.y - b.pos.y, pos.z - b.pos.z)
          ..normalize()
          ..scale(ButterflyConfig.physics.separationForce);
        accel.add(push);
      }
    }
  }

  void _boundary() {
    void check(Vec3 wall) {
      final distSq = pos.dst(wall);
      if (distSq > 0 && distSq < 400) {
        final dir = Vec3(pos.x - wall.x, pos.y - wall.y, pos.z - wall.z)
          ..normalize()
          ..scale(ButterflyConfig.physics.boundaryForce / (distSq * 0.05 + 1));
        accel.add(dir);
      }
    }

    check(Vec3(-w, pos.y, pos.z));
    check(Vec3(w, pos.y, pos.z));
    check(Vec3(pos.x, -h - 200, pos.z)); // Yukarıya biraz daha fazla izin ver
    check(Vec3(pos.x, h, pos.z));
    check(Vec3(pos.x, pos.y, -400));
    check(Vec3(pos.x, pos.y, d));
  }

  void _move() {
    vel.add(accel);
    final l = vel.len;
    if (l > ButterflyConfig.physics.maxSpeed) {
      vel.divScale(l / ButterflyConfig.physics.maxSpeed);
    }
    pos.add(vel);
    accel.set(0, 0, 0);
  }
}

// ── GÖRSEL KELEBEK ─────────────────────────────────────────────────────────
class ButterflyVisual {
  final ButterflyBoid boid;
  final Vec3 rot = Vec3();
  double currentWingAngle = 0.0;
  final Color baseColor;

  ButterflyVisual({required this.boid, required this.baseColor}) {
    rot.y = _rng.nextDouble() * pi * 2;
  }

  final Random _rng = Random();

  void updateVisuals() {
    final targetYaw = atan2(boid.vel.y, boid.vel.x);
    double diffY = targetYaw - rot.y;
    while (diffY > pi) diffY -= pi * 2;
    while (diffY < -pi) diffY += pi * 2;
    rot.y += diffY * ButterflyConfig.visual.yawSmooth;

    final speedXZ = sqrt(boid.vel.x * boid.vel.x + boid.vel.z * boid.vel.z);
    final targetPitch = atan2(boid.vel.y, speedXZ);
    rot.z += (targetPitch - rot.z) * ButterflyConfig.visual.pitchSmooth;

    final targetRoll = diffY * 2.0;
    rot.x += (targetRoll - rot.x) * ButterflyConfig.visual.bankSmooth;

    // YENİ ÇIRPMA MANTIĞI: Kelebek kanatları aşağı doğru kırılmaz, yukarı kapanır.
    if (boid.state == ButterflyState.gliding) {
      final targetAngle = ButterflyConfig.visual.wingFlapAmplitude *
          ButterflyConfig.visual.glideWingRatio;
      currentWingAngle += (targetAngle - currentWingAngle) * 0.15;
    } else {
      // sin dalgasını modifiye ederek kanatların çoğunlukla yukarıda çırpılmasını sağladık
      currentWingAngle =
          (sin(boid.phase) * ButterflyConfig.visual.wingFlapAmplitude) + 0.4;
    }
  }

  void draw(Canvas canvas) {
    final fl = ButterflyConfig.physics.focalLength;
    final zsc = fl + boid.pos.z;
    if (zsc < 50) return;

    final tZ = ((boid.pos.z + ButterflyConfig.visual.zFadeRange) /
            (ButterflyConfig.visual.zFadeRange * 2.0))
        .clamp(0.0, 1.0);
    final alpha = (1.0 - tZ * (1.0 - ButterflyConfig.visual.alphaMin))
        .clamp(ButterflyConfig.visual.alphaMin, 1.0);

    canvas.save();

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 1 / fl)
      ..translate(boid.pos.x, boid.pos.y, boid.pos.z)
      ..rotateZ(rot.z)
      ..rotateY(rot.y)
      ..rotateX(rot.x);

    canvas.transform(transform.storage);

    final alphaInt = (255 * alpha).toInt();

    // GÖVDE
    final bodyPaint = Paint()
      ..color = baseColor.withAlpha(alphaInt)
      ..style = PaintingStyle.fill;

    // DOKULU KANAT RENGİ (Transparan gradient efekti)
    final wingGradient = ui.Gradient.radial(
        const Offset(0, 0), // Gövdeden dışarı doğru
        40.0, // Yayılma alanı
        [
          baseColor.withAlpha((alphaInt * 0.9).toInt()), // İç kısım opak
          baseColor.withAlpha((alphaInt * 0.15).toInt()), // Uçlar şeffaf
        ]);

    final wingPaint = Paint()
      ..shader = wingGradient
      ..style = PaintingStyle.fill;

    // KANAT ÇERÇEVESİ (Hafif bir damar/kenar hissi verir)
    final wingBorderPaint = Paint()
      ..color = Colors.white.withAlpha((alphaInt * 0.3).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Çizim: Gövde
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 12, height: 3), bodyPaint);

    // Çizim: Sol Kanat (X ekseni etrafında döner)
    canvas.save();
    canvas.transform((Matrix4.identity()..rotateX(currentWingAngle)).storage);
    canvas.drawPath(_leftWingPath, wingPaint);
    canvas.drawPath(_leftWingPath, wingBorderPaint); // Kenarlık eklendi
    canvas.restore();

    // Çizim: Sağ Kanat
    canvas.save();
    canvas.transform((Matrix4.identity()..rotateX(-currentWingAngle)).storage);
    canvas.drawPath(_rightWingPath, wingPaint);
    canvas.drawPath(_rightWingPath, wingBorderPaint); // Kenarlık eklendi
    canvas.restore();

    canvas.restore();
  }
}

// ── WIDGET & PAINTER KISIMLARI AYNI (Değişiklik yok) ──────────────────────
class ButterflyOverlay extends StatefulWidget {
  const ButterflyOverlay({Key? key}) : super(key: key);
  @override
  ButterflyOverlayState createState() => ButterflyOverlayState();
}

class ButterflyOverlayState extends State<ButterflyOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<ButterflyBoid> _boids = [];
  final List<ButterflyVisual> _visuals = [];
  final Random _rng = Random();
  Timer? _deactiveTimer;
  Timer? _removalTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    Degiskenler.butterflyTriggerNotifier.addListener(_onTrigger);
    if (ButterflyConfig.spawn.initialCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => spawns(count: ButterflyConfig.spawn.initialCount),
      );
    }
  }

  void _onTrigger() {
    if (!Degiskenler.butterflyTriggerNotifier.value) return;
    _deactiveTimer?.cancel();
    _removalTimer?.cancel();
    setState(() {
      _boids.clear();
      _visuals.clear();
    });
    spawns(count: ButterflyConfig.spawn.triggerCount);

    _deactiveTimer = Timer(
      Duration(seconds: ButterflyConfig.spawn.waitSec),
      () {
        if (!mounted) return;
        _removalTimer = Timer.periodic(
          Duration(seconds: ButterflyConfig.spawn.removalIntervalSec),
          (timer) {
            if (mounted && _boids.isNotEmpty) {
              setState(() {
                _boids.removeAt(0);
                _visuals.removeAt(0);
              });
              if (_boids.isEmpty) {
                timer.cancel();
                Degiskenler.butterflyTriggerNotifier.value = false;
              }
            } else {
              timer.cancel();
            }
          },
        );
      },
    );
  }

  void spawns({int count = 12, Offset? position}) {
    if (!mounted) return;
    final theme = Degiskenler.currentThemeNotifier.value;
    final color = theme.accentColor;

    final spawnXY = ButterflyConfig.spawn.spawnXY;
    final zMin = ButterflyConfig.spawn.spawnZMin;
    final zMax = ButterflyConfig.spawn.spawnZMax;
    final vel0 = ButterflyConfig.spawn.spawnVelocity;

    for (int i = 0; i < count; i++) {
      final boid = ButterflyBoid();
      boid.pos.set(
        _rng.nextDouble() * spawnXY * 2 - spawnXY,
        _rng.nextDouble() * spawnXY * 2 - spawnXY,
        zMin + _rng.nextDouble() * (zMax - zMin),
      );

      boid.vel.set(
        _rng.nextDouble() * vel0 * 2 - vel0,
        _rng.nextDouble() * vel0 * 2 - vel0,
        _rng.nextDouble() * vel0 * 2 - vel0,
      );

      boid.wanderTheta = _rng.nextDouble() * pi * 2;
      boid.phase = _rng.nextDouble() * pi * 2;

      _boids.add(boid);
      _visuals.add(ButterflyVisual(boid: boid, baseColor: color));
    }

    if (_boids.length > ButterflyConfig.spawn.maxLimit) {
      final excess = _boids.length - ButterflyConfig.spawn.maxLimit;
      _boids.removeRange(0, excess);
      _visuals.removeRange(0, excess);
    }
    setState(() {});
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;

    for (int i = 0; i < _boids.length; i++) {
      _boids[i].run(_boids, size);
      _visuals[i].updateVisuals();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _deactiveTimer?.cancel();
    _removalTimer?.cancel();
    Degiskenler.butterflyTriggerNotifier.removeListener(_onTrigger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ButterflyFlockPainter(_visuals),
      child: const SizedBox.expand(),
    );
  }
}

class _ButterflyFlockPainter extends CustomPainter {
  final List<ButterflyVisual> visuals;
  _ButterflyFlockPainter(this.visuals);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    final sorted = List<ButterflyVisual>.from(visuals)
      ..sort((a, b) => b.boid.pos.z.compareTo(a.boid.pos.z));

    for (final v in sorted) {
      v.draw(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
