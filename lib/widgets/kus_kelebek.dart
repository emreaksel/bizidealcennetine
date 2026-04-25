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
//  Tüm sihirli sayılar buradadır. Kod içinde sabit numara bulunmaz.
// ═══════════════════════════════════════════════════════════════════════════

class _SpawnConfig {
  const _SpawnConfig();

  /// Tetiklenince kaç kelebek doğar
  final int triggerCount = 20;

  /// Ekranda aynı anda bulunabilecek maksimum kelebek
  final int maxLimit = 60;

  /// Uygulama açılışında doğan kelebek sayısı (0 = kapalı)
  final int initialCount = 0;

  /// Tetiklenmeden kaç saniye sonra kelebekler silinmeye başlar
  final int waitSec = 10;

  /// Her kaç saniyede bir kelebek silinir (azalma hızı)
  final int removalIntervalSec = 1;

  /// Kelebeklerin doğduğu X ve Y ekseninde yayılım yarıçapı (piksel)
  final double spawnXY = 200.0;

  /// Doğuş Z aralığı min değeri (negatif = kameraya yakın)
  final double spawnZMin = -150.0;

  /// Doğuş Z aralığı max değeri (pozitif = kameradan uzak)
  final double spawnZMax = 700.0;

  /// Doğuşta verilen rastgele başlangıç hız aralığı (± bu değer)
  final double spawnVelocity = 2.0;
}

class _PhysicsConfig {
  const _PhysicsConfig();

  /// Maksimum uçuş hızı (birim/kare); aşılınca normalize edilir
  final double maxSpeed = 3.0;

  /// Steering hesaplamalarında kullanılmak üzere ayrılmış maksimum kuvvet
  final double maxForce = 0.25;

  /// Bu mesafenin altındaki komşulardan uzaklaşılır (sürü ayrışması)
  final double separationDist = 120.0;

  /// Kelebeklerin dolaştığı alanın Z ekseni yarıçapı (ön-arka sınır)
  final double areaRadius = 800.0;

  /// Sınıra yaklaştıkça uygulanan geri itme kuvveti çarpanı
  final double boundaryForce = 4.0;

  /// Fare/dokunma noktasından kaçma başlama mesafesi
  final double repelRadius = 150.0;

  /// Fare/dokunma kaçma kuvveti çarpanı
  final double repelStrength = 3.0;

  /// Perspektif odak uzunluğu: küçüldükçe dramatik derinlik farkı artar.
  /// Önerilen aralık: 300–600. 1000+ neredeyse izometrik görünür.
  final double focalLength = 450.0;

  /// Near-clip eşiği: (focalLength + boid.z) bu değerin altına düşerse
  /// kelebek çizilmez. Ağ/çizgi artefaktını önler. focalLength'in ~%40'ı ideal.
  final double nearClip = 200.0;

  /// Uçuş türbülansı — X ekseni (sağ-sol salınım genliği)
  final double turbulenceX = 0.4;

  /// Uçuş türbülansı — Y ekseni (yukarı-aşağı dalışlar; yüksek = derin kavisler)
  final double turbulenceY = 1.3;

  /// Uçuş türbülansı — Z ekseni (kameraya yaklaşıp uzaklaşma genliği)
  final double turbulenceZ = 0.8;

  /// Her karede ayrışma kuvvetinin uygulanma olasılığı (0–1)
  final double separationChance = 0.7;

  /// Süzülürken kelebeği yavaşça aşağı çeken yerçekimi ivmesi
  final double glideGravity = 0.04;
}

class _BehaviorConfig {
  const _BehaviorConfig();

  /// Uçuş sona erince süzülmeye geçme olasılığı (0–1).
  /// 0.60 → her iki uçuştan biri süzülmeyle biter.
  final double glideProbability = 0.60;

  /// Süzülme minimum süresi (kare; 60 kare ≈ 1 saniye)
  final int glideMinFrames = 90;

  /// Süzülme süresine eklenen rastgele üst sınır (kare)
  final int glideRangeFrames = 150;

  /// Uçuş minimum süresi (kare)
  final int flyMinFrames = 40;

  /// Uçuş süresine eklenen rastgele üst sınır (kare)
  final int flyRangeFrames = 80;
}

class _VisualConfig {
  const _VisualConfig();

  /// Kanat çırpma hızı (radyan/kare); büyüdükçe kanatlar daha hızlı çırpar
  final double wingFlapSpeed = 0.35;

  /// Kanat çırpma genliği (piksel); büyüdükçe kanatlar daha açık çırpar
  final double wingFlapAmplitude = 8.5;

  /// Süzülürken kanatların V pozisyonunda tutulduğu yükseklik
  /// (wingFlapAmplitude * glideWingRatio)
  final double glideWingRatio = 0.8;

