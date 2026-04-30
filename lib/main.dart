import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'yaveran/Degiskenler.dart';
import 'yaveran/logic.dart';
import 'widgets/splash_screen.dart';
import 'screens/main_screen.dart';
import 'yaveran/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService().info("Uygulama başlatılıyor...", tag: "System");

  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics'i yapılandır
  FlutterError.onError = (errorDetails) {
    LogService().error("Flutter Hatası: ${errorDetails.exception}", tag: "System");
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Platform tabanlı hataları yakala (Asenkron hatalar vb.)
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService().error("Asenkron Hata: $error", tag: "System");
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Bildirim çubuğunu gizle ve tam ekran moduna geç (Odaklanmayı artırmak için)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(MyApp());

  // Önce linkleri kontrol et (iOS cold start için kritik)
  await initUniLinks(handleLink);

  if (!Degiskenler.hazirlaniyor) {
    await arkaplanIslemleri();
  }
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
        title: 'Ateşi Aşk',
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
