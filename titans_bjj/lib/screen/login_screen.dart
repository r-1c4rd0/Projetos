import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  bool _bioAvailable = false;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _refreshBioState();
  }

  Future<void> _refreshBioState() async {
    final available = await BiometricService.instance.isAvailable();
    final hasUser = FirebaseAuth.instance.currentUser != null;
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _hasSession = hasUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBio = _bioAvailable && _hasSession;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('TITANS BJJ', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Entre com e-mail ou desbloqueie com biometria',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  enabled: !_loading,
                ),

                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _loginEmail,
                    child: _loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Entrar'),
                  ),
                ),

                const SizedBox(height: 10),

                if (showBio)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear com biometria'),
                      onPressed: _loading ? null : _unlockWithBiometrics,
                    ),
                  ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _refreshBioState,
                  child: const Text('Recarregar biometria'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loginEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      await _refreshBioState();
    } catch (e) {
      setState(() => _error = 'Falha no login: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await BiometricService.instance.authenticate(
      reason: 'Confirme sua biometria para desbloquear',
    );

    if (!ok) {
      setState(() => _error = 'Biometria não confirmada.');
    }

    if (mounted) setState(() => _loading = false);
  }
}
