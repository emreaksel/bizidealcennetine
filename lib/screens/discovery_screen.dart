import 'package:flutter/material.dart';
import '../yaveran/Degiskenler.dart';
import '../yaveran/ui_support.dart';
import '../yaveran/logic.dart';
import '../yaveran/app_theme.dart';

class DinlemeListesiWidget extends StatefulWidget {
  @override
  _DinlemeListesiWidgetState createState() => _DinlemeListesiWidgetState();
}

class _DinlemeListesiWidgetState extends State<DinlemeListesiWidget>
    with SingleTickerProviderStateMixin {
  int? selectedItemId;
  String selectedExplanation = "";
  String selectedCaption = "Seçiniz";
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
    List<dynamic> dinlemeListeleri = Degiskenler.dinlemeListeleriNotifier.value;

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
    UI_support.ekranboyut_ana(0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: Degiskenler.currentThemeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          body: Container(
            color: theme.backgroundColor,
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
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.playlist_play_rounded,
                                  size: 48,
                                  color: theme.textColor.withOpacity(0.9),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Dinleme Listeleri',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  height: 3,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
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
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.cardColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            isExpanded: true,
                                            dropdownColor:
                                                theme.backgroundColor,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            elevation: 8,
                                            icon: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: theme.accentColor
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: theme.textColor
                                                    .withOpacity(0.9),
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
                                                      color: theme.accentColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: theme
                                                              .accentColor
                                                              .withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.music_note_rounded,
                                                      color: theme.textColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      selectedCaption,
                                                      style: TextStyle(
                                                        color: theme.textColor
                                                            .withOpacity(0.95),
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                                selectedCaption =
                                                    dinlemeListeleri.firstWhere(
                                                            (element) =>
                                                                element["id"] ==
                                                                selectedItem)[
                                                        "caption"];
                                                selectedExplanation =
                                                    dinlemeListeleri.firstWhere(
                                                            (element) =>
                                                                element["id"] ==
                                                                selectedItem)[
                                                        "explanation"];
                                              });
                                            },
                                            items: dinlemeListeleri.map((item) {
                                              return DropdownMenuItem<int>(
                                                value: item["id"],
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 8),
                                                  margin: EdgeInsets.symmetric(
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              theme.accentColor,
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: theme
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      0.4),
                                                              blurRadius: 4,
                                                              offset:
                                                                  Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(width: 16),
                                                      Expanded(
                                                        child: Text(
                                                          item["caption"],
                                                          style: TextStyle(
                                                            color: theme
                                                                .textColor
                                                                .withOpacity(
                                                                    0.95),
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
                                      AnimatedContainer(
                                        duration: Duration(milliseconds: 300),
                                        height:
                                            selectedItemId != null ? null : 0,
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
                                                      Icons
                                                          .info_outline_rounded,
                                                      color: theme.accentColor,
                                                      size: 24,
                                                    ),
                                                    SizedBox(height: 12),
                                                    Text(
                                                      selectedExplanation,
                                                      style: TextStyle(
                                                        color: theme.textColor
                                                            .withOpacity(0.8),
                                                        fontSize: 14,
                                                        height: 1.5,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : SizedBox(),
                                      ),
                                      SizedBox(height: 40),
                                      Container(
                                        width: double.infinity,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: selectedItemId != null
                                              ? theme.accentColor
                                              : theme.textColor
                                                  .withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                                    color: selectedItemId !=
                                                            null
                                                        ? theme.textColor
                                                        : theme.textColor
                                                            .withOpacity(0.5),
                                                    size: 28,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Dinle",
                                                    style: TextStyle(
                                                      color: selectedItemId !=
                                                              null
                                                          ? theme.textColor
                                                          : theme.textColor
                                                              .withOpacity(0.5),
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
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
      },
    );
  }
}
