import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import 'titans_feedback.dart';

class TrainingScreenUnavailableState extends StatelessWidget {
  final bool requiresSelectedStudent;

  const TrainingScreenUnavailableState({
    super.key,
    required this.requiresSelectedStudent,
  });

  @override
  Widget build(BuildContext context) {
    if (requiresSelectedStudent) {
      return const TitansStateView.noStudent(
        message: 'Selecione um aluno no Painel do Mestre para acessar Treinos.',
      );
    }

    return const TitansStateView.error(
      title: 'Perfil não carregado',
      message:
          'Não foi possível identificar seu usuário para carregar Treinos.',
    );
  }
}

class TrainingScreenLoadingState extends StatelessWidget {
  const TrainingScreenLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const TitansSkeletonCard(lines: 4);
}

class TrainingScreenErrorState extends StatelessWidget {
  final Object error;

  const TrainingScreenErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) => TitansStateView.error(
    title: 'Erro ao carregar treinos',
    message: error.toString(),
  );
}
