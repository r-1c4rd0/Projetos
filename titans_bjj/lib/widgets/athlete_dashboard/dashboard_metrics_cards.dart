import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/home/domain/home_dashboard_models.dart';
import 'dashboard_surfaces.dart';

class AthleteMinimalMetricsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final HomeTrainingMetrics metrics;

  const AthleteMinimalMetricsCard({
    super.key,
    required this.cs,
    required this.frequency,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.md),
        color: TitansUI.subtleFillColor(context, alpha: 0.62),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.48)),
      ),
      child: TitansCompactMetricGrid(
        fourColumnMinWidth: 440,
        spacing: 8,
        children: [
          _StatMini(
            title: '8 SEMANAS',
            value: '$frequency%',
            highlight: cs.primary,
          ),
          _StatMini(
            title: '30 DIAS',
            value: metrics.recent.toString(),
            highlight: TitansUI.successGreen,
          ),
          _StatMini(
            title: 'ANO',
            value: metrics.year.toString(),
            highlight: TitansUI.actionGold,
          ),
          _StatMini(
            title: 'TOTAL',
            value: metrics.total.toString(),
            highlight: cs.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String title;
  final String value;
  final Color highlight;

  const _StatMini({
    required this.title,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return TitansCompactMetricCard(
      label: title,
      value: value,
      color: highlight,
    );
  }
}

class StatsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final HomeTrainingMetrics metrics;

  const StatsCard({
    super.key,
    required this.cs,
    required this.frequency,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREQUÊNCIA RECENTE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: '8 SEMANAS',
                  value: '$frequency%',
                  highlight: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: '30 DIAS',
                  value: metrics.recent.toString(),
                  highlight: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: 'MES',
                  value: metrics.month.toString(),
                  highlight: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'ANO',
                  value: metrics.year.toString(),
                  highlight: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatMini(
            title: 'TOTAL DE TREINOS',
            value: metrics.total.toString(),
            highlight: Colors.lightGreenAccent,
          ),
        ],
      ),
    );
  }
}

class DebriefInsightsCard extends StatelessWidget {
  final ColorScheme cs;
  final HomeDebriefInsights insights;

  const DebriefInsightsCard({
    super.key,
    required this.cs,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      accent: cs.error.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INTELLIGENCE LITE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          DashboardInsightBlock(
            title: 'FOCO T\u00c9CNICO',
            value: insights.technicalFocus,
            empty:
                'Registre debriefs nos treinos para gerar foco t\u00e9cnico.',
          ),
          const SizedBox(height: 12),
          DashboardInsightBlock(
            title: 'PONTO DE ATENÇÃO',
            value: insights.attentionPoint,
            empty: 'Sem dificuldades registradas nos debriefs recentes.',
          ),
          const SizedBox(height: 12),
          DashboardInsightBlock(
            title: 'PONTO FORTE RECENTE',
            value: insights.strengthPoint,
            empty: 'Sem sucessos registrados nos debriefs recentes.',
          ),
          const SizedBox(height: 12),
          DashboardInsightBlock(
            title: 'INTENSIDADE RECENTE',
            value:
                insights.averageIntensity == null
                    ? null
                    : 'Média recente: ${insights.averageIntensity!.toStringAsFixed(1)}/5',
            empty: 'Sem intensidade registrada nos debriefs recentes.',
          ),
        ],
      ),
    );
  }
}
