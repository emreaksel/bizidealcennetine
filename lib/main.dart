import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:bizidealcennetine/yaveran/widgets.dart';
import 'package:bizidealcennetine/yaveran/Degiskenler.dart';
import 'package:bizidealcennetine/yaveran/Notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kenburns_nullsafety/kenburns_nullsafety.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'yaveran/HttpService.dart';
import 'yaveran/JsonHelper.dart';
import 'dart:math';
import 'dart:math' as math;
import 'yaveran/ui_support.dart';
import 'yaveran/audio_service.dart';

//flutter devices
//flutter run -d emulator-5554 --release

final Degiskenler degiskenler = Degiskenler();
//final AudioService _audioService = AudioService(); // AudioService nesnesini oluşturun

AkanYazi _akanYazi =
    AkanYazi("..."); // Varsayılan metni burada belirleyebilirsiniz
final appLinks = AppLinks(); // AppLinks instance oluştur

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());

  // AudioService'i app başladıktan sonra initialize et
  if (!Degiskenler.hazirlaniyor) {
    arkaplanIslemleri();
  }

  initUniLinks();
}

void arkaplanIslemleri() async {
  Degiskenler.hazirlaniyor = true;

  // AudioService'i burada initialize et - sadece bir kez
  try {
    print("Initializing AudioService...");
    await AudioService.init();
  } catch (e) {
    print("Error initializing AudioService: $e");
  }
  // Ana çağrı
  fetchData_jsonMenba("${Degiskenler.kaynakYolu}kaynak/menba.json");
  fetchData_jsonFotograflar("${Degiskenler.kaynakYolu}medya/images.json");
  fetchData_jsonSozler("${Degiskenler.kaynakYolu}kaynak/sozler.json");

  Degiskenler.hazirlaniyor = false;
}

void setPlaylist(data) async {
  print("setPlaylist called with ${data.length} items");

  List<dynamic> reversedData = data.reversed.toList();

  degiskenler.listDinle = reversedData;
  Degiskenler.songListNotifier.value = reversedData;

  List<AudioSource> playlist = [];
  for (var item in reversedData) {
    playlist.add(
      AudioSource.uri(
        Uri.parse(item['url']),
        tag: MediaItem(
          id: '${item['sira_no']}',
          album: item['parca_adi'],
          title: item['parca_adi'],
          artUri: Uri.parse(
            "${Degiskenler.kaynakYolu}medya/atesiask/0001_kus.jpg",
          ),
          artist: item['seslendiren'],
        ),
      ),
    );
  }

  // AudioService.setPlaylist artık initialization'ı bekleyecek
  //await Future.delayed(Duration(seconds: 10));

  await AudioService.setPlaylist(playlist);
  print("Playlist set successfully");
}

Future<void> initUniLinks() async {
  // Platform messages may fail, so we use a try/catch PlatformException.
  try {
    // İlk linki al
    final initialLink = await appLinks.getInitialLink();
    print("initialLink $initialLink");

    if (initialLink != null) {
      handleLink(initialLink.toString());
      /*Degiskenler.currentNoticeNotifier.value = initialLink;
    Degiskenler.showDialogNotifier.value = true;*/
    }

    // Dinleme
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print("uriLinkStream $uri");
        handleLink(uri.toString());
      }
    });
  } on PlatformException {
    // Handle exception by warning the user their action did not succeed
    // return?
  }
}

void handleLink(String? link) {
  if (link != null) {
    Degiskenler.currentNoticeNotifier.value = link.toString();
    Degiskenler.showDialogNotifier.value = true;
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

    // Mevcut yapın aynen korunuyor
    return MaterialApp(
      home: WillPopScope(
        //geri tuşunu dinlemek için
        onWillPop: () async {
          /*bool shouldExit = await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Çıkmak istediğinize emin misiniz?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text('Hayır'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Evet'),
                  ),
                ],
              );
            },
          );*/
          FocusScope.of(context).unfocus(); // Klavyeyi gizler
          return true; // Geri tuşuna izin verir
        },
        child: MainScreen(),
      ),
    );
  }
}


