import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  GÖÇ ANIMASYONU AYARLARI
// ═══════════════════════════════════════════════════════════════════════════

/// Tetikleme ve spawn ayarları
class _MigSpawnConfig {
  const _MigSpawnConfig();

  /// Toplam dalga sayısı (arka arkaya kaç kez kuş grubu gelecek)
  final int waveCount = 5;

  /// Dalgalar arası bekleme süresi
  final Duration waveDelay = const Duration(milliseconds: 7000);

  /// Her tetiklemede/dalgada oluşturulacak koloni sayısı
  final int colonyCount = 7;

  /// Bir kolonideki minimum kuş sayısı
  final int minBirdsPerColony = 1;

  /// Bir kolonideki maksimum kuş sayısı
  final int maxBirdsPerColony = 13;

  /// En yakın koloninin z değeri (Kameraya en yakın mesafe)
  final double nearestZ = -200.0;

  /// En uzak koloninin z değeri (Ufuk çizgisine en yakın mesafe)
  final double farthestZ = 1200.0;

  /// Spawn noktasının ekranın sağ kenarından ne kadar dışarıda olacağı (piksel)
  final double spawnXOffset = 320.0;
}

/// Göç fiziği
class _MigPhysicsConfig {
  const _MigPhysicsConfig();

  /// Kolonilerin kendi seçeceği MİNİMUM hız
  final double minColonySpeed = 1.5;

  /// Kolonilerin kendi seçeceği MAKSİMUM hız (Senin sevdiğin 2.9 limiti buraya taşındı, yakındakiler bunu asla geçemez)
  final double maxColonySpeed = 2.3;

  /// Hız rastgele sapma miktarı (Kuşların koloni içindeki bireysel hız farkı ±)
  final double speedJitter = 0.6;

  /// Koloni içi hizalanma kuvveti
  final double alignStrength = 0.07;

  /// Koloniden ayrılmama kuvveti (hafif toplanma)
  final double cohereStrength = 0.03;

  /// Birbirinden uzaklaşma mesafesi
  final double separationDist = 35.0;

  /// Birbirinden uzaklaşma kuvveti
  final double separationStrength = 0.12;

  /// Y ekseni hafif titreşim genliği (doğal dalga hareketi)
  final double yDriftAmplitude = 0.04;

  /// YENİ: Fizik motorunun tavan hızı (Uzaktaki kuşların perspektifi telafi edebilmesi için geniş tutuldu)
  final double maxSpeed = 4.0;

  /// Maksimum kuvvet
  final double maxForce = 0.10;

  /// Projeksiyon odak uzaklığı
  final double focalLength = 600.0;

  /// Ekranın üst/alt sınırından geçiş tamponu (tüm ekranı kullanırlar)
  final double verticalPadding = 0.97;
}

/// Görsel ayarlar
class _MigVisualConfig {
  const _MigVisualConfig();

  /// Kanat çırpma hızı
  final double wingFlapSpeed = 0.18;

  /// Kanat genliği
  final double wingFlapAmplitude = 5.5;
}

class MigrationConfig {
  static const spawn = _MigSpawnConfig();
  static const physics = _MigPhysicsConfig();
  static const visual = _MigVisualConfig();
}

// ═══════════════════════════════════════════════════════════════════════════
//  TEKİL TETIKLEYICI
// ═══════════════════════════════════════════════════════════════════════════

// ── 3D VEKTÖR ─────────────────────────────────────────────────────────────
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

// ── KUŞ GEOMETRİSİ ─────────────────────────────────────
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
//  GÖÇ BOID
// ══════════════════════════════════════════════════════════════════════════
class _MigBoid {
  final _V3 pos = _V3();
  final _V3 vel = _V3();
  final _V3 accel = _V3();

  int colonyId = 0;
  double yPhase = 0.0;

  // YENİ: Her kuşun hatırlayacağı orijinal "Göç İçgüdüsü" hızı
  double baseSpeed = 0.0;

  bool get exitedLeft => pos.x < -2400;

  void step(List<_MigBoid> allBoids, List<_MigBoid> myColony, double dtScale) {
    yPhase += 0.02 * dtScale;
    final yDrift = sin(yPhase) * MigrationConfig.physics.yDriftAmplitude;
    accel.add(_V3(0, yDrift, 0));

    if (myColony.length > 1) {
      accel.add(_align(myColony));
      accel.add(_cohere(myColony));
    }
    accel.add(_separate(allBoids));

    accel.x = 0; // ← Hiçbir kuvvet X'e dokunamaz

    accel.scale(dtScale);
    vel.add(accel);

    // X'i limitsiz bırak, sadece Y/Z'yi sınırla
    final lateralSpeed = sqrt(vel.y * vel.y + vel.z * vel.z);
    const maxLateral = 0.9;   
    if (lateralSpeed > maxLateral) {
      final ratio = maxLateral / lateralSpeed;
      vel.y *= ratio;
      vel.z *= ratio;
    }

    if (vel.x > -0.5) vel.x = -0.5;

    final scaledVel = vel.clone()..scale(dtScale);
    pos.add(scaledVel);
    accel.set(0, 0, 0);
  }

