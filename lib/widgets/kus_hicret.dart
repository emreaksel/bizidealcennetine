import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  GÖÇ ANIMASYONU AYARLARI
// ═══════════════════════════════════════════════════════════════════════════

class _MigSpawnConfig {
  const _MigSpawnConfig();
  final int waveCount = 1;
  final Duration waveDelay = const Duration(milliseconds: 4000);
  final int colonyCount = 3;
  final int minBirdsPerColony = 3;
  final int maxBirdsPerColony = 17;
  final double nearestZ = -50.0;
  final double farthestZ = 1200.0;
  final double spawnXOffset = 320.0;

  // Kolonilerin X ekseninde ne kadar dağılacağını kontrol eder.
  // Dar koridor için 200–400, geniş için 800–1200 arası dene.
  final double colonyXSpread = 400.0;

  // V dizilimindeki kuşlar arası yatay boşluk.
  // Sıkı formasyon için 10–14, gevşek için 20–28 arası dene.
  final double wingXStep = 14.0;
}

class _MigPhysicsConfig {
  const _MigPhysicsConfig();
  final double minColonySpeed = 1.5;
  final double maxColonySpeed = 2.3;
  final double speedJitter = 0.6;
  final double alignStrength = 0.07;
  final double cohereStrength = 0.03;
  final double separationDist = 35.0;
  final double separationStrength = 0.12;
  final double yDriftAmplitude = 0.04;
  final double maxSpeed = 4.0;
  final double maxForce = 0.10;
  final double focalLength = 600.0;
  final double verticalPadding = 0.97;
}

class _MigVisualConfig {
  const _MigVisualConfig();
  final double wingFlapSpeed = 0.18;
  final double wingFlapAmplitude = 5.5;
}

class MigrationConfig {
  static const spawn = _MigSpawnConfig();
  static const physics = _MigPhysicsConfig();
  static const visual = _MigVisualConfig();
}

// ═══════════════════════════════════════════════════════════════════════════
//  3D VEKTÖR
// ═══════════════════════════════════════════════════════════════════════════
class _V3 {
  double x, y, z;
  _V3([this.x = 0, this.y = 0, this.z = 0]);

  _V3 clone() => _V3(x, y, z);

