import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/widgets.dart';
import '../yaveran/audio_service.dart';
import '../yaveran/Notifier.dart';
import '../widgets/visuals.dart';
import '../widgets/confetti.dart';
import '../widgets/dialogs.dart';
import '../widgets/settings_menu.dart';
import 'playlist_screen.dart';
import 'discovery_screen.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: MyCustomLayout(),
        ),
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
                        ImprovedConfettiDemo(
                          child: KenBurnsViewWidget(
                            backWidget: AkanYazi(""),
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
            ValueListenableBuilder<ButtonState>(
              valueListenable: AudioService.playButtonNotifier,
              builder: (context, value, child) {
                switch (value) {
                  case ButtonState.loading:
                    return Align(
                      alignment: Alignment.center,
                      child: LoadingWidget(),
                    );
                  default:
                    return Container();
                }
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
      ],
        );
      },
    );
  }
}
