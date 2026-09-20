import 'package:flutter/material.dart';

import '../../features/technical_domain/domain/technical_taxonomy.dart';
import '../../model/training_session.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class RecentActivityTimelineCard extends StatelessWidget {
  final ColorScheme cs;
  final List<TrainingSession> items;
  final bool compact;
  final VoidCallback onOpenTraining;
  final VoidCallback? onRegisterTraining;
  final ValueChanged<TrainingSession>? onOpenTrainingSession;
  final ValueChanged<HomeTechniqueNavigationTarget>? onOpenTechnique;

  const RecentActivityTimelineCard({
    super.key,
    required this.cs,
    required this.items,
    this.compact = false,
    required this.onOpenTraining,
    this.onRegisterTraining,
    this.onOpenTrainingSession,
    this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final lastSession = items.isEmpty ? null : items.first;

    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '\u00daLTIMO TREINO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenTraining,
                child: Text(compact ? 'Hist\u00f3rico' : 'Ver hist\u00f3rico'),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          if (lastSession == null)
            _LastTrainingEmptyState(
              cs: cs,
              onRegisterTraining: onRegisterTraining,
            )
          else
            _LastTrainingFocus(
              cs: cs,
              session: lastSession,
              previousSessions: items.skip(1).take(2).toList(),
              compact: compact,
              onOpenTraining: onOpenTraining,
              onOpenTrainingSession: onOpenTrainingSession,
              onOpenTechnique: onOpenTechnique,
            ),
        ],
      ),
    );
  }
}

class _LastTrainingEmptyState extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback? onRegisterTraining;

  const _LastTrainingEmptyState({required this.cs, this.onRegisterTraining});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nenhum treino realizado ainda.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (onRegisterTraining != null) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onRegisterTraining,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar treino'),
          ),
        ],
      ],
    );
  }
}

class _LastTrainingFocus extends StatelessWidget {
  final ColorScheme cs;
  final TrainingSession session;
  final List<TrainingSession> previousSessions;
  final bool compact;
  final VoidCallback onOpenTraining;
  final ValueChanged<TrainingSession>? onOpenTrainingSession;
  final ValueChanged<HomeTechniqueNavigationTarget>? onOpenTechnique;

  const _LastTrainingFocus({
    required this.cs,
    required this.session,
    required this.previousSessions,
    required this.compact,
    required this.onOpenTraining,
    required this.onOpenTrainingSession,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final techniques = session.effectiveTechniqueEntries;
    final visibleTechniques = techniques.take(3).toList();
    final overflowCount = techniques.length - visibleTechniques.length;
    final headline = _LastTrainingHeadline.fromSession(session);
    final notes = shortDebriefText(session.debriefNotes ?? session.notes);
    final difficulties = shortDebriefText(session.difficulties);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    headline.subtitle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatShortDate(session.date),
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DashboardInsightBadge(
              label: headline.techniqueCountLabel,
              color: cs.primary,
            ),
            if (session.intensity != null)
              DashboardInsightBadge(
                label: 'Intensidade ${session.intensity}/5',
                color: cs.secondary,
              ),
            if (headline.position != null)
              DashboardInsightBadge(label: headline.position!, color: cs.tertiary),
          ],
        ),
        if (visibleTechniques.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < visibleTechniques.length; i++) ...[
            _LastTrainingTechniqueRow(
              entry: visibleTechniques[i],
              session: session,
              onOpenTechnique: onOpenTechnique,
            ),
            if (i != visibleTechniques.length - 1)
              Divider(color: cs.onSurface.withValues(alpha: 0.08)),
          ],
          if (overflowCount > 0) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _openTrainingSessionOrHistory(session),
              icon: const Icon(Icons.more_horiz_rounded),
              label: Text('+ $overflowCount t\u00e9cnicas'),
            ),
          ],
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'Treino realizado sem t\u00e9cnica detalhada.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
          ),
        ],
        if (difficulties != null) ...[
          const SizedBox(height: 10),
          _LastTrainingNote(label: 'Dificuldade', text: difficulties),
        ],
        if (notes != null) ...[
          const SizedBox(height: 8),
          _LastTrainingNote(label: 'Observa\u00e7\u00e3o', text: notes),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _openTrainingSessionOrHistory(session),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Treino completo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenTraining,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Hist\u00f3rico'),
              ),
            ),
          ],
        ),
        if (!compact && previousSessions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'ANTERIORES',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final previous in previousSessions)
            _PreviousTrainingRow(
              session: previous,
              onTap: () => _openTrainingSessionOrHistory(previous),
            ),
        ],
      ],
    );
  }

  void _openTrainingSessionOrHistory(TrainingSession selected) {
    final openSession = onOpenTrainingSession;
    if (openSession == null) {
      onOpenTraining();
      return;
    }
    openSession(selected);
  }
}

