import 'dart:math';

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
    if (currentSiraNo != -1) {
      _history.add(currentSiraNo);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }
    currentSiraNo = int.tryParse(toSong['sira_no'].toString()) ?? -1;
    _playedSet.add(currentSiraNo);
    isGiftTrackPlaying = toSong['_isGift'] == true;
  }

  /// Sonraki parçayı hesaplar (state değiştirmez).
  Map<String, dynamic>? calculateNext() {
    final list = activeList;
    if (list.isEmpty) return null;

    if (isRepeatOne) return findBySiraNo(currentSiraNo);

    if (isShuffleEnabled) {
      final unplayed = list.where((e) {
        final sn = int.tryParse(e['sira_no'].toString()) ?? -1;
        return !_playedSet.contains(sn);
      }).toList();

      if (unplayed.isEmpty) {
        // Tüm liste çalındı — seti sıfırla ve tamamını karıştır
        _playedSet.clear();
        final all = List<dynamic>.from(list)..shuffle();
        return Map<String, dynamic>.from(all.first as Map);
      }
      unplayed.shuffle();
      return Map<String, dynamic>.from(unplayed.first as Map);
    } else {
      // Sıralı
      final idx = list.indexWhere(
          (e) => e['sira_no'].toString() == currentSiraNo.toString());
      final nextIdx = (idx + 1) % list.length;
      return Map<String, dynamic>.from(list[nextIdx] as Map);
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
