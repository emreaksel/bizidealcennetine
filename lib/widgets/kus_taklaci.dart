import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  KUŞ AYARLARI
// ═══════════════════════════════════════════════════════════════════════════

/// Spawn (Doğma) ayarları — kaç kuş çıkacak, ne kadar süre kalacak
class _SpawnConfig {
  const _SpawnConfig();

  /// Beğeni yapıldığında ekrana gönderilecek kuş sayısı
  final int triggerCount = 30;

  /// Ekranda aynı anda bulunabilecek maksimum kuş sayısı
  final int maxLimit = 80;

  /// Uygulama ilk açıldığında ekranda hazır bulunan kuş sayısı (0 = yok)
  final int initialCount = 0;

  /// Kuşlar oluştuktan kaç saniye sonra kaybolmaya başlar
  final int waitSec = 17;

  /// Kaybolma sırasında kaç saniyede bir kuş ekrandan silinir
  final int removalIntervalSec = 1;
}

/// Fizik ayarları — hareket, kuvvet, algılama mesafeleri
class _PhysicsConfig {
  const _PhysicsConfig();

  /// Kuşların maksimum uçuş hızı (birim/kare)
  final double maxSpeed = 2.0;

  /// Manevra kabiliyeti: kuşların yön değiştirme kuvvetinin üst sınırı.
  final double maxForce = 0.04;

  /// Bir kuşun komşularını algılayabileceği maksimum mesafe
  final double neighborDist = 200.0;

  /// Bu mesafenin altına giren kuşlar birbirinden aktif olarak uzaklaşır
  final double separationDist = 60.0;

  /// Kuşların ekrana (kameraya) en fazla ne kadar yaklaşabileceği (Z ekseni alt sınırı).
  final double minDepth = 100.0;

  /// Sürünün arka planda gidebileceği maksimum derinlik
  final double maxDepth = 900.0;

  /// Sınıra yaklaşıldığında uygulanan geri itme kuvvetinin çarpanı
  final double boundaryForce = 5.0;

  /// Ekran dokunuşunun kuşları kaçırmaya başladığı yarıçap (piksel)
  final double repelRadius = 180.0;

  /// Dokunuş kaçırma kuvvetinin çarpanı — büyütmek daha sert kaçırır
  final double repelStrength = 2.5;

  /// Perspektif projeksiyonu için odak uzaklığı (focal length)
  final double focalLength = 800.0;

  /// Kuşların ekranın sağ/sol veya alt/üst kenarlarından ne kadar dışarı çıkabileceği (piksel).
  final double screenMargin = 450.0;

  /// Sürüden kopan (etrafında kuş kalmayan) kuşların sürüye geri dönme (yetişme) kuvveti çarpanı.
  final double orphanCatchUpMultiplier = 2.0;

  // ── YENİ: SARMAL (GİRDAP) AYARLARI ─────────────────────────────────────────

  /// Sarmal hareket için teğet (döndürme) kuvveti
  final double spiralStrength = 0.005;

  /// Sarmalın merkezine doğru çekim kuvveti (kuşların çok fazla dağılmasını önler)
  final double spiralCenterPull = 0.001;
}

/// Görsel ayarlar — kanat animasyonu
class _VisualConfig {
  const _VisualConfig();

  /// Her karede faz değerine eklenen miktar — büyütmek kanat çırpmayı hızlandırır
  final double wingFlapSpeed = 0.2;

  /// Kanat ucunun yukarı/aşağı hareket genliği (piksel cinsinden 3D birim)
  final double wingFlapAmplitude = 5.0;
}

/// Takla ayarları — taklacı güvercin davranışı
class _TumbleConfig {
  const _TumbleConfig();

  /// Sürüdeki kuşların kaçta kaçı taklacı olabilir (0.0 – 1.0)
  final double tumblerRatio = 0.2;

  /// Her karede taklacı bir kuşun taklaya başlama olasılığı
  final double triggerChance = 0.00063;

  /// Bir kuşun art arda atabileceği maksimum takla sayısı.
  final int maxTumbles = 2;

  /// 1 taklanın kaç kare süreceği — Daha keskin bir takla için 100 (~1.6 saniye)
  final int durationTicks = 40;

  /// Her karede ileri eksene eklenen rotasyon açısı — Dönüş hızı
  final double rollSpeed = 0.12;

  /// Takla bittikten kaç kare sonra aynı kuş tekrar takla atabilir
  final int cooldownTicks = 500;

