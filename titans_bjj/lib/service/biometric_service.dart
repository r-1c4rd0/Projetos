

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BioStatus {
  const BioStatus({
    required this.supported,
    required this.canCheck,
    required this.enrolled,
    required this.types,
    required this.reason,
  });

  final bool supported;
  final bool canCheck;
  final bool enrolled;
  final List<BiometricType> types;
  final String reason;
}

class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  static Future<BioStatus> status() async {
    if (kIsWeb) {
      return _webUnsupportedStatus();
    }

    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final types = await _auth.getAvailableBiometrics();
      final enrolled = canCheck && types.isNotEmpty;
      final reason = _reasonFor(
        supported: supported,
        canCheck: canCheck,
        types: types,
      );

      print(
        '[BIO] supported=$supported canCheck=$canCheck types=$types enrolled=$enrolled reason=$reason',
      );

      return BioStatus(
        supported: supported,
        canCheck: canCheck,
        enrolled: enrolled,
        types: types,
        reason: reason,
      );
    } on PlatformException catch (e) {
      print('[BIO][ERR] code=${e.code} msg=${e.message}');
      return _fallbackStatus();
    } catch (e) {
      print('[BIO][ERR] $e');
      return _fallbackStatus();
    }
  }

  static Future<bool> authenticate(String reason) async {
    if (kIsWeb) {
      print('[BIO] web unsupported, skipping local_auth');
      return false;
    }

    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('[BIO][ERR] code=${e.code} msg=${e.message}');
      return false;
    } catch (e) {
      print('[BIO][ERR] $e');
      return false;
    }
  }

  static String _reasonFor({
    required bool supported,
    required bool canCheck,
    required List<BiometricType> types,
  }) {
    if (!supported) {
      return 'device_not_supported';
    }
    if (!canCheck) {
      return 'cannot_check';
    }
    if (types.isEmpty) {
      return 'not_enrolled';
    }

    return 'ok';
  }

  static BioStatus _fallbackStatus() {
    const status = BioStatus(
      supported: false,
      canCheck: false,
      enrolled: false,
      types: [],
      reason: 'status_error',
    );
    print(
      '[BIO] supported=${status.supported} canCheck=false types=${status.types} enrolled=${status.enrolled} reason=${status.reason}',
    );
    return status;
  }

  static BioStatus _webUnsupportedStatus() {
    const status = BioStatus(
      supported: false,
      canCheck: false,
      enrolled: false,
      types: [],
      reason: 'web_unsupported',
    );
    print('[BIO] web unsupported, skipping local_auth');
    print(
      '[BIO] supported=${status.supported} canCheck=${status.canCheck} types=${status.types} enrolled=${status.enrolled} reason=${status.reason}',
    );
    return status;
  }
}
