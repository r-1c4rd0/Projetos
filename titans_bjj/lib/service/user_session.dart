import 'package:flutter/material.dart';
import '../model/app_user.dart';

/// Provider simples de sessão do usuário logado (AppUser)
class UserScope extends InheritedWidget {
  final AppUser user;

  const UserScope({
    super.key,
    required this.user,
    required super.child,
  });

  /// Lança erro claro quando não existe UserScope acima
  static AppUser of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UserScope>();
    if (scope == null) {
      throw FlutterError(
        'UserScope.of(context) foi chamado, mas não existe UserScope acima desse widget.\n\n'
            'Correção:\n'
            '- Para telas que aceitam overrides (academyIdOverride/uidOverride), use UserScope.maybeOf(context)\n'
            '  e valide academyId/uid antes de acessar Firestore.\n',
      );
    }
    return scope.user;
  }

  /// Retorna null se não existir UserScope acima (ideal para telas com override)
  static AppUser? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserScope>()?.user;
  }

  @override
  bool updateShouldNotify(UserScope oldWidget) => oldWidget.user != user;
}

/// Wrapper opcional (se você usa no AuthGate para injetar o AppUser)
class UserSession extends StatelessWidget {
  final AppUser user;
  final Widget child;

  const UserSession({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return UserScope(user: user, child: child);
  }
}