class MyApp_old extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WillPopScope(
        //geri tuşunu dinlemek için
        onWillPop: () async {
          /*bool shouldExit = await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Çıkmak istediğinize emin misiniz?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text('Hayır'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Evet'),
                  ),
                ],
              );
            },
          );*/
          FocusScope.of(context).unfocus(); // Klavyeyi gizler
          return true; // Geri tuşuna izin verir
        },

        child: MainScreen(),
      ),
    );
  }
}

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
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: Degiskenler.ustEkranIndexNotifier,
                  builder: (context, value, child) {
                    return IndexedStack(
                      index: value,
                      children: [
                        ImprovedConfettiDemo(),
                        // ImprovedConfettiWidget(
                        //     config: ConfettiPresets.createCustom(
                        //       particleCount: 100,
                        //       speed: 500.0,
                        //       color: Colors.purple,
                        //     ),
                        //     child: KenBurnsViewWidget()),

                        ListeWidget(),
                        DinlemeListesiWidget(),
                        // Diğer widget'ları buraya ekleyebilirsiniz
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
              //mana yükleniyor
              valueListenable: AudioService.playButtonNotifier,
              builder: (context, value, child) {
                switch (value) {
                  case ButtonState.loading:
                    return Align(
                      alignment: Alignment.center,
                      child: LoadingWidget(),
                    );
                  default:
                    return Container(); // Diğer durumlarda bir şey gösterme
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class LoadingWidget extends StatelessWidget {
  double calculateFontSize(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double fontSize =
        screenHeight * (Degiskenler.altEkranBoyutNotifier.value / 100) * 0.11;
    return fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.57, // Yarı genişlik
        height: MediaQuery.of(context).size.height * 0.23, // Yarı yükseklik
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0), // Border radius ekleyin
          color: Colors.black,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Image.asset(
                  'assets/images/atesiask.jpg', // Kullanmak istediğiniz resmin yolunu belirtin
                  height: MediaQuery.of(context).size.height *
                      0.12, // Yarı yükseklik
                ),
                /*const Text(
                  'ATEŞ-İ AŞK  ', // Başlık metni
                  style: TextStyle(
                    fontSize: 21.0,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),*/
              ],
            ),
            const SizedBox(height: 6.0), // Boşluk eklemek için

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Image.asset(
                    'assets/images/loading.gif', // Kullanmak istediğiniz resmin yolunu belirtin
                    height: MediaQuery.of(context).size.height *
                        0.05, // Yarı yükseklik
                  ),
                ),
                Text(
                  '  Mana Yükleniyor...', // Başlık metni
                  style: TextStyle(
                    fontSize: calculateFontSize(context),
                    color: Colors.white,
                    //fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class KenBurnsViewWidget extends StatefulWidget {
  @override
  _KenBurnsViewWidgetState createState() => _KenBurnsViewWidgetState();
}

class _KenBurnsViewWidgetState extends State<KenBurnsViewWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Siyah arka plan rengi
      child: Stack(
        children: [
          KenBurns(
              minAnimationDuration: Duration(milliseconds: 10000),
              maxAnimationDuration: Duration(milliseconds: 13000),
              maxScale: 1.3,
              child: Base64ImageWidget()),
          Positioned(
            bottom: 0, // Alt boşluk
            left: 0, // Sol boşluk
            right: 0, // Sağ boşluk
            child: _akanYazi,
          ),
        ],
      ),
    );
  }
}

class AkanYazi extends StatelessWidget {
  final String text;

  AkanYazi(this.text);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double yaziBoyutu =
        screenHeight * 0.019; // Yüksekliğin %5'i kadar bir yazı boyutu

    String setEpigram(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: yaziBoyutu)),
        textDirection: TextDirection.ltr,
      )..layout();

      double textWidth = painter.width;
      int targetLength = (textWidth / 3.34)
          .toInt(); // Yazının genişlik oranına göre hedef uzunluk hesaplayın
      String finalText;
      if (screenWidth > textWidth) {
        finalText = text + ' ' * (screenWidth / 3.9).toInt();
      } else {
        int spacesToAdd = targetLength - text.length;
        finalText = text + ' ' * spacesToAdd;
      }
      return finalText;
    }

    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: Degiskenler.currentEpigramNotifier,
        builder: (_, title, __) {
          return TextScroll(
            setEpigram(title),
            // title değişkenini kullanmak istediğinizi varsayıyorum
            mode: TextScrollMode.endless,
            velocity: Velocity(pixelsPerSecond: Offset(50, 0)),
            delayBefore: Duration(milliseconds: 500),
            numberOfReps: 99999,
            pauseBetween: Duration(milliseconds: 50),
            style: TextStyle(color: Colors.white, fontSize: yaziBoyutu),
            textAlign: TextAlign.right,
            selectable: true,
          );
        },
      ),
    );
  }
}

class ListeWidget extends StatefulWidget {
  @override
  _ListeWidgetState createState() => _ListeWidgetState();
}

