import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'config/app_config.dart';
import 'model/academy_membership.dart';
import 'model/app_user.dart';
import 'screen/login_screen.dart';
import 'repository/academy_membership_repository.dart';
import 'repository/invite_repository.dart';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnap.hasError) {
          return _ErrorScreen(
            title: 'Erro no authStateChanges()',
            error: authSnap.error,
          );
        }

        final firebaseUser = authSnap.data;
        if (firebaseUser == null) return const LoginScreen();

        return AnimatedBuilder(
          animation: SessionLockController.instance,
          builder: (context, _) {
            if (SessionLockController.instance.locked) {
              return const LoginScreen(unlockOnly: true);
            }

            return _AuthenticatedApp(
              firebaseUser: firebaseUser,
              app: widget.app,
            );
          },
        );
      },
    );
  }
}

class _AuthenticatedApp extends StatefulWidget {
  final User firebaseUser;
  final Widget app;

  const _AuthenticatedApp({required this.firebaseUser, required this.app});

  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
  late Future<_ResolvedUserSession> _sessionFuture;
  String? _selectedAcademyId;
  String _lastResolvedAcademyId = AppConfig.resolveActiveAcademyId();

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
  }

  @override
  void didUpdateWidget(_AuthenticatedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid ||
        oldWidget.firebaseUser.email != widget.firebaseUser.email) {
      _selectedAcademyId = null;
      _sessionFuture = _loadSession();
    }
  }

  Future<_ResolvedUserSession> _loadSession() async {
    final memberships = await _loadMemberships();
    final activeMemberships = memberships
        .where((membership) => membership.isActive)
        .toList(growable: false);

    if (activeMemberships.length > 1 && _selectedAcademyId == null) {
      return _ResolvedUserSession.needsSelection(activeMemberships);
    }

    final activeMembership = _resolveActiveMembership(activeMemberships);
    final activeAcademyId = activeMembership?.academyId ?? _fallbackAcademyId();
    _lastResolvedAcademyId = activeAcademyId;

    await _acceptPendingInviteIfAvailable(activeAcademyId);

    final appUser = await UserRepository.instance
        .ensureUserDoc(
          uid: widget.firebaseUser.uid,
          email: widget.firebaseUser.email ?? '',
          academyId: activeAcademyId,
        )
        .timeout(const Duration(seconds: 12));

    return _ResolvedUserSession(
      user: appUser,
      activeAcademyId: activeAcademyId,
      memberships: memberships,
      activeMembership: activeMembership,
    );
  }

  Future<List<AcademyMembership>> _loadMemberships() async {
    try {
      return await AcademyMembershipRepository.instance
          .listMemberships(widget.firebaseUser.uid)
          .timeout(const Duration(seconds: 8));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'unavailable') {
        debugPrint(
          '[MULTI_ACADEMY] memberships fallback code=${error.code} message=${error.message}',
        );
        return const <AcademyMembership>[];
      }
      rethrow;
    }
  }

  AcademyMembership? _resolveActiveMembership(
    List<AcademyMembership> activeMemberships,
  ) {
    if (activeMemberships.isEmpty) return null;
    final selectedAcademyId = _selectedAcademyId;
    if (selectedAcademyId != null) {
      for (final membership in activeMemberships) {
        if (membership.academyId == selectedAcademyId) return membership;
      }
    }
    return activeMemberships.first;
  }

  String _fallbackAcademyId() {
    return AppConfig.resolveActiveAcademyId();
  }

  void _selectAcademy(AcademyMembership membership) {
    setState(() {
      _selectedAcademyId = membership.academyId;
      _sessionFuture = _loadSession();
    });
  }

  Future<void> _acceptPendingInviteIfAvailable(String activeAcademyId) async {
    final inviteRepo = InviteRepository.instance;
    final email = widget.firebaseUser.email ?? '';
    if (inviteRepo.normalizeEmail(email).isEmpty) return;
    if (!inviteRepo.canAcceptInvites) return;

    try {
      final invite = await inviteRepo
          .watchPendingInviteForEmail(academyId: activeAcademyId, email: email)
          .first
          .timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (invite == null) return;

      await inviteRepo.acceptInviteForCurrentUser(
        academyId: activeAcademyId,
        inviteId: invite.id,
        firebaseUser: widget.firebaseUser,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        '[AUTH_INVITE] skipped code=${error.code} message=${error.message}',
      );
    } catch (error, stackTrace) {
      debugPrint('[AUTH_INVITE] skipped error=$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedUserSession>(
      future: _sessionFuture,
      builder: (context, sessionSnap) {
        if (sessionSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnap.hasError) {
          final err = sessionSnap.error?.toString() ?? '';
          final isOfflineFirestore =
              err.contains('client is offline') ||
              err.contains('cloud_firestore/unavailable');

          if (kIsWeb && isOfflineFirestore) {
            final appUser = AppUser(
              uid: widget.firebaseUser.uid,
              email: widget.firebaseUser.email ?? '',
              academyId: _lastResolvedAcademyId,
              role: UserRole.athlete,
            );
            return UserScope(
              user: appUser,
              activeAcademyId: _lastResolvedAcademyId,
              child: widget.app,
            );
          }

          return _ErrorScreen(
            title: 'Erro ao criar/ler academies/{academyId}/users/{uid}',
            error: sessionSnap.error,
          );
        }

        final session = sessionSnap.data;
        if (session == null) {
          return const _ErrorScreen(
            title: 'Usuario nao carregou',
            error: 'ensureUserDoc retornou null',
          );
        }

        if (session.needsAcademySelection) {
          return _AcademySelectorScreen(
            memberships: session.memberships,
            onSelected: _selectAcademy,
          );
        }

        final appUser = session.user;
        if (appUser == null) {
          return const _ErrorScreen(
            title: 'Usuario nao carregou',
            error: 'sessao sem AppUser resolvido',
          );
        }

        return UserScope(
          user: appUser,
          activeAcademyId: session.activeAcademyId,
          memberships: session.memberships,
          activeMembership: session.activeMembership,
          child: widget.app,
        );
      },
    );
  }
}

class _ResolvedUserSession {
  final AppUser? user;
  final String? activeAcademyId;
  final List<AcademyMembership> memberships;
  final AcademyMembership? activeMembership;

  bool get needsAcademySelection =>
      user == null &&
      activeAcademyId == null &&
      activeMembership == null &&
      memberships.length > 1;

  const _ResolvedUserSession({
    required this.user,
    required this.activeAcademyId,
    required this.memberships,
    required this.activeMembership,
  });

  const _ResolvedUserSession.needsSelection(this.memberships)
    : user = null,
      activeAcademyId = null,
      activeMembership = null;
}

class _AcademySelectorScreen extends StatelessWidget {
  final List<AcademyMembership> memberships;
  final ValueChanged<AcademyMembership> onSelected;

  const _AcademySelectorScreen({
    required this.memberships,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher academia')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final membership = memberships[index];
                final title =
                    membership.academyName.isEmpty
                        ? membership.academyId
                        : membership.academyName;
                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(_roleLabel(membership.role)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelected(membership),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: memberships.length,
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.professor:
        return 'Professor';
      case UserRole.athlete:
        return 'Atleta';
    }
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
