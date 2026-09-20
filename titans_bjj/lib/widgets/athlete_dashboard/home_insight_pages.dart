import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/home/domain/home_dashboard_models.dart';
import '../../features/technical_domain/domain/technical_models.dart';
import '../../model/training_session.dart';
import 'belt_progress_ring.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';
import 'home_technical_radar_card.dart';
import 'home_view_models.dart';

class HomeRadarInsight extends StatelessWidget {
  final ColorScheme cs;
  final HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;
  final VoidCallback? onRegisterTraining;

  const HomeRadarInsight({
    super.key,
    required this.cs,
    required this.radar,
    required this.onOpenMap,
    this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    return HomeInteractiveTechnicalRadarCard(
      cs: cs,
      radar: radar,
      onOpenMap: onOpenMap,
      onRegisterTraining: onRegisterTraining,
    );
  }
}

class HomeTrainingInsight extends StatelessWidget {
  final ColorScheme cs;
  final HomeTrainingMetrics metrics;
  final List<TrainingSession> recentSessions;
  final TrainingSession? lastSession;
  final VoidCallback onOpenTraining;
  final VoidCallback? onRegisterTraining;

  const HomeTrainingInsight({
    super.key,
    required this.cs,
    required this.metrics,
    required this.recentSessions,
    required this.lastSession,
    required this.onOpenTraining,
    this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : formatShortDate(lastSession!.date);
    final hasRecent = recentSessions.isNotEmpty;

    return DashboardGlassCard(
      accent: TitansUI.successGreen.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Ritmo de treino',
            badgeLabel: '${metrics.recent} em 30 dias',
            badgeIcon: Icons.show_chart_rounded,
            accent: TitansUI.successGreen,
          ),
          const SizedBox(height: 14),
          _HomeTrainingTimeline(
            sessions: recentSessions,
            accent: TitansUI.successGreen,
          ),
          const SizedBox(height: 14),
          _HomeDeckInsightLine(
            icon: Icons.calendar_month_outlined,
            accent: TitansUI.successGreen,
            text:
                hasRecent
                    ? 'Voc\u00ea treinou ${metrics.recent} vezes nos \u00faltimos 30 dias. \u00daltimo treino: $lastTrainingLabel.'
                    : 'Registre treinos para construir essa leitura.',
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label:
                onRegisterTraining == null ? 'Ver treinos' : 'Registrar treino',
            icon:
                onRegisterTraining == null
                    ? Icons.fitness_center_outlined
                    : Icons.add_task_outlined,
            onPressed: onRegisterTraining ?? onOpenTraining,
            filled: onRegisterTraining != null,
          ),
        ],
      ),
    );
  }
}

class HomeProgressInsight extends StatelessWidget {
  final ColorScheme cs;
  final BeltProgress beltProgress;
  final HomeTrainingMetrics metrics;
  final int frequency;

  const HomeProgressInsight({
    super.key,
    required this.cs,
    required this.beltProgress,
    required this.metrics,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = beltProgressRingColor(beltProgress.belt);
    final ruleLabel =
        beltProgress.hasOfficialRule
            ? '${beltProgress.sessionsInBelt}/${beltProgress.sessionsRequired} sess\u00f5es na faixa'
            : '${beltProgress.sessionsInBelt} sess\u00f5es registradas';

    return DashboardGlassCard(
      accent: ringColor.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Progresso de faixa',
            badgeLabel:
                '${beltLabel(beltProgress.belt)} · ${beltProgress.degree}\u00ba grau',
            badgeIcon: Icons.workspace_premium_outlined,
            accent: ringColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              BeltProgressRing(
                colorScheme: cs,
                value: beltProgress.percentToNextBelt,
                color: ringColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeProgressMiniBar(
                      label: ruleLabel,
                      value: beltProgress.percentToNextBelt,
                      color: ringColor,
                    ),
                    const SizedBox(height: 10),
                    _HomeDeckInsightLine(
                      icon: Icons.insights_outlined,
                      accent: ringColor,
                      text:
                          'Base real: ${metrics.total} treinos totais e $frequency% de regularidade em 8 semanas.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HomeDeckPassiveCta(
            icon: Icons.workspace_premium_outlined,
            text: 'Leitura de progresso exibida aqui sem abrir nova rota.',
          ),
        ],
      ),
    );
  }
}