class _ListeWidgetState extends State<ListeWidget>
    with SingleTickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  List<dynamic> filteredSongList = [];
  String searchText = "";
  FocusNode _focusNode = FocusNode();
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _autoUnfocus() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 3), () {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        searchText = "";
        filteredSongList.clear();
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0a0a),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Modern Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(25),
                      bottomRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Title and Search Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple.shade400,
                                      Colors.blue.shade400,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                Degiskenler.liste_adi,
                                style: TextStyle(
                                  fontSize: calculateFontSize(context) * 0.7,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isSearchExpanded ? Icons.close : Icons.search,
                                color: Colors.white.withOpacity(0.9),
                                size: 22,
                              ),
                              onPressed: _toggleSearch,
                            ),
                          ),
                        ],
                      ),

                      // Animated Search Bar
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: _isSearchExpanded ? 60 : 0,
                        curve: Curves.easeInOut,
                        child: _isSearchExpanded
                            ? Container(
                                margin: EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  focusNode: _focusNode,
                                  controller: _searchController,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  onChanged: (value) {
                                    searchText = value.toLowerCase();
                                    List<dynamic> filteredList = Degiskenler
                                        .songListNotifier.value
                                        .where((song) {
                                      String songName =
                                          song['parca_adi'].toLowerCase();
                                      String singerName =
                                          song['seslendiren'].toLowerCase();

                                      String replaceTurkishCharacters(
                                          String text) {
                                        text = text.replaceAll("â", "a");
                                        text = text.replaceAll("ş", "s");
                                        text = text.replaceAll("ö", "o");
                                        text = text.replaceAll("ü", "u");
                                        text = text.replaceAll("ı", "i");
                                        text = text.replaceAll("ç", "c");
                                        text = text.replaceAll("ğ", "g");
                                        return text;
                                      }

                                      return replaceTurkishCharacters(songName)
                                              .contains(
                                                  replaceTurkishCharacters(
                                                      searchText)) ||
                                          replaceTurkishCharacters(singerName)
                                              .contains(
                                                  replaceTurkishCharacters(
                                                      searchText));
                                    }).toList();

                                    setState(() {
                                      filteredSongList = filteredList;
                                    });
                                    _autoUnfocus();
                                  },
                                  onTap: () {
                                    if (_focusNode.hasFocus) {
                                      _focusNode.unfocus();
                                    } else {
                                      _autoUnfocus();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: "bul...",
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Colors.white.withOpacity(0.7),
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              )
                            : SizedBox(),
                      ),
                    ],
                  ),
                ),

                // Song List
                Expanded(
                  child: ValueListenableBuilder<List<dynamic>>(
                    valueListenable: Degiskenler.songListNotifier,
                    builder: (context, songList, child) {
                      List<dynamic> displayList = filteredSongList.isNotEmpty
                          ? filteredSongList
                          : songList;
                      displayList = displayList.reversed.toList();

                      if (filteredSongList.isEmpty && searchText.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Hiçbir sonuç bulunamadı",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Farklı anahtar kelimeler deneyin",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return ListView.builder(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.05),
                                    Colors.white.withOpacity(0.02),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    AudioService.playAtId(
                                        displayList[index]['sira_no']);
                                    ekranboyut_ana(0);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Play Icon
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.deepPurple.shade400,
                                                Colors.blue.shade400,
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.deepPurple
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 16),

                                        // Song Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayList[index]['parca_adi'],
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                displayList[index]
                                                    ['seslendiren'],
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  letterSpacing: 0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade400,
              Colors.blue.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: AlternativeListButton(),
      ),
    );
  }
}

class CustomDialog extends StatelessWidget {
  final String buttonText;
  final String icerik;
  //final bool gosterimde= Degiskenler.showDialogNotifier.value ? true : false;

  CustomDialog({
    required this.icerik,
  }) : buttonText = icerik.contains('https://benolanben.com/dinle/')
            ? 'Dinle'
            : 'Teşekkürler';

  void closeDialog() {
    Future.delayed(Duration.zero, () {
      ekranboyut_ana(0);
      Degiskenler.showDialogNotifier.value = false;
    });
  }

