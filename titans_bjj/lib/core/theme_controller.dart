import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode;

  ThemeController({ThemeMode initialMode = ThemeMode.dark}) : _mode = initialMode;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
