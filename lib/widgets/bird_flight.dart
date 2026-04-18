import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  KUŞ AYARLARI (BURADAN DEĞİŞTİREBİLİRSİN)
// ═══════════════════════════════════════════════════════════════════════════
class BirdConfig {
  // Adetler
  static const int triggerBirdCount =
      30; // Beğeni yapıldığında çıkacak kuş sayısı
  static const int maxBirdLimit = 80; // Ekrandaki maksimum kuş sınırı
  static const int initialBirds =
      0; // Uygulama açılışında olsun mu? (7-8 gibi bir değer verilebilir)

  // Süreler
  static const int waitDurationSec =
      10; // Kaç saniye sonra kaybolmaya başlasınlar?
  static const int removalIntervalSec =
      1; // Kaç saniyede bir, bir kuş silinsin?

  // Fizik Ayarları
  static const double maxSpeed =
      3.5; // Kuşların uçuş hızı (Örn: 2.0 daha yavaş, 5.0 daha hızlı)
  static const double maxForce = 0.08; // Manevra kabiliyeti (Dönüş yumuşaklığı)
  static const double neighborDist =
      200.0; // Kuşların birbirini algılama mesafesi
  static const double areaRadius =
      700.0; // Görünürlük derinliği (Perspective depth)

  // Görsel
  static const double wingsFlapSpeed = 0.2; // Kanat çırpma hızı
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
  const fl = 1000.0;
  final zsc = fl + p.z;
  if (zsc <= 0) return Offset.zero;
  final scale = fl / zsc;
  return Offset(p.x * scale, -p.y * scale);
}

// ── 3D KUŞ GEOMETRİSİ ──────────────────────────────────────────────────────
const _verts = [
  [6.0, 0.0, 0.0],
  [-6.0, -2.0, 1.0],
  [-6.0, 0.0, 0.0],
  [-6.0, -2.0, -1.0],
  [0.0, 2.0, -7.0],
  [0.0, 2.0, 7.0],
  [2.0, 0.0, 0.0],
  [-4.0, 0.0, 0.0],
];
const _faces = [
  [0, 1, 2],
  [4, 7, 6],
  [5, 6, 7]
];

// ── 3D BOID ───────────────────────────────────────────────────────────────
class Boid {
  final Vec3 pos = Vec3();
  final Vec3 vel = Vec3();
  final Vec3 accel = Vec3();
  final _rng = Random();

  double w = 400, h = 400, d = BirdConfig.areaRadius;

  void run(List<Boid> flock, Size screenSize) {
    w = screenSize.width / 2;
    h = screenSize.height / 2;
    _boundary();
    if (_rng.nextDouble() > 0.5) {
      accel.add(_align(flock));
      accel.add(_cohere(flock));
      accel.add(_separate(flock));
    }
    _move();
  }