  void hediye() {
    var hediye = icerik.replaceAll('https://benolanben.com/dinle/', '');
    var link = hediye.split('&')[0];
    var id = hediye.split('&')[1];
    if (link.isNotEmpty && id.isNotEmpty) {
      // Your code here when link and id are not empty
      print('Link: $link');
      print('ID: $id');
      hediye_irtibat(link, id);
    } else {
      // Your code here when link or id is empty
      print('Link or ID is empty.');
    }
    closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    String noticeText = icerik.contains('https://benolanben.com/dinle/')
        ? 'Dinle!\nHediyeyi Duyacaksın..'
        : icerik;
    if (Degiskenler.showDialogNotifier.value) {
      Future.delayed(Duration.zero, () {
        ekranboyut_minik(0);
      });
    }
    ; //eğer bildirim gösterilmeyecek ise, ekranı düzenle

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.59, // Yarı genişlik
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0), // Border radius ekleyin
          color: Colors.black,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Image.asset(
                    'assets/images/atesiask.jpg', // Kullanmak istediğiniz resmin yolunu belirtin
                    height: MediaQuery.of(context).size.height *
                        0.12, // Yarı yükseklik
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0), // Boşluk eklemek için
            //Text('),
            Padding(
              padding: EdgeInsets.all(16.0), // Yastıklama (padding) ekleyin
              child: SelectableText(
                noticeText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: calculateFontSize(context) * 0.8, 
                ),
                textAlign: TextAlign.center, // Metni ortala (isteğe bağlı)
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: ElevatedButton(
                onPressed: () async {
                  if (icerik.contains('https://benolanben.com/dinle/')) {
                    hediye();
                  } else {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setString('bildirim', icerik);
                    closeDialog();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0), // Padding ekleyin
                  child: Text(buttonText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void hediye_irtibat(link, id) {
  compute(getirJsonData, "${Degiskenler.kaynakYolu}kaynak/$link.json")
      .then((data) {
    List<dynamic> listDinle = data["sesler"];

    for (var item in listDinle) {
      if (item['sira_no'].toString() == id.toString()) {
        AudioService.addTrackToPlaylist(item['parca_adi'], item['seslendiren'],
             item['url'], item['sira_no'], true);
        Degiskenler.hediyeninIndex = item['sira_no'];
        break;
      }
    }
  });
}

class DinlemeListesiWidget extends StatefulWidget {
  @override
  _DinlemeListesiWidgetState createState() => _DinlemeListesiWidgetState();
}

class _DinlemeListesiWidgetState extends State<DinlemeListesiWidget>
    with SingleTickerProviderStateMixin {
  int? selectedItemId;
  String selectedExplanation = "";
  String selectedCaption = "Seçiniz"; // Default metin
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void dinle(int i) {
    // Degiskenler.dinlemeListeleriNotifier değerini al
    List<dynamic> dinlemeListeleri = Degiskenler.dinlemeListeleriNotifier.value;

    // Verilen id'yi eşleştirmeye çalış
    for (var item in dinlemeListeleri) {
      int id = item["id"];
      var link = item["link"];
      var caption = item["caption"];
      if (id == i) {
        Degiskenler.liste_adi = caption;
        Degiskenler.liste_link = link;
        fetchData_jsonDinlemeListesi(
            "${Degiskenler.kaynakYolu}kaynak/$link.json", link);
      }
    }
    ekranboyut_ana(0);
    print("CLICK ListButton ustEkranAktifIndex = 2;");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f3460),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ValueListenableBuilder<List<dynamic>>(
              valueListenable: Degiskenler.dinlemeListeleriNotifier,
              builder: (context, dinlemeListeleri, child) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.playlist_play_rounded,
                              size: 48,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Dinleme Listeleri',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 3,
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade300,
                                    Colors.blue.shade300,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 400),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Dropdown Container
                                  // Mevcut dropdown container'ını şu şekilde değiştirin:
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.15),
                                          Colors.white.withOpacity(0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 15,
                                          offset: Offset(0, 8),
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: Colors.deepPurple
                                              .withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: Offset(0, -5),
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        dropdownColor: Color(0xFF1a1a2e),
                                        borderRadius: BorderRadius.circular(16),
                                        elevation: 8,
                                        icon: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            size: 24,
                                          ),
                                        ),
                                        hint: Container(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors
                                                          .deepPurple.shade400,
                                                      Colors.blue.shade400,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.deepPurple
                                                          .withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  Icons.music_note_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              Expanded(
                                                child: Text(
                                                  selectedCaption,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.95),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        onChanged: (selectedItem) {
                                          setState(() {
                                            selectedItemId = selectedItem;
                                            selectedCaption = dinlemeListeleri
                                                .firstWhere((element) =>
                                                    element["id"] ==
                                                    selectedItem)["caption"];
                                            selectedExplanation =
                                                dinlemeListeleri.firstWhere(
                                                        (element) =>
                                                            element["id"] ==
                                                            selectedItem)[
                                                    "explanation"];
                                          });
                                          print("selectedItem $selectedItem");
                                        },
                                        items: dinlemeListeleri.map((item) {
                                          return DropdownMenuItem<int>(
                                            value: item["id"],
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12, horizontal: 8),
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.deepPurple
                                                              .shade300,
                                                          Colors.blue.shade300,
                                                        ],
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors
                                                              .deepPurple
                                                              .withOpacity(0.4),
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      item["caption"],
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.95),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 32),

                                  // Explanation Section
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    height: selectedItemId != null ? null : 0,
                                    child: selectedItemId != null
                                        ? Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors
                                                    .deepPurple.shade300
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.info_outline_rounded,
                                                  color: Colors
                                                      .deepPurple.shade300,
                                                  size: 24,
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  selectedExplanation,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    fontSize: 14,
                                                    height: 1.5,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          )
                                        : SizedBox(),
                                  ),

                                  SizedBox(height: 40),

                                  // Play Button
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: selectedItemId != null
                                          ? LinearGradient(
                                              colors: [
                                                Colors.deepPurple.shade400,
                                                Colors.blue.shade400,
                                              ],
                                            )
                                          : null,
                                      color: selectedItemId == null
                                          ? Colors.grey.withOpacity(0.3)
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: selectedItemId != null
                                          ? [
                                              BoxShadow(
                                                color: Colors
                                                    .deepPurple.shade400
                                                    .withOpacity(0.4),
                                                blurRadius: 20,
                                                offset: Offset(0, 8),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: selectedItemId != null
                                            ? () async {
                                                dinle(selectedItemId!);
                                              }
                                            : null,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.play_arrow_rounded,
                                                color: selectedItemId != null
                                                    ? Colors.white
                                                    : Colors.white
                                                        .withOpacity(0.5),
                                                size: 28,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                "Dinle",
                                                style: TextStyle(
                                                  color: selectedItemId != null
                                                      ? Colors.white
                                                      : Colors.white
                                                          .withOpacity(0.5),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> fetchData_jsonDinlemeListesi(String url, String link) async {
  var json = link;
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);

    jsonData.then((jsonData) {
      List<dynamic> listDinle = jsonData["sesler"];
      //setPlaylist(listDinle.reversed.toList());
      setPlaylist(listDinle);
      //print(degiskenler.listDinle);
    });
  } catch (error) {
    print("Hata oluştu: $error");
    
  }
}

Future<void> fetchData_jsonFotograflar(String url) async {
  var json = "fotograflar";
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);

    jsonData.then((jsonDataMap) {
      if (jsonDataMap.containsKey("isaretler")) {
        final List<dynamic> fotograflarListesi = jsonDataMap["isaretler"];
        if (fotograflarListesi.isNotEmpty) {
          degiskenler.listFotograflar = fotograflarListesi;
          UI_support.changeImage();
        } else {
          print("fotograf listesi boş.");
        }
      } 
    });
  } catch (error) {
    print("Hata oluştu: $error");
  }
}

Future<void> fetchData_jsonMenba(String url) async {
  var json = "menba";
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);
    jsonData.then((jsonData) {
      
      int versiyon = jsonData["versiyon"];
      //print("versiyon: $versiyon");
      int dinlemeListesiID = jsonData["aktifliste"]["dinlemeListesiID"];
      //print("dinlemeListesiID: $dinlemeListesiID");
      List<dynamic> dinlemeListeleri = jsonData["dinlemeListeleri"];
      for (var item in dinlemeListeleri) {
        int id = item["id"];
        String link = item["link"];
        String caption = item["caption"];
        String explanation = item["explanation"];
        if (id == dinlemeListesiID) {
          Degiskenler.liste_adi = caption;
          Degiskenler.liste_link = link;
          fetchData_jsonDinlemeListesi(
              "${Degiskenler.kaynakYolu}kaynak/$link.json", link);

          /*compute(getirJsonData, "${Degiskenler.kaynakYolu}/kaynak/$link.json")
                .then((data) {
              List<dynamic> listDinle = data["sesler"];
              //setPlaylist(listDinle.reversed.toList());
              setPlaylist(listDinle);
              //print(degiskenler.listDinle);
            });*/
        }
        //print("id: $id, link: $link, caption: $caption, explanation: $explanation");
      }

      Map<String, dynamic> bildirim = jsonData["bildirim"];
      bildirimKontrol(bildirim);

      degiskenler.versionMenba = versiyon;
      Degiskenler.dinlemeListeleriNotifier =
          ValueNotifier<List<dynamic>>(dinlemeListeleri);

      //print(jsonData["aktifliste"]);
    });
  } catch (error) {
    print("Hata oluştu: $error");
  }
}

