class AppConfig {
  // Ative com:
  // flutter run -d chrome --dart-define=USE_MOCKS=true
  static const bool useMocks =
  bool.fromEnvironment('USE_MOCKS', defaultValue: false);
}