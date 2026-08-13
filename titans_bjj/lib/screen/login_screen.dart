import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/biometric_service.dart';
import '../service/session_lock_controller.dart';
import '../widgets/titans_logo.dart';

class LoginScreen extends StatefulWidget {
  final bool unlockOnly;

  const LoginScreen({
    super.key,
    this.unlockOnly = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  bool _bioReady = false;
  bool _hasSession = false;
  bool _refreshingBio = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reloadBio();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _reloadBio() async {
    if (_refreshingBio) return;

    setState(() {
      _refreshingBio = true;
      _error = null;
    });

    final st = await BiometricService.status();
    final sess = FirebaseAuth.instance.currentUser != null;

    if (!mounted) return;

    setState(() {
      _bioReady = st.enrolled && st.supported;
      _hasSession = sess;
      _refreshingBio = false;
      if (!_bioReady && sess) {
        _error = 'Biometria: ${st.reason}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBio = _bioReady && _hasSession;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle = widget.unlockOnly
        ? 'Desbloqueie sua sessao ativa com biometria'
        : 'Entre com e-mail ou desbloqueie com biometria';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.55),
                  radius: 1.2,
                  colors: [
                    cs.primary.withValues(alpha: 0.16),
                    cs.surface.withValues(alpha: 0.98),
                    cs.surface,
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: TitansLogo.watermark()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TitansLogo.icon(size: 72),
                        const SizedBox(height: 10),
                        Text(
                          'TITANS BJJ',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
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
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        if (!_hasSession)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Faca login com e-mail primeiro. A biometria apenas desbloqueia uma sessao ativa.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: (_loading || _refreshingBio)
                                ? null
                                : _loginEmail,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                              onPressed: (_loading || _refreshingBio)
                                  ? null
                                  : _unlockWithBiometrics,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: (_loading || _refreshingBio)
                              ? null
                              : _reloadBio,
                          child: Text(
                            _refreshingBio
                                ? 'Recarregando biometria...'
                                : 'Recarregar biometria',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
      SessionLockController.instance.unlock();
      await _reloadBio();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha no login: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _reloadBio();

      if (!mounted) return;

      if (!(_bioReady && _hasSession)) {
        setState(() => _error = 'Biometria indisponivel ou sem sessao.');
        return;
      }

      final ok = await BiometricService.authenticate(
        'Confirme sua biometria para desbloquear',
      );

      if (!mounted) return;

      if (ok) {
        SessionLockController.instance.unlock();
        return;
      }

      setState(() => _error = 'Biometria nao confirmada.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
