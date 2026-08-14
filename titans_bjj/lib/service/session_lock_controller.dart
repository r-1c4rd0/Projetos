import 'package:flutter/foundation.dart';

class SessionLockController extends ChangeNotifier {
  SessionLockController._();

  static final SessionLockController instance = SessionLockController._();

  bool _locked = false;

  bool get locked => _locked;

  void lock() {
    if (_locked) return;
    _locked = false;
    notifyListeners();
  }

  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  void reset() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }
}
