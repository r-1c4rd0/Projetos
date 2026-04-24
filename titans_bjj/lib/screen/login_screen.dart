import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/biometric_service.dart';
import '../widgets/titans_logo.dart';

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

  Future<void> _refreshBioState({
    bool showLoading = false,
    bool showUnavailableError = false,
  }) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final available = await BiometricService.instance.isAvailable();
      final hasUser = FirebaseAuth.instance.currentUser != null;

      if (!mounted) return;

      setState(() {
        _bioAvailable = available;
        _hasSession = hasUser;
        _error =
            showUnavailableError && !available
                ? BiometricService.instance.lastErrorMessage ??
                    'Biometria indisponivel neste aparelho.'
                : null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _bioAvailable = false;
        _hasSession = FirebaseAuth.instance.currentUser != null;
        _error = 'Nao foi possivel recarregar a biometria.';
      });
    } finally {
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBio = _bioAvailable && _hasSession;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                          'Entre com e-mail ou desbloqueie com biometria',
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

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _loginEmail,
                            child:
                                _loading
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
                              onPressed:
                                  _loading ? null : _unlockWithBiometrics,
                            ),
                          ),

                        const SizedBox(height: 8),
                        TextButton(
                          onPressed:
                              _loading
                                  ? null
                                  : () async {
                                    await _refreshBioState(
                                      showLoading: true,
                                      showUnavailableError: true,
                                    );
                                  },
                          child: const Text('Recarregar biometria'),
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
      await _refreshBioState();
    } catch (e) {
      if (!mounted) return;
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

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _error =
            BiometricService.instance.lastErrorMessage ??
            'Biometria nao confirmada.';
      });
    }

    if (mounted) setState(() => _loading = false);
  }
}
