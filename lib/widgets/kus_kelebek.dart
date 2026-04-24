import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  KELEBEK DURUMLARI
// ═══════════════════════════════════════════════════════════════════════════
enum ButterflyState { flying, gliding }

// ═══════════════════════════════════════════════════════════════════════════
//  KELEBEK AYARLARI
// ═══════════════════════════════════════════════════════════════════════════

class _SpawnConfig {
  const _SpawnConfig();
  final int triggerCount = 20;
  final int maxLimit = 60;
  final int initialCount = 0;
  final int waitSec = 10;
  final int removalIntervalSec = 1;
}

class _PhysicsConfig {
  const _PhysicsConfig();
  // Daha derin ve geniş kavisler için hız ve manevra artırıldı
  final double maxSpeed = 3.0;
  final double maxForce = 0.25;
  final double separationDist = 120.0;
  final double areaRadius = 800.0;
  final double boundaryForce = 4.0;
  final double repelRadius = 150.0;
  final double repelStrength = 3.0;
  final double focalLength = 1000.0;
}

class _VisualConfig {
  const _VisualConfig();
  final double wingFlapSpeed = 0.35;
  final double wingFlapAmplitude = 8.5;
}

class ButterflyConfig {
  static const spawn = _SpawnConfig();
  static const physics = _PhysicsConfig();
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

  void subOf(Vec3 a, Vec3 b) {
    x = a.x - b.x;
    y = a.y - b.y;
    z = a.z - b.z;
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
  double dst(Vec3 v) => sqrt(dsq(v));
  double dsq(Vec3 v) {
    final dx = x - v.x, dy = y - v.y, dz = z - v.z;
    return dx * dx + dy * dy + dz * dz;
  }

  double dot(Vec3 v) => x * v.x + y * v.y + z * v.z;
  void normalize() => divScale(len);
}

// ── DÖNÜŞ VE PROJEKSİYON ───────────────────────────────────────────────────
void _rotX(Vec3 p, double a) {
  final s = sin(a), c = cos(a);
  final ny = p.y * c - p.z * s;
  final nz = p.y * s + p.z * c;
  p.y = ny;
  p.z = nz;
}

void _rotY(Vec3 p, double a) {
  final s = sin(a), c = cos(a);
  final nx = p.x * c - p.z * s;
  final nz = p.x * s + p.z * c;
  p.x = nx;
  p.z = nz;
}

void _rotZ(Vec3 p, double a) {
  final s = sin(a), c = cos(a);
  final nx = p.x * c - p.y * s;
  final ny = p.x * s + p.y * c;
  p.x = nx;
  p.y = ny;
}

Offset _project(Vec3 p) {
  final fl = ButterflyConfig.physics.focalLength;
  final zsc = fl + p.z;
  if (zsc <= 0) return Offset.zero;
  final scale = fl / zsc;
  return Offset(p.x * scale, -p.y * scale);
}

// ── 3D KELEBEK GEOMETRİSİ ──────────────────────────────────────────────────
const _verts = [
  [4.0, 0.0, 0.0], // 0: Gövde Ön (Baş)
  [-4.0, 0.0, 0.0], // 1: Gövde Arka (Kuyruk)
  [0.0, 0.0, -8.0], // 2: Sol Kanat Üst Dış
  [-3.0, 0.0, -5.0], // 3: Sol Kanat Alt Dış
  [0.0, 0.0, 8.0], // 4: Sağ Kanat Üst Dış
  [-3.0, 0.0, 5.0], // 5: Sağ Kanat Alt Dış
];
const _faces = [
  [0, 2, 1],
  [1, 2, 3],
  [0, 1, 4],
  [1, 5, 4]
];

// ── 3D KELEBEK UÇUŞ FİZİĞİ ──────────────────────────────────────────────
class ButterflyBoid {
  final Vec3 pos = Vec3();
  final Vec3 vel = Vec3();
  final Vec3 accel = Vec3();
  final _rng = Random();

  ButterflyState state = ButterflyState.flying;
  int stateTimer = 0;

  double w = 400, h = 400;
  double get d => ButterflyConfig.physics.areaRadius;