  /// Takla sırasında kanat çırpma hızı çarpanı — panikleyerek daha hızlı çırpar
  final double wingFlapSpeedMultiplier = 3.5;

  /// Takla atarken hava sürtünmesi (fren).
  final double tumbleBrake = 0.41;

  /// Takla atarken aşağı doğru irtifa kaybetme (yerçekimi).
  final double tumbleGravity = 0.009;
}

/// Ana yapılandırma sınıfı — tüm alt gruplara buradan erişilir
class BirdConfig {
  static const spawn = _SpawnConfig();
  static const physics = _PhysicsConfig();
  static const visual = _VisualConfig();
  static const tumble = _TumbleConfig();
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

void _rotX(Vec3 p, double a) {
  final s = sin(a), c = cos(a);
  final ny = p.y * c - p.z * s;
  final nz = p.y * s + p.z * c;
  p.y = ny;
  p.z = nz;
}

Offset _project(Vec3 p) {
  final fl = BirdConfig.physics.focalLength;
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

  double w = 400, h = 400;

  bool isTumbling = false;

  void run(List<Boid> flock, Size screenSize) {
    w = (screenSize.width / 2) + BirdConfig.physics.screenMargin;
    h = (screenSize.height / 2) + BirdConfig.physics.screenMargin;
    _boundary();

    if (isTumbling) {
      vel.scale(BirdConfig.tumble.tumbleBrake);
      accel.y -= BirdConfig.tumble.tumbleGravity;
    } else if (_rng.nextDouble() > 0.5) {
      accel.add(_align(flock));
      accel.add(_cohere(flock)); // Yetim radarı burada çalışır
      accel.add(_separate(flock));
      accel.add(_spiral()); // YENİ: Sarmal kuvveti eklendi
    }
    _move();
  }

  void repelFrom(Vec3 pt) {
    final dist = pos.dst(pt);
    if (dist < BirdConfig.physics.repelRadius) {
      final dir = pos.clone()
        ..sub(pt)
        ..scale(BirdConfig.physics.repelStrength / (dist + 0.01));
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
          ..scale(BirdConfig.physics.boundaryForce);
        accel.add(dir);
      }
    }

    check(Vec3(-w, pos.y, pos.z));
    check(Vec3(w, pos.y, pos.z));
    check(Vec3(pos.x, -h, pos.z));
    check(Vec3(pos.x, h, pos.z));
    check(Vec3(pos.x, pos.y, BirdConfig.physics.minDepth));
    check(Vec3(pos.x, pos.y, BirdConfig.physics.maxDepth));
  }

  void _move() {
    vel.add(accel);
    final l = vel.len;
    if (l > BirdConfig.physics.maxSpeed) {
      vel.divScale(l / BirdConfig.physics.maxSpeed);
    }
    pos.add(vel);
    accel.set(0, 0, 0);
  }

  Vec3 _align(List<Boid> flock) {
    final sum = Vec3();
    int cnt = 0;
    for (final b in flock) {
      final dist = b.pos.dst(pos);
      if (dist > 0 && dist <= BirdConfig.physics.neighborDist) {
        sum.add(b.vel);
        cnt++;
      }
    }
    if (cnt > 0) {
      sum.divScale(cnt.toDouble());
      final v = sum.len;
      if (v > BirdConfig.physics.maxForce) {
        sum.divScale(v / BirdConfig.physics.maxForce);
      }
    }
    return sum;
  }

  Vec3 _cohere(List<Boid> flock) {
    final center = Vec3();
    int cnt = 0;
    for (final b in flock) {
      final dist = b.pos.dst(pos);
      if (dist > 0 && dist <= BirdConfig.physics.neighborDist) {
        center.add(b.pos);
        cnt++;
      }
    }

    // Normal sürülere katılma (etrafında kuş varsa)
    if (cnt > 0) {
      center.divScale(cnt.toDouble());
      final dir = Vec3()..subOf(center, pos);
      final l = dir.len;
      if (l > BirdConfig.physics.maxForce) {
        dir.divScale(l / BirdConfig.physics.maxForce);
      }
      return dir;
    } else {
      // YETİM RADARI (Sürüden kopan kuşlar için)
      // Eğer kuşun etrafında hiç kimse kalmadıysa (takla sonrası uzaklaştıysa)
      // tüm sürünün global merkezini bulup oraya doğru panik kuvvetiyle uçar.
      if (flock.length > 1) {
        for (final b in flock) {
          center.add(b.pos);
        }
        center.divScale(flock.length.toDouble());
        final dir = Vec3()..subOf(center, pos);
        final l = dir.len;

        final catchUpForce = BirdConfig.physics.maxForce *
            BirdConfig.physics.orphanCatchUpMultiplier;
        if (l > catchUpForce) {
          dir.divScale(l / catchUpForce);
        }
        return dir;
      }
    }
    return Vec3();
  }

