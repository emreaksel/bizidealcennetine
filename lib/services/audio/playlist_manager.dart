import 'dart:math';
import 'package:bizidealcennetine/services/log_service.dart';

/// Playlist navigasyonunu, shuffle ve geçmiş (geri butonu) mantığını yönetir.
/// ConcatenatingAudioSource'a bağımlı değildir; ham JSON listeleriyle çalışır.
class PlaylistManager {
  // ── Listeler ──────────────────────────────────────────────
  List<dynamic> _mainList = [];
  List<dynamic> _likesList = [];
  bool _isDokunanlarActive = false;

  List<dynamic> get activeList => _isDokunanlarActive ? _likesList : _mainList;

  bool get isMainListActive => !_isDokunanlarActive;

  // ── Oynatma Durumu ────────────────────────────────────────
  bool isShuffleEnabled = true;
  bool isRepeatOne = false;

  int currentSiraNo = -1;
  bool isGiftTrackPlaying = false;

  // ── Shuffle Kümesi ────────────────────────────────────────
  final Set<int> _playedSet = {};

  // ── Geçmiş (geri butonu) ─────────────────────────────────
  final List<int> _history = [];
  static const int _maxHistory = 100;

  // ═════════════════════════════════════════════════════════
  //  Liste Yönetimi
  // ═════════════════════════════════════════════════════════

  void setMainList(List<dynamic> list) {
    _mainList = list;
    _isDokunanlarActive = false;
    _playedSet.clear();
    _history.clear();
    isGiftTrackPlaying = false;
  }

  void setDokunanlarList(List<dynamic> list) {
    _likesList = list;
  }

  void switchToMainList() {
    if (_isDokunanlarActive) {
      _isDokunanlarActive = false;
      _playedSet.clear();
      _history.clear();
      isGiftTrackPlaying = false;
    }
  }

  void switchToDokunanlar() {
    if (!_isDokunanlarActive) {
      _isDokunanlarActive = true;
      _playedSet.clear();
      _history.clear();
      isGiftTrackPlaying = false;
    }
  }

  bool get isEmpty => activeList.isEmpty;

  // ═════════════════════════════════════════════════════════
  //  Parça Arama
  // ═════════════════════════════════════════════════════════

  Map<String, dynamic>? findBySiraNo(int siraNo) {
    final list = activeList;
    for (final e in list) {
      if (e['sira_no']?.toString() == siraNo.toString()) {
        return Map<String, dynamic>.from(e as Map);
      }
    }
    return null;
  }

  Map<String, dynamic>? findBySiraNoInMain(int siraNo) {
    for (final e in _mainList) {
      if (e['sira_no']?.toString() == siraNo.toString()) {
        return Map<String, dynamic>.from(e as Map);
      }
    }
    return null;
  }

  Map<String, dynamic>? randomSong() {
    final list = activeList;
    if (list.isEmpty) return null;
    final idx = Random().nextInt(list.length);
    return Map<String, dynamic>.from(list[idx] as Map);
  }

  // ═════════════════════════════════════════════════════════
  //  Navigasyon
  // ═════════════════════════════════════════════════════════