class HomeConsistencyInsight extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final List<GameMapEntry> gameMap;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final VoidCallback onOpenMap;

  const HomeConsistencyInsight({
    super.key,
    required this.cs,
    required this.frequency,
    required this.gameMap,
    required this.skillMatrix,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final topPosition = _topGameMapPosition(gameMap);
    final topTechnique = _topSkillMatrixTechnique(skillMatrix);
    final totalTechniques = skillMatrix.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );

    return DashboardGlassCard(
      accent: cs.secondary.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Consist\u00eancia e repert\u00f3rio',
            badgeLabel: '$frequency% em 8 semanas',
            badgeIcon: Icons.account_tree_outlined,
            accent: cs.secondary,
          ),
          const SizedBox(height: 14),
          _HomeConsistencyConstellation(
            gameMap: gameMap,
            skillMatrix: skillMatrix,
            accent: cs.secondary,
          ),
          const SizedBox(height: 14),
          _HomeDeckInsightLine(
            icon: Icons.hub_outlined,
            accent: cs.secondary,
            text:
                topPosition == null && topTechnique == null
                    ? 'Repert\u00f3rio em forma\u00e7\u00e3o. Registre posi\u00e7\u00e3o e t\u00e9cnica para construir essa leitura.'
                    : 'Mais presente: ${topPosition ?? topTechnique}. Repert\u00f3rio com $totalTechniques t\u00e9cnicas registradas.',
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _HomeDeckHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color accent;

  const _HomeDeckHeader({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardSectionHeaderCompact(title: title),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        DashboardInsightBadge(label: badgeLabel, color: accent, icon: badgeIcon),
      ],
    );
  }
}

class _HomeTrainingTimeline extends StatelessWidget {
  final List<TrainingSession> sessions;
  final Color accent;

  const _HomeTrainingTimeline({required this.sessions, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = sessions.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child:
          items.isEmpty
              ? Text(
                'Dados em forma\u00e7\u00e3o',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              )
              : Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(
                      child: _HomeTrainingTimelineNode(
                        session: items[items.length - 1 - i],
                        accent: accent,
                      ),
                    ),
                    if (i != items.length - 1)
                      Container(
                        width: 10,
                        height: 2,
                        color: cs.onSurface.withValues(alpha: 0.10),
                      ),
                  ],
                ],
              ),
    );
  }
}

class _HomeTrainingTimelineNode extends StatelessWidget {
  final TrainingSession session;
  final Color accent;

  const _HomeTrainingTimelineNode({
    required this.session,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.22),
            border: Border.all(color: accent.withValues(alpha: 0.72)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatShortDate(session.date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HomeProgressMiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HomeProgressMiniBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeValue = value.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 7,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _HomeConsistencyConstellation extends StatelessWidget {
  final List<GameMapEntry> gameMap;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final Color accent;

  const _HomeConsistencyConstellation({
    required this.gameMap,
    required this.skillMatrix,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positions = gameMap.take(4).toList();
    final techniques =
        <SkillMatrixTechniqueEntry>[
          for (final entry in skillMatrix) ...entry.techniques.take(2),
        ].take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child:
          positions.isEmpty && techniques.isEmpty
              ? Text(
                'Dados em forma\u00e7\u00e3o',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              )
              : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in positions)
                    DashboardInsightBadge(
                      label: entry.position,
                      color: accent,
                      icon: Icons.place_outlined,
                    ),
                  for (final technique in techniques)
                    DashboardInsightBadge(
                      label: technique.technique,
                      color: cs.primary,
                      icon: Icons.bubble_chart_outlined,
                      muted: true,
                    ),
                ],
              ),
    );
  }
}

class _HomeDeckInsightLine extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;

  const _HomeDeckInsightLine({
    required this.icon,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDeckPassiveCta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HomeDeckPassiveCta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cs.onSurface.withValues(alpha: 0.045),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.62)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.66),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _topGameMapPosition(List<GameMapEntry> entries) {
  if (entries.isEmpty) return null;
  final ordered = List<GameMapEntry>.from(entries)
    ..sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
  return ordered.first.position;
}

String? _topSkillMatrixTechnique(List<SkillMatrixCategoryEntry> entries) {
  final techniques = <SkillMatrixTechniqueEntry>[
    for (final entry in entries) ...entry.techniques,
  ];
  if (techniques.isEmpty) return null;
  techniques.sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
  return techniques.first.technique;
}

class _HomeRadarCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  const _HomeRadarCta({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_rounded, size: 16),
      ],
    );

    final minimumSize = const Size.fromHeight(42);
    final stylePadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    );
    final button =
        filled
            ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: minimumSize,
                visualDensity: VisualDensity.compact,
                padding: stylePadding,
                backgroundColor: cs.secondary,
                foregroundColor: Colors.black,
              ),
              child: child,
            )
            : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: minimumSize,
                visualDensity: VisualDensity.compact,
                padding: stylePadding,
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.secondary.withValues(alpha: 0.32)),
                backgroundColor: cs.secondary.withValues(alpha: 0.05),
              ),
              child: child,
            );

    return SizedBox(width: double.infinity, child: button);
  }
}