  void set(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void add(_V3 v) {
    x += v.x;
    y += v.y;
    z += v.z;
  }

  void sub(_V3 v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
  }

  void subOf(_V3 a, _V3 b) {
    x = a.x - b.x;
    y = a.y - b.y;
    z = a.z - b.z;
  }

  void scale(double s) {
    x *= s;
    y *= s;
    z *= s;
  }

  void divSafe(double s) {
    if (s.abs() > 1e-9) {
      x /= s;
      y /= s;
      z /= s;
    }
  }

  double get len => sqrt(x * x + y * y + z * z);

  double dst(_V3 v) {
    final dx = x - v.x, dy = y - v.y, dz = z - v.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  double dstSq(_V3 v) {
    final dx = x - v.x, dy = y - v.y, dz = z - v.z;
    return dx * dx + dy * dy + dz * dz;
  }

  double dot(_V3 v) => x * v.x + y * v.y + z * v.z;

  void normalize() => divSafe(len);

  void limit(double max) {
    final l = len;
    if (l > max) divSafe(l / max);
  }
}

// ── DÖNÜŞ VE PROJEKSİYON ──────────────────────────────────────────────────
void _rY(_V3 p, double a) {
  final s = sin(a), c = cos(a);
  final nx = p.x * c - p.z * s;
  final nz = p.x * s + p.z * c;
  p.x = nx;
  p.z = nz;
}

void _rZ(_V3 p, double a) {
  final s = sin(a), c = cos(a);
  final nx = p.x * c - p.y * s;
  final ny = p.x * s + p.y * c;
  p.x = nx;
  p.y = ny;
}

void _rX(_V3 p, double a) {
  final s = sin(a), c = cos(a);
  final ny = p.y * c - p.z * s;
  final nz = p.y * s + p.z * c;
  p.y = ny;
  p.z = nz;
}

Offset? _proj(_V3 p) {
  final fl = MigrationConfig.physics.focalLength;
  final zsc = fl + p.z;
  if (zsc < 20) return null;
  final scale = fl / zsc;
  return Offset(p.x * scale, -p.y * scale);
}

const _mVerts = [
  [6.0, 0.0, 0.0],
  [-6.0, -2.0, 1.0],
  [-6.0, 0.0, 0.0],
  [-6.0, -2.0, -1.0],
  [0.0, 2.0, -7.0],
  [0.0, 2.0, 7.0],
  [2.0, 0.0, 0.0],
  [-4.0, 0.0, 0.0],
];
const _mFaces = [
  [0, 1, 2],
  [4, 7, 6],
  [5, 6, 7],
];

// ══════════════════════════════════════════════════════════════════════════
//  GÖÇ BOID (HIZA DUYARLI DİNAMİK FİZİK VE ÇİFT YÖNLÜ)
// ══════════════════════════════════════════════════════════════════════════
class _MigBoid {
  final _V3 pos = _V3();
  final _V3 vel = _V3();
  final _V3 accel = _V3();

  int colonyId = 0;
  double yPhase = 0.0;
  double baseSpeed = 0.0;

  // -1 ise Sağdan Sola, 1 ise Soldan Sağa
  int direction = -1;

  // Çıkış sınırı yöne göre belirlenir
  bool get hasExited => direction == -1 ? pos.x < -2400 : pos.x > 2400;

  // RAM DOSTU: Her karede yeniden yaratılmamak üzere sabitlenmiş geçici vektörler
  static final _V3 _tAlign = _V3();
  static final _V3 _tCohereC = _V3();
  static final _V3 _tCohereD = _V3();
  static final _V3 _tSepS = _V3();
  static final _V3 _tSepR = _V3();

  void step(List<_MigBoid> allBoids, List<_MigBoid> myColony, double dtScale) {
    yPhase += 0.02 * dtScale;
    final yDrift = sin(yPhase) * MigrationConfig.physics.yDriftAmplitude;

    accel.set(0, yDrift, 0);

    // Hıza duyarlı sürü algoritması oranı
    final double speedRatio = (baseSpeed / 2.0).clamp(0.5, 2.5);
    final double dynamicSepDist =
        MigrationConfig.physics.separationDist * speedRatio;
    final double dynamicSepStr =
        MigrationConfig.physics.separationStrength * speedRatio;
    final double dynamicCohereStr =
        MigrationConfig.physics.cohereStrength / speedRatio;

    if (myColony.length > 1) {
      _align(myColony, _tAlign);
      accel.add(_tAlign);

      _cohere(myColony, _tCohereD, dynamicCohereStr);
      accel.add(_tCohereD);
    }

    _separate(allBoids, _tSepS, dynamicSepDist, dynamicSepStr);
    accel.add(_tSepS);

    accel.x = 0; // Hiçbir kuvvet X'e dokunamaz (İleri gidiş engellenemez)

    // Kameraya (ekrana) çok yaklaşmayı engelleyen Z sınırı
    const double minAllowedZ = -150.0;
    if (pos.z < minAllowedZ) {
      accel.z += (minAllowedZ - pos.z) * 0.005;
    }

    accel.scale(dtScale);
    vel.add(accel);

    final lateralSpeed = sqrt(vel.y * vel.y + vel.z * vel.z);
    const maxLateral = 0.9;
    if (lateralSpeed > maxLateral) {
      final ratio = maxLateral / lateralSpeed;
      vel.y *= ratio;
      vel.z *= ratio;
    }

    // Hız limitlerini uçuş yönüne göre sınırla
    if (direction == -1) {
      if (vel.x > -0.5) vel.x = -0.5; // Sağa dönmesini engelle
    } else {
      if (vel.x < 0.5) vel.x = 0.5; // Sola dönmesini engelle
    }

    pos.x += vel.x * dtScale;
    pos.y += vel.y * dtScale;
    pos.z += vel.z * dtScale;

    accel.set(0, 0, 0);
  }

  void _align(List<_MigBoid> colony, _V3 out) {
    out.set(0, 0, 0);
    int count = 0;
    for (final b in colony) {
      if (b == this) continue;
      out.add(b.vel);
      count++;
    }
    if (count > 0) {
      out.divSafe(count.toDouble());
      out.limit(MigrationConfig.physics.maxForce *
          MigrationConfig.physics.alignStrength /
          0.1);
    }
  }

  void _cohere(List<_MigBoid> colony, _V3 out, double dynamicStrength) {
    _tCohereC.set(0, 0, 0);
    int count = 0;
    for (final b in colony) {
      if (b == this) continue;
      _tCohereC.add(b.pos);
      count++;
    }
    if (count > 0) {
      _tCohereC.divSafe(count.toDouble());
      out.subOf(_tCohereC, pos);
      out.scale(dynamicStrength);
      out.limit(MigrationConfig.physics.maxForce);
    } else {
      out.set(0, 0, 0);
    }
  }

  void _separate(
      List<_MigBoid> all, _V3 out, double dynamicDist, double dynamicStrength) {
    out.set(0, 0, 0);
    final sepDistSq = dynamicDist * dynamicDist;

    for (final b in all) {
      if (b == this) continue;
      final dSq = pos.dstSq(b.pos);
      if (dSq > 0 && dSq < sepDistSq) {
        final d = sqrt(dSq);
        _tSepR.subOf(pos, b.pos);
        _tSepR.divSafe(d * d);
        out.add(_tSepR);
      }
    }
    out.scale(dynamicStrength);
    out.limit(MigrationConfig.physics.maxForce);
    out.x = 0;
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  GÖRSEL KUŞ
// ══════════════════════════════════════════════════════════════════════════
class _MigBirdVisual {
  final _V3 pos;
  final _V3 rot = _V3();
  double phase;
  double wingY = 0;
  double bankAngle = 0.0;
  Color baseColor;
  double opacity;

  _MigBirdVisual({
    required this.pos,
    required this.phase,
    required this.baseColor,
    this.opacity = 1.0,
  });

  void draw(Canvas canvas) {
    for (int fi = 0; fi < _mFaces.length; fi++) {
      final face = _mFaces[fi];
      final pts = face.map((vi) {
        final v = _mVerts[vi];
        return _V3(v[0], v[1], v[2]);
      }).toList();
      if (fi > 0) pts[0].y = wingY;
      for (final p in pts) {
        _rX(p, bankAngle);
        _rY(p, rot.y);
        _rZ(p, rot.z);
        p.x += pos.x;
        p.y += pos.y;
        p.z += pos.z;
      }
      final color = _shade(pts);
      final p1 = _proj(pts[0]);
      final p2 = _proj(pts[1]);
      final p3 = _proj(pts[2]);
      if (p1 == null || p2 == null || p3 == null) continue;
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity((color.opacity * opacity).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill,
      );
    }
  }

  Color _shade(List<_V3> pts) {
    final e1 = pts[1].clone()..sub(pts[0]);
    final e2 = pts[2].clone()..sub(pts[0]);
    final normal = _V3(
      e1.y * e2.z - e1.z * e2.y,
      e1.z * e2.x - e1.x * e2.z,
      e1.x * e2.y - e1.y * e2.x,
    );
    final nLen = normal.len;
    if (nLen > 0) normal.divSafe(nLen);
    final light = _V3(0.0, 1.0, 0.8)..normalize();
    final diffuse = normal.dot(light).abs().clamp(0.0, 1.0);
    return Color.fromARGB(
      255,
      (baseColor.red * (0.55 + 0.45 * diffuse)).toInt().clamp(0, 255),
      (baseColor.green * (0.55 + 0.45 * diffuse)).toInt().clamp(0, 255),
      (baseColor.blue * (0.55 + 0.45 * diffuse)).toInt().clamp(0, 255),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  KOLONİ
// ══════════════════════════════════════════════════════════════════════════
class _Colony {
  final int id;
  final double baseZ;
  final Color color;
  final List<_MigBoid> boids = [];
  final List<_MigBirdVisual> visuals = [];

  _Colony({required this.id, required this.baseZ, required this.color});

  bool get allExited => boids.isNotEmpty && boids.every((b) => b.hasExited);
}

// ══════════════════════════════════════════════════════════════════════════
//  WIDGET
// ══════════════════════════════════════════════════════════════════════════
class BirdMigrationOverlay extends StatefulWidget {
  const BirdMigrationOverlay({Key? key}) : super(key: key);

  @override
  BirdMigrationOverlayState createState() => BirdMigrationOverlayState();
}

class BirdMigrationOverlayState extends State<BirdMigrationOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Colony> _colonies = [];
  final Random _rng = Random();

  Duration? _lastElapsed;
  bool _active = false;

  int _wavesSpawned = 0;
  Timer? _waveTimer;
  int _globalColonyId = 0;

  // Bu tetiklemedeki genel yön. -1 (Sağdan Sola), 1 (Soldan Sağa)
  int _currentDirection = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    Degiskenler.birdMigrationTriggerNotifier.addListener(_onTrigger);
  }

  void _onTrigger() {
    if (!Degiskenler.birdMigrationTriggerNotifier.value) return;
    if (!mounted) return;

    _waveTimer?.cancel();
    _colonies.clear();
    _wavesSpawned = 0;
    _globalColonyId = 0;

    // Tetikleme anında yönü rastgele seç
    _currentDirection = _rng.nextBool() ? 1 : -1;

    _spawnNextWave();
  }

  void _spawnNextWave() {
    if (!mounted) return;
    setState(() {
      _active = true;
    });

    final theme = Degiskenler.currentThemeNotifier.value;
    final cfg = MigrationConfig.spawn;
    final phy = MigrationConfig.physics;
    final size = MediaQuery.of(context).size;

    final rightEdge = size.width / 2;

    // Yöne göre başlangıç (spawn) noktasını belirle.
    // Sağdan Sola ise ekranın sağından, Soldan Sağa ise solundan başlar.
    final spawnX = _currentDirection == 1
        ? -rightEdge - cfg.spawnXOffset
        : rightEdge + cfg.spawnXOffset;

    for (int ci = 0; ci < cfg.colonyCount; ci++) {
      final colonyZ =
          cfg.nearestZ + _rng.nextDouble() * (cfg.farthestZ - cfg.nearestZ);

      final t = ci / (cfg.colonyCount - 1).clamp(1, cfg.colonyCount - 1);
      final colonyColor =
          Color.lerp(theme.accentColor, theme.textColor, t * 0.6) ??
              theme.accentColor;

      final colony =
          _Colony(id: _globalColonyId++, baseZ: colonyZ, color: colonyColor);

      // Kolonilerin X dağılımını cfg.colonyXSpread ile kontrol et
      final colonyXOffset = spawnX +
          _rng.nextDouble() *
              cfg.colonyXSpread *
              (_currentDirection == 1 ? -1 : 1);

      final birdCount = cfg.minBirdsPerColony +
          _rng.nextInt(cfg.maxBirdsPerColony - cfg.minBirdsPerColony + 1);
      final spreadFactor = 0.5 + _rng.nextDouble() * 1.0;

      final randomColonyBaseSpeed = phy.minColonySpeed +
          _rng.nextDouble() * (phy.maxColonySpeed - phy.minColonySpeed);

      final zRatio = (colonyZ - cfg.nearestZ) / (cfg.farthestZ - cfg.nearestZ);
      final depthSpeedMult = 1.0 + (zRatio * 1.2);
      final finalColonySpeed = randomColonyBaseSpeed * depthSpeedMult;

      _spawnColonyBirds(colony, colonyXOffset, colonyZ, colonyColor, size,
          spreadFactor, finalColonySpeed, birdCount, _currentDirection);

      _colonies.add(colony);
    }

    _wavesSpawned++;

    if (_wavesSpawned < cfg.waveCount) {
      _waveTimer = Timer(cfg.waveDelay, _spawnNextWave);
    }
  }

  void _spawnColonyBirds(
    _Colony colony,
    double spawnX,
    double colonyZ,
    Color color,
    Size size,
    double spread,
    double colonySpeed,
    int birdCount,
    int direction,
  ) {
    final cfg = MigrationConfig.spawn;
    final phyCfg = MigrationConfig.physics;
    final yRange = size.height * phyCfg.verticalPadding;
    final centerY = (_rng.nextDouble() - 0.5) * yRange;
    final colonyVerticalDrift = (_rng.nextDouble() - 0.5) * 1.2;

    for (int i = 0; i < birdCount; i++) {
      final boid = _MigBoid()
        ..colonyId = colony.id
        ..direction = direction;

      double vx = 0, vy = 0, vz = 0;
      if (i == 0) {
        vx = spawnX;
        vy = centerY;
        vz = colonyZ;
      } else {
        final wing = (i + 1) ~/ 2;
        final side = (i % 2 == 0) ? 1.0 : -1.0;

        // V dizilimindeki arkadan gelen kuşları yöne göre liderin arkasına yerleştir.
        // cfg.wingXStep ile yatay boşluk kontrol edilir.
        final xOffsetMultiplier = direction == 1 ? -1.0 : 1.0;
        vx = spawnX +
            ((wing * cfg.wingXStep * spread) +
                    (_rng.nextDouble() * 14.0 * spread)) *
                xOffsetMultiplier;

        vy = centerY +
            (side * wing * 18.0 * spread) +
            (_rng.nextDouble() - 0.5) * 10.0;
        vz = colonyZ + (wing * 8.0 * spread) + (_rng.nextDouble() - 0.5) * 20.0;
      }

      boid.pos.set(vx, vy, vz);

      final speed =
          colonySpeed + (_rng.nextDouble() - 0.5) * phyCfg.speedJitter;
      boid.baseSpeed = speed;

      // Başlangıç hız vektörünü x ekseni üzerinde yöne doğru belirle
      boid.vel.set(
        speed * direction,
        colonyVerticalDrift + (_rng.nextDouble() - 0.5) * 0.4,
        (_rng.nextDouble() - 0.5) * 0.2,
      );
      boid.yPhase = _rng.nextDouble() * pi * 2;

      colony.boids.add(boid);

      final visual = _MigBirdVisual(
        pos: boid.pos,
        phase: _rng.nextDouble() * 62.8,
        baseColor:
            Color.lerp(color, Colors.white, _rng.nextDouble() * 0.15) ?? color,
      );
      colony.visuals.add(visual);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !_active || _colonies.isEmpty) return;

    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }

    final double dt = (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    double dtScale = dt * 120.0;
    if (dtScale > 3.0) dtScale = 3.0;

    final allBoids = _colonies.expand((c) => c.boids).toList(growable: false);
    bool anyActive = false;

    for (final colony in _colonies) {
      if (colony.allExited) continue;
      anyActive = true;

      for (int i = 0; i < colony.boids.length; i++) {
        final boid = colony.boids[i];

        boid.step(allBoids, colony.boids, dtScale);

        final visual = colony.visuals[i];
        final newRotY = atan2(-boid.vel.z, boid.vel.x);

        double yawDelta = newRotY - visual.rot.y;
        if (yawDelta > pi) yawDelta -= 2 * pi;
        if (yawDelta < -pi) yawDelta += 2 * pi;

        visual.bankAngle = (visual.bankAngle * 0.88 - yawDelta * 12.0 * 0.12)
            .clamp(-pi / 2.5, pi / 2.5);
        visual.rot.y = newRotY;

        final vLen = boid.vel.len;
        visual.rot.z =
            vLen > 0 ? asin((boid.vel.y / vLen).clamp(-1.0, 1.0)) : 0;

        visual.phase =
            (visual.phase + MigrationConfig.visual.wingFlapSpeed * dtScale) %
                62.8;
        visual.wingY =
            sin(visual.phase) * MigrationConfig.visual.wingFlapAmplitude;
      }
    }

    if (!anyActive && _wavesSpawned >= MigrationConfig.spawn.waveCount) {
      setState(() {
        _colonies.clear();
        _active = false;
        Degiskenler.birdMigrationTriggerNotifier.value = false;
      });
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _waveTimer?.cancel();
    Degiskenler.birdMigrationTriggerNotifier.removeListener(_onTrigger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active || _colonies.isEmpty) return const SizedBox.shrink();

    final allVisuals = _colonies.expand((c) {
      return Iterable.generate(c.boids.length, (i) {
        if (c.boids[i].hasExited) return null;
        return c.visuals[i];
      }).whereType<_MigBirdVisual>();
    }).toList();

    return CustomPaint(
      painter: _MigrationPainter(allVisuals),
      child: const SizedBox.expand(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  PAINTER
// ══════════════════════════════════════════════════════════════════════════
class _MigrationPainter extends CustomPainter {
  final List<_MigBirdVisual> visuals;
  _MigrationPainter(this.visuals);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    final sorted = List<_MigBirdVisual>.from(visuals)
      ..sort((a, b) => a.pos.z.compareTo(b.pos.z));

    for (final v in sorted) {
      v.draw(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
