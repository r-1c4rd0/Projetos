import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../widgets/titans_scaffold.dart';

class GameMapScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? title;
  final String? targetName;

  const GameMapScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.title,
    this.targetName,
  });

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  late final TrainingRepository _repository = TrainingRepository.instance;
  late final Stream<List<TrainingSession>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _sessionsStream = _repository.watchSessions(
      academyId: widget.academyId,
      uid: widget.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansScaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Game Map')),
      body: StreamBuilder<List<TrainingSession>>(
        stream: _sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TitansStateView.loading();
          }
          if (snapshot.hasError) {
            return TitansStateView.error(
              title: 'Erro ao carregar Game Map',
              message: snapshot.error.toString(),
            );
          }

          final sessions = List<TrainingSession>.from(
            snapshot.data ?? const <TrainingSession>[],
          )..sort((a, b) => b.date.compareTo(a.date));
          final recentSessions = sessions.take(20).toList();
          final entries = _buildGameMap(recentSessions);

          return ListView(
            padding: TitansUI.listPadding(context),
            children: [
              _HeaderCard(
                colorScheme: cs,
                targetName: widget.targetName,
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                _EmptyGameMapCard(colorScheme: cs)
              else
                for (final entry in entries) ...[
                  _GameMapPositionCard(entry: entry),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  List<_GameMapEntry> _buildGameMap(List<TrainingSession> sessions) {
    final byPosition = <String, Map<String, _TechniqueDraft>>{};

    for (final session in sessions.take(20)) {
      final technique = _cleanText(session.technique);
      if (technique == null) continue;

      final position = _cleanText(session.position) ?? 'Sem posicao definida';
      final techniquesByKey = byPosition.putIfAbsent(position, () => {});
      final key = technique.toLowerCase();
      final draft = techniquesByKey.putIfAbsent(
        key,
        () => _TechniqueDraft(technique: technique),
      );

      draft.sessionsCount += 1;
      if (draft.lastTrainedAt == null ||
          session.date.isAfter(draft.lastTrainedAt!)) {
        draft.lastTrainedAt = session.date;
      }

      final intensity = session.intensity;
      if (intensity != null && intensity >= 1 && intensity <= 5) {
        draft.intensities.add(intensity);
      }

      final difficulty = _cleanText(session.difficulties);
      if (difficulty != null && draft.recentDifficulty == null) {
        draft.recentDifficulty = difficulty;
      }

      final success = _cleanText(session.successes);
      if (success != null && draft.recentSuccess == null) {
        draft.recentSuccess = success;
      }
    }

    final entries = byPosition.entries.map((entry) {
      final techniques = entry.value.values
          .map((draft) => draft.toSummary())
          .toList()
        ..sort(_compareTechnique);

      return _GameMapEntry(
        position: entry.key,
        techniques: techniques,
      );
    }).where((entry) => entry.techniques.isNotEmpty).toList()
      ..sort(_comparePosition);

    return entries;
  }

  int _comparePosition(_GameMapEntry a, _GameMapEntry b) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.position.toLowerCase().compareTo(b.position.toLowerCase());
  }

  int _compareTechnique(_TechniqueSummary a, _TechniqueSummary b) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.technique.toLowerCase().compareTo(b.technique.toLowerCase());
  }
}

class _HeaderCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? targetName;

  const _HeaderCard({
    required this.colorScheme,
    required this.targetName,
  });

  @override
  Widget build(BuildContext context) {
    final name = targetName?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Map',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mapa tecnico baseado nos debriefs recentes',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            if (name != null && name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyGameMapCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyGameMapCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Registre posicao e tecnica nos debriefs dos treinos para montar o Game Map.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.68)),
        ),
      ),
    );
  }
}

class _GameMapPositionCard extends StatelessWidget {
  final _GameMapEntry entry;

  const _GameMapPositionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.position,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < entry.techniques.length; i++) ...[
              _TechniqueTile(summary: entry.techniques[i]),
              if (i != entry.techniques.length - 1)
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TechniqueTile extends StatelessWidget {
  final _TechniqueSummary summary;

  const _TechniqueTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = summary.averageIntensity;
    final details = <String>[
      '${summary.sessionsCount} ${summary.sessionsCount == 1 ? 'sessao' : 'sessoes'}',
      'ultima em ${_formatShortDate(summary.lastTrainedAt)}',
      if (intensity != null)
        'intensidade media ${intensity.toStringAsFixed(1)}/5',
    ];
    final difficulty = _shortText(summary.recentDifficulty);
    final success = _shortText(summary.recentSuccess);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.technique,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            details.join(' - '),
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.66)),
          ),
          if (success != null) ...[
            const SizedBox(height: 6),
            Text(
              'Sucesso recente: $success',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
            ),
          ],
          if (difficulty != null) ...[
            const SizedBox(height: 6),
            Text(
              'Dificuldade recente: $difficulty',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameMapEntry {
  final String position;
  final List<_TechniqueSummary> techniques;

  const _GameMapEntry({
    required this.position,
    required this.techniques,
  });

  int get sessionsCount => techniques.fold<int>(
        0,
        (sum, technique) => sum + technique.sessionsCount,
      );

  DateTime get lastTrainedAt {
    return techniques
        .map((technique) => technique.lastTrainedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class _TechniqueSummary {
  final String technique;
  final int sessionsCount;
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;

  const _TechniqueSummary({
    required this.technique,
    required this.sessionsCount,
    required this.lastTrainedAt,
    required this.averageIntensity,
    required this.recentSuccess,
    required this.recentDifficulty,
  });
}

class _TechniqueDraft {
  final String technique;
  int sessionsCount = 0;
  DateTime? lastTrainedAt;
  final List<int> intensities = [];
  String? recentSuccess;
  String? recentDifficulty;

  _TechniqueDraft({required this.technique});

  _TechniqueSummary toSummary() {
    final averageIntensity = intensities.isEmpty
        ? null
        : intensities.fold<int>(0, (sum, value) => sum + value) /
            intensities.length;

    return _TechniqueSummary(
      technique: technique,
      sessionsCount: sessionsCount,
      lastTrainedAt: lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      averageIntensity: averageIntensity,
      recentSuccess: recentSuccess,
      recentDifficulty: recentDifficulty,
    );
  }
}

String? _cleanText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String? _shortText(String? value, {int maxLength = 96}) {
  final text = _cleanText(value);
  if (text == null) return null;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3).trimRight()}...';
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}