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
      apiKey: _requiredDefine('TITANS_FIREBASE_TEST_API_KEY'),
      appId: _requiredDefine('TITANS_FIREBASE_TEST_APP_ID'),
      messagingSenderId: _requiredDefine(
        'TITANS_FIREBASE_TEST_MESSAGING_SENDER_ID',
      ),
      projectId: _requiredDefine('TITANS_FIREBASE_TEST_PROJECT_ID'),
      authDomain: _requiredDefine('TITANS_FIREBASE_TEST_AUTH_DOMAIN'),
      storageBucket: _requiredDefine('TITANS_FIREBASE_TEST_STORAGE_BUCKET'),
      databaseURL: _optionalDefine('TITANS_FIREBASE_TEST_DATABASE_URL'),
    );
  }

  static String _requiredDefine(String key) {
    final value = String.fromEnvironment(key).trim();
    if (value.isEmpty) {
      throw StateError('$key obrigatorio para TITANS_FIREBASE_ENV=test.');
    }
    return value;
  }

  static String? _optionalDefine(String key) {
    final value = String.fromEnvironment(key).trim();
    return value.isEmpty ? null : value;
  }
}
