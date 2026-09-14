import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class TitansFirebaseEnvironment {
  static const String selected = String.fromEnvironment(
    'TITANS_FIREBASE_ENV',
    defaultValue: 'default',
  );

  static FirebaseOptions get currentPlatform {
    switch (selected.trim().toLowerCase()) {
      case 'test':
      case 'homologation':
      case 'hml':
        return _testWebOptions;
      case 'default':
      case '':
        return DefaultFirebaseOptions.currentPlatform;
      default:
        throw StateError('TITANS_FIREBASE_ENV invalido: $selected');
    }
  }

  static FirebaseOptions get _testWebOptions {
    return FirebaseOptions(
      apiKey: _requiredDefine('TITANS_FIREBASE_TEST_API_KEY', _testApiKey),
      appId: _requiredDefine('TITANS_FIREBASE_TEST_APP_ID', _testAppId),
      messagingSenderId: _requiredDefine(
        'TITANS_FIREBASE_TEST_MESSAGING_SENDER_ID',
        _testMessagingSenderId,
      ),
      projectId: _requiredDefine(
        'TITANS_FIREBASE_TEST_PROJECT_ID',
        _testProjectId,
      ),
      authDomain: _requiredDefine(
        'TITANS_FIREBASE_TEST_AUTH_DOMAIN',
        _testAuthDomain,
      ),
      storageBucket: _requiredDefine(
        'TITANS_FIREBASE_TEST_STORAGE_BUCKET',
        _testStorageBucket,
      ),
      databaseURL: _optionalDefine(_testDatabaseUrl),
    );
  }

  static const String _testApiKey = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_API_KEY',
  );
  static const String _testAppId = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_APP_ID',
  );
  static const String _testMessagingSenderId = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_MESSAGING_SENDER_ID',
  );
  static const String _testProjectId = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_PROJECT_ID',
  );
  static const String _testAuthDomain = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_AUTH_DOMAIN',
  );
  static const String _testStorageBucket = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_STORAGE_BUCKET',
  );
  static const String _testDatabaseUrl = String.fromEnvironment(
    'TITANS_FIREBASE_TEST_DATABASE_URL',
  );

  static String _requiredDefine(String key, String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      throw StateError('$key obrigatorio para TITANS_FIREBASE_ENV=test.');
    }
    return value;
  }

  static String? _optionalDefine(String rawValue) {
    final value = rawValue.trim();
    return value.isEmpty ? null : value;
  }
}
