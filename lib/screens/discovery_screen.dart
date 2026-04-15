import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/ui_support.dart';
import '../yaveran/logic.dart';
import '../yaveran/app_theme.dart';
import 'dart:math' as math;

class DinlemeListesiWidget extends StatefulWidget {
  @override
  _DinlemeListesiWidgetState createState() => _DinlemeListesiWidgetState();
}

class _DinlemeListesiWidgetState extends State<DinlemeListesiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int? _loadingId;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dinle(Map<dynamic, dynamic> item) {
    setState(() => _loadingId = item["id"]);

    Degiskenler.liste_adi = item["caption"];
    Degiskenler.liste_link = item["link"];

    // Ana ekrana hemen dön (kullanıcı beklemek zorunda kalmasın)
    UI_support.ekranboyut_ana(0);

    // Listeyi yükle (arka planda devam eder, await etmiyoruz ki UI hemen dönsün)
    fetchData_jsonDinlemeListesi(
      "${Degiskenler.kaynakYolu}kaynak/${item["link"]}.json",
      item["link"],
    ).then((_) {
      if (mounted) {
        setState(() {
          _loadingId = null;
          _expandedId = null;
        });
      }
    });
  }

  void _toggleExpand(int id) {
    setState(() {
      if (_expandedId == id) {
        _expandedId = null;
      } else {
        _expandedId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Container(
          color: theme.backgroundColor,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: Degiskenler.dinlemeListeleriNotifier,
                builder: (context, dinlemeListeleri, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dinleme Listeleri',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: theme.textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 2,
                              width: 40,
                              decoration: BoxDecoration(
                                color: theme.accentColor.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: dinlemeListeleri.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = dinlemeListeleri[index];
                            final bool isActive =
                                item["link"] == Degiskenler.liste_link;
                            final bool isLoading = _loadingId == item["id"];
                            final bool isExpanded = _expandedId == item["id"];

                            return _ListeKarti(
                              item: item,
                              theme: theme,
                              isActive: isActive,
                              isLoading: isLoading,
                              isExpanded: isExpanded,
                              index: index,
                              onTap: () => _toggleExpand(item["id"]),
                              onPlay: () => _dinle(item),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ListeKarti extends StatefulWidget {
  final Map<dynamic, dynamic> item;
  final AppTheme theme;
  final bool isActive;
  final bool isLoading;
  final bool isExpanded;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _ListeKarti({
    required this.item,
    required this.theme,
    required this.isActive,
    required this.isLoading,
    required this.isExpanded,
    required this.index,
    required this.onTap,
    required this.onPlay,
  });

  @override
  State<_ListeKarti> createState() => _ListeKartiState();
}

class _ListeKartiState extends State<_ListeKarti>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 60),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isActive = widget.isActive;
    final isExpanded = widget.isExpanded;
    final item = widget.item;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: theme.accentColor.withOpacity(0.1),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 350),
              curve: Curves.easeInOutQuart,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.accentColor.withOpacity(0.08)
                    : (isExpanded
                        ? theme.cardColor
                        : theme.cardColor.withOpacity(0.7)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? theme.accentColor.withOpacity(0.4)
                      : (isExpanded
                          ? theme.accentColor.withOpacity(0.2)
                          : theme.textColor.withOpacity(0.05)),
                  width: (isActive || isExpanded) ? 1.5 : 1.0,
                ),
                boxShadow: (isActive || isExpanded)
                    ? [
                        BoxShadow(
                          color: theme.accentColor.withOpacity(0.08),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Sol: İkon
                      AnimatedContainer(
                        duration: Duration(milliseconds: 350),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isActive || isExpanded)
                              ? theme.accentColor.withOpacity(0.15)
                              : theme.textColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: widget.isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.accentColor,
                                ),
                              )
                            : Icon(
                                isActive
                                    ? Icons.graphic_eq_rounded
                                    : (isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.playlist_play_rounded),
                                color: (isActive || isExpanded)
                                    ? theme.accentColor
                                    : theme.textColor.withOpacity(0.4),
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Orta: Metin
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item["caption"] ?? '',
                              style: TextStyle(
                                color: (isActive || isExpanded)
                                    ? theme.accentColor
                                    : theme.textColor,
                                fontSize: 16,
                                fontWeight: (isActive || isExpanded)
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                            if (!isExpanded && item["explanation"] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item["explanation"],
                                style: TextStyle(
                                  color: theme.textColor.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (!isExpanded && isActive)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Aktif',
                            style: TextStyle(
                              color: theme.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Genişleyen Bölüm
                  AnimatedCrossFade(
                    firstChild: SizedBox(width: double.infinity),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Divider(color: theme.textColor.withOpacity(0.05)),
                        const SizedBox(height: 8),
                        Text(
                          item["explanation"] ?? '',
                          style: TextStyle(
                            color: theme.textColor.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.isLoading ? null : widget.onPlay,
                            icon: Icon(Icons.play_arrow_rounded, size: 24),
                            label: Text(
                              'Dinle',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
