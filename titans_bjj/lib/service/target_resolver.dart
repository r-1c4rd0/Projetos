import 'package:flutter/material.dart';

import '../model/app_user.dart';
import 'selected_student_scope.dart';
import 'user_session.dart';

/// Contexto explicito usado para resolver quem e o alvo das telas de atleta.
enum TargetMode {
  self,
  selectedStudent,
}

/// Define o perfil alvo que esta sendo visualizado nas telas base (Treinos, Progresso, Nutricao).
class TargetProfile {
  final String uid;
  final String academyId;

  const TargetProfile({required this.uid, required this.academyId});
}

/// Helper para centralizar a logica de "quem eu estou vendo".
///
/// Regras:
/// - athlete sempre usa o proprio UserScope;
/// - professor/admin + TargetMode.self usa o proprio UserScope;
/// - professor/admin + TargetMode.selectedStudent exige aluno selecionado;
/// - nunca cai silenciosamente no usuario logado em contexto de aluno.
class TargetResolver {
  /// Retorna o [TargetProfile] atual ou null caso nao exista contexto valido.
  static TargetProfile? maybeOf(
    BuildContext context, {
    TargetMode mode = TargetMode.self,
  }) {
    final loggedUser = UserScope.maybeOf(context);
    if (loggedUser == null) return null;

    if (loggedUser.role == UserRole.athlete || mode == TargetMode.self) {
      return TargetProfile(uid: loggedUser.uid, academyId: loggedUser.academyId);
    }

    final selectedScope =
        context.dependOnInheritedWidgetOfExactType<SelectedStudentScope>();
    final selected = selectedScope?.notifier?.selected;
    if (selected == null) return null;

    return TargetProfile(uid: selected.uid, academyId: selected.academyId);
  }

  /// Retorna o [TargetProfile] atual e lanca erro detalhado caso nao encontre contexto.
  static TargetProfile of(
    BuildContext context, {
    TargetMode mode = TargetMode.self,
  }) {
    final profile = maybeOf(context, mode: mode);
    if (profile == null) {
      throw FlutterError(
        'TargetResolver.of(context) foi chamado, mas nao ha target valido.\n'
        'Use TargetMode.self para dados proprios ou TargetMode.selectedStudent para telas de aluno selecionado.',
      );
    }
    return profile;
  }
}