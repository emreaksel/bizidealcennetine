import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class AkanYazi extends StatelessWidget {
  final String? text;

  const AkanYazi([this.text, Key? key]) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double yaziBoyutu = screenHeight * 0.019;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 1),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withOpacity(0.45),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              top: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
              left: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
              right: BorderSide(
                  color: theme.textColor.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: Degiskenler.currentEpigramNotifier,
            builder: (_, title, __) {
              
              return RepaintBoundary(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [
                        Colors.transparent, 
                        Colors.black,
                        Colors.black,
                        Colors.transparent, 
                      ],
                      stops: [0.0, 0.17, 0.83, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  
                  child: SizedBox(
                    height: yaziBoyutu * 1.5,
                    child: Marquee(
                      text: title.isNotEmpty ? title : " ",
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.9),
                        fontSize: yaziBoyutu,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      
                      blankSpace: screenWidth, 
                      
                      // ========================================================
                      // ÇÖZÜM: SAĞDAN PÜRÜZSÜZ GİRİŞ
                      // ========================================================
                      // İlk açılışta metnin tam ekran genişliği kadar 
                      // sağdan başlamasını sağlar. Böylece metin boş ekrana 
                      // pürüzsüzce sağ dışarıdan giriş yapar.
                      startPadding: screenWidth, 
                      // ========================================================
                      
                      velocity: 30.0, 
                      pauseAfterRound: const Duration(milliseconds: 100),
                      
                      showFadingOnlyWhenScrolling: true,
                      fadingEdgeStartFraction: 0.3,
                      fadingEdgeEndFraction: 0.3,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}