  void run(List<ButterflyBoid> flock, Size screenSize) {
    w = screenSize.width / 2;
    h = screenSize.height / 2;

    _updateState();
    _boundary();

    if (state == ButterflyState.flying) {
      if (_rng.nextDouble() > 0.3) {
        accel.add(_separate(flock));
      }
      // DAHA DERİN HAREKET: Y ve Z eksenindeki itiş güçleri ciddi oranda artırıldı
      accel.add(Vec3(
        (_rng.nextDouble() - 0.5) * 0.4, // X (Sağ-sol salınım)
        (_rng.nextDouble() - 0.5) *
            1.3, // Y (Derin dalışlar ve keskin tırmanışlar)
        (_rng.nextDouble() - 0.5) *
            0.8, // Z (Derinlik - kameraya hızlı yaklaşıp uzaklaşma)
      ));
      _move();
    } else if (state == ButterflyState.gliding) {
      accel.add(Vec3(0, 0.04, 0)); // Süzülürken yerçekimi etkisi
      _move();
    }
  }

  void _updateState() {
    if (stateTimer > 0) {
      stateTimer--;
    } else {
      double rand = _rng.nextDouble();

      if (state == ButterflyState.flying) {
        // %25 ihtimalle süzülmeye geçer
        if (rand < 0.25) {
          state = ButterflyState.gliding;
          stateTimer = 40 + _rng.nextInt(80);
        } else {
          stateTimer = 60; // Uçmaya devam
        }
      } else {
        // Süzülme bittiğinde güçlü bir kanat çırpışıyla (yukarı ivmeyle) uçuşa geçer
        state = ButterflyState.flying;
        stateTimer = 80 + _rng.nextInt(120);
      }
    }
  }

  void repelFrom(Vec3 pt) {
    final dist = pos.dst(pt);
    if (dist < ButterflyConfig.physics.repelRadius) {
      final dir = pos.clone()
        ..sub(pt)
        ..scale(ButterflyConfig.physics.repelStrength / (dist + 0.01));
      accel.add(dir);
    }
  }

  void _boundary() {
    void check(Vec3 pt) {
      final dsq = pos.dsq(pt);
      if (dsq > 0) {
        final dir = pos.clone()
          ..sub(pt)
          ..divScale(dsq)
          ..scale(ButterflyConfig.physics.boundaryForce);
        accel.add(dir);
      }
    }

    check(Vec3(-w, pos.y, pos.z));
    check(Vec3(w, pos.y, pos.z));
    check(Vec3(pos.x, -h, pos.z));
    check(Vec3(pos.x, h, pos.z));
    check(Vec3(pos.x, pos.y, -d));
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

  Vec3 _separate(List<ButterflyBoid> flock) {
    final sum = Vec3();
    for (final b in flock) {
      final dist = b.pos.dst(pos);
      if (dist > 0 && dist <= ButterflyConfig.physics.separationDist) {
        final rep = Vec3()
          ..subOf(pos, b.pos)
          ..normalize()
          ..divScale(dist);
        sum.add(rep);
      }
    }
    return sum;
  }
}

// ── GÖRSEL KELEBEK ─────────────────────────────────────────────────────────
class ButterflyVisual {
  final Vec3 pos;
  final Vec3 rot = Vec3();
  double phase;
  double wingY = 0;
  Color baseColor;

  ButterflyVisual(
      {required this.pos, required this.phase, required this.baseColor});

  void draw(Canvas canvas) {
    for (int fi = 0; fi < _faces.length; fi++) {
      final face = _faces[fi];
      final pts = face.map((vi) {
        final v = _verts[vi];
        final p = Vec3(v[0], v[1], v[2]);

        if (vi >= 2) {
          p.y += wingY;
        }
        return p;
      }).toList();

      for (final p in pts) {
        _rotX(p, rot.x);
        _rotZ(p, rot.z);
        _rotY(p, rot.y);

        p.x += pos.x;
        p.y += pos.y;
        p.z += pos.z;
      }

      final color = _shade(pts);
      final p1 = _project(pts[0]);
      final p2 = _project(pts[1]);
      final p3 = _project(pts[2]);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  Color _shade(List<Vec3> pts) {
    final e1 = pts[1].clone()..sub(pts[0]);
    final e2 = pts[2].clone()..sub(pts[0]);
    final normal = Vec3(
      e1.y * e2.z - e1.z * e2.y,
      e1.z * e2.x - e1.x * e2.z,
      e1.x * e2.y - e1.y * e2.x,
    );
    final nLen = normal.len;
    if (nLen > 0) normal.divScale(nLen);

    final light = Vec3(0, 1, 0.8)..normalize();
    final diffuse = normal.dot(light).abs().clamp(0.0, 1.0);

    return Color.fromARGB(
      255,
      (baseColor.red * (0.5 + 0.5 * diffuse)).toInt().clamp(0, 255),
      (baseColor.green * (0.5 + 0.5 * diffuse)).toInt().clamp(0, 255),
      (baseColor.blue * (0.5 + 0.5 * diffuse)).toInt().clamp(0, 255),
    );
  }
}

// ── WIDGET ────────────────────────────────────────────────────────────────
class FlightOverlay extends StatefulWidget {
  const FlightOverlay({Key? key}) : super(key: key);

  @override
  FlightOverlayState createState() => FlightOverlayState();
}

class FlightOverlayState extends State<FlightOverlay>
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
    Degiskenler.birdTriggerNotifier.addListener(_onTrigger);
    if (ButterflyConfig.spawn.initialCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => spawns(count: ButterflyConfig.spawn.initialCount),
      );
    }
  }