  _V3 _align(List<_MigBoid> colony) {
    final sum = _V3();
    int count = 0;
    for (final b in colony) {
      if (b == this) continue;
      sum.add(b.vel);
      count++;
    }
    if (count > 0) {
      sum.divSafe(count.toDouble());
      sum.limit(MigrationConfig.physics.maxForce *
          MigrationConfig.physics.alignStrength /
          0.1);
    }
    return sum;
  }

  _V3 _cohere(List<_MigBoid> colony) {
    final center = _V3();
    int count = 0;
    for (final b in colony) {
      if (b == this) continue;
      center.add(b.pos);
      count++;
    }
    if (count > 0) {
      center.divSafe(count.toDouble());
      final dir = _V3()..subOf(center, pos);
      dir.scale(MigrationConfig.physics.cohereStrength);
      dir.limit(MigrationConfig.physics.maxForce);
      return dir;
    }
    return _V3();
  }

  _V3 _separate(List<_MigBoid> all) {
    final sum = _V3();
    final sepDistSq = MigrationConfig.physics.separationDist *
        MigrationConfig.physics.separationDist;

    for (final b in all) {
      if (b == this) continue;

      final dSq = pos.dstSq(b.pos);
      if (dSq > 0 && dSq < sepDistSq) {
        final d = sqrt(dSq);
        final rep = _V3()
          ..subOf(pos, b.pos)
          ..divSafe(d * d);
        sum.add(rep);
      }
    }
    sum.scale(MigrationConfig.physics.separationStrength);
    sum.limit(MigrationConfig.physics.maxForce);
    sum.x = 0; // ← BUNU EKLE: x momentumuna dokunma, sadece y/z'yi düzenle
    return sum;
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

  bool get allExited => boids.isNotEmpty && boids.every((b) => b.exitedLeft);
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
    final spawnX = rightEdge + cfg.spawnXOffset;

    for (int ci = 0; ci < cfg.colonyCount; ci++) {
      final colonyZ =
          cfg.nearestZ + _rng.nextDouble() * (cfg.farthestZ - cfg.nearestZ);

      final t = ci / (cfg.colonyCount - 1).clamp(1, cfg.colonyCount - 1);
      final colonyColor =
          Color.lerp(theme.accentColor, theme.textColor, t * 0.6) ??
              theme.accentColor;

      final colony =
          _Colony(id: _globalColonyId++, baseZ: colonyZ, color: colonyColor);
      final colonyXOffset = spawnX + _rng.nextDouble() * 1000.0;
      final birdCount = cfg.minBirdsPerColony +
          _rng.nextInt(cfg.maxBirdsPerColony - cfg.minBirdsPerColony + 1);
      final spreadFactor = 0.5 + _rng.nextDouble() * 1.0;

      final randomColonyBaseSpeed = phy.minColonySpeed +
          _rng.nextDouble() * (phy.maxColonySpeed - phy.minColonySpeed);

      // YENİ: Uzaktaki kuşlar perspektiften dolayı çok yavaş görünecekleri için, dünya hızlarını
      // orantılı olarak artırıyoruz ki ekranda yakındakilerle aynı hissiyatı versinler.
      final zRatio = (colonyZ - cfg.nearestZ) / (cfg.farthestZ - cfg.nearestZ);
      final depthSpeedMult = 1.0 + (zRatio * 1.2);

      final finalColonySpeed = randomColonyBaseSpeed * depthSpeedMult;

      _spawnColonyBirds(colony, colonyXOffset, colonyZ, colonyColor, size,
          spreadFactor, finalColonySpeed, birdCount);

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
  ) {
    final phyCfg = MigrationConfig.physics;

    final yRange = size.height * phyCfg.verticalPadding;
    final centerY = (_rng.nextDouble() - 0.5) * yRange;

    final colonyVerticalDrift = (_rng.nextDouble() - 0.5) * 1.2;

    for (int i = 0; i < birdCount; i++) {
      final boid = _MigBoid()..colonyId = colony.id;

      double vx = 0, vy = 0, vz = 0;
      if (i == 0) {
        vx = spawnX;
        vy = centerY;
        vz = colonyZ;
      } else {
        final wing = (i + 1) ~/ 2;
        final side = (i % 2 == 0) ? 1.0 : -1.0;

        vx = spawnX +
            (wing * 22.0 * spread) +
            (_rng.nextDouble() * 14.0 * spread);
        vy = centerY +
            (side * wing * 18.0 * spread) +
            (_rng.nextDouble() - 0.5) * 10.0;
        vz = colonyZ + (wing * 8.0 * spread) + (_rng.nextDouble() - 0.5) * 20.0;
      }

      boid.pos.set(vx, vy, vz);

      final speed =
          colonySpeed + (_rng.nextDouble() - 0.5) * phyCfg.speedJitter;

      // Kuş kendi atanmış hedef hızını hafızasına kazıyor
      boid.baseSpeed = speed;

      boid.vel.set(
        -speed,
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

        // Hız sabitleyici sayesinde artık "boid.exitedLeft" iptaline gerek kalmadı.
        // Motor arkada çalışmaya devam etse de cruise control kuşları çekecek.

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
        // PERFORMANS KORUMASI: Fizik hesaplansa bile ekrandan çıkanları ekrana çizmeye (render) çalışmıyoruz.
        if (c.boids[i].exitedLeft) return null;
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
