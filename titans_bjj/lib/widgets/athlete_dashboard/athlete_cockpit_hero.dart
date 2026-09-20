import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/technical_domain/domain/technical_models.dart';
import '../../model/training_session.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class AthleteHomeCockpitHero extends StatelessWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;
  final NextTrainingRecommendation nextTraining;
  final TrainingSession? lastSession;
  final TrainingSession? pendingConfirmation;
  final bool confirmingPending;
  final Future<void> Function()? onConfirmPending;
  final VoidCallback onRegisterTraining;

  const AthleteHomeCockpitHero({
    super.key,
    required this.cs,
    required this.focus,
    required this.nextTraining,
    required this.lastSession,
    required this.pendingConfirmation,
    required this.confirmingPending,
    required this.onConfirmPending,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingConfirmation;
    final accent = _priorityColor(cs, focus.priority, nextTraining.priority);
    final title =
        pending != null
            ? 'Confirmar treino de ${formatShortDate(pending.date)}'
            : focus.hasRecommendation
            ? focus.title
            : nextTraining.hasRecommendation
            ? nextTraining.title
            : 'Foco do treino em construção';
    final subtitle =
        pending != null
            ? 'Você fez este treino?'
            : focus.hasRecommendation
            ? focus.summary
            : nextTraining.hasRecommendation
            ? nextTraining.subtitle
            : 'Registre treinos e debriefs para alimentar seu próximo passo.';
    final support =
        pending != null
            ? 'Confirme a ocorrência existente sem criar outro registro.'
            : _supportText();
    final tags =
        <String>[
          if (focus.hasRecommendation) ...focus.tags,
          if (!focus.hasRecommendation && nextTraining.hasRecommendation)
            ...nextTraining.tags,
        ].take(2).toList();
    final lastActivity =
        lastSession == null
            ? 'Sem treino registrado ainda'
            : 'Última atividade ${formatShortDate(lastSession!.date)}';

    return DashboardGlassCard(
      accent: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(Icons.flag_outlined, color: accent, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOCO DO TREINO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            support,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.60),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DashboardInsightBadge(
                label: lastActivity,
                color: cs.onSurface.withValues(alpha: 0.46),
                icon: Icons.history_rounded,
                muted: true,
              ),
              for (final tag in tags) DashboardInsightBadge(label: tag, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width:
                    constraints.maxWidth < 360
                        ? double.infinity
                        : constraints.maxWidth.clamp(180.0, 260.0),
                child: FilledButton.icon(
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
                                : Icons.add_rounded,
                            size: 18,
                          ),
                  label: Text(
                    pending != null ? 'Já treinei' : 'Registro rápido',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: TitansUI.actionGold,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _supportText() {
    if (focus.hasRecommendation) return focus.reason;
    if (nextTraining.hasRecommendation) return nextTraining.objective;
    return nextTraining.emptyMessage ?? nextTraining.subtitle;
  }

  Color _priorityColor(
    ColorScheme cs,
    RecommendedTrainingFocusPriority focusPriority,
    RecommendedTrainingFocusPriority nextPriority,
  ) {
    final priority =
        focusPriority == RecommendedTrainingFocusPriority.none
            ? nextPriority
            : focusPriority;
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return cs.error;
      case RecommendedTrainingFocusPriority.medium:
        return TitansUI.actionGold;
      case RecommendedTrainingFocusPriority.low:
        return TitansUI.successGreen;
      case RecommendedTrainingFocusPriority.none:
        return cs.primary;
    }
  }
}