  void _onTrigger() {
    if (Degiskenler.birdTriggerNotifier.value) {
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
                  Degiskenler.birdTriggerNotifier.value = false;
                }
              } else {
                timer.cancel();
              }
            },
          );
        },
      );
    }
  }

  void spawns({int count = 12, Offset? position}) {
    if (!mounted) return;
    final theme = Degiskenler.currentThemeNotifier.value;
    for (int i = 0; i < count; i++) {
      final boid = ButterflyBoid();
      boid.pos.set(
        _rng.nextDouble() * 400 - 200,
        _rng.nextDouble() * 400 - 200,
        // Z ekseninde daha geniş bir alanda doğarak derinliği hissettirsinler
        _rng.nextDouble() * 800 - 400,
      );
      boid.vel.set(
        _rng.nextDouble() * 4 - 2,
        _rng.nextDouble() * 4 - 2,
        _rng.nextDouble() * 4 - 2,
      );
      _boids.add(boid);

      _visuals.add(ButterflyVisual(
        pos: boid.pos,
        phase: _rng.nextDouble() * 62.8,
        baseColor: Color.lerp(theme.accentColor,
                Colors.primaries[_rng.nextInt(Colors.primaries.length)], 0.4) ??
            theme.accentColor,
      ));
    }

    if (_boids.length > ButterflyConfig.spawn.maxLimit) {
      final range = _boids.length - ButterflyConfig.spawn.maxLimit;
      _boids.removeRange(0, range);
      _visuals.removeRange(0, range);
    }
    setState(() {});
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;

    for (int i = 0; i < _boids.length; i++) {
      final boid = _boids[i];
      boid.run(_boids, size);
      final visual = _visuals[i];

      // Uçuş sırasındaki sabit eğim (Kanatları görebilmek için)
      visual.rot.x += (0.5 - visual.rot.x) * 0.1;

      visual.rot.y = atan2(-boid.vel.z, boid.vel.x);

      final vLen = boid.vel.len;
      final targetRotZ = vLen > 0 ? asin((boid.vel.y / vLen).clamp(-1, 1)) : 0;

      // DERİN HAREKET: Tırmanış/dalış sırasındaki gövde yatış çarpanı (0.4'ten 0.6'ya) çıkarıldı
      visual.rot.z += ((targetRotZ * 0.6) - visual.rot.z) * 0.15;

      if (boid.state == ButterflyState.gliding) {
        // Süzülürken kanatları V şeklinde yukarıda tut
        final targetWingY = ButterflyConfig.visual.wingFlapAmplitude * 0.8;
        visual.wingY += (targetWingY - visual.wingY) * 0.15;
      } else {
        // Normal Uçuş (Çırpınma)
        visual.phase =
            (visual.phase + ButterflyConfig.visual.wingFlapSpeed) % 62.8;
        visual.wingY =
            sin(visual.phase) * ButterflyConfig.visual.wingFlapAmplitude;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _deactiveTimer?.cancel();
    _removalTimer?.cancel();
    Degiskenler.birdTriggerNotifier.removeListener(_onTrigger);
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

// ── PAINTER ───────────────────────────────────────────────────────────────
class _ButterflyFlockPainter extends CustomPainter {
  final List<ButterflyVisual> visuals;
  _ButterflyFlockPainter(this.visuals);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final sorted = List<ButterflyVisual>.from(visuals)
      ..sort((a, b) => a.pos.z.compareTo(b.pos.z));
    for (final v in sorted) {
      v.draw(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