  Vec3 _separate(List<Boid> flock) {
    final sum = Vec3();
    for (final b in flock) {
      final dist = b.pos.dst(pos);
      if (dist > 0 && dist <= BirdConfig.physics.separationDist) {
        final rep = Vec3()
          ..subOf(pos, b.pos)
          ..normalize()
          ..divScale(dist);
        sum.add(rep);
      }
    }
    return sum;
  }

  // ── YENİ: SARMAL (GİRDAP) HAREKETİ ─────────────────────────────────────────
  Vec3 _spiral() {
    // Sürünün döneceği merkez noktası (X: 0, Y: 0, Z: Derinliğin tam ortası)
    final center = Vec3(
        0, 0, (BirdConfig.physics.minDepth + BirdConfig.physics.maxDepth) / 2);

    // Kuşun merkeze olan uzaklık vektörü
    final dir = Vec3()..subOf(pos, center);
    final dist = dir.len;

    if (dist == 0) return Vec3();

    // 1. Merkeze doğru çekim kuvveti (içeri doğru sarmal yapmak için negatife doğru çekiyoruz)
    final pull = dir.clone()
      ..normalize()
      ..scale(-BirdConfig.physics.spiralCenterPull);

    // 2. XZ düzleminde teğet kuvvet (etrafında dönmeleri için çapraz vektör)
    // Sadece yatayda dönmeleri için X ve Z'yi yer değiştirip birini negatif yapıyoruz.
    // Y eksenine hafif bir düzeltme veriyoruz ki girdap yukarı/aşağı çok dağılmasın.
    final tangent = Vec3(
        -dir.z,
        (center.y - pos.y) * 0.02, // Y ekseninde merkeze yumuşak bir hiza
        dir.x)
      ..normalize()
      ..scale(BirdConfig.physics.spiralStrength);

    // İki kuvveti birleştir: Merkeze çekil + Etrafında dön = Sarmal
    final spiralForce = Vec3()
      ..add(pull)
      ..add(tangent);

    return spiralForce;
  }
}

// ── GÖRSEL KUŞ ────────────────────────────────────────────────────────────
class BirdVisual {
  final Vec3 pos;
  final Vec3 rot = Vec3();
  double phase;
  double wingY = 0;
  Color baseColor;

  // ── Taklacı güvercin durumu ──────────────────────────────────────────────

  final bool canTumble;
  bool isTumbling = false;

  int targetTumbles = 0;
  int tumblesDone = 0;

  int tumbleTicksLeft = 0;
  double tumbleRollAngle = 0.0;
  int tumbleCooldownLeft = 0;

  BirdVisual({
    required this.pos,
    required this.phase,
    required this.baseColor,
    required this.canTumble,
  });

