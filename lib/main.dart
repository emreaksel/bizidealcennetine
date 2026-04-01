import 'package:flutter/material.dart';
import 'yaveran/Degiskenler.dart';
import 'yaveran/logic.dart';
import 'widgets/splash_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());

  if (!Degiskenler.hazirlaniyor) {
    arkaplanIslemleri();
  }

  initUniLinks(handleLink);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        title: 'Biz İdeal Cennetine',
        debugShowCheckedModeBanner: false,
        home: SplashScreenWidget(
          onComplete: () {
            setState(() {
              _showSplash = false;
            });
          },
          displayDuration: Duration(seconds: 5),
          animationDuration: Duration(milliseconds: 800),
        ),
      );
    }

    return MaterialApp(
      title: 'Biz İdeal Cennetine',
      debugShowCheckedModeBanner: false,
      home: WillPopScope(
        onWillPop: () async {
          FocusScope.of(context).unfocus();
          return true;
        },
        child: MainScreen(),
      ),
    );
  }
}
