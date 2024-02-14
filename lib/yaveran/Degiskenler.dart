
import 'package:flutter/cupertino.dart';

class Degiskenler {
  static final Degiskenler _instance = Degiskenler._internal();
  int versionMenba = 0;

  static var hazirlaniyor=false;
  //String kaynakYolu=".";
  static var kaynakYolu="https://kardelendergisi.com/atesiask";
  static var alternatif_kaynakYolu="https://raw.githubusercontent.com/benolanben/atesiask/main/kaynak";

  //static var kaynakYolu="https://raw.githubusercontent.com/emreaksel/atesiask/main/flutter";
  static var parcaIndex=-1;
  static var hediyeninIndex=-1;
  static var liste_link="baska";

  static var currentEpigramNotifier = ValueNotifier<String>('...');
  static var currentImageNotifier = ValueNotifier<String>('');
  static var songListNotifier = ValueNotifier<List<dynamic>>([]);
  static var dinlemeListeleriNotifier = ValueNotifier<List<dynamic>>([{"id": 1, "caption": "Liste 1", "link": "link1", "explanation": "Açıklama 1"}]);
  static var currentNoticeNotifier = ValueNotifier<String>('Hoşgeldin Güzeller Güzelim...');
  static var showDialogNotifier = ValueNotifier<bool>(false);

  static var altEkranBoyutNotifier = ValueNotifier<int>(20);
  static var ustEkranBoyutNotifier = ValueNotifier<int>(80);
  static var ustEkranIndexNotifier = ValueNotifier<int>(0);

  List<dynamic> listSozler=[];
  List<dynamic> listDinle=[];
  List<dynamic> listFotograflar=[];

  factory Degiskenler() {
    return _instance;
  }

  Degiskenler._internal();
}