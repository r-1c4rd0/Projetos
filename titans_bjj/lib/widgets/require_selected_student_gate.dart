import 'package:flutter/material.dart';

import '../service/selected_student.dart';
import '../service/selected_student_scope.dart';

class RequireSelectedStudentGate extends StatelessWidget {
  final Widget Function(BuildContext context, SelectedStudent selected) builder;

  const RequireSelectedStudentGate({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final controller = SelectedStudentScope.maybeOf(context);
    final selected = controller?.selected;

    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Selecione um aluno no Painel do Mestre',
                    style: TextStyle(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para acessar Treinos, Progresso ou Nutricao, professor/admin precisa abrir o console a partir do card de um aluno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return builder(context, selected);
  }
}
