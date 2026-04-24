import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  String? lastErrorMessage;

  Future<bool> isAvailable() async {
    lastErrorMessage = null;

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        lastErrorMessage = 'Biometria indisponivel neste aparelho.';
        return false;
      }

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        lastErrorMessage = 'Cadastre uma biometria nas configuracoes.';
        return false;
      }

      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        lastErrorMessage = 'Cadastre uma biometria nas configuracoes.';
        return false;
      }

      return true;
    } on PlatformException catch (e) {
      return _handleAvailabilityException(e);
    } catch (_) {
      lastErrorMessage = 'Nao foi possivel verificar a biometria.';
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Desbloquear com biometria',
  }) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      _setAuthenticationError(e);
      return false;
    } catch (_) {
      lastErrorMessage = 'Nao foi possivel confirmar a biometria.';
      return false;
    }
  }

  bool _handleAvailabilityException(PlatformException e) {
    switch (_normalizeCode(e.code)) {
      case 'notenrolled':
      case 'nobiometrics':
        lastErrorMessage = 'Cadastre uma biometria nas configuracoes.';
        return false;
      case 'notavailable':
      case 'nohardware':
        lastErrorMessage = 'Biometria indisponivel neste aparelho.';
        return false;
      case 'lockedout':
      case 'permanentlylockedout':
        lastErrorMessage = 'Biometria bloqueada. Tente novamente mais tarde.';
        return false;
      case 'passcodenotset':
        lastErrorMessage = 'Configure o bloqueio de tela para usar biometria.';
        return false;
      default:
        lastErrorMessage = 'Nao foi possivel verificar a biometria.';
        return false;
    }
  }

  void _setAuthenticationError(PlatformException e) {
    switch (_normalizeCode(e.code)) {
      case 'lockedout':
      case 'permanentlylockedout':
        lastErrorMessage = 'Biometria bloqueada. Tente novamente mais tarde.';
        return;
      case 'notenrolled':
      case 'nobiometrics':
        lastErrorMessage = 'Cadastre uma biometria nas configuracoes.';
        return;
      case 'notavailable':
      case 'nohardware':
        lastErrorMessage = 'Biometria indisponivel neste aparelho.';
        return;
      default:
        lastErrorMessage = 'Biometria nao confirmada.';
    }
  }

  String _normalizeCode(String code) {
    return code.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
  }
}
