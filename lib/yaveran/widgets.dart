

import 'package:bizidealcennetine/main.dart';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'AudioService.dart';
import 'Notifier.dart';
import 'audio_video_progress_bar.dart';

final AudioService _audioService = AudioService(); // AudioService nesnesini oluşturun
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
                _audioService.play();
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
                _audioService.pause();
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
              _audioService.seek(duration);
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
                  _audioService.repeat();
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
                  _audioService.repeat();
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
                  _audioService.previous();
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
                  _audioService.next();
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
class AlternativeListButton extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    return FloatingActionButton(
        onPressed: () {
          // Your button functionality here
          // For example, you can navigate to another screen or perform an action
          ekranboyut_ana(2);
          print("CLICK ustEkranAktifIndex = 2;");
        },
        child: SvgPicture.asset(
          'assets/icons/playlist.svg',
          width: calculateIconSize(context)*0.8,
          height: calculateIconSize(context)*0.8,
          //color: Colors.red, // İstenilen rengi belirtin
        )
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
      opacity: 1.0, // 0.0, yani tamamen şeffaf olacak şekilde ayarlanmıştır
      child: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/kalp_duru.svg',
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

