import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'audio_service.dart';
import 'Notifier.dart';
import 'audio_video_progress_bar.dart';
import 'dart:math' as math;
import 'MusicApiService.dart';
import 'ui_support.dart';
import 'app_theme.dart';

// Responsive Tasarım Yardımcısı
class UISize {
  static const double textMultiplier = 0.087;
  static const double iconMultiplier = 0.17;

  static double calculate(BuildContext context, double multiplier,
      {double min = 10.0, double max = 50.0}) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double panelHeight =
        screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100);
    return (panelHeight * multiplier).clamp(min, max);
  }

  static double fontSize(BuildContext context) =>
      calculate(context, textMultiplier, min: 14.0, max: 24.0);
  static double iconSize(BuildContext context) =>
      calculate(context, iconMultiplier, min: 24.0, max: 48.0);
}

class PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ButtonState>(
      valueListenable: AudioService.playButtonNotifier,
      builder: (_, value, __) {
        final theme = Degiskenler.currentThemeNotifier.value;
        switch (value) {
          case ButtonState.loading:
            return Container(
              width: UISize.iconSize(context) * 0.8,
              height: UISize.iconSize(context) * 0.8,
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.accentColor,
              ),
            );
          case ButtonState.paused:
            return IconButton(
              icon: SvgPicture.asset(
                'assets/icons/play.svg',
                width: UISize.iconSize(context) * 0.8,
                height: UISize.iconSize(context) * 0.8,
              ),
              onPressed: () {
                AudioService.play();
              },
            );
          case ButtonState.playing:
            return IconButton(
              icon: SvgPicture.asset(
                'assets/icons/pause.svg',
                width: UISize.iconSize(context) * 0.8,
                height: UISize.iconSize(context) * 0.8,
              ),
              onPressed: () {
                AudioService.pause();
              },
            );
        }
      },
    );
  }
}

class CurrentSongTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AudioService.currentSongTitleNotifier,
      builder: (_, title, __) {
        return ValueListenableBuilder<AppTheme>(
          valueListenable: Degiskenler.currentThemeNotifier,
          builder: (context, theme, _) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: UISize.fontSize(context),
                  color: theme.textColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CurrentSongSubTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AudioService.currentSongSubTitleNotifier,
      builder: (_, title, __) {
        return ValueListenableBuilder<AppTheme>(
          valueListenable: Degiskenler.currentThemeNotifier,
          builder: (context, theme, _) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: UISize.fontSize(context),
                  color: theme.textColor.withOpacity(0.6),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SeekBar extends StatelessWidget {
  const SeekBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19.0),
      // Kenarlara 16 piksellik padding ekleyin
      child: ValueListenableBuilder2<ProgressBarState, AppTheme>(
        first: AudioService.progressNotifier,
        second: Degiskenler.currentThemeNotifier,
        builder: (context, value, theme, _) {
          return ProgressBar(
            progress: value.current,
            buffered: value.buffered,
            total: value.total,
            onSeek: (duration) {
              AudioService.seek(duration);
            },
            progressBarColor: theme.accentColor,
            baseBarColor: theme.textColor.withOpacity(0.12),
            bufferedBarColor: theme.textColor.withOpacity(0.08),
            thumbColor: theme.accentColor,
            barCapShape: BarCapShape.round,
            timeLabelTextStyle: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
            timeLabelLocation: TimeLabelLocation.sides,
            barHeight: 8.0,
            thumbRadius: 11.0,
            thumbBorderThickness: 0,
            thumbGlowRadius: 24,
          );
        },
      ),
    );
  }
}

class RepeatButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RepeatState>(
      valueListenable: AudioService.repeatButtonNotifier,
      builder: (context, value, child) {
        switch (value) {
          case RepeatState.off:
            return IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/shuffle.svg',
                  width: UISize.iconSize(context),
                  height: UISize.iconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: UISize.iconSize(context),
                onPressed: () {
                  AudioService.repeat();
                });
          case RepeatState.on:
            return IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/repeat.svg',
                  width: UISize.iconSize(context),
                  height: UISize.iconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: UISize.iconSize(context),
                onPressed: () {
                  AudioService.repeat();
                });
        }
      },
    );
  }
}

class PreviousSongButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ButtonState>(
      valueListenable: AudioService.playButtonNotifier,
      builder: (_, value, __) {
        return IconButton(
            icon: SvgPicture.asset(
              'assets/icons/previous.svg',
              width: UISize.iconSize(context),
              height: UISize.iconSize(context),
              colorFilter: value == ButtonState.loading
                  ? ColorFilter.mode(
                      Degiskenler.currentThemeNotifier.value.textColor
                          .withOpacity(0.3),
                      BlendMode.srcIn)
                  : null,
            ),
            iconSize: UISize.iconSize(context),
            onPressed: value == ButtonState.loading
                ? null
                : () {
                    AudioService.previous();
                  });
      },
    );
  }
}

class NextSongButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ButtonState>(
      valueListenable: AudioService.playButtonNotifier,
      builder: (_, value, __) {
        return IconButton(
            icon: SvgPicture.asset(
              'assets/icons/next.svg',
              width: UISize.iconSize(context),
              height: UISize.iconSize(context),
              colorFilter: value == ButtonState.loading
                  ? ColorFilter.mode(
                      Degiskenler.currentThemeNotifier.value.textColor
                          .withOpacity(0.3),
                      BlendMode.srcIn)
                  : null,
            ),
            iconSize: UISize.iconSize(context),
            onPressed: value == ButtonState.loading
                ? null
                : () {
                    AudioService.next();
                  });
      },
    );
  }
}

class ListButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: SvgPicture.asset(
          'assets/icons/playlist.svg',
          width: UISize.iconSize(context) * 0.8,
          height: UISize.iconSize(context) * 0.8,
          //color: Colors.red, // İstenilen rengi belirtin
        ),
        onPressed: () {
          UI_support.ekranboyut_minik(1);
          print("CLICK ListButton ustEkranAktifIndex = 1;");
        });
  }
}

class AlternativeListButton extends StatefulWidget {
  @override
  _AlternativeListButtonState createState() => _AlternativeListButtonState();
}