  /// Şu anki parçayı geçmişe ekler ve yeni parçayı current yapar.
  void recordNavigation(Map<String, dynamic> toSong) {
    LogService().info("[PlaylistManager] recordNavigation çağrıldı: toSong=${toSong['sira_no']} - ${toSong['parca_adi']}, mevcut currentSiraNo=$currentSiraNo", tag: "Audio");
    if (currentSiraNo != -1) {
      _history.add(currentSiraNo);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    currentSiraNo = int.tryParse(toSong['sira_no'].toString()) ?? -1;
    _playedSet.add(currentSiraNo);
    isGiftTrackPlaying = toSong['_isGift'] == true;
    LogService().info("[PlaylistManager] recordNavigation bitti: yeni currentSiraNo=$currentSiraNo, playedSet.length=${_playedSet.length}", tag: "Audio");
  }

  /// Sonraki parçayı hesaplar (state değiştirmez).
  /// [referenceSiraNo] verilirse o parçadan sonrakini bulur, verilmezse [currentSiraNo]'yu baz alır.
  Map<String, dynamic>? calculateNext({int? referenceSiraNo}) {
    LogService().info("[PlaylistManager] calculateNext çağrıldı: referenceSiraNo=$referenceSiraNo, currentSiraNo=$currentSiraNo", tag: "Audio");
    final list = activeList;
    if (list.isEmpty) {
      LogService().warn("[PlaylistManager] calculateNext: activeList boş!", tag: "Audio");
      return null;
    }

    // Referans belirtilmemişse mevcut parçayı kullan
    final ref = referenceSiraNo ?? currentSiraNo;

    // Tek parça tekrarı aktifse ve manuel bir referans istenmemişse aynı parçayı dön
    if (isRepeatOne && referenceSiraNo == null) {
      LogService().info("[PlaylistManager] calculateNext: isRepeatOne aktif, aynı parça dönülüyor. ref=$ref", tag: "Audio");
      return findBySiraNo(ref);
    }

    if (isShuffleEnabled) {
      // Çalınmamış parçaları bul (mevcut parça hariç)
      final unplayed = list.where((e) {
        final sn = int.tryParse(e['sira_no'].toString()) ?? -1;
        return !_playedSet.contains(sn) && sn != ref;
      }).toList();

      LogService().info("[PlaylistManager] calculateNext (Shuffle): unplayed.length=${unplayed.length}, playedSet.length=${_playedSet.length}", tag: "Audio");

      if (unplayed.isEmpty) {
        // Tüm liste bittiyse seti sıfırla (mevcut parçayı hariç tutarak)
        _playedSet.clear();
        _playedSet.add(ref);

        final others = list.where((e) {
          final sn = int.tryParse(e['sira_no'].toString()) ?? -1;
          return sn != ref;
        }).toList();

        if (others.isEmpty) {
          LogService().info("[PlaylistManager] calculateNext (Shuffle): Liste 1 elemanlı, aynısı dönülüyor.", tag: "Audio");
          return findBySiraNo(ref); // Liste 1 elemanlıysa mecburen aynısı
        }

        final randomIdx = Random().nextInt(others.length);
        final result = Map<String, dynamic>.from(others[randomIdx] as Map);
        LogService().info("[PlaylistManager] calculateNext (Shuffle) Reset sonrası SONUÇ: ${result['sira_no']} - ${result['parca_adi']}", tag: "Audio");
        return result;
      }

      final randomIdx = Random().nextInt(unplayed.length);
      final result = Map<String, dynamic>.from(unplayed[randomIdx] as Map);
      LogService().info("[PlaylistManager] calculateNext (Shuffle) SONUÇ: ${result['sira_no']} - ${result['parca_adi']}", tag: "Audio");
      return result;
    } else {
      // Sıralı: Listede bul ve bir sonrakini al
      final idx =
          list.indexWhere((e) => e['sira_no'].toString() == ref.toString());

      // Eğer bulunamazsa (-1), nextIdx 0 olur (listenin başı)
      final nextIdx = (idx + 1) % list.length;
      final result = Map<String, dynamic>.from(list[nextIdx] as Map);
      LogService().info("[PlaylistManager] calculateNext (Sıralı) SONUÇ: ${result['sira_no']} - ${result['parca_adi']}, idx=$idx, nextIdx=$nextIdx", tag: "Audio");
      return result;
    }
  }

  /// Önceki parçayı hesaplar — geçmişten alır (state değiştirmez).
  Map<String, dynamic>? calculatePrevious() {
    if (_history.isEmpty) return findBySiraNo(currentSiraNo);
    final prevSiraNo = _history.last;
    return findBySiraNo(prevSiraNo);
  }

  /// Önceki parça için geçmişi günceller.
  /// Ayrıldığımız parçayı _playedSet'ten çıkarır ki shuffle havuzuna geri girsin.
  void rewindHistory() {
    if (_history.isEmpty) return;
    final leavingSiraNo = currentSiraNo;
    final prevSiraNo = _history.removeLast();
    if (leavingSiraNo != -1) {
      _playedSet.remove(leavingSiraNo);
    }
    currentSiraNo = prevSiraNo;
  }
}
