import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/training/domain/training_models.dart';
import 'glass_card.dart';

class _TrainingMetricRailItemData {
  final String label;
  final String value;
  final Color color;

  const _TrainingMetricRailItemData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _TrainingMetricRail extends StatelessWidget {
  final List<_TrainingMetricRailItemData> items;

  const _TrainingMetricRail({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.48),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.34)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
          final columns = maxWidth >= 520 ? 4 : 2;
          const gap = 8.0;
          final itemWidth = (maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth.clamp(112.0, maxWidth).toDouble(),
                  child: _TrainingMetricRailItem(
                    item: item,
                    baseColor: cs.onSurface,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrainingMetricRailItem extends StatelessWidget {
  final _TrainingMetricRailItemData item;
  final Color baseColor;

  const _TrainingMetricRailItem({required this.item, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: baseColor.withValues(alpha: 0.54),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TitansAnimatedMetricValue(
            value: item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class TrainingCompactMetricsAndActions extends StatelessWidget {
  final TrainingOverviewSummary summary;
  final String lastTrainingLabel;
  final bool canAddTraining;
  final VoidCallback? onQuickLog;
  final VoidCallback? onAddTraining;
  final VoidCallback? onScheduleTraining;

  const TrainingCompactMetricsAndActions({
    super.key,
    required this.summary,
    required this.lastTrainingLabel,
    required this.canAddTraining,
    this.onQuickLog,
    this.onAddTraining,
    this.onScheduleTraining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = summary.averageIntensity;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Histórico de treinos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastTrainingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TrainingMetricRail(
            items: [
              _TrainingMetricRailItemData(
                label: 'Treinos',
                value: summary.total.toString(),
                color: cs.onSurface,
              ),
              _TrainingMetricRailItemData(
                label: 'Técnicas',
                value: summary.techniques.toString(),
                color: cs.onSurface,
              ),
              _TrainingMetricRailItemData(
                label: 'Intensidade',
                value:
                    intensity == null
                        ? 'Sem dados'
                        : '${intensity.toStringAsFixed(1)}/5',
                color: TitansUI.actionGold,
              ),
              _TrainingMetricRailItemData(
                label: 'Aplicação',
                value: summary.applicationCount.toString(),
                color: TitansUI.successGreen,
              ),
            ],
          ),
          if (canAddTraining &&
              (onQuickLog != null ||
                  onAddTraining != null ||
                  onScheduleTraining != null)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onQuickLog != null)
                  FilledButton.icon(
                    onPressed: onQuickLog,
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Registro rápido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TitansUI.actionGold,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                if (onAddTraining != null)
                  OutlinedButton.icon(
                    onPressed: onAddTraining,
                    icon: const Icon(Icons.add_task_outlined, size: 18),
                    label: const Text('Treino completo'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                if (onScheduleTraining != null)
                  OutlinedButton.icon(
                    onPressed: onScheduleTraining,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Planejar'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
