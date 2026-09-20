import 'package:flutter/material.dart';

import '../../features/technical_domain/domain/technical_models.dart';
import 'dashboard_surfaces.dart';

class NextTrainingCard extends StatefulWidget {
  final ColorScheme cs;
  final NextTrainingRecommendation recommendation;

  const NextTrainingCard({
    super.key,
    required this.cs,
    required this.recommendation,
  });

  @override
  State<NextTrainingCard> createState() => _NextTrainingCardState();
}

class _NextTrainingCardState extends State<NextTrainingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final recommendation = widget.recommendation;
    final priorityColor = _priorityColor(cs, recommendation.priority);
    final visibleTags = recommendation.tags.take(2).toList();
    final hiddenTags = recommendation.tags.skip(2).toList();

    return DashboardGlassCard(
      accent: priorityColor.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                recommendation.hasRecommendation
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardSectionHeaderCompact(title: 'PRÓXIMO TREINO'),
                        const SizedBox(height: 10),
                        Text(
                          recommendation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendation.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommendation.hasRecommendation) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: priorityColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!recommendation.hasRecommendation) ...[
            Text(
              recommendation.emptyMessage ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
            ),
          ] else ...[
            Text(
              recommendation.objective,
              maxLines: _expanded ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.78)),
            ),
            if (visibleTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in visibleTags)
                    DashboardInsightBadge(label: tag, color: priorityColor),
                ],
              ),
            ],
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
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.self_improvement_outlined,
                    label: 'Aquecimento técnico',
                    text: recommendation.warmupSuggestion,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 10),
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.repeat_outlined,
                    label: 'Drill principal',
                    text: recommendation.technicalDrill,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 10),
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.fact_check_outlined,
                    label: 'Aplicação/checagem',
                    text: recommendation.applicationSuggestion,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recommendation.intensityGuidance,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hiddenTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in hiddenTags.take(2))
                          DashboardInsightBadge(label: tag, color: priorityColor),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
}

class _NextTrainingBlock extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _NextTrainingBlock({
    required this.cs,
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
                text,
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
    );
  }
}