Future<void> fetchData_jsonSozler(String url) async {
  var json = "sozler";
  try {
    final Future<Map<String, dynamic>> jsonData = compute(getirJsonData, url);
    jsonData.then((jsonData) {
      if (jsonData["sozler"] == null || jsonData["sozler"] == false) {
        return;
      }

      if (jsonData.containsKey("sozler")) {
        final List<dynamic> sozlerListesi = jsonData["sozler"];
        if (sozlerListesi.isNotEmpty) {
          /*final Random random = Random();
        final int randomIndex = random.nextInt(sozlerListesi.length);
        final String secilenSoz = sozlerListesi[randomIndex];
        Degiskenler.currentEpigramNotifier.value = secilenSoz;
        print("Rastgele Seçilen Söz: $secilenSoz");*/
          degiskenler.listSozler = sozlerListesi;
          UI_support.changeEpigram();
        } else {
          print("Söz listesi boş.");
        }
      } else {
        print("Verilerde 'sozler' anahtarı bulunamadı.");
      }
    });
  } catch (error) {
    print("Hata oluştu: $error");
    
  }
}

Future<void> ekranboyut_minik(int goster) async {
  Degiskenler.ustEkranIndexNotifier.value = goster;
  Degiskenler.altEkranBoyutNotifier.value = 17;
  Degiskenler.ustEkranBoyutNotifier.value = 83;
}

