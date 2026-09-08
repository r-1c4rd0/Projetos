import 'dart:async';

import 'package:flutter/material.dart';

import 'theme_preference_store.dart';
import 'titans_theme.dart';

enum TitansThemeChoice { black, midnight, light }

extension TitansThemeChoiceLabels on TitansThemeChoice {
  String get label {
    switch (this) {
      case TitansThemeChoice.black:
        return 'Titans Black';
      case TitansThemeChoice.midnight:
        return 'Titans Midnight';
      case TitansThemeChoice.light:
        return 'Titans Light';
    }
  }

  String get description {
    switch (this) {
      case TitansThemeChoice.black:
        return 'Preto profundo, carvão e dourado preciso.';
      case TitansThemeChoice.midnight:
        return 'Azul-escuro clássico do Titans.';
      case TitansThemeChoice.light:
        return 'Claro levemente quente, com contraste ajustado.';
    }
  }

  static TitansThemeChoice? parse(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final choice in TitansThemeChoice.values) {
      if (choice.name == normalized) return choice;
    }
    if (normalized == 'dark') return TitansThemeChoice.midnight;
    return null;
  }
}

class ThemeController extends ChangeNotifier {
  TitansThemeChoice _choice;
  final Future<String?> Function() _loadPreference;
  final Future<void> Function(String value) _savePreference;
  bool _loaded = false;

  ThemeController({
    TitansThemeChoice initialChoice = TitansThemeChoice.midnight,
    Future<String?> Function()? loadPreference,
    Future<void> Function(String value)? savePreference,
  }) : _choice = initialChoice,
       _loadPreference = loadPreference ?? const ThemePreferenceStore().read,
       _savePreference = savePreference ?? const ThemePreferenceStore().write;

  TitansThemeChoice get choice => _choice;
  bool get isLoaded => _loaded;
  bool get isDark => _choice != TitansThemeChoice.light;
  ThemeMode get mode => isDark ? ThemeMode.dark : ThemeMode.light;
  ThemeData get theme {
    switch (_choice) {
      case TitansThemeChoice.black:
        return buildTitansBlackTheme();
      case TitansThemeChoice.midnight:
        return buildTitansMidnightTheme();
      case TitansThemeChoice.light:
        return buildTitansLightTheme();
    }
  }

  Future<void> load() async {
    final stored = TitansThemeChoiceLabels.parse(await _loadPreference());
    if (stored != null) {
      _choice = stored;
    }
    _loaded = true;
    notifyListeners();
  }

  void setChoice(TitansThemeChoice choice) {
    if (_choice == choice) return;
    _choice = choice;
    notifyListeners();
    unawaited(_savePreference(choice.name));
  }

  void setMode(ThemeMode mode) {
    setChoice(
      mode == ThemeMode.light
          ? TitansThemeChoice.light
          : TitansThemeChoice.midnight,
    );
  }

  void toggle() {
    setChoice(isDark ? TitansThemeChoice.light : TitansThemeChoice.midnight);
  }
}

final ThemeController themeController = ThemeController();
