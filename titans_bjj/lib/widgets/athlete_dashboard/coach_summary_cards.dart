import 'package:flutter/material.dart';

import '../../features/home/domain/home_dashboard_models.dart';
import '../../features/technical_domain/domain/technical_models.dart';
import '../../model/grading_rules.dart';
import '../../model/training_session.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class CoachStudentEmptyCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final VoidCallback onRegisterTraining;

  const CoachStudentEmptyCard({
    super.key,
    required this.cs,
    required this.studentName,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = studentName.trim().split(RegExp(r'\s+')).first;
    return DashboardGlassCard(
      accent: cs.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(title: 'COME\u00c7AR A ACOMPANHAR'),
          const SizedBox(height: 12),
          Text(
            "$firstName ainda n\u00e3o tem treinos registrados.",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Registre o primeiro treino para iniciar o acompanhamento.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRegisterTraining,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Registrar primeiro treino'),
          ),
        ],
      ),
    );
  }
}

class CoachStudentFoundationCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final BeltColor belt;
  final int degree;
  final HomeTrainingMetrics metrics;
  final TrainingSession? lastSession;
  final VoidCallback onRegisterTraining;

  const CoachStudentFoundationCard({
    super.key,
    required this.cs,
    required this.studentName,
    required this.belt,
    required this.degree,
    required this.metrics,
    required this.lastSession,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : formatShortDate(lastSession!.date);
    return DashboardGlassCard(
      accent: cs.secondary.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(title: 'VISÃO DO ALUNO'),
          const SizedBox(height: 12),
          Text(
            studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${beltLabel(belt)} - $degreeº grau',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DashboardMetricPill(
                label: 'TREINOS',
                value: metrics.total.toString(),
                color: cs.primary,
              ),
              DashboardMetricPill(
                label: '30 DIAS',
                value: metrics.recent.toString(),
                color: Colors.amber,
              ),
              DashboardMetricPill(
                label: 'ÚLTIMO',
                value: lastTrainingLabel,
                color: cs.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Perfil técnico ainda em formação. Continue registrando treinos para ampliar as evidências.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 14),
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRegisterTraining,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Registrar treino'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CoachStudentActiveSummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final BeltColor belt;
  final int degree;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final TrainingSession? lastSession;
  final RecommendedTrainingFocus focus;
  final VoidCallback onOpenEvidence;

  const CoachStudentActiveSummaryCard({
    super.key,
    required this.cs,
    required this.studentName,
    required this.belt,
    required this.degree,
    required this.metrics,
    required this.frequency,
    required this.lastSession,
    required this.focus,
    required this.onOpenEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : formatShortDate(lastSession!.date);
    final attentionLabel = _activeAttentionLabel(focus);

    return DashboardGlassCard(
      accent: cs.primary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(
            title: 'VISÃO DO ALUNO',
            action: TextButton.icon(
              onPressed: onOpenEvidence,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Ver evidências'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${beltLabel(belt)} - $degreeº grau',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DashboardMetricPill(
                label: 'TREINOS',
                value: metrics.total.toString(),
                color: cs.primary,
              ),
              DashboardMetricPill(
                label: '30 DIAS',
                value: metrics.recent.toString(),
                color: Colors.amber,
              ),
              DashboardMetricPill(
                label: '8 SEMANAS',
                value: '$frequency%',
                color: cs.secondary,
              ),
              DashboardMetricPill(
                label: 'ÚLTIMO',
                value: lastTrainingLabel,
                color: Colors.lightGreenAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          DashboardInsightBlock(
            title: 'ATENÇÃO TÉCNICA PRINCIPAL',
            value: attentionLabel,
            empty: 'Atenção técnica ainda não definida.',
          ),
        ],
      ),
    );
  }

  String? _activeAttentionLabel(RecommendedTrainingFocus focus) {
    if (!focus.hasRecommendation) return null;
    final technique = focus.technique?.trim();
    if (technique == null || technique.isEmpty) return null;
    final position = focus.position?.trim();
    if (position == null || position.isEmpty) return technique;
    return '$technique em $position';
  }
}

class CoachTechnicalFocusCard extends StatelessWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;
  final NextTrainingRecommendation nextTraining;
  final bool compact;
  final VoidCallback onOpenEvidence;
  final VoidCallback onOpenSkills;

  const CoachTechnicalFocusCard({
    super.key,
    required this.cs,
    required this.focus,
    required this.nextTraining,
    required this.compact,
    required this.onOpenEvidence,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final technique = _technicalFocusTechnique();
    final position = _technicalFocusPosition();
    final hasFocus = technique != null || position != null;
    final status = _technicalFocusStatus();
    final reason = _shortFocusText(
      focus.hasRecommendation ? focus.reason : nextTraining.subtitle,
      fallback: 'Foco técnico ainda em construção.',
      maxLength: compact ? 96 : 132,
    );
    final action = _shortFocusText(
      focus.hasRecommendation
          ? focus.suggestedAction
          : nextTraining.technicalDrill,
      fallback: 'Registrar debrief completo no próximo treino.',
      maxLength: compact ? 80 : 112,
    );
    final accent = _technicalFocusColor(cs, focus.priority);

    if (compact && !hasFocus) {
      return const SizedBox.shrink();
    }

    return DashboardGlassCard(
      accent: accent.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(title: 'FOCO PARA O PRÓXIMO TREINO'),
          const SizedBox(height: 10),
          Text(
            technique ?? 'Foco técnico em formação',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          if (position != null) ...[
            const SizedBox(height: 3),
            Text(
              position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            reason,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
          ),
          const SizedBox(height: 10),
          Text(
            'Recomendação:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            action,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.84),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenEvidence,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Ver evidências'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSkills,
                  icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: const Text('Abrir Skills'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _technicalFocusTechnique() {
    final focusTechnique = focus.technique?.trim();
    if (focusTechnique != null && focusTechnique.isNotEmpty) {
      return focusTechnique;
    }
    final nextTechnique = nextTraining.focusTechnique?.trim();
    if (nextTechnique != null && nextTechnique.isNotEmpty) {
      return nextTechnique;
    }
    return null;
  }

  String? _technicalFocusPosition() {
    final focusPosition = focus.position?.trim();
    if (focusPosition != null && focusPosition.isNotEmpty) {
      return focusPosition;
    }
    final nextPosition = nextTraining.focusPosition?.trim();
    if (nextPosition != null && nextPosition.isNotEmpty) {
      return nextPosition;
    }
    return null;
  }

  String _technicalFocusStatus() {
    if (!focus.hasRecommendation && !nextTraining.hasRecommendation) {
      return focus.confidenceLabel;
    }
    switch (focus.priority) {
      case RecommendedTrainingFocusPriority.high:
      case RecommendedTrainingFocusPriority.medium:
        return 'Precisa de ajuste';
      case RecommendedTrainingFocusPriority.low:
        return 'Repetir para ganhar recorrência';
      case RecommendedTrainingFocusPriority.none:
        return focus.confidenceLabel;
    }
  }

  Color _technicalFocusColor(
    ColorScheme cs,
    RecommendedTrainingFocusPriority priority,
  ) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return cs.error;
      case RecommendedTrainingFocusPriority.medium:
        return Colors.amber;
      case RecommendedTrainingFocusPriority.low:
        return Colors.lightGreenAccent;
      case RecommendedTrainingFocusPriority.none:
        return cs.primary;
    }
  }

  String _shortFocusText(
    String? value, {
    required String fallback,
    required int maxLength,
  }) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return fallback;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3).trimRight()}...';
  }
}