Future<void> ekranboyut_ana(int goster) async {
  Degiskenler.ustEkranIndexNotifier.value = goster;
  Degiskenler.altEkranBoyutNotifier.value = 20;
  Degiskenler.ustEkranBoyutNotifier.value = 80;
}

Future<Map<String, dynamic>> getirJsonData(String yol) async {
  final HttpService _httpService = HttpService();
  print("getirJsonData $yol");

  try {
    final jsonStr = await _httpService.fetchData(yol);
    final jsonDataList = JsonHelper.parseJson(
        jsonStr); // Bu satırı kullanmanıza gerek yok, veri zaten bir liste
    return jsonDataList; // Gelen veriyi doğrudan döndürüyoruz
  } catch (error) {
    print('Veri çekilirken bir hata oluştu: $error');
    return {};
    //throw Exception('Veri çekilirken bir hata oluştu: $error');
  }
}

void bildirimKontrol(bildirim) async {
  String vakit1Str = bildirim["vakit1"];
  String vakit2Str = bildirim["vakit2"];

  // Veriyi ayrıştırma işlevi
  DateTime parseDateTime(String dateStr) {
    List<String> parts = dateStr.split(" "); // Boşluğa göre böleriz
    List<String> dateParts = parts[0].split("/"); // Tarihi ayırırız
    List<String> timeParts = parts[1].split(":"); // Saati ayırırız

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    return DateTime(year, month, day, hour, minute);
  }

  DateTime vakit1 = parseDateTime(vakit1Str);
  DateTime vakit2 = parseDateTime(vakit2Str);

  DateTime now =
      DateTime.now().toUtc(); // Şu anki tarihi UTC saat dilimine çevir
  DateTime suAn = now.add(
      Duration(hours: 3)); // 3 saat ekleyerek gelecekteki bir zamanı hesapla

  //print("KONTROLL $suAn ==> $vakit1, $vakit2");

  if (suAn.isAfter(vakit1) && suAn.isBefore(vakit2)) {
    //bildirim zamanında mıyız
    //print("Bildirim ==> Şu an vakit1 ve vakit2 arasında.");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? yanit =
        prefs.getString('bildirim') ?? "bos"; // Eğer değer yoksa false kullan
    print(
        "Bildirim ==> Şu an vakit1 ve vakit2 arasında.  $yanit && ${bildirim["metin"]}");

    if (yanit != bildirim["metin"]) {
      if (!Degiskenler.currentNoticeNotifier.value
          .contains('https://benolanben.com/dinle/')) {
        //benolanben değilse
        Degiskenler.currentNoticeNotifier.value = bildirim["metin"];
        Degiskenler.showDialogNotifier.value = true;
      }
    }
  } else {
    print("Bildirim ==> Şu an vakit1 ve vakit2 arasında değil.");
  }
}

class Base64ImageWidget extends StatefulWidget {
  @override
  _Base64ImageWidgetState createState() => _Base64ImageWidgetState();
}

class _Base64ImageWidgetState extends State<Base64ImageWidget> {
  Uint8List? _imageBytes;
  String? _currentImageUrl; // Bu, mevcut imageUrl'i saklamak için kullanılır.
  @override
  void initState() {
    super.initState();
  }

