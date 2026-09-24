import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/technical_domain/domain/technical_context.dart';
import '../service/training_aggregator.dart';
import 'charts/titans_technical_radar.dart';
import 'titans_feedback.dart';

class GameMapHeaderCard extends StatelessWidget {
  final String? targetName;

  const GameMapHeaderCard({super.key, required this.targetName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalizedName = targetName?.trim();
    final name =
        normalizedName == null || normalizedName.isEmpty
            ? 'Atleta'
            : normalizedName;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TitansUI.surfaceColor(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Game Map',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameMapContextChangedState extends StatelessWidget {
  const GameMapContextChangedState({super.key});

  @override
  Widget build(BuildContext context) => const TitansStateView.error(
    title: 'Contexto de academia alterado',
    message: 'Abra novamente o Game Map no workspace ativo.',
  );
}

class GameMapLoadingState extends StatelessWidget {
  final bool skeleton;

  const GameMapLoadingState({super.key, this.skeleton = false});

  @override
  Widget build(BuildContext context) =>
      skeleton
          ? const TitansSkeletonCard(lines: 5)
          : const TitansStateView.loading();
}

class GameMapErrorState extends StatelessWidget {
  final Object error;

  const GameMapErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) => TitansStateView.error(
    title: 'Erro ao carregar Game Map',
    message: error.toString(),
  );
}

class GameMapRadarPanel extends StatelessWidget {
  final String subtitle;
  final String stateLabel;
  final List<TitansTechnicalRadarEvidence> evidences;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final TechnicalRadarAxis? selectedAxis;
  final ValueChanged<TechnicalRadarAxis?> onAxisChanged;

  const GameMapRadarPanel({
    super.key,
    required this.subtitle,
    required this.stateLabel,
    required this.evidences,
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
    required this.selectedAxis,
    required this.onAxisChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TitansCard(
      accent: cs.tertiary,
      child: TitansTechnicalRadar(
        subtitle: subtitle,
        stateLabel: stateLabel,
        evidences: evidences,
        axisEvidence: axisEvidence,
        classifiedEvidenceCount: classifiedEvidenceCount,
        awaitingClassificationCount: awaitingClassificationCount,
        interactive: true,
        showMetrics: false,
        contained: false,
        enableHolographicMode: true,
        enablePerspectiveControls: true,
        initialPerspective: TitansRadarPerspective.live,
        enableSweep: true,
        enableHudDetails: true,
        initialFocusedAxis: selectedAxis,
        onFocusedAxisChanged: onAxisChanged,
      ),
    );
  }
}

class GameMapIndicatorRail extends StatelessWidget {
  final int positionsCount;
  final int techniquesCount;
  final String topAxisLabel;
  final int needsReviewCount;
  final int coachEvaluationsCount;

  const GameMapIndicatorRail({
    super.key,
    required this.positionsCount,
    required this.techniquesCount,
    required this.topAxisLabel,
    required this.needsReviewCount,
    required this.coachEvaluationsCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final items = <Widget>[
          _GameMapIndicator(
            label: 'Posições',
            value: positionsCount.toString(),
            icon: Icons.place_outlined,
            color: cs.primary,
          ),
          _GameMapIndicator(
            label: 'Técnicas',
            value: techniquesCount.toString(),
            icon: Icons.sports_mma_outlined,
            color: TitansUI.successGreen,
          ),
          _GameMapIndicator(
            label: 'Eixo principal',
            value: topAxisLabel,
            icon: Icons.radar_outlined,
            color: TitansUI.actionGold,
          ),
          _GameMapIndicator(
            label: 'Avaliações',
            value: coachEvaluationReviewStatusLabel(
              evaluationsCount: coachEvaluationsCount,
              needsReviewCount: needsReviewCount,
            ),
            icon: Icons.rate_review_outlined,
            color:
                coachEvaluationsCount == 0
                    ? cs.onSurface.withValues(alpha: 0.58)
                    : needsReviewCount > 0
                    ? TitansUI.alertRed
                    : TitansUI.successGreen,
          ),
        ];
        const spacing = 8.0;
        final columns = compact ? 2 : 4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _GameMapIndicator extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GameMapIndicator({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class GameMapIndicatorsHelp extends StatelessWidget {
  final bool hasVisualMap;
  final bool hasTechnicalEvidence;
  final bool hasRepertoire;
  final VoidCallback onOpenVisualMap;
  final VoidCallback onOpenTechnicalSummary;
  final VoidCallback onOpenRepertoire;

  const GameMapIndicatorsHelp({
    super.key,
    required this.hasVisualMap,
    required this.hasTechnicalEvidence,
    required this.hasRepertoire,
    required this.onOpenVisualMap,
    required this.onOpenTechnicalSummary,
    required this.onOpenRepertoire,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('game-map-about-indicators'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          'Sobre estes indicadores',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          const _IndicatorExplanation(
            title: 'Radar e eixo principal',
            description:
                'Evidências técnicas classificadas nas últimas 100 sessões concluídas e únicas.',
          ),
          const _IndicatorExplanation(
            title: 'Posições e técnicas',
            description:
                'Posições usam as últimas 20 sessões concluídas; técnicas e categorias usam as últimas 50.',
          ),
          const _IndicatorExplanation(
            title: 'Origem e repertório',
            description:
                'Os dados vêm dos registros de treino. A frequência usa 84 dias e o histórico concluído preserva seu recorte próprio.',
          ),
          const _IndicatorExplanation(
            title: 'Ausências',
            description:
                'Sem registro, sem classificação técnica e sem avaliação humana são estados diferentes.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasVisualMap)
                TextButton.icon(
                  onPressed: onOpenVisualMap,
                  icon: const Icon(Icons.hub_outlined, size: 16),
                  label: const Text('Mapa visual de posições'),
                ),
              if (hasTechnicalEvidence)
                TextButton.icon(
                  onPressed: onOpenTechnicalSummary,
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Resumo agregado'),
                ),
              if (hasRepertoire)
                TextButton.icon(
                  onPressed: onOpenRepertoire,
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Indicadores de repertório'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorExplanation extends StatelessWidget {
  final String title;
  final String description;

  const _IndicatorExplanation({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: description),
                ],
              ),
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.66),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