class _LastTrainingTechniqueRow extends StatelessWidget {
  final TrainingTechniqueEntry entry;
  final TrainingSession session;
  final ValueChanged<HomeTechniqueNavigationTarget>? onOpenTechnique;

  const _LastTrainingTechniqueRow({
    required this.entry,
    required this.session,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = HomeTechniqueNavigationTarget.fromEntry(entry, session);
    final detailParts = <String>[
      if (cleanDebriefText(entry.position) != null)
        cleanDebriefText(entry.position)!,
      if (TrainingSession.applicationContextLabel(entry.applicationContext) !=
          null)
        TrainingSession.applicationContextLabel(entry.applicationContext)!,
      if (TrainingSession.techniqueOutcomeLabel(entry.techniqueOutcome) != null)
        TrainingSession.techniqueOutcomeLabel(entry.techniqueOutcome)!,
    ];
    final note = shortDebriefText(entry.notes, maxLength: 64);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpenTechnique == null ? null : () => onOpenTechnique!(target),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detailParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.70),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onOpenTechnique != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.48),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LastTrainingNote extends StatelessWidget {
  final String label;
  final String text;

  const _LastTrainingNote({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.74)),
        ),
      ],
    );
  }
}

class _PreviousTrainingRow extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onTap;

  const _PreviousTrainingRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headline = _LastTrainingHeadline.fromSession(session);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                formatShortDate(session.date),
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headline.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.48),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastTrainingHeadline {
  final String title;
  final String subtitle;
  final String techniqueCountLabel;
  final String? position;

  const _LastTrainingHeadline({
    required this.title,
    required this.subtitle,
    required this.techniqueCountLabel,
    required this.position,
  });

  factory _LastTrainingHeadline.fromSession(TrainingSession session) {
    final entries = session.effectiveTechniqueEntries;
    final primaryEntry = entries.isEmpty ? null : entries.first;
    final technique =
        cleanDebriefText(primaryEntry?.technique) ??
        cleanDebriefText(session.technique);
    final position =
        cleanDebriefText(primaryEntry?.position) ??
        cleanDebriefText(session.position);
    final context =
        TrainingSession.applicationContextLabel(
          primaryEntry?.applicationContext,
        ) ??
        TrainingSession.applicationContextLabel(session.applicationContext) ??
        cleanDebriefText(session.classType);
    final title = switch ((technique, position)) {
      (final String tech, final String pos) => '$tech · $pos',
      (final String tech, null) => tech,
      (null, final String pos) => pos,
      _ => 'Treino realizado',
    };
    final subtitleParts = <String>[
      _coachTimelinePlaceLabel(session.place),
      if (context != null) context,
    ];

    return _LastTrainingHeadline(
      title: title,
      subtitle: subtitleParts.join(' · '),
      techniqueCountLabel: _techniqueCountLabel(entries.length),
      position: position,
    );
  }
}

class HomeTechniqueNavigationTarget {
  final String skillId;
  final String displayName;
  final JiuJitsuSkillCategory category;
  final String? position;

  const HomeTechniqueNavigationTarget({
    required this.skillId,
    required this.displayName,
    required this.category,
    required this.position,
  });

  factory HomeTechniqueNavigationTarget.fromEntry(
    TrainingTechniqueEntry entry,
    TrainingSession session,
  ) {
    final displayName =
        cleanDebriefText(entry.technique) ?? 'Treino t\u00e9cnico';
    final position =
        cleanDebriefText(entry.position) ??
        cleanDebriefText(session.position);

    return HomeTechniqueNavigationTarget(
      skillId: _homeSkillIdForTechnique(displayName),
      displayName: displayName,
      category: JiuJitsuTaxonomy.categoryFor(
        position: position,
        technique: displayName,
      ),
      position: position,
    );
  }
}

String _homeSkillIdForTechnique(String technique) {
  final identity = JiuJitsuTaxonomy.resolveSkillIdentity(technique);
  final normalizedName =
      identity?.normalizedName ?? JiuJitsuTaxonomy.normalizedKey(technique);
  return identity?.skillId ?? 'custom.${normalizedName.replaceAll(' ', '_')}';
}

String _techniqueCountLabel(int count) {
  if (count == 1) return '1 t\u00e9cnica';
  return '$count t\u00e9cnicas';
}

String _coachTimelinePlaceLabel(TrainingPlace place) {
  switch (place) {
    case TrainingPlace.academy:
      return 'Academia';
    case TrainingPlace.home:
      return 'Casa';
    case TrainingPlace.other:
      return 'Outro local';
  }
}

String _formatTimelineDate(DateTime date) {
  const months = <String>[
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${months[date.month - 1]}';
}