  Future<void> _downloadImage(imageUrl) async {
    final HttpService _httpService = HttpService();
    try {
      final responseBytes = await _httpService
          .fetchBytes("${Degiskenler.kaynakYolu}medya/atesiask/$imageUrl");
      setState(() {
        _imageBytes = responseBytes;
        _currentImageUrl = imageUrl; // imageUrl'i güncelle
      });
    } catch (e) {
      print('Resim indirme hatası: $e');
      try {
        final responseBytes = await _httpService.fetchBytes(
            "https://raw.githubusercontent.com/benolanben/atesiask/main/fotograflar/$imageUrl");
        setState(() {
          _imageBytes = responseBytes;
          _currentImageUrl = imageUrl; // imageUrl'i güncelle
        });
      } catch (e) {
        print('Resim indirme hatası: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Degiskenler.currentImageNotifier,
      builder: (context, imageUrl, child) {
        //print("yeni resim yolu $imageUrl");
        // Eğer imageUrl önceki ile aynı ise ve _imageBytes doluysa, mevcut resmi göster
        if (_currentImageUrl == imageUrl && _imageBytes != null) {
          return Image.memory(
            _imageBytes!,
            fit: BoxFit.cover,
          );
        } else {
          if (imageUrl.contains(".jpg") || imageUrl.contains(".png")) {
            // Değişiklik varsa veya _imageBytes null ise resmi indir
            _downloadImage(imageUrl);
            return _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/images/loading.gif', // Kullanmak istediğiniz resmin yolunu belirtin
                    height: MediaQuery.of(context).size.height *
                        0.05, // Yarı yükseklik
                  );
          } else
            return Image.asset(
              'assets/images/loading.gif', // Kullanmak istediğiniz resmin yolunu belirtin
              height:
                  MediaQuery.of(context).size.height * 0.05, // Yarı yükseklik
            );
        }
      },
    );
  }
}

/**
 * 
 * KONFETİ
 */

class HeartConfettiWidget extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Duration animationDuration;
  final Color heartColor;

  const HeartConfettiWidget({
    Key? key,
    required this.child,
    this.particleCount = 30,
    this.animationDuration = const Duration(seconds: 3),
    this.heartColor = Colors.red,
  }) : super(key: key);

  @override
  _HeartConfettiWidgetState createState() => _HeartConfettiWidgetState();
}

class _HeartConfettiWidgetState extends State<HeartConfettiWidget>
    with TickerProviderStateMixin {
  List<HeartParticle> particles = [];
  late AnimationController _animationController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          particles.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startConfetti(Offset position) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    setState(() {
      _isAnimating = true;
      particles.clear();

      final random = Random();

      for (int i = 0; i < widget.particleCount; i++) {
        // Yukarı doğru patlama için açı aralığı (120 derece yukarı doğru)
        final angle =
            (math.pi + (math.pi / 3)) + (random.nextDouble() * (math.pi / 3));
        final speed = 200.0 + random.nextDouble() * 300.0;

        final initialVelocityX = math.cos(angle) * speed;
        final initialVelocityY = math.sin(angle) * speed;

        particles.add(HeartParticle(
          startPosition: position,
          size: 4.0 + random.nextDouble() * 9.0,
          initialVelocity: Offset(initialVelocityX, initialVelocityY),
          rotationSpeedX: -10.0 + random.nextDouble() * 50.0,
          rotationSpeedY: -10.0 + random.nextDouble() * 50.0,
          rotationSpeedZ: -10.0 + random.nextDouble() * 50.0,
          gravity: 700.0 + random.nextDouble() * 400.0,
          color: widget.heartColor,
        ));
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (details) {
            _startConfetti(details.localPosition);
          },
          child: widget.child,
        ),
        if (_isAnimating && particles.isNotEmpty)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: HeartConfettiPainter(
                  particles: particles,
                  progress: _animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
      ],
    );
  }
}

class HeartParticle {
  final Offset startPosition;
  final double size;
  final Offset initialVelocity;
  final double rotationSpeedX;
  final double rotationSpeedY;
  final double rotationSpeedZ;
  final double gravity;
  final Color color;

  HeartParticle({
    required this.startPosition,
    required this.size,
    required this.initialVelocity,
    required this.rotationSpeedX,
    required this.rotationSpeedY,
    required this.rotationSpeedZ,
    required this.gravity,
    required this.color,
  });

  Offset getPosition(double time) {
    final x = startPosition.dx + initialVelocity.dx * time;
    final y = startPosition.dy +
        initialVelocity.dy * time +
        0.5 * gravity * time * time;
    return Offset(x, y);
  }

  double getRotationX(double time) => rotationSpeedX * time;
  double getRotationY(double time) => rotationSpeedY * time;
  double getRotationZ(double time) => rotationSpeedZ * time;

