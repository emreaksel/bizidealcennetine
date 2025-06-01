

import 'package:bizidealcennetine/main.dart';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'audio_service.dart';
import 'Notifier.dart';
import 'audio_video_progress_bar.dart';
import 'dart:math' as math;

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
                width: calculateIconSize(context)*0.8,
                height: calculateIconSize(context)*0.8,
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
                width: calculateIconSize(context)*0.8,
                height: calculateIconSize(context)*0.8,
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
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: calculateFontSize(context),
              // Dinamik font boyutu kullanılıyor
              color: Colors.white,
            ),
          ),
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
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: calculateFontSize(context),
              // Dinamik font boyutu kullanılıyor
              color: Colors.white,
            ),
          ),
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
      child: ValueListenableBuilder<ProgressBarState>(
        valueListenable: AudioService.progressNotifier,
        builder: (_, value, __) {
          return ProgressBar(
            progress: value.current,
            buffered: value.buffered,
            total: value.total,
            onSeek: (duration) {
              AudioService.seek(duration);
            },
            progressBarColor: Colors.white,
            baseBarColor: Colors.black,
            bufferedBarColor: Colors.black,
            thumbColor: Color(0xFFFF0000),
            barCapShape: BarCapShape.round,
            timeLabelTextStyle: TextStyle(color: Colors.white),
            timeLabelLocation: TimeLabelLocation.sides,
            barHeight: 5.0,
            thumbRadius: 10.0,
            thumbBorderThickness: 3.0,
            thumbBorderColor: Colors.black,
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
          width: calculateIconSize(context)*0.8,
          height: calculateIconSize(context)*0.8,
          //color: Colors.red, // İstenilen rengi belirtin
        ),
        onPressed: () {
          ekranboyut_minik(1);
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

  // Animasyonlu gradient renkleri
  List<Color> _getAnimatedGradientColors() {
    final progress = _gradientAnimation.value;
    
    // 6 farklı renk kombinasyonu arasında geçiş
    final colorSets = [
      [Colors.deepPurple.shade400, Colors.blue.shade400, Colors.purple.shade300],
      [Colors.blue.shade400, Colors.cyan.shade400, Colors.indigo.shade300],
      [Colors.cyan.shade400, Colors.teal.shade400, Colors.blue.shade300],
      [Colors.teal.shade400, Colors.green.shade400, Colors.cyan.shade300],
      [Colors.green.shade400, Colors.lime.shade400, Colors.teal.shade300],
      [Colors.lime.shade400, Colors.deepPurple.shade400, Colors.green.shade300],
    ];
    
    final currentIndex = (progress * (colorSets.length - 1)).floor();
    final nextIndex = (currentIndex + 1) % colorSets.length;
    final localProgress = (progress * (colorSets.length - 1)) - currentIndex;
    
    return [
      Color.lerp(colorSets[currentIndex][0], colorSets[nextIndex][0], localProgress)!,
      Color.lerp(colorSets[currentIndex][1], colorSets[nextIndex][1], localProgress)!,
      Color.lerp(colorSets[currentIndex][2], colorSets[nextIndex][2], localProgress)!,
    ];
  }

  // Animasyonlu radial gradient merkezi
  Alignment _getAnimatedCenter() {
    final progress = _gradientAnimation.value;
    final angle = progress * 2 * 3.14159; // 360 derece dönüş
    return Alignment(
      math.cos(angle) * 0.3, // Daha küçük hareket alanı
      math.sin(angle) * 0.3,
    );
  }

  // Animasyonlu radial gradient yarıçapı
  double _getAnimatedRadius() {
    final progress = _gradientAnimation.value;
    // 0.8 ile 1.2 arasında salınım
    return 0.8 + (math.sin(progress * 4 * 3.14159) * 0.2).abs();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _gradientAnimationController]),
      builder: (context, child) {
        final animatedColors = _getAnimatedGradientColors();
        
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: () {
                ekranboyut_ana(2);
                print("CLICK ustEkranAktifIndex = 2;");
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: animatedColors,
                    center: _getAnimatedCenter(),
                    radius: _getAnimatedRadius(),
                    stops: [0.0, 0.6, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: animatedColors[0].withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: animatedColors[1].withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                      spreadRadius: 1,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      center: Alignment.topLeft,
                      radius: 1.2,
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(2),
                      child: SvgPicture.asset(
                        'assets/icons/playlist.svg',
                        width: calculateIconSize(context) * 0.9,
                        height: calculateIconSize(context) * 0.9,
                        colorFilter: ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
          ekranboyut_ana(0);
          print("CLICK BackButton ustEkranAktifIndex = 0;");
        });
  }
}
class ShareButton extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    

    return IconButton(
      icon: SvgPicture.asset(
        'assets/icons/bird.svg',
        width: calculateIconSize(context),
        height: calculateIconSize(context),
        //color: Colors.red, // İstenilen rengi belirtin
      ),
      onPressed: () {
        print('INDEXXX ${Degiskenler.hediyeninIndex.toInt()}-${Degiskenler.parcaIndex}');
        if (Degiskenler.hediyeninIndex.toInt()!=Degiskenler.parcaIndex) Share.share('https://benolanben.com/dinle/${Degiskenler.liste_link}&${Degiskenler.parcaIndex}');
      },
    );
  }
}
class LikeButton extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    return Opacity(
      opacity: 0.0, // 0.0, yani tamamen şeffaf olacak şekilde ayarlanmıştır //1.0 görünür
      child: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/kalp_yanan.svg',
            width: calculateIconSize(context),
            height: calculateIconSize(context),
            //color: Colors.red, // İstenilen rengi belirtin
          ),
          iconSize: calculateIconSize(context),
          onPressed: () {
            //_audioService.repeat();
          }),
    );
  }
}

class AudioControlButtons extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Degiskenler.altEkranBoyutNotifier,
      builder: (context, altEkranBoyutValue, child) {
        bool showTrackNames = altEkranBoyutValue >= 20;

        return Container(
          decoration: showTrackNames
              ? const BoxDecoration(
            color: Colors.black,
          )
              : const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(27.0),
              topRight: Radius.circular(27.0),
            ),
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
                        Row(
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
                        SeekBar(),
                      ],
                    )
                  ],
                ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0), // Üst ve alt tarafta 16 birimlik padding ekler
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (showTrackNames)
                      ListButton()
                    else
                      BackButton(),
                    PreviousSongButton(),
                    PlayButton(),
                    NextSongButton(),
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



