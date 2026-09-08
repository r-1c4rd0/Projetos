import 'theme_preference_store_stub.dart'
    if (dart.library.html) 'theme_preference_store_web.dart'
    if (dart.library.io) 'theme_preference_store_io.dart'
    as impl;

class ThemePreferenceStore {
  const ThemePreferenceStore();

  Future<String?> read() => impl.readThemePreference();

  Future<void> write(String value) => impl.writeThemePreference(value);
}
