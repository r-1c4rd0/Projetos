import 'package:flutter/material.dart';

import '../model/academy_membership.dart';
import '../model/app_user.dart';

/// Provider simples de sessao do usuario logado (AppUser) e academia ativa.
class UserScope extends InheritedWidget {
  final AppUser user;
  final String activeAcademyId;
  final List<AcademyMembership> memberships;
  final AcademyMembership? activeMembership;

  const UserScope({
    super.key,
    required this.user,
    String? activeAcademyId,
    this.memberships = const [],
    this.activeMembership,
    required super.child,
  }) : activeAcademyId = activeAcademyId ?? user.academyId;

  /// Lanca erro claro quando nao existe UserScope acima.
  static AppUser of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UserScope>();
    if (scope == null) {
      throw FlutterError(
        'UserScope.of(context) foi chamado, mas nao existe UserScope acima desse widget.\n\n'
        'Correcao:\n'
        '- Para telas que aceitam overrides (academyIdOverride/uidOverride), use UserScope.maybeOf(context)\n'
        '  e valide academyId/uid antes de acessar Firestore.\n',
      );
    }
    return scope.user;
  }

  static UserScope scopeOf(BuildContext context) {
    final scope = maybeScopeOf(context);
    if (scope == null) {
      throw FlutterError(
        'UserScope.scopeOf(context) foi chamado, mas nao existe UserScope acima desse widget.',
      );
    }
    return scope;
  }

  /// Retorna null se nao existir UserScope acima (ideal para telas com override).
  static AppUser? maybeOf(BuildContext context) {
    return maybeScopeOf(context)?.user;
  }

  static UserScope? maybeScopeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserScope>();
  }

  @override
  bool updateShouldNotify(UserScope oldWidget) {
    return oldWidget.user != user ||
        oldWidget.activeAcademyId != activeAcademyId ||
        oldWidget.memberships != memberships ||
        oldWidget.activeMembership != activeMembership;
  }
}

/// Wrapper opcional para injetar o AppUser e a academia ativa.
class UserSession extends StatelessWidget {
  final AppUser user;
  final String? activeAcademyId;
  final List<AcademyMembership> memberships;
  final AcademyMembership? activeMembership;
  final Widget child;

  const UserSession({
    super.key,
    required this.user,
    this.activeAcademyId,
    this.memberships = const [],
    this.activeMembership,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return UserScope(
      user: user,
      activeAcademyId: activeAcademyId,
      memberships: memberships,
      activeMembership: activeMembership,
      child: child,
    );
  }
}