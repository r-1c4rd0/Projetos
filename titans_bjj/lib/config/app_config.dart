class AppConfig {
  // Ative com:
  // flutter run -d chrome --dart-define=USE_MOCKS=true
  static const bool useMocks =
      bool.fromEnvironment('USE_MOCKS', defaultValue: false);

  // TODO multi-academy: substituir por selecao de academia ativa.
  // Fallback temporario explicito para preservar o fluxo atual ate existir
  // membership/seletor de academia. Nao usar a string diretamente no app.
  static const String defaultAcademyId = String.fromEnvironment(
    'TITANS_ACADEMY_ID',
    defaultValue: 'default',
  );

  static String resolveActiveAcademyId() {
    final academyId = defaultAcademyId.trim();
    if (academyId.isEmpty) {
      throw StateError('TITANS_ACADEMY_ID nao pode ser vazio.');
    }
    return academyId;
  }
}