  void repelFrom(Vec3 pt) {
    final dist = pos.dst(pt);
    if (dist < 180) {
      final dir = pos.clone()
        ..sub(pt)
        ..scale(2.5 / (dist + 0.01));
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
          ..scale(5);
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
    if (l > BirdConfig.maxSpeed) vel.divScale(l / BirdConfig.maxSpeed);
    pos.add(vel);
    accel.set(0, 0, 0);
  }

  Vec3 _align(List<Boid> flock) {
    final sum = Vec3();
    int cnt = 0;
    for (final b in flock) {
      double dist = b.pos.dst(pos);
      if (dist > 0 && dist <= BirdConfig.neighborDist) {
        sum.add(b.vel);
        cnt++;
      }
    }
    if (cnt > 0) {
      sum.divScale(cnt.toDouble());
      final v = sum.len;
      if (v > BirdConfig.maxForce) sum.divScale(v / BirdConfig.maxForce);
    }
    return sum;
  }

  Vec3 _cohere(List<Boid> flock) {
    final center = Vec3();
    int cnt = 0;
    for (final b in flock) {
      double dist = b.pos.dst(pos);
      if (dist > 0 && dist <= BirdConfig.neighborDist) {
        center.add(b.pos);
        cnt++;
      }
    }
    if (cnt > 0) {
      center.divScale(cnt.toDouble());
      final dir = Vec3()..subOf(center, pos);
      final l = dir.len;
      if (l > BirdConfig.maxForce) dir.divScale(l / BirdConfig.maxForce);
      return dir;
    }
    return Vec3();
  }

  Vec3 _separate(List<Boid> flock) {
    final sum = Vec3();
    for (final b in flock) {
      double dist = b.pos.dst(pos);
      if (dist > 0 && dist <= 60) {
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

class BirdVisual {
  final Vec3 pos;
  final Vec3 rot = Vec3();
  double phase;
  double wingY = 0;
  Color baseColor;

  BirdVisual({required this.pos, required this.phase, required this.baseColor});

  void draw(Canvas canvas) {
    for (int fi = 0; fi < _faces.length; fi++) {
      final face = _faces[fi];
      final pts = face.map((vi) {
        final v = _verts[vi];
        return Vec3(v[0], v[1], v[2]);
      }).toList();
      if (fi > 0) pts[0].y = wingY;
      for (final p in pts) {
        _rotY(p, rot.y);
        _rotZ(p, rot.z);
        p.x += pos.x;
        p.y += pos.y;
        p.z += pos.z;
      }
      final color = _shade(pts, fi);
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
            ..style = PaintingStyle.fill);
    }
  }

  Color _shade(List<Vec3> pts, int faceIndex) {
    final e1 = pts[1].clone()..sub(pts[0]);
    final e2 = pts[2].clone()..sub(pts[0]);
    final normal = Vec3(e1.y * e2.z - e1.z * e2.y, e1.z * e2.x - e1.x * e2.z,
        e1.x * e2.y - e1.y * e2.x);
    final nLen = normal.len;
    if (nLen > 0) normal.divScale(nLen);
    final light = Vec3(0, 1, 0.8)..normalize();
    final diffuse = normal.dot(light).abs().clamp(0.0, 1.0);
    return Color.fromARGB(
        255,
        (baseColor.red * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255),
        (baseColor.green * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255),
        (baseColor.blue * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255));
  }
}

class BirdFlightOverlay extends StatefulWidget {
  const BirdFlightOverlay({Key? key}) : super(key: key);
  @override
  BirdFlightOverlayState createState() => BirdFlightOverlayState();
}

class BirdFlightOverlayState extends State<BirdFlightOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<Boid> _boids = [];
  final List<BirdVisual> _visuals = [];
  final Random _rng = Random();
  Offset? _predatorPos;
  Timer? _deactiveTimer;
  Timer? _removalTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    Degiskenler.birdTriggerNotifier.addListener(_onBirdTrigger);
    if (BirdConfig.initialBirds > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => spawnBirds(count: BirdConfig.initialBirds));
    }
  }

  void _onBirdTrigger() {
    if (Degiskenler.birdTriggerNotifier.value) {
      _deactiveTimer?.cancel();
      _removalTimer?.cancel();
      setState(() {
        _boids.clear();
        _visuals.clear();
      });
      spawnBirds(count: BirdConfig.triggerBirdCount);
      _deactiveTimer =
          Timer(const Duration(seconds: BirdConfig.waitDurationSec), () {
        if (!mounted) return;
        _removalTimer = Timer.periodic(
            const Duration(seconds: BirdConfig.removalIntervalSec), (timer) {
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
        });
      });
    }
  }

  void spawnBirds({int count = 12, Offset? position}) {
    if (!mounted) return;
    final theme = Degiskenler.currentThemeNotifier.value;
    for (int i = 0; i < count; i++) {
      final boid = Boid();
      boid.pos.set(_rng.nextDouble() * 200 - 100, _rng.nextDouble() * 200 - 100,
          _rng.nextDouble() * 400 - 200);
      boid.vel.set(_rng.nextDouble() * 4 - 2, _rng.nextDouble() * 4 - 2,
          _rng.nextDouble() * 4 - 2);
      _boids.add(boid);
      _visuals.add(BirdVisual(
          pos: boid.pos,
          phase: _rng.nextDouble() * 62.8,
          baseColor: Color.lerp(
                  theme.accentColor, theme.textColor, _rng.nextDouble()) ??
              theme.accentColor));
    }
    if (_boids.length > BirdConfig.maxBirdLimit) {
      final range = _boids.length - BirdConfig.maxBirdLimit;
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
      visual.rot.y = atan2(-boid.vel.z, boid.vel.x);
      final vLen = boid.vel.len;
      visual.rot.z = vLen > 0 ? asin((boid.vel.y / vLen).clamp(-1, 1)) : 0;
      visual.phase = (visual.phase + BirdConfig.wingsFlapSpeed) % 62.8;
      visual.wingY = sin(visual.phase) * 5;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _deactiveTimer?.cancel();
    _removalTimer?.cancel();
    Degiskenler.birdTriggerNotifier.removeListener(_onBirdTrigger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _BirdFlockPainter(_visuals), child: const SizedBox.expand());
  }
}

class _BirdFlockPainter extends CustomPainter {
  final List<BirdVisual> visuals;
  _BirdFlockPainter(this.visuals);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final sorted = List<BirdVisual>.from(visuals)
      ..sort((a, b) => a.pos.z.compareTo(b.pos.z));
    for (final v in sorted) {
      v.draw(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