  /// rot.x hedefi: kanatları görmek için gövdeye verilen sabit yan eğim
  final double bankTargetX = 0.5;

  /// rot.x → hedefe yaklaşma hızı (lerp faktörü, 0–1)
  final double bankSmoothX = 0.1;

  /// Tırmanış/dalış gövde yatışı çarpanı (0 = her zaman yatay, 1 = tam hizalı)
  final double pitchMultiplier = 0.6;

  /// rot.z → hedefe yaklaşma hızı
  final double pitchSmoothZ = 0.15;

  /// Süzülürken kanat Y pozisyonunun hedefe yaklaşma hızı
  final double glideWingSmoothY = 0.15;

  /// Atmosferik solma Z referans mesafesi:
  /// Z = -zFadeRange → alpha 1.0 (tam parlak)
  /// Z = +zFadeRange → alpha alphaMin (soluk)
  final double zFadeRange = 600.0;

  /// En uzaktaki kelebeğin minimum opaklığı (0–1)
  final double alphaMin = 0.18;

  /// Işık yönü X bileşeni (normalize edilecek)
  final double lightX = 0.0;

  /// Işık yönü Y bileşeni
  final double lightY = 1.0;

  /// Işık yönü Z bileşeni
  final double lightZ = 0.8;
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

// ── DÖNÜŞ MATRİSLERİ ────────────────────────────────────────────────────────
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

/// Perspektif projeksiyonu. zsc < nearClip ise null → yüz çizilmez.
Offset? _project(Vec3 p) {
  final fl = ButterflyConfig.physics.focalLength;
  final nc = ButterflyConfig.physics.nearClip;
  final zsc = fl + p.z;
  if (zsc < nc) return null;
  final scale = fl / zsc;
  return Offset(p.x * scale, -p.y * scale);
}

// ── 3D KELEBEK GEOMETRİSİ ──────────────────────────────────────────────────
const _verts = [
  [4.0, 0.0, 0.0], // 0: Gövde Ön  (Baş)
  [-4.0, 0.0, 0.0], // 1: Gövde Arka (Kuyruk)
  [0.0, 0.0, -8.0], // 2: Sol Kanat Üst Dış
  [-3.0, 0.0, -5.0], // 3: Sol Kanat Alt Dış
  [0.0, 0.0, 8.0], // 4: Sağ Kanat Üst Dış
  [-3.0, 0.0, 5.0], // 5: Sağ Kanat Alt Dış
];
const _faces = [
  [0, 2, 1], // Sol kanat üst
  [1, 2, 3], // Sol kanat alt
  [0, 1, 4], // Sağ kanat üst
  [1, 5, 4], // Sağ kanat alt
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
      // Ayrışma: separationChance olasılığıyla komşulardan uzaklaş
      if (_rng.nextDouble() < ButterflyConfig.physics.separationChance) {
        accel.add(_separate(flock));
      }
      // Rastgele türbülans: X/Y/Z eksenleri bağımsız ayarlanabilir
      accel.add(Vec3(
        (_rng.nextDouble() - 0.5) * ButterflyConfig.physics.turbulenceX,
        (_rng.nextDouble() - 0.5) * ButterflyConfig.physics.turbulenceY,
        (_rng.nextDouble() - 0.5) * ButterflyConfig.physics.turbulenceZ,
      ));
      _move();
    } else {
      // Süzülme: yalnızca hafif yerçekimi
      accel.add(Vec3(0, ButterflyConfig.physics.glideGravity, 0));
      _move();
    }
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
    // Her sınır düzlemi için ters kare mesafe kuvveti: yaklaştıkça sertleşir
    void check(Vec3 wall) {
      final dsq = pos.dsq(wall);
      if (dsq > 0) {
        final dir = pos.clone()
          ..sub(wall)
          ..divScale(dsq)
          ..scale(ButterflyConfig.physics.boundaryForce);
        accel.add(dir);
      }
    }

    check(Vec3(-w, pos.y, pos.z)); // Sol
    check(Vec3(w, pos.y, pos.z)); // Sağ
    check(Vec3(pos.x, -h, pos.z)); // Alt
    check(Vec3(pos.x, h, pos.z)); // Üst
    check(Vec3(pos.x, pos.y, -d)); // Ön (kameraya yakın taraf)
    check(Vec3(pos.x, pos.y, d)); // Arka
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
        // Mesafeyle ters orantılı itme: yakın komşular daha güçlü iter
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

  /// Yalnızca tema accent rengi kullanılır; kod içinde karıştırılmaz
  final Color baseColor;

  ButterflyVisual({
    required this.pos,
    required this.phase,
    required this.baseColor,
  });

