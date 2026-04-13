import 'package:flutter/material.dart';

import 'selected_student_scope.dart';
import 'user_session.dart';

/// Define o perfil alvo que está sendo visualizado nas telas base (Treinos, Progresso, Nutrição).
class TargetProfile {
  final String uid;
  final String academyId;

  const TargetProfile({required this.uid, required this.academyId});
}

/// Helper para centralizar a lógica de "quem eu estou vendo".
/// Remove a necessidade de passar `academyIdOverride` e `uidOverride` para toda tela.
class TargetResolver {
  /// Retorna o [TargetProfile] atual ou null caso não exista contexto válido.
  static TargetProfile? maybeOf(BuildContext context) {
    // 1. Tenta pegar o aluno selecionado (caso o mestre esteja acessando o console)
    final selectedScope = context.dependOnInheritedWidgetOfExactType<SelectedStudentScope>();
    if (selectedScope != null && selectedScope.notifier!.hasSelected) {
      final student = selectedScope.notifier!.selected!;
      return TargetProfile(uid: student.uid, academyId: student.academyId);
    }

    // 2. Se não tem aluno selecionado, pega o usuário logado (caso o atleta acesse seu próprio dashboard)
    final userScope = context.dependOnInheritedWidgetOfExactType<UserScope>();
    if (userScope != null) {
      return TargetProfile(uid: userScope.user.uid, academyId: userScope.user.academyId);
    }

    return null;
  }

  /// Retorna o [TargetProfile] atual e lança erro detalhado caso não encontre contexto.
  static TargetProfile of(BuildContext context) {
    final profile = maybeOf(context);
    if (profile == null) {
      throw FlutterError(
        'TargetResolver.of(context) foi chamado, mas não há SelectedStudentScope nem UserScope ativos.\n'
        'Certifique-se de que a tela está sendo acessada por um atleta logado ou por um mestre com aluno selecionado.',
      );
    }
    return profile;
  }
}
