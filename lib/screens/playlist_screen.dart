import 'dart:async';
import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/MusicApiService.dart';
import '../yaveran/audio_service.dart';
import '../yaveran/ui_support.dart';
import '../yaveran/widgets.dart';
import '../yaveran/app_theme.dart';

class ListeWidget extends StatefulWidget {
  @override
  _ListeWidgetState createState() => _ListeWidgetState();
}

class _ListeWidgetState extends State<ListeWidget>
    with TickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> filteredSongList = [];
  String searchText = "";
  FocusNode _focusNode = FocusNode();
  Timer? _timer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  final MusicApiService _apiService = MusicApiService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Sekme değiştiğinde aramayı temizle
      if (mounted && searchText.isNotEmpty) {
        setState(() {
          _searchController.clear();
          searchText = "";
          filteredSongList.clear();
        });
      }

      // Sadece senkronize ise VE ikinci tabda boş liste varsa istek atalım
      if (_tabController.index == 1 && 
          Degiskenler.isSyncedNotifier.value && 
          Degiskenler.myLikesNotifier.value.isEmpty) {
        _fetchMyLikes();
      }
    });

    if (Degiskenler.isSyncedNotifier.value) {
      _fetchMyLikes();
    }

    Degiskenler.isSyncedNotifier.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    if (Degiskenler.isSyncedNotifier.value) {
      // Senkronize olduğu an listeyi çekelim
      _fetchMyLikes();
    } else {
      Degiskenler.myLikesNotifier.value = [];
      _tabController.index = 0;
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchMyLikes() async {
    final likes = await _apiService.fetchMyLikes(limit: 500);
    Degiskenler.myLikesNotifier.value = likes;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    _fadeController.dispose();
    _tabController.dispose();
    Degiskenler.isSyncedNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  String _normalizeSearchText(String input) {
    return input
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('i', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Â', 'a')
        .replaceAll('â', 'a')
        .replaceAll('Î', 'i')
        .replaceAll('î', 'i')
        .replaceAll('Û', 'u')
        .replaceAll('û', 'u')
        .replaceAll('Ô', 'o')
        .replaceAll('ô', 'o')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _runSearch(String value) {
    setState(() {
      searchText = value;
      final normalizedSearch = _normalizeSearchText(value);
      final currentList = _tabController.index == 0
          ? Degiskenler.songListNotifier.value
          : Degiskenler.myLikesNotifier.value;

      filteredSongList = currentList.where((song) {
        String songName = _normalizeSearchText(song['parca_adi'].toString());
        String singerName = _normalizeSearchText((song['seslendiren'] ?? "").toString());
        String songNumber = _normalizeSearchText(song['sira_no'].toString());
        
        return songName.contains(normalizedSearch) || 
               singerName.contains(normalizedSearch) || 
               songNumber.contains(normalizedSearch);
      }).toList();
    });
  }

  double calculateFontSize(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double fontSize =
        screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100) * 0.11;
    return fontSize;
  }

  Widget _buildSongList(List<dynamic> songList, {bool reverse = true}) {
    List<dynamic> displayList =
        filteredSongList.isNotEmpty ? filteredSongList : songList;

    if (reverse) {
      displayList = displayList.reversed.toList();
    }

    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        if (filteredSongList.isEmpty && searchText.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: theme.textColor.withOpacity(0.3),
                ),
                SizedBox(height: 16),
                Text(
                  "Hiçbir sonuç bulunamadı",
                  style: TextStyle(
                    color: theme.textColor.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Farklı anahtar kelimeler deneyin",
                  style: TextStyle(
                    color: theme.textColor.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        } else if (displayList.isEmpty) {
          return Center(
            child: Text(
              "Liste henüz boş...",
              style: TextStyle(color: theme.textColor.withOpacity(0.5)),
            ),
          );
        } else {
          return ValueListenableBuilder<List<dynamic>>(
            valueListenable: Degiskenler.myLikesNotifier,
            builder: (context, myLikes, _) {
              final bool isSynced = Degiskenler.isSyncedNotifier.value;
              return ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final song = displayList[index];
                  final bool isLiked = isSynced && 
                      myLikes.any((liked) => liked['sira_no'].toString() == song['sira_no'].toString());

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          AudioService.loadQueueAndPlay(
                            reverse ? songList.reversed.toList() : songList,
                            song['sira_no']
                          );
                          UI_support.ekranboyut_ana(0);
                        },
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.textColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: theme.accentColor,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        song['parca_adi'].toString().toUpperCase(),
                                        style: TextStyle(
                                          color: theme.textColor.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0),
                                      child: Text(
                                        " • ",
                                        style: TextStyle(
                                          color: theme.textColor.withOpacity(0.4),
                                          fontSize: 14,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      song['seslendiren'] ?? '',
                                      style: TextStyle(
                                        color: theme.subTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isLiked) ...[
                                      SizedBox(width: 8),
                                      Icon(Icons.favorite, color: theme.accentColor, size: 14),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Degiskenler.isSyncedNotifier,
      builder: (context, isSynced, child) {
        return ValueListenableBuilder<AppTheme>(
          valueListenable: Degiskenler.currentThemeNotifier,
          builder: (context, theme, _) {
            return Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: theme.textColor.withOpacity(0.05)),
                    ),
                    child: SafeArea(
                      bottom: false,
                      top: false,
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: theme.textColor.withOpacity(0.5),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                        tabs: [
                          Tab(text: Degiskenler.liste_adi.toUpperCase()),
                          const Tab(text: "DOKUNANLAR"),
                        ],
                      ),
                    ),
                  ),

                  // --- LİSTE ALANI (TABBARVIEW) ---
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 1. HAZİNE (ANA LİSTE)
                          ValueListenableBuilder<List<dynamic>>(
                            valueListenable: Degiskenler.songListNotifier,
                            builder: (context, songList, _) =>
                                _buildSongList(songList, reverse: true),
                          ),

                          // 2. DOKUNANLAR (BEĞENİLER)
                          isSynced
                              ? ValueListenableBuilder<List<dynamic>>(
                                  valueListenable: Degiskenler.myLikesNotifier,
                                  builder: (context, myLikes, _) =>
                                      _buildSongList(myLikes, reverse: false),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_off_rounded,
                                        size: 64,
                                        color: theme.textColor.withOpacity(0.1),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Oturum Açılmadı",
                                        style: TextStyle(
                                          color:
                                              theme.textColor.withOpacity(0.7),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 40),
                                        child: Text(
                                          "Beğendiğiniz parçaları senkronize etmek için lütfen cihazınızı eşleştirin.",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme.textColor
                                                .withOpacity(0.4),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),

                  // --- ALT PANEL (SABİT ARAMA ALANI) ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      border: Border(
                          top: BorderSide(
                              color: theme.textColor.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.textColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: theme.textColor.withOpacity(0.1)),
                            ),
                            child: TextField(
                              focusNode: _focusNode,
                              controller: _searchController,
                              style: TextStyle(
                                  color: theme.textColor, fontSize: 14),
                              onChanged: (value) => _runSearch(value),
                              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                              decoration: InputDecoration(
                                hintText: "Hatırla...",
                                hintStyle: TextStyle(
                                    color: theme.textColor.withOpacity(0.3),
                                    fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: theme.accentColor, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                suffixIcon: searchText.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: theme.textColor
                                                .withOpacity(0.5),
                                            size: 18),
                                        onPressed: () {
                                          FocusManager.instance.primaryFocus?.unfocus();
                                          setState(() {
                                            _searchController.clear();
                                            searchText = "";
                                            filteredSongList.clear();
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Alt menü butonu (sağ tarafa taşındı)
                        AlternativeListButton(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
