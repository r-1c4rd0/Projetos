import 'package:flutter/material.dart';

import '../../service/training_aggregator.dart';
import 'dashboard_surfaces.dart';

class SkillMatrixSummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final List<SkillMatrixCategoryEntry> entries;
  final VoidCallback onOpenSkillMatrix;

  const SkillMatrixSummaryCard({
    super.key,
    required this.cs,
    required this.entries,
    required this.onOpenSkillMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final activeCategories = List<SkillMatrixCategoryEntry>.from(
      entries,
    )..sort((a, b) {
      final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
      if (sessionsCompare != 0) return sessionsCompare;
      final techniquesCompare = b.techniquesCount.compareTo(a.techniquesCount);
      if (techniquesCompare != 0) return techniquesCompare;
      return a.category.displayLabel.compareTo(b.category.displayLabel);
    });
    final totalTechniques = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );
    final recurringTechniques = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.consistencyCount,
    );
    final measuredApplicationTechniques = entries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          entry.techniques
              .where((technique) => technique.application == true)
              .length,
    );
    final mainCategory =
        activeCategories.isEmpty
            ? '--'
            : activeCategories.first.category.displayLabel;

    return DashboardGlassCard(
      accent: cs.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(
            title: 'SKILL MATRIX',
            action: TextButton.icon(
              onPressed: onOpenSkillMatrix,
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: const Text('Ver Skill Matrix'),
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para montar sua Skill Matrix.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                DashboardMetricPill(
                  label: 'REGISTRADAS',
                  value: totalTechniques.toString(),
                  color: cs.primary,
                ),
                DashboardMetricPill(
                  label: 'RECORRENTES',
                  value: recurringTechniques.toString(),
                  color: Colors.lightGreenAccent,
                ),
                DashboardMetricPill(
                  label: 'CATEGORIA',
                  value: mainCategory,
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Resumo dos debriefs: o mapa completo mostra posi\u00e7\u00e3o, categoria, recorr\u00eancia e intensidade por t\u00e9cnica.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 12),
            DashboardInsightBadge(
              label:
                  measuredApplicationTechniques > 0
                      ? '${TrainingAggregator.techniqueCountLabel(measuredApplicationTechniques)} com aplica\u00e7\u00e3o medida no mapa completo.'
                      : 'Aplica\u00e7\u00e3o ainda n\u00e3o medida.',
              color: cs.onSurface.withValues(alpha: 0.42),
              icon: Icons.radio_button_unchecked,
              muted: true,
            ),
          ],
        ],
      ),
    );
  }
}
