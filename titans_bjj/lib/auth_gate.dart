
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'model/app_user.dart';
import 'screen/login_screen.dart';
import 'repository/user_repository.dart';
import 'service/user_session.dart';

class AuthGate extends StatelessWidget {
  final Widget app;
  const AuthGate({required this.app, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
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
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                    );
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
