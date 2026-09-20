import 'package:flutter/material.dart';

import '../../features/technical_domain/domain/technical_models.dart';
import '../../model/training_session.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class DashboardPrimaryActionCard extends StatelessWidget {
  final ColorScheme cs;
  final NextTrainingRecommendation nextTraining;
  final TrainingSession? pendingConfirmation;
  final bool confirmingPending;
  final Future<void> Function()? onConfirmPending;
  final VoidCallback onRegisterTraining;
  final VoidCallback onOpenTraining;

  const DashboardPrimaryActionCard({
    super.key,
    required this.cs,
    required this.nextTraining,
    required this.pendingConfirmation,
    required this.confirmingPending,
    required this.onConfirmPending,
    required this.onRegisterTraining,
    required this.onOpenTraining,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingConfirmation;
    return DashboardGlassCard(
      accent: cs.primary.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(title: 'A\u00c7\u00c3O PRINCIPAL'),
          const SizedBox(height: 10),
          Text(
            pending == null ? 'Registrar treino' : 'Confirmar treino pendente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            pending != null
                ? 'Você fez o treino de ${formatShortDate(pending.date)}?'
                : nextTraining.hasRecommendation
                ? 'Use o pr\u00f3ximo treino como guia e registre o resultado depois.'
                : 'Registre a pr\u00f3xima sess\u00e3o para liberar recomenda\u00e7\u00f5es mais precisas.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed:
                    pending != null
                        ? () => onConfirmPending?.call()
                        : onRegisterTraining,
                icon:
                    confirmingPending
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.onPrimary,
                            ),
                          ),
                        )
                        : Icon(
                          pending != null
                              ? Icons.check_circle_outline
                              : Icons.add_task_outlined,
                        ),
                label: Text(
                  pending != null ? 'Já treinei' : 'Registrar treino',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenTraining,
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('Abrir treinos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
