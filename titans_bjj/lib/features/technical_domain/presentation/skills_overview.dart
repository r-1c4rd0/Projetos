import 'package:flutter/material.dart';

import '../../../core/titans_ui.dart';
import '../../../model/coach_evaluation.dart';
import '../../../service/training_aggregator.dart';
import '../../../widgets/titans_expandable_section.dart';

class SkillsOverview extends StatelessWidget {
  final bool embedded;
  final String? targetName;
  final SkillsOverviewSummary summary;

  const SkillsOverview({
    super.key,
    required this.embedded,
    required this.targetName,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          _SkillsLibraryHero(targetName: targetName, summary: summary),
          const SizedBox(height: 8),
        ],
        _SkillsMetricRail(summary: summary),
        const SizedBox(height: 12),
        TitansExpandableSection(
          title: 'Visão do repertório',
          subtitle: 'Técnicas registradas a partir dos treinos.',
          initiallyExpanded: true,
          child: _SkillsOverviewCard(summary: summary),
        ),
      ],
    );
  }
}

class SkillsOverviewSummary {
  final int registeredTechniques;
  final int appliedTechniques;
  final int mappedCategories;
  final int mappedPositions;
  final int evaluatedTechniques;

  const SkillsOverviewSummary({
    required this.registeredTechniques,
    required this.appliedTechniques,
    required this.mappedCategories,
    required this.mappedPositions,
    required this.evaluatedTechniques,
  });

  int get maxOverviewValue {
    final values = [
      registeredTechniques,
      appliedTechniques,
      mappedCategories,
      mappedPositions,
      evaluatedTechniques,
      1,
    ];
    values.sort();
    return values.last;
  }

  factory SkillsOverviewSummary.from({
    required List<GameMapEntry> entries,
    required List<SkillMatrixCategoryEntry> categories,
    required List<CoachEvaluation> evaluations,
  }) {
    final techniques = categories.expand((entry) => entry.techniques).toList();
    final evaluatedSkillIds = <String>{};
    for (final evaluation in evaluations) {
      final skillId = evaluation.skillId.trim();
      if (skillId.isNotEmpty) evaluatedSkillIds.add(skillId);
    }

    return SkillsOverviewSummary(
      registeredTechniques: techniques.length,
      appliedTechniques:
          techniques.where((entry) => entry.application == true).length,
      mappedCategories: categories.length,
      mappedPositions: entries.length,
      evaluatedTechniques: evaluatedSkillIds.length,
    );
  }
}

class _SkillsLibraryHero extends StatelessWidget {
  final String? targetName;
  final SkillsOverviewSummary summary;

  const _SkillsLibraryHero({required this.targetName, required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = targetName?.trim();
    final hasData =
        summary.registeredTechniques > 0 ||
        summary.mappedCategories > 0 ||
        summary.mappedPositions > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TitansUI.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.psychology_alt_outlined,
              size: 18,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Biblioteca técnica',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  name == null || name.isEmpty
                      ? 'Técnicas e registros organizados a partir dos seus treinos.'
                      : 'Técnicas e registros de $name.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasData) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${summary.registeredTechniques} técnicas e ${summary.mappedCategories} categorias nas últimas 50 concluídas · ${summary.mappedPositions} posições nas últimas 20',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.52),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsMetricRail extends StatelessWidget {
  final SkillsOverviewSummary summary;

  const _SkillsMetricRail({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TitansUI.spaceSm),
      child: TitansCompactMetricGrid(
        spacing: TitansUI.spaceXs,
        children: [
          TitansCompactMetricCard(
            label: 'TÉCNICAS · 50',
            value: summary.registeredTechniques.toString(),
            color: cs.primary,
          ),
          TitansCompactMetricCard(
            label: 'CATEGORIAS · 50',
            value: summary.mappedCategories.toString(),
            color: Colors.lightGreenAccent,
          ),
          TitansCompactMetricCard(
            label: 'POSIÇÕES · 20',
            value: summary.mappedPositions.toString(),
            color: TitansUI.technicalBlue,
          ),
          TitansCompactMetricCard(
            label: 'APLICADAS · 50',
            value: summary.appliedTechniques.toString(),
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _SkillsOverviewCard extends StatelessWidget {
  final SkillsOverviewSummary summary;

  const _SkillsOverviewCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverviewLine(
            label: 'Técnicas registradas',
            value: summary.registeredTechniques,
            maxValue: summary.maxOverviewValue,
            color: cs.primary,
          ),
          const SizedBox(height: 8),
          _OverviewLine(
            label: 'Técnicas aplicadas',
            value: summary.appliedTechniques,
            maxValue: summary.maxOverviewValue,
            color: cs.secondary,
          ),
          const SizedBox(height: 8),
          _OverviewLine(
            label: 'Posições mapeadas',
            value: summary.mappedPositions,
            maxValue: summary.maxOverviewValue,
            color: Colors.lightGreenAccent,
          ),
          const SizedBox(height: 8),
          _OverviewLine(
            label: 'Técnicas com avaliação do professor',
            value: summary.evaluatedTechniques,
            maxValue: summary.maxOverviewValue,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}

class _OverviewLine extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _OverviewLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction =
        maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.68),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: fraction,
            backgroundColor: cs.onSurface.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
