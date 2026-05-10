import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:bizidealcennetine/firebase_options.dart';
import 'package:bizidealcennetine/services/Degiskenler.dart';
import 'package:bizidealcennetine/services/arkaplanislemleri.dart';
import 'package:bizidealcennetine/widgets/splash_screen.dart';
import 'package:bizidealcennetine/screens/main_screen.dart';
import 'package:bizidealcennetine/services/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogService().info("Uygulama başlatılıyor...", tag: "System");

  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics'i yapılandır
  FlutterError.onError = (errorDetails) {
    LogService()
        .error("Flutter Hatası: ${errorDetails.exception}", tag: "System");
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
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    Degiskenler.showSplashNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Degiskenler.showSplashNotifier.value) {
      return MaterialApp(
        title: 'Ateşi Aşk',
        debugShowCheckedModeBanner: false,
        home: SplashScreenWidget(
          onComplete: () async {
            // Hazırlık devam etmiyorsa VE liste henüz yüklenmediyse işlemleri başlat
            if (!Degiskenler.hazirlaniyor && !Degiskenler.listeYuklendi) {
              arkaplanIslemleri(); // await YOK — arka planda devam eder
            }
            // Splash ekranını hemen kapat, işlemler arka planda sürsün
            Degiskenler.showSplashNotifier.value = false;
          },
          displayDuration: const Duration(seconds: 5),
          animationDuration: const Duration(milliseconds: 800),
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