  double getOpacity(double progress) {
    if (progress < 0.7) {
      return 1.0;
    } else {
      return 1.0 - (progress - 0.7) / 0.3;
    }
  }

  double getScale(double progress) {
    if (progress < 0.1) {
      return progress / 0.1;
    } else if (progress > 0.9) {
      return 1.0 - (progress - 0.9) / 0.1;
    }
    return 1.0;
  }
}

class HeartConfettiPainter extends CustomPainter {
  final List<HeartParticle> particles;
  final double progress;

  HeartConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 3.0;

    for (final particle in particles) {
      final position = particle.getPosition(time);

      // Ekran sınırları kontrolü
      if (position.dx < -50 ||
          position.dx > size.width + 50 ||
          position.dy > size.height + 50 ||
          position.dy < -100) {
        continue;
      }

      final rotationX = particle.getRotationX(time);
      final rotationY = particle.getRotationY(time);
      final rotationZ = particle.getRotationZ(time);
      final opacity = particle.getOpacity(progress);
      final scale = particle.getScale(progress);

      if (opacity <= 0 || scale <= 0) continue;

      // 3D perspektif efekti
      final perspectiveScale = (math.cos(rotationY).abs() * 0.5 + 0.5) * scale;
      final skewX = math.sin(rotationY) * 0.3;
      final skewY = math.sin(rotationX) * 0.2;

      // Renk değişimi
      final colorIntensity = (math.cos(rotationX) + 1) / 2;
      final heartColor = Color.lerp(
        particle.color.withOpacity(0.8),
        particle.color.withOpacity(0.4),
        colorIntensity,
      )!;

      final paint = Paint()
        ..color = heartColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotationZ);
      canvas.scale(perspectiveScale, scale);
      canvas.skew(skewX, skewY);

      _drawMathematicalHeart(canvas, particle.size, paint);

      canvas.restore();
    }
  }

  void _drawMathematicalHeart(Canvas canvas, double size, Paint paint) {
    final path = Path();
    bool isFirst = true;
    const int steps = 100;

    for (int i = 0; i <= steps; i++) {
      final t = (i * 2 * math.pi) / steps;

      // Matematiksel kalp denklemi: x = 16sin³(t), y = 13cos(t) - 5cos(2t) - 2cos(3t) - cos(4t)
      final x = 16 * math.pow(math.sin(t), 3);
      final y = 13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t);

      final scaledX = x * size / 32.0;
      final scaledY = -y * size / 32.0; // Y eksenini ters çevir

      if (isFirst) {
        path.moveTo(scaledX, scaledY);
        isFirst = false;
      } else {
        path.lineTo(scaledX, scaledY);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ImprovedConfettiDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HeartConfettiWidget(
      particleCount: 29, // Parçacık sayısı
      animationDuration: Duration(seconds: 4), // Animasyon süresi
      heartColor: const Color.fromARGB(255, 235, 48, 34), // Kalp rengi
      child: KenBurnsViewWidget(), // Mevcut içeriğiniz
    );
  }
}

/**
 * 
 * KONFETİ SON
 */



/**
 * 
 * SPLASH SCREEN WIDGET
 */

class SplashScreenWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration displayDuration;
  final Duration animationDuration;

  const SplashScreenWidget({
    Key? key,
    this.onComplete,
    this.displayDuration = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  _SplashScreenWidgetState createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    
    // Fade animasyon controller'ı
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    // Scale animasyon controller'ı
    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Fade animasyonu (0'dan 1'e, sonra 1'den 0'a)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Scale animasyonu (küçükten büyüğe, sonra büyükten küçüğe)
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _startSplashSequence();
  }

  void _startSplashSequence() {
    // Başlangıç animasyonları
    _fadeController.forward();
    _scaleController.forward();

    // Belirtilen süre sonra çıkış animasyonu başlat
    _displayTimer = Timer(widget.displayDuration, () {
      _startExitAnimation();
    });
  }

  void _startExitAnimation() {
    // Çıkış animasyonları
    _fadeController.reverse().then((_) {
      // Animasyon tamamlandığında callback'i çağır
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
    
    _scaleController.animateTo(1.2, curve: Curves.easeInBack);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _displayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Center(
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(50, 246, 63, 4), // Alpha: 1.0 (tam opak)
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/atesiask.jpg',
                        width: MediaQuery.of(context).size.width * 0.83,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: MediaQuery.of(context).size.width * 0.6,
                            height: MediaQuery.of(context).size.width * 0.6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white.withOpacity(0.5),
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/**
 * 
 * SPLASH SCREEN WIDGET SON
 */

