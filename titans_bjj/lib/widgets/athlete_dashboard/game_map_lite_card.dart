import 'package:flutter/material.dart';

import '../../service/training_aggregator.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class GameMapLiteCard extends StatelessWidget {
  final ColorScheme cs;
  final List<GameMapEntry> entries;
  final VoidCallback onOpenFullMap;

  const GameMapLiteCard({
    super.key,
    required this.cs,
    required this.entries,
    required this.onOpenFullMap,
  });

  @override
  Widget build(BuildContext context) {
    final positionsCount = entries.length;
    final techniquesCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.techniques.length,
    );
    final sessionsCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.sessionsCount,
    );
    final mainEntry =
        entries.isEmpty
            ? null
            : (List<GameMapEntry>.from(entries)..sort(
              (a, b) => b.sessionsCount.compareTo(a.sessionsCount),
            )).first;
    final mainTechniques =
        mainEntry?.techniques.take(3).toList() ??
        const <GameMapTechniqueSummary>[];
    final recentSignal = _firstGameMapSignal(entries);

    return DashboardGlassCard(
      accent: cs.secondary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAME MAP INSIGHT',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Baseado nos últimos treinos',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'Registre posição e técnica nos debriefs para montar o Game Map.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else if (mainEntry != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GameMapInsightPill(
                      label: 'Posições',
                      value: positionsCount.toString(),
                      color: cs.primary,
                    ),
                    _GameMapInsightPill(
                      label: 'Técnicas',
                      value: techniquesCount.toString(),
                      color: cs.secondary,
                    ),
                    _GameMapInsightPill(
                      label: 'Sessões',
                      value: sessionsCount.toString(),
                      color: Colors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Olhe primeiro para',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mainEntry.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final technique in mainTechniques)
                      _GameMapInsightTechniqueChip(technique: technique),
                  ],
                ),
                if (recentSignal != null) ...[
                  const SizedBox(height: 12),
                  _GameMapInsightSignal(signal: recentSignal),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenFullMap,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Ver mapa completo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GameMapInsightPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightTechniqueChip extends StatelessWidget {
  final GameMapTechniqueSummary technique;

  const _GameMapInsightTechniqueChip({required this.technique});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart_outlined, size: 15, color: cs.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              technique.technique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            TrainingAggregator.sessionCountLabel(technique.sessionsCount),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightSignal extends StatelessWidget {
  final _GameMapInsightSignalViewModel signal;

  const _GameMapInsightSignal({required this.signal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: signal.color.withValues(alpha: 0.08),
        border: Border.all(color: signal.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signal.icon, size: 18, color: signal.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${signal.label}: ${signal.text}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightSignalViewModel {
  final String label;
  final String text;
  final IconData icon;
  final Color color;

  const _GameMapInsightSignalViewModel({
    required this.label,
    required this.text,
    required this.icon,
    required this.color,
  });
}

_GameMapInsightSignalViewModel? _firstGameMapSignal(
  List<GameMapEntry> entries,
) {
  for (final entry in entries) {
    for (final technique in entry.techniques) {
      final difficulty = shortDebriefText(technique.recentDifficulty);
      if (difficulty != null) {
        return _GameMapInsightSignalViewModel(
          label: 'Atenção recente',
          text: difficulty,
          icon: Icons.warning_amber_outlined,
          color: Colors.amber,
        );
      }

      final success = shortDebriefText(technique.recentSuccess);
      if (success != null) {
        return _GameMapInsightSignalViewModel(
          label: 'Sucesso recente',
          text: success,
          icon: Icons.check_circle_outline,
          color: Colors.lightGreenAccent,
        );
      }
    }
  }

  return null;
}
