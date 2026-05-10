import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/Degiskenler.dart';
import '../yaveran/widgets.dart';
import '../services/audio/audio_service.dart';
import '../services/Notifier.dart';
import '../widgets/visuals.dart';
import '../widgets/confetti.dart';
import '../widgets/dialogs.dart';
import '../widgets/settings_menu.dart';
import 'listeler_ekrani.dart';
import 'diger_listeler_ekrani.dart';
import '../yaveran/app_theme.dart';
import '../widgets/kus_kelebek.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MyCustomLayout(),
      ),
    );
  }
}

class MyCustomLayout extends StatefulWidget {
  @override
  _MyCustomLayoutState createState() => _MyCustomLayoutState();
}

class _MyCustomLayoutState extends State<MyCustomLayout> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Stack(
          children: [
            Container(
              color: theme.backgroundColor,
              child: Column(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: Degiskenler.ustEkranIndexNotifier,
                      builder: (context, value, child) {
                        return IndexedStack(
                          index: value,
                          children: [
                            GestureDetector(
                              onTapDown: (details) {
                                if (math.Random().nextDouble() < 0.01) {
                                  Degiskenler.butterflyTriggerNotifier.value =
                                      true;
                                } else {
                                  Degiskenler.confettiTriggerNotifier.value =
                                      ConfettiTriggerData(
                                          details.localPosition);
                                }
                              },
                              child: ImprovedConfettiDemo(
                                child: KenBurnsViewWidget(
                                  backWidget: AkanYazi(""),
                                ),
                              ),
                            ),
                            ListeWidget(),
                            DinlemeListesiWidget(),
                          ],
                        );
                      },
                    ),
                  ),
                  AudioControlButtons(),
                ],
              ),
            ),
            Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: Degiskenler.showDialogNotifier,
                    builder: (context, goster, child) {
                      return Visibility(
                        visible: goster,
                        child: Align(
                          alignment: Alignment.center,
                          child: CustomDialog(
                              icerik: Degiskenler.currentNoticeNotifier.value),
                        ),
                      );
                    },
                  ),
                ),
                // --- YENİ DÜZENLEME ---
                // İki farklı yükleme durumunu dinleyerek SpiritualLoader'ı anında tetikliyoruz.
                ValueListenableBuilder<bool>(
                  // 1. DURUM: Playlist'in hazırlanma durumu (manuel tetikleme).
                  valueListenable: AudioService.playlistLoadingNotifier,
                  builder: (context, isPlaylistLoading, child) {
                    return ValueListenableBuilder<ButtonState>(
                      // 2. DURUM: Player'ın kendi yükleme/buffer durumu.
                      valueListenable: AudioService.playButtonNotifier,
                      builder: (context, buttonState, child) {
                        // İki durumdan herhangi biri "yükleniyor" ise loader'ı göster.
                        final bool isPlayerLoading =
                            (buttonState == ButtonState.loading);
                        final bool shouldShowLoader =
                            isPlaylistLoading || isPlayerLoading;

                        return SpiritualLoader(
                          isLoading: shouldShowLoader,
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: ValueListenableBuilder<int>(
                    valueListenable: Degiskenler.ustEkranIndexNotifier,
                    builder: (context, value, child) {
                      return Visibility(
                        visible: value == 0,
                        child: SettingsMenu(),
                      );
                    },
                  ),
                ),
              ],
            ),
            const IgnorePointer(child: ButterflyOverlay()),
          ],
        );
      },
    );
  }
}