  void draw(Canvas canvas) {
    for (int fi = 0; fi < _faces.length; fi++) {
      final face = _faces[fi];

      final pts = face.map((vi) {
        final v = _verts[vi];
        final p = Vec3(v[0], v[1], v[2]);
        // vi >= 2: kanat köşeleri — wingY sinüs animasyonunu uygular
        if (vi >= 2) p.y += wingY;
        return p;
      }).toList();

      // Sırayla: eğim (X) → yatış (Z) → yön (Y) rotasyonları, ardından dünya uzayı
      for (final p in pts) {
        _rotX(p, rot.x);
        _rotZ(p, rot.z);
        _rotY(p, rot.y);
        p.x += pos.x;
        p.y += pos.y;
        p.z += pos.z;
      }

      final color = _shade(pts, pos.z);
      final p1 = _project(pts[0]);
      final p2 = _project(pts[1]);
      final p3 = _project(pts[2]);

      // Near-clip: herhangi bir köşe kameraya çok yakınsa yüzü atla
      if (p1 == null || p2 == null || p3 == null) continue;

      canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close(),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  /// Difüz ışıklandırma + Z'ye bağlı atmosferik solma.
  /// Yüzey normali ve ışık yönü config'den gelir.
  Color _shade(List<Vec3> pts, double boidZ) {
    final e1 = pts[1].clone()..sub(pts[0]);
    final e2 = pts[2].clone()..sub(pts[0]);
    final normal = Vec3(
      e1.y * e2.z - e1.z * e2.y,
      e1.z * e2.x - e1.x * e2.z,
      e1.x * e2.y - e1.y * e2.x,
    );
    final nLen = normal.len;
    if (nLen > 0) normal.divScale(nLen);

    final light = Vec3(
      ButterflyConfig.visual.lightX,
      ButterflyConfig.visual.lightY,
      ButterflyConfig.visual.lightZ,
    )..normalize();
    final diffuse = normal.dot(light).abs().clamp(0.0, 1.0);

    // Atmosferik solma: boidZ → [-zFadeRange, +zFadeRange] → alpha [1.0, alphaMin]
    final zRange = ButterflyConfig.visual.zFadeRange;
    final alphaMin = ButterflyConfig.visual.alphaMin;
    final tZ = ((boidZ + zRange) / (zRange * 2.0)).clamp(0.0, 1.0);
    final alpha = (1.0 - tZ * (1.0 - alphaMin)).clamp(alphaMin, 1.0);

    return Color.fromARGB(
      (255 * alpha).toInt().clamp(0, 255),
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
    if (!Degiskenler.birdTriggerNotifier.value) return;
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

  void spawns({int count = 12, Offset? position}) {
    if (!mounted) return;
    final theme = Degiskenler.currentThemeNotifier.value;

    // Renk: rastgele karışım yok, doğrudan tema accent rengi
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
      _boids.add(boid);
      _visuals.add(ButterflyVisual(
        pos: boid.pos,
        phase: _rng.nextDouble() * 62.8,
        baseColor: color,
      ));
    }

    // Limiti aşanları en eskiden sil
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
      final boid = _boids[i];
      final visual = _visuals[i];

      boid.run(_boids, size);

      // Yan eğim (X): kanatları görmek için bankTargetX'e yumuşakça yaklaşır
      visual.rot.x += (ButterflyConfig.visual.bankTargetX - visual.rot.x) *
          ButterflyConfig.visual.bankSmoothX;

      // Yatay yön (Y): hız vektörünün XZ projeksiyonundan hesaplanır
      visual.rot.y = atan2(-boid.vel.z, boid.vel.x);

      // Tırmanış/dalış eğimi (Z): hızın Y bileşeninden → pitchMultiplier ile ölçeklenir
      final vLen = boid.vel.len;
      final targetPitch =
          vLen > 0 ? asin((boid.vel.y / vLen).clamp(-1.0, 1.0)) : 0.0;
      visual.rot.z += ((targetPitch * ButterflyConfig.visual.pitchMultiplier) -
              visual.rot.z) *
          ButterflyConfig.visual.pitchSmoothZ;

      // Kanat animasyonu: süzülme ↔ çırpma
      if (boid.state == ButterflyState.gliding) {
        // Süzülme: kanatlar V pozisyonunda sabit
        final targetWingY = ButterflyConfig.visual.wingFlapAmplitude *
            ButterflyConfig.visual.glideWingRatio;
        visual.wingY += (targetWingY - visual.wingY) *
            ButterflyConfig.visual.glideWingSmoothY;
      } else {
        // Uçuş: sinüs dalgasıyla kanat çırpma
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
    // Painter's algorithm: yüksek Z (uzak) → düşük Z (yakın) sırasıyla çiz
    // Böylece öndekiler arkadakilerin üzerine doğal biner.
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
