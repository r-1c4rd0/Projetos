import 'package:flutter/foundation.dart';

@immutable
class SelectedStudent {
  final String academyId;
  final String uid;
  final String name;

  const SelectedStudent({
    required this.academyId,
    required this.uid,
    required this.name,
  });
}

class SelectedStudentController extends ChangeNotifier {
  SelectedStudent? _selected;

  SelectedStudent? get selected => _selected;
  bool get hasSelected => _selected != null;

  void select(SelectedStudent s) {
    _selected = s;
    notifyListeners();
  }

  void clear() {
    _selected = null;
    notifyListeners();
  }
}