class _AlternativeListButtonState extends State<AlternativeListButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _gradientAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();

    // Basma animasyonu için controller
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Gradient animasyonu için controller
    _gradientAnimationController = AnimationController(
      duration: Duration(seconds: 13),
      vsync: this,
    )..repeat(); // Sürekli tekrar et

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Gradient animasyonu
    _gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gradientAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gradientAnimationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  // Animasyonlu gradient renkleri (Tema uyumlu)
  List<Color> _getAnimatedGradientColors(AppTheme theme) {
    final accent = theme.accentColor;

    // Temanın accent rengine dayalı 3 farklı ton
    return [
      accent,
      accent.withOpacity(0.7),
      accent.withOpacity(0.9),
    ];
  }

  // Animasyonlu radial gradient merkezi
  Alignment _getAnimatedCenter() {
    final progress = _gradientAnimation.value;
    final angle = progress * 2 * math.pi;
    return Alignment(
      math.cos(angle) * 0.4,
      math.sin(angle) * 0.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return AnimatedBuilder(
          animation: Listenable.merge(
              [_animationController, _gradientAnimationController]),
          builder: (context, child) {
            final animatedColors = _getAnimatedGradientColors(theme);

            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  onTap: () {
                    UI_support.ekranboyut_ana(2);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: animatedColors,
                        center: _getAnimatedCenter(),
                        radius: 1.2,
                        stops: const [0.0, 0.6, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/playlist.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
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
}

class BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
        icon: SvgPicture.asset(
          'assets/icons/back.svg',
          width: UISize.iconSize(context),
          height: UISize.iconSize(context),
          //color: Colors.red, // İstenilen rengi belirtin
        ),
        onPressed: () {
          UI_support.ekranboyut_ana(0);
          print("CLICK BackButton ustEkranAktifIndex = 0;");
        });
  }
}

class ShareButton extends StatefulWidget {
  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  // GlobalKey ile RenderBox'ı her koşulda doğru alıyoruz (iOS cold start dahil)
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return IconButton(
          key: _buttonKey,
          icon: Transform.scale(
            scale: 1.15,
            child: SvgPicture.asset(
              'assets/icons/bird.svg',
              width: UISize.iconSize(context),
              height: UISize.iconSize(context),
              colorFilter: ColorFilter.mode(
                theme.textColor.withOpacity(0.7),
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () {
            if (Degiskenler.parcaIndex == -1) return;

            String shareLink =
                'https://benolanben.com/dinle/${Degiskenler.liste_link}&${Degiskenler.parcaIndex}';
            try {
              for (var item in Degiskenler.songListNotifier.value) {
                if (item['sira_no']?.toString() ==
                    Degiskenler.parcaIndex.toString()) {
                  if (item['hyperlink'] != null &&
                      item['hyperlink'].toString().isNotEmpty) {
                    shareLink = 'https://benolanben.com/${item['hyperlink']}';
                  }
                  break;
                }
              }
            } catch (e) {
              print("Share error: $e");
            }

            // iOS/iPad: GlobalKey üzerinden RenderBox alıyoruz.
            // StatelessWidget'ta context.findRenderObject() cold start'ta
            // yanlış koordinat dönebilir; GlobalKey bunu engeller.
            final renderBox =
                _buttonKey.currentContext?.findRenderObject() as RenderBox?;
            Rect? sharePositionOrigin;
            if (renderBox != null && renderBox.hasSize) {
              sharePositionOrigin =
                  renderBox.localToGlobal(Offset.zero) & renderBox.size;
            }

            Share.share(
              shareLink,
              sharePositionOrigin: sharePositionOrigin,
            );
          },
        );
      },
    );
  }
}

class LikeButton extends StatefulWidget {
  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  final MusicApiService _apiService = MusicApiService();
  bool _isLiked = false;
  bool _isLoading = false;

  static int _lastCheckedIndex = -1;
  static bool _lastCheckedStatus = false;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
    AudioService.currentSongTitleNotifier.addListener(_checkLikeStatus);
  }

  @override
  void dispose() {
    AudioService.currentSongTitleNotifier.removeListener(_checkLikeStatus);
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    if (!mounted) return;

    if (Degiskenler.parcaIndex != -1) {
      // Eğer zaten bu şarkıyı kontrol ettiysek tekrar sorma
      if (_lastCheckedIndex == Degiskenler.parcaIndex) {
        if (mounted) setState(() => _isLiked = _lastCheckedStatus);
        return;
      }

      // ŞARKı DEĞİŞTİ: Yeni şarkı kontrol edilirken butonu hemen sıfırla (Sticky state önleyici)
      if (mounted) {
        setState(() {
          _isLiked = false; 
          _isLoading = true;
        });
      }

      // 1. Senkronize liste üzerinden hızlı kontrol (İnternet gerekmez)
      if (Degiskenler.isSyncedNotifier.value) {
        bool inLikes = Degiskenler.myLikesNotifier.value.any((liked) =>
            liked['sira_no'].toString() == Degiskenler.parcaIndex.toString());
        
        _lastCheckedIndex = Degiskenler.parcaIndex;
        _lastCheckedStatus = inLikes;
        
        if (mounted) {
          setState(() {
            _isLiked = inLikes;
            _isLoading = false;
          });
        }
        return;
      }
      try {
        final token = await _apiService.storage.read(key: 'jwt_token');
        if (token != null) {
          bool liked =
              await _apiService.checkLikeStatus(Degiskenler.parcaIndex);
          _lastCheckedIndex = Degiskenler.parcaIndex;
          _lastCheckedStatus = liked;
          if (mounted) {
            setState(() {
              _isLiked = liked;
            });
          }
        }
      } catch (e) {
        print("Like status check error: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCodeEntryDialog() async {
    final TextEditingController codeController = TextEditingController();
    bool isDialogLoading = false;
    String? errorMessage;
    final theme = Degiskenler.currentThemeNotifier.value;

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.backgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.important_devices_rounded,
                      color: theme.accentColor),
                  const SizedBox(width: 12),
                  Text('Cihaz Eşleştirme',
                      style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStep(
                      1,
                      InkWell(
                        onTap: () async {
                          final url =
                              Uri.parse('https://benolanben.com/atesiask');
                          try {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          } catch (e) {
                            debugPrint('URL açılamadı: $url, Hata: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.accentColor.withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.open_in_browser_rounded,
                                  color: theme.accentColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                    'benolanben.com/atesiask\nAdresine gitmek için Tıklayın',
                                    style: TextStyle(
                                        color: theme.accentColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      theme,
                    ),
                    _buildStep(
                      2,
                      Text(
                          'Tarayıcıda açılan sayfada sağ üstten Apple veya Google hesabınızla giriş yapın.',
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4)),
                      theme,
                    ),
                    _buildStep(
                      3,
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4),
                          children: [
                            TextSpan(
                                text: 'Ekranda sol üstteki senkronizasyon ('),
                            WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(Icons.cloud_sync_rounded,
                                    size: 18,
                                    color: theme.textColor.withOpacity(0.9))),
                            TextSpan(text: ') simgesine dokunun.'),
                          ],
                        ),
                      ),
                      theme,
                    ),
                    _buildStep(
                      4,
                      Text(
                          'Ekranda beliren 6 haneli cihaz kodunu aşağıdaki alana girin.',
                          style: TextStyle(
                              color: theme.textColor.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.4)),
                      theme,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: TextStyle(
                          color: theme.textColor,
                          fontSize: 32,
                          letterSpacing: 14,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle:
                            TextStyle(color: theme.textColor.withOpacity(0.1)),
                        errorText: errorMessage,
                        counterText: "",
                        filled: true,
                        fillColor: theme.textColor.withOpacity(0.03),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: theme.textColor.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: theme.accentColor, width: 2)),
                      ),
                    ),
                    if (isDialogLoading)
                      Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                                color: theme.accentColor)),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                      isDialogLoading ? null : () => Navigator.pop(context),
                  child: Text('İptal',
                      style: TextStyle(
                          color: theme.textColor.withOpacity(0.5),
                          fontSize: 15)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(
                                () => errorMessage = 'Kod 6 haneli olmalıdır.');
                            return;
                          }
                          setDialogState(() {
                            isDialogLoading = true;
                            errorMessage = null;
                          });
                          final success =
                              await _apiService.exchangeCodeWithServer(code);
                          if (success) {
                            if (mounted) {
                              Navigator.pop(context);
                              _checkLikeStatus();
                            }
                          } else {
                            setDialogState(() {
                              isDialogLoading = false;
                              errorMessage = 'Hatalı kod veya sunucu hatası.';
                            });
                          }
                        },
                  child: Text('Doğrula',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            );
          });
        });
  }

  Widget _buildStep(int number, Widget content, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(
                top: 2), // Metinle hizalamak için ufak pay
            decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.15),
                shape: BoxShape.circle),
            child: Center(
              child: Text('$number',
                  style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _handleLikeToggle() async {
    if (_isLoading) return;

    final token = await _apiService.storage.read(key: 'jwt_token');
    if (token == null) {
      await _showCodeEntryDialog();
      final tokenAfter = await _apiService.storage.read(key: 'jwt_token');
      if (tokenAfter == null) return;
      _checkLikeStatus();
    } else {
      if (Degiskenler.parcaIndex != -1) {
        setState(() {
          _isLoading = true;
          _isLiked = !_isLiked;
        });

        try {
          // Beğenme işlemi yapıldıysa kuşları uçur (30 saniye)
          if (_isLiked) {
            Degiskenler.birdTriggerNotifier.value = true;
          }

          final success = await _apiService.toggleLike(Degiskenler.parcaIndex);
          if (success) {
            _lastCheckedStatus = _isLiked;
            final likes = await _apiService.fetchMyLikes(limit: 500);
            Degiskenler.myLikesNotifier.value = likes;
          } else {
            if (mounted) {
              setState(() {
                _isLiked = !_isLiked;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('İşlem başarısız oldu.')));
            }
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return IconButton(
          icon: _isLoading
              ? SizedBox(
                  width: UISize.iconSize(context) * 0.5,
                  height: UISize.iconSize(context) * 0.5,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentColor,
                  ),
                )
              : Transform.scale(
                  scale: 1.15, // İnce çizgiyi telafi etmek için büyüt
                  child: SvgPicture.asset(
                    _isLiked
                        ? 'assets/icons/kalp_yanan.svg'
                        : 'assets/icons/kalp.svg',
                    width: UISize.iconSize(context),
                    height: UISize.iconSize(context),
                    colorFilter: _isLiked
                        ? ColorFilter.mode(theme.accentColor, BlendMode.srcIn)
                        : ColorFilter.mode(
                            theme.textColor.withOpacity(0.7), BlendMode.srcIn),
                  ),
                ),
          iconSize: UISize.iconSize(context),
          onPressed: _isLoading ? null : _handleLikeToggle,
        );
      },
    );
  }
}

class AudioControlButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<int, AppTheme>(
      first: Degiskenler.altEkranBoyutNotifier,
      second: Degiskenler.currentThemeNotifier,
      builder: (context, altEkranBoyutValue, theme, _) {
        bool showTrackNames = altEkranBoyutValue >= 20;

        return Container(
          decoration: showTrackNames
              ? BoxDecoration(
                  color: theme.backgroundColor,
                  border: Border(
                      top:
                          BorderSide(color: theme.textColor.withOpacity(0.05))),
                )
              : BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(27.0),
                    topRight: Radius.circular(27.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Dikeyde ortala
            children: [
              if (showTrackNames)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 3.0),
                          child: Row(
                            children: [
                              LikeButton(),
                              Expanded(
                                child: Column(
                                  children: [
                                    CurrentSongTitle(),
                                    CurrentSongSubTitle(),
                                  ],
                                ),
                              ),
                              ShareButton(),
                            ],
                          ),
                        ),
                        SeekBar(),
                      ],
                    )
                  ],
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showTrackNames) ListButton() else BackButton(),

                    // Orta Grup (Geri, Oynat, İleri) - Merkeze daha yakın
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PreviousSongButton(),
                        const SizedBox(
                            width:
                                24), // 8 -> 24 yapıldı, birbirine girmesinler
                        PlayButton(),
                        const SizedBox(
                            width:
                                24), // 8 -> 24 yapıldı, birbirine girmesinler
                        NextSongButton(),
                      ],
                    ),

                    RepeatButton(),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class UserSyncIcon extends StatelessWidget {
  final MusicApiService _apiService = MusicApiService();

  void _showLogoutDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Oturumu Sırla',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: const Text(
                  'Cihazın senkronizasyonunu dinlendirmek istiyor musunuz?',
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Şimdi Değil',
                      style: TextStyle(color: Colors.white70)),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _apiService.logout();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Cihaz bağlantısı başarıyla dinlendirildi.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    child: const Text('Evet',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Degiskenler.isSyncedNotifier,
      builder: (context, isSynced, child) {
        return IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSynced
                  ? Colors.green.withOpacity(0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: isSynced
                  ? const Color(0xFF00E676)
                  : Colors.white.withOpacity(0.4),
              size: 28.0,
            ),
          ),
          tooltip: isSynced ? 'Dokunanlar' : 'Bağlı Değil',
          onPressed: () {
            if (isSynced) {
              _showLogoutDialog(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Eşleştirme için bir parçaya dokunarak (beğenerek) başlayabilirsiniz.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    Key? key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  }) : super(key: key);

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget? child;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
        valueListenable: first,
        builder: (context, a, _) => ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) => builder(context, a, b, child),
        ),
      );
}