  void draw(Canvas canvas) {
    for (int fi = 0; fi < _faces.length; fi++) {
      final face = _faces[fi];
      final pts = face.map((vi) {
        final v = _verts[vi];
        return Vec3(v[0], v[1], v[2]);
      }).toList();
      if (fi > 0) pts[0].y = wingY;
      for (final p in pts) {
        if (isTumbling) _rotX(p, tumbleRollAngle);
        _rotY(p, rot.y);
        _rotZ(p, rot.z);
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
      (baseColor.red * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255),
      (baseColor.green * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255),
      (baseColor.blue * (0.6 + 0.4 * diffuse)).toInt().clamp(0, 255),
    );
  }
}

// ── WIDGET ────────────────────────────────────────────────────────────────
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
  Timer? _deactiveTimer;
  Timer? _removalTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    Degiskenler.birdTriggerNotifier.addListener(_onBirdTrigger);
    if (BirdConfig.spawn.initialCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => spawnBirds(count: BirdConfig.spawn.initialCount),
      );
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
      spawnBirds(count: BirdConfig.spawn.triggerCount);
      _deactiveTimer = Timer(
        Duration(seconds: BirdConfig.spawn.waitSec),
        () {
          if (!mounted) return;
          _removalTimer = Timer.periodic(
            Duration(seconds: BirdConfig.spawn.removalIntervalSec),
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

  void spawnBirds({int count = 12, Offset? position}) {
    if (!mounted) return;
    final theme = Degiskenler.currentThemeNotifier.value;

    // Uygulamanın anlık ekran boyutunu alıyoruz ki kuşları tam ekrana yayalım
    final size = MediaQuery.of(context).size;

    for (int i = 0; i < count; i++) {
      final boid = Boid();

      // Kuşları ekranın ortasına hapsetmek yerine tüm ekran alanına serpiştiriyoruz
      boid.pos.set(
        (_rng.nextDouble() * size.width) - (size.width / 2.5),
        (_rng.nextDouble() * size.height) - (size.height / 2.5),
        // Derinlik olarak da arka plana doğru daha geniş bir alana dağıtıyoruz
        BirdConfig.physics.minDepth +
            (_rng.nextDouble() *
                (BirdConfig.physics.maxDepth - BirdConfig.physics.minDepth)),
      );

      boid.vel.set(
        _rng.nextDouble() * 4 - 2,
        _rng.nextDouble() * 4 - 2,
        _rng.nextDouble() * 4 - 2,
      );

      _boids.add(boid);
      _visuals.add(BirdVisual(
        pos: boid.pos,
        phase: _rng.nextDouble() * 62.8,
        baseColor:
            Color.lerp(theme.accentColor, theme.textColor, _rng.nextDouble()) ??
                theme.accentColor,
        canTumble: _rng.nextDouble() < BirdConfig.tumble.tumblerRatio,
      ));
    }

    if (_boids.length > BirdConfig.spawn.maxLimit) {
      final range = _boids.length - BirdConfig.spawn.maxLimit;
      _boids.removeRange(0, range);
      _visuals.removeRange(0, range);
    }
    setState(() {});
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final tc = BirdConfig.tumble;
    final vc = BirdConfig.visual;

    for (int i = 0; i < _boids.length; i++) {
      final boid = _boids[i];
      final visual = _visuals[i];

      // ── Takla durum makinesi ──────────────────────────────────────────────

      if (visual.isTumbling) {
        visual.tumbleRollAngle += tc.rollSpeed;
        visual.tumbleTicksLeft--;

        if (visual.tumbleTicksLeft <= 0) {
          visual.tumblesDone++; // Bir takla tamamlandı

          if (visual.tumblesDone >= visual.targetTumbles) {
            // Hedeflenen tüm taklalar bitti
            visual.isTumbling = false;
            visual.tumbleRollAngle = 0.0;
            visual.tumbleCooldownLeft = tc.cooldownTicks;
            boid.isTumbling = false;
          } else {
            // Kuş coştu, sıradaki taklaya hiç durmadan devam ediyor
            visual.tumbleTicksLeft = tc.durationTicks;
          }
        }
      } else {
        if (visual.tumbleCooldownLeft > 0) visual.tumbleCooldownLeft--;

        final canTrigger = visual.canTumble &&
            visual.tumbleCooldownLeft == 0 &&
            _rng.nextDouble() < tc.triggerChance;

        if (canTrigger) {
          visual.isTumbling = true;
          visual.targetTumbles = _rng.nextInt(tc.maxTumbles) + 1;
          visual.tumblesDone = 0;
          visual.tumbleTicksLeft = tc.durationTicks;
          visual.tumbleRollAngle = 0.0;
          boid.isTumbling = true;
        }
      }

      // ── Fizik güncelle ───────────────────────────────────────────────────
      boid.run(_boids, size);

      // ── Görsel rotasyon ──────────────────────────────────────────────────
      visual.rot.y = atan2(-boid.vel.z, boid.vel.x);
      final vLen = boid.vel.len;
      visual.rot.z = vLen > 0 ? asin((boid.vel.y / vLen).clamp(-1, 1)) : 0;

      final flapSpeed = visual.isTumbling
          ? vc.wingFlapSpeed * tc.wingFlapSpeedMultiplier
          : vc.wingFlapSpeed;
      visual.phase = (visual.phase + flapSpeed) % 62.8;
      visual.wingY = sin(visual.phase) * vc.wingFlapAmplitude;
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
      painter: _BirdFlockPainter(_visuals),
      child: const SizedBox.expand(),
    );
  }
}

// ── PAINTER ───────────────────────────────────────────────────────────────
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
