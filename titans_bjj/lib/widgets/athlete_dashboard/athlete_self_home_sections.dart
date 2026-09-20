import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/home/domain/home_dashboard_models.dart';
import '../../model/training_session.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class AthleteHomeHistorySummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final HomeTrainingMetrics metrics;
  final TrainingSession? lastSession;
  final VoidCallback onOpenTraining;
  final ValueChanged<TrainingSession> onOpenTrainingSession;

  const AthleteHomeHistorySummaryCard({
    super.key,
    required this.cs,
    required this.frequency,
    required this.metrics,
    required this.lastSession,
    required this.onOpenTraining,
    required this.onOpenTrainingSession,
  });

  @override
  Widget build(BuildContext context) {
    final session = lastSession;

    return DashboardGlassCard(
      accent: TitansUI.successGreen.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(
            title: 'RESUMO DO HISTÓRICO',
            action: TextButton(
              onPressed: onOpenTraining,
              child: const Text('Ver todos'),
            ),
          ),
          if (session == null) ...[
            const SizedBox(height: 6),
            Text(
              'Seu histórico começa quando você registra o primeiro treino.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            TitansCompactMetricGrid(
              spacing: 8,
              children: [
                TitansCompactMetricCard(
                  label: '8 SEMANAS',
                  value: '$frequency%',
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: '30 DIAS',
                  value: metrics.recent.toString(),
                  color: TitansUI.successGreen,
                ),
                TitansCompactMetricCard(
                  label: 'ANO',
                  value: metrics.year.toString(),
                  color: TitansUI.actionGold,
                ),
                TitansCompactMetricCard(
                  label: 'TOTAL',
                  value: metrics.total.toString(),
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: cs.onSurface.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 10),
            _LatestTrainingRow(
              session: session,
              onPressed: () => onOpenTrainingSession(session),
            ),
          ],
        ],
      ),
    );
  }
}

class AthleteHomeExpandableDetails extends StatelessWidget {
  final Widget child;

  const AthleteHomeExpandableDetails({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.md),
        color: TitansUI.subtleFillColor(context, alpha: 0.48),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.42)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Icon(Icons.analytics_outlined, color: cs.primary),
          title: const Text(
            'Ver análises e detalhes',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            'Radar, ritmo, progresso e repertório',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class AthleteHomeDestinationsCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onOpenTraining;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenSkills;

  const AthleteHomeDestinationsCard({
    super.key,
    required this.cs,
    required this.onOpenTraining,
    required this.onOpenProgress,
    required this.onOpenGameMap,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = [
      _HomeDestination(
        label: 'Treinos',
        icon: Icons.sports_mma_outlined,
        onPressed: onOpenTraining,
      ),
      _HomeDestination(
        label: 'Progresso',
        icon: Icons.insights_outlined,
        onPressed: onOpenProgress,
      ),
      _HomeDestination(
        label: 'Game Map',
        icon: Icons.map_outlined,
        onPressed: onOpenGameMap,
      ),
      _HomeDestination(
        label: 'Skills',
        icon: Icons.psychology_alt_outlined,
        onPressed: onOpenSkills,
      ),
    ];

    return DashboardGlassCard(
      accent: cs.primary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardSectionHeaderCompact(title: 'ACESSOS'),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final columns = textScale > 1.3 ? 1 : 2;
              const spacing = 8.0;
              final buttonWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final destination in destinations)
                    SizedBox(
                      width: buttonWidth,
                      child: OutlinedButton.icon(
                        onPressed: destination.onPressed,
                        icon: Icon(destination.icon, size: 18),
                        label: Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeDestination {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _HomeDestination({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class _LatestTrainingRow extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onPressed;

  const _LatestTrainingRow({required this.session, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = session.effectiveTechniqueEntries;
    final technique =
        entries.isEmpty ? 'Treino registrado' : entries.first.technique;
    final position =
        entries.isEmpty ? session.position : entries.first.position;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.history_rounded, color: cs.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                technique,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  formatShortDate(session.date),
                  if (position != null && position.trim().isNotEmpty) position,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onPressed, child: const Text('Abrir')),
      ],
    );
  }
}
