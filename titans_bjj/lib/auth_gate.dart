import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'config/app_config.dart';
import 'core/startup_performance_trace.dart';
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
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    StartupPerformanceTrace.mark('AuthGate initState');
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    _buildCount += 1;
    StartupPerformanceTrace.mark('AuthGate build #$_buildCount');
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          StartupPerformanceTrace.mark('authStateChanges waiting');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnap.hasError) {
          StartupPerformanceTrace.mark('authStateChanges error');
          return _ErrorScreen(
            title: 'Erro no authStateChanges()',
            error: authSnap.error,
          );
        }

        final firebaseUser = authSnap.data;
        if (firebaseUser == null) {
          StartupPerformanceTrace.mark('Home/Login returned: Login');
          return const LoginScreen();
        }
        StartupPerformanceTrace.mark('authStateChanges user received');

        return AnimatedBuilder(
          animation: SessionLockController.instance,
          builder: (context, _) {
            if (SessionLockController.instance.locked) {
              StartupPerformanceTrace.mark('Home/Login returned: Login unlock');
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
    _sessionFuture = _startSessionLoad('init');
  }

  @override
  void didUpdateWidget(_AuthenticatedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid ||
        oldWidget.firebaseUser.email != widget.firebaseUser.email) {
      StartupPerformanceTrace.mark('AuthGate user changed');
      _selectedAcademyId = null;
      _sessionFuture = _startSessionLoad('user changed');
    }
  }

  Future<_ResolvedUserSession> _startSessionLoad(String reason) {
    StartupPerformanceTrace.start('AuthGate session load: $reason');
    return _loadSession(reason);
  }

  Future<_ResolvedUserSession> _loadSession(String reason) async {
    final memberships = await _loadMemberships();
    final activeMemberships = memberships
        .where((membership) => membership.isActive)
        .toList(growable: false);

    if (activeMemberships.length > 1 && _selectedAcademyId == null) {
      StartupPerformanceTrace.mark(
        'AuthGate resolved destination: academy selection',
      );
      StartupPerformanceTrace.end('AuthGate session load: $reason');
      return _ResolvedUserSession.needsSelection(activeMemberships);
    }

    final activeMembership = _resolveActiveMembership(activeMemberships);
    final activeAcademyId = activeMembership?.academyId ?? _fallbackAcademyId();
    _lastResolvedAcademyId = activeAcademyId;

    await _acceptPendingInviteIfAvailable(activeAcademyId);

    StartupPerformanceTrace.start('ensureUserDoc');
    final appUser = await UserRepository.instance
        .ensureUserDoc(
          uid: widget.firebaseUser.uid,
          email: widget.firebaseUser.email ?? '',
          academyId: activeAcademyId,
        )
        .timeout(const Duration(seconds: 12));
    StartupPerformanceTrace.end('ensureUserDoc');
    StartupPerformanceTrace.mark('AuthGate resolved destination: app');
    StartupPerformanceTrace.end('AuthGate session load: $reason');

    return _ResolvedUserSession(
      user: appUser,
      activeAcademyId: activeAcademyId,
      memberships: memberships,
      activeMembership: activeMembership,
    );
  }

  Future<List<AcademyMembership>> _loadMemberships() async {
    StartupPerformanceTrace.start('membership load');
    try {
      final memberships = await AcademyMembershipRepository.instance
          .listMemberships(widget.firebaseUser.uid)
          .timeout(const Duration(seconds: 8));
      StartupPerformanceTrace.end(
        'membership load',
        detail: 'count=${memberships.length}',
      );
      return memberships;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'unavailable') {
        debugPrint(
          '[MULTI_ACADEMY] memberships fallback code=${error.code} message=${error.message}',
        );
        StartupPerformanceTrace.end(
          'membership load',
          detail: 'fallback=${error.code}',
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
    if (!mounted) return;
    setState(() {
      _selectedAcademyId = membership.academyId;
      _sessionFuture = _startSessionLoad('academy selected');
    });
  }

  Future<void> _acceptPendingInviteIfAvailable(String activeAcademyId) async {
    StartupPerformanceTrace.start('invite check');
    final inviteRepo = InviteRepository.instance;
    final email = widget.firebaseUser.email ?? '';
    if (inviteRepo.normalizeEmail(email).isEmpty) {
      StartupPerformanceTrace.end(
        'invite check',
        detail: 'skipped=empty-email',
      );
      return;
    }
    if (!inviteRepo.canAcceptInvites) {
      StartupPerformanceTrace.end(
        'invite check',
        detail: 'skipped=unavailable',
      );
      return;
    }

    try {
      final invite = await inviteRepo
          .watchPendingInviteForEmail(academyId: activeAcademyId, email: email)
          .first
          .timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (invite == null) {
        StartupPerformanceTrace.end('invite check', detail: 'none');
        return;
      }

      await inviteRepo.acceptInviteForCurrentUser(
        academyId: activeAcademyId,
        inviteId: invite.id,
        firebaseUser: widget.firebaseUser,
      );
      StartupPerformanceTrace.end('invite check', detail: 'accepted');
    } on FirebaseException catch (error) {
      debugPrint(
        '[AUTH_INVITE] skipped code=${error.code} message=${error.message}',
      );
      StartupPerformanceTrace.end(
        'invite check',
        detail: 'error=${error.code}',
      );
    } catch (error, stackTrace) {
      debugPrint('[AUTH_INVITE] skipped error=$error');
      debugPrintStack(stackTrace: stackTrace);
      StartupPerformanceTrace.end('invite check', detail: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    StartupPerformanceTrace.mark('AuthenticatedApp build');
    return FutureBuilder<_ResolvedUserSession>(
      future: _sessionFuture,
      builder: (context, sessionSnap) {
        if (sessionSnap.connectionState == ConnectionState.waiting) {
          StartupPerformanceTrace.mark('AuthGate session waiting');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (sessionSnap.hasError) {
          StartupPerformanceTrace.mark('AuthGate session error');
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
            StartupPerformanceTrace.mark(
              'AuthGate resolved destination: app offline fallback',
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
          StartupPerformanceTrace.mark(
            'Home/Login returned: academy selection',
          );
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

        StartupPerformanceTrace.mark('Home/Login returned: Home');
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
