import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'config/app_config.dart';
import 'model/app_user.dart';
import 'screen/login_screen.dart';
import 'repository/user_repository.dart';
import 'service/session_lock_controller.dart';
import 'service/user_session.dart';

class AuthGate extends StatefulWidget {
  final Widget app;
  const AuthGate({required this.app, super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (authSnap.hasError) {
          return _ErrorScreen(
            title: 'Erro no authStateChanges()',
            error: authSnap.error,
          );
        }

        final firebaseUser = authSnap.data;
        if (firebaseUser == null) return const LoginScreen();

        return FutureBuilder<AppUser>(
          future: UserRepository.instance
              .ensureUserDoc(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            academyId: 'default', // MVP
          )
              .timeout(const Duration(seconds: 12)),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnap.hasError) {
              final err = userSnap.error?.toString() ?? '';
              final isOfflineFirestore =
                  err.contains('client is offline') ||
                      err.contains('cloud_firestore/unavailable');

              // ✅ fallback web pra destravar UI
              if (kIsWeb && isOfflineFirestore) {
                final appUser = AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                  academyId: 'default',
                  role: UserRole.athlete, // ✅ enum correto
                );
                return UserScope(user: appUser, child: app);
              }

              return _ErrorScreen(
                title: 'Erro ao criar/ler academies/{academyId}/users/{uid}',
                error: userSnap.error,
              );
            }

            final appUser = userSnap.data;
            if (appUser == null) {
              return const _ErrorScreen(
                title: 'Usuário não carregou',
                error: 'ensureUserDoc retornou null',
              );
            }

            return UserScope(user: appUser, child: app);
          },
        );
      },
    );
  }
}

class _AuthenticatedApp extends StatefulWidget {
  final User firebaseUser;
  final Widget app;

  const _AuthenticatedApp({
    required this.firebaseUser,
    required this.app,
  });

  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  late final String _activeAcademyId;
  late Future<AppUser> _userFuture;

  @override
  void initState() {
    super.initState();
    _activeAcademyId = AppConfig.resolveActiveAcademyId();
    _userFuture = _loadUser();
  }

  @override
  void didUpdateWidget(_AuthenticatedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid ||
        oldWidget.firebaseUser.email != widget.firebaseUser.email) {
      _userFuture = _loadUser();
    }
  }

  Future<AppUser> _loadUser() {
    return UserRepository.instance
        .ensureUserDoc(
          uid: widget.firebaseUser.uid,
          email: widget.firebaseUser.email ?? '',
          academyId: _activeAcademyId,
        )
        .timeout(const Duration(seconds: 12));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _userFuture,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (userSnap.hasError) {
          final err = userSnap.error?.toString() ?? '';
          final isOfflineFirestore =
              err.contains('client is offline') ||
              err.contains('cloud_firestore/unavailable');

          if (kIsWeb && isOfflineFirestore) {
            final appUser = AppUser(
              uid: widget.firebaseUser.uid,
              email: widget.firebaseUser.email ?? '',
              academyId: _activeAcademyId,
              role: UserRole.athlete,
            );
            return UserScope(user: appUser, child: widget.app);
          }

          return _ErrorScreen(
            title: 'Erro ao criar/ler academies/{academyId}/users/{uid}',
            error: userSnap.error,
          );
        }

        final appUser = userSnap.data;
        if (appUser == null) {
          return const _ErrorScreen(
            title: 'Usuario nao carregou',
            error: 'ensureUserDoc retornou null',
          );
        }

        return UserScope(user: appUser, child: widget.app);
      },
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String title;
  final Object? error;

  const _ErrorScreen({required this.title, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  error?.toString() ?? 'Erro desconhecido',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    SessionLockController.instance.reset();
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Ir para Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}