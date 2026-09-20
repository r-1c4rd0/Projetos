import 'package:flutter/material.dart';

import '../../features/technical_domain/domain/technical_models.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class RecommendedFocusCard extends StatefulWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;

  const RecommendedFocusCard({super.key, required this.cs, required this.focus});

  @override
  State<RecommendedFocusCard> createState() => _RecommendedFocusCardState();
}

class _RecommendedFocusCardState extends State<RecommendedFocusCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final focus = widget.focus;
    final priorityColor = _priorityColor(cs, focus.priority);
    final primaryTags = focus.tags.take(1).toList();
    final secondaryTags = focus.tags.skip(1).toList();
    final evidence = <String>[
      ...focus.evidenceTags,
      focus.confidenceLabel,
      focus.evidenceLabel,
      if (focus.avgIntensity != null)
        'Intensidade média ${focus.avgIntensity!.toStringAsFixed(1)}/5',
      if (focus.lastTrainedAt != null)
        'Último treino: ${formatShortDate(focus.lastTrainedAt!)}',
    ];

    return DashboardGlassCard(
      accent: priorityColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardSectionHeaderCompact(title: 'FOCO RECOMENDADO'),
                        const SizedBox(height: 10),
                        Text(
                          focus.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focus.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: priorityColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _focusStatusLabel(focus.priority),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: priorityColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            focus.reason,
            maxLines: _expanded ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DashboardInsightBadge(
                label: _priorityLabel(focus.priority),
                color: priorityColor,
                icon: Icons.bolt_outlined,
                muted: focus.priority == RecommendedTrainingFocusPriority.none,
              ),
              for (final tag in primaryTags)
                DashboardInsightBadge(label: tag, color: priorityColor),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: priorityColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ação sugerida:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.62),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            focus.suggestedAction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (secondaryTags.isNotEmpty || evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in secondaryTags.take(3))
                        DashboardInsightBadge(label: tag, color: priorityColor),
                      for (final label in evidence.take(3))
                        DashboardInsightBadge(
                          label: label,
                          color: cs.onSurface.withValues(alpha: 0.46),
                          icon: Icons.analytics_outlined,
                          muted: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(
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
        return cs.onSurface.withValues(alpha: 0.48);
    }
  }

  String _focusStatusLabel(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
      case RecommendedTrainingFocusPriority.medium:
        return 'Precisa de ajuste';
      case RecommendedTrainingFocusPriority.low:
        return 'Manter atenção';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }

  String _priorityLabel(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return 'Prioridade alta';
      case RecommendedTrainingFocusPriority.medium:
        return 'Prioridade média';
      case RecommendedTrainingFocusPriority.low:
        return 'Prioridade baixa';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }
}
