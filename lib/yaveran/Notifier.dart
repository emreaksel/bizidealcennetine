import 'package:flutter/cupertino.dart';

class PlayButtonNotifier extends ValueNotifier<ButtonState> {
  PlayButtonNotifier() : super(_initialValue);
  static const _initialValue = ButtonState.paused;
}
enum ButtonState { paused, playing, loading, }

class RepeatButtonNotifier extends ValueNotifier<RepeatState> {
  RepeatButtonNotifier() : super(_initialValue);
  static const _initialValue = RepeatState.off;
  void nextState() {
    final next = (value.index + 1) % RepeatState.values.length;
    value = RepeatState.values[next];
  }
}
enum RepeatState {  off, on }

class ProgressNotifier extends ValueNotifier<ProgressBarState> {
  ProgressNotifier() : super(_initialValue);
  static const _initialValue = ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  );

}
class ProgressBarState {
  const ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
  final Duration current;
  final Duration buffered;
  final Duration total;
}
/*

class EkranBoyutModel {
  int altEkranBoyut;
  int ustEkranBoyut;
  int ustEkranAktifIndex;

  EkranBoyutModel(
      {required this.altEkranBoyut,
        required this.ustEkranBoyut,
        required this.ustEkranAktifIndex});
}
class EkranBoyutNotifier extends ChangeNotifier {
  EkranBoyutModel _ekranBoyutModel = EkranBoyutModel(
      altEkranBoyut: 20, ustEkranBoyut: 80, ustEkranAktifIndex: 0);

  int get altEkranBoyut => _ekranBoyutModel.altEkranBoyut;

  int get ustEkranBoyut => _ekranBoyutModel.ustEkranBoyut;

  int get ustEkranAktifIndex => _ekranBoyutModel.ustEkranAktifIndex;

  set altEkranBoyut(int value) {
    _ekranBoyutModel.altEkranBoyut = value;
    notifyListeners();
  }

  set ustEkranBoyut(int value) {
    _ekranBoyutModel.ustEkranBoyut = value;
    notifyListeners();
  }

  set ustEkranAktifIndex(int value) {
    _ekranBoyutModel.ustEkranAktifIndex = value;
    notifyListeners();
  }

  setEkranBoyut(int altEkranBoyut, int ustEkranBoyut, int ustEkranAktifIndex) {
      _ekranBoyutModel.altEkranBoyut = altEkranBoyut;
      _ekranBoyutModel.ustEkranBoyut = ustEkranBoyut;
      _ekranBoyutModel.ustEkranAktifIndex = ustEkranAktifIndex;
      notifyListeners();
  }

}*/
