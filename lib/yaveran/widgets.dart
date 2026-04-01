import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'audio_service.dart';
import 'Notifier.dart';
import 'audio_video_progress_bar.dart';
import 'dart:math' as math;
import 'MusicApiService.dart';
import 'ui_support.dart';

double calculateIconSize(BuildContext context) {
  double screenHeight = MediaQuery.of(context).size.height;
  double iconSize =
      screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100) * 0.19;
  return iconSize;
}

double calculateFontSize(BuildContext context) {
  double screenHeight = MediaQuery.of(context).size.height;
  double fontSize =
      screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100) * 0.11;
  return fontSize;
}

class PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ButtonState>(
      valueListenable: AudioService.playButtonNotifier,
      builder: (_, value, __) {
        switch (value) {
          case ButtonState.paused:
            return IconButton(
              icon: SvgPicture.asset(
                'assets/icons/play.svg',
                width: calculateIconSize(context) * 0.8,
                height: calculateIconSize(context) * 0.8,
                //color: Colors.red, // İstenilen rengi belirtin
              ),
              // Dinamik ikon boyutu kullanılıyor
              onPressed: () {
                AudioService.play();
              },
            );
          case ButtonState.playing || ButtonState.loading:
            return IconButton(
              icon: SvgPicture.asset(
                'assets/icons/pause.svg',
                width: calculateIconSize(context) * 0.8,
                height: calculateIconSize(context) * 0.8,
                //color: Colors.red, // İstenilen rengi belirtin
              ),
              // Dinamik ikon boyutu kullanılıyor
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
                  fontSize: calculateFontSize(context),
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
                  fontSize: calculateFontSize(context),
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
              letterSpacing: 0.5
            ),
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
                  width: calculateIconSize(context),
                  height: calculateIconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: calculateIconSize(context),
                onPressed: () {
                  AudioService.repeat();
                });
          case RepeatState.on:
            return IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/repeat.svg',
                  width: calculateIconSize(context),
                  height: calculateIconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: calculateIconSize(context),
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
        switch (value) {
          case ButtonState.loading:
            return Container(
              margin: const EdgeInsets.all(8.0),
              width: 32.0,
              height: 32.0,
              /*child: const CircularProgressIndicator(),*/
            );
          case ButtonState.paused || ButtonState.playing:
            return IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/previous.svg',
                  width: calculateIconSize(context),
                  height: calculateIconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: calculateIconSize(context),
                onPressed: () {
                  AudioService.previous();
                });
        }
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
        switch (value) {
          case ButtonState.loading:
            return Container(
              margin: const EdgeInsets.all(8.0),
              width: 32.0,
              height: 32.0,
              /*child: const CircularProgressIndicator(),*/
            );
          case ButtonState.paused || ButtonState.playing:
            return IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/next.svg',
                  width: calculateIconSize(context),
                  height: calculateIconSize(context),
                  //color: Colors.red, // İstenilen rengi belirtin
                ),
                iconSize: calculateIconSize(context),
                onPressed: () {
                  AudioService.next();
                });
        }
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
          width: calculateIconSize(context) * 0.8,
          height: calculateIconSize(context) * 0.8,
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
          width: calculateIconSize(context),
          height: calculateIconSize(context),
          //color: Colors.red, // İstenilen rengi belirtin
        ),
        onPressed: () {
          UI_support.ekranboyut_ana(0);
          print("CLICK BackButton ustEkranAktifIndex = 0;");
        });
  }
}

class ShareButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return IconButton(
          icon: Transform.scale(
            scale: 1.15, // Görsel ağırlığı dengelemek için hafifçe büyüt
            child: SvgPicture.asset(
              'assets/icons/bird.svg',
              width: calculateIconSize(context),
              height: calculateIconSize(context),
              colorFilter: ColorFilter.mode(
                theme.textColor.withOpacity(0.7), // Daha belirgin (0.5 -> 0.7)
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () {
            if (Degiskenler.hediyeninIndex.toInt() != Degiskenler.parcaIndex) {
              Share.share(
                  'https://benolanben.com/dinle/${Degiskenler.liste_link}&${Degiskenler.parcaIndex}');
            }
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
    if (Degiskenler.parcaIndex != -1) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final token = await _apiService.storage.read(key: 'jwt_token');
        if (token != null) {
          bool liked =
              await _apiService.checkLikeStatus(Degiskenler.parcaIndex);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Cihaz Eşleştirme',
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep(1, 'https://benolanben.com/atesiask adresine gidin.', theme),
                    _buildStep(2, 'Sağ üstten Apple/Google ile giriş yapın.', theme),
                    _buildStep(3, 'Sol üstteki senkronizasyon (bulut) simgesine basın.', theme),
                    _buildStep(4, 'Ekranda gördüğünüz 6 haneli kodu aşağıya girin.', theme),
                    const SizedBox(height: 24),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: TextStyle(
                          color: theme.textColor, fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(color: theme.textColor.withOpacity(0.1)),
                        errorText: errorMessage,
                        counterText: "",
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.textColor.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.accentColor)),
                      ),
                    ),
                    if (isDialogLoading)
                      Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: theme.accentColor)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDialogLoading ? null : () => Navigator.pop(context),
                  child: Text('İptal',
                      style: TextStyle(color: theme.textColor.withOpacity(0.6))),
                ),
                TextButton(
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
                      style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          });
        });
  }

  Widget _buildStep(int number, String text, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: theme.accentColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Text('$number',
                style: TextStyle(color: theme.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: theme.textColor.withOpacity(0.8), fontSize: 13))),
        ],
      ),
    );
  }

  void _handleLikeToggle() async {
    final token = await _apiService.storage.read(key: 'jwt_token');
    if (token == null) {
      await _showCodeEntryDialog();
      final tokenAfter = await _apiService.storage.read(key: 'jwt_token');
      if (tokenAfter == null) return;
      _checkLikeStatus();
    } else {
      if (Degiskenler.parcaIndex != -1) {
        setState(() {
          _isLiked = !_isLiked;
        });
        final success = await _apiService.toggleLike(Degiskenler.parcaIndex);
        if (success) {
          // Başarılı olduğunda global dokunanlar listesini de yenileylim
          final likes = await _apiService.fetchMyLikes(limit: 50);
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
                  width: calculateIconSize(context) * 0.5,
                  height: calculateIconSize(context) * 0.5,
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
                    width: calculateIconSize(context),
                    height: calculateIconSize(context),
                    colorFilter: _isLiked
                        ? ColorFilter.mode(theme.accentColor, BlendMode.srcIn)
                        : ColorFilter.mode(theme.textColor.withOpacity(0.7), BlendMode.srcIn),
                  ),
                ),
          iconSize: calculateIconSize(context),
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
                  border: Border(top: BorderSide(color: theme.textColor.withOpacity(0.05))),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showTrackNames) ListButton() else BackButton(),
                    
                    // Orta Grup (Geri, Oynat, İleri) - Merkeze daha yakın
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PreviousSongButton(),
                        const SizedBox(width: 24), // 8 -> 24 yapıldı, birbirine girmesinler
                        PlayButton(),
                        const SizedBox(width: 24), // 8 -> 24 yapıldı, birbirine girmesinler
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
