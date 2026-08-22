import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
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

          final sessions = snapshot.data ?? const <TrainingSession>[];
          final skillMatrix = TrainingAggregator.buildSkillMatrix(
            sessions,
            limit: 50,
          );
          final entries = TrainingAggregator.buildGameMap(
            sessions,
            limit: 20,
          );

          return ListView(
            padding: TitansUI.listPadding(context),
            children: [
              _HeaderCard(
                colorScheme: cs,
                targetName: widget.targetName,
              ),
              const SizedBox(height: 12),
              _SkillMatrixCard(
                colorScheme: cs,
                entries: skillMatrix,
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

class _SkillMatrixCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<SkillMatrixCategoryEntry> entries;

  const _SkillMatrixCard({
    required this.colorScheme,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skill Matrix',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Matriz tecnica derivada dos debriefs recentes',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(
                'Registre tecnicas nos debriefs para montar a Skill Matrix.',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              )
            else
              for (var i = 0; i < entries.length; i++) ...[
                _SkillMatrixCategoryBlock(entry: entries[i]),
                if (i != entries.length - 1)
                  Divider(color: colorScheme.onSurface.withValues(alpha: 0.08)),
              ],
          ],
        ),
      ),
    );
  }
}

class _SkillMatrixCategoryBlock extends StatelessWidget {
  final SkillMatrixCategoryEntry entry;

  const _SkillMatrixCategoryBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = entry.averageIntensity;
    final summary = <String>[
      '${entry.techniquesCount} ${entry.techniquesCount == 1 ? 'tecnica' : 'tecnicas'}',
      '${entry.sessionsCount} ${entry.sessionsCount == 1 ? 'sessao' : 'sessoes'}',
      '${entry.consistencyCount} recorrente${entry.consistencyCount == 1 ? '' : 's'}',
      if (intensity != null) 'intensidade ${intensity.toStringAsFixed(1)}/5',
    ];
    final visibleTechniques = entry.techniques.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.category.label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            summary.join(' - '),
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.66)),
          ),
          const SizedBox(height: 10),
          for (final technique in visibleTechniques) ...[
            _SkillMatrixTechniqueRow(entry: technique),
            if (technique != visibleTechniques.last)
              SizedBox(
                height: 10,
                child: Center(
                  child: Container(
                    height: 1,
                    color: cs.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SkillMatrixTechniqueRow extends StatelessWidget {
  final SkillMatrixTechniqueEntry entry;

  const _SkillMatrixTechniqueRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = entry.averageIntensity;
    final details = <String>[
      '${entry.sessionsCount} ${entry.sessionsCount == 1 ? 'sessao' : 'sessoes'}',
      'ultima em ${_formatShortDate(entry.lastTrainedAt)}',
      if (intensity != null) 'intensidade ${intensity.toStringAsFixed(1)}/5',
    ];
    final statuses = <String>[
      if (entry.knowledge) 'Registrada',
      if (entry.drill) 'Treinada',
      if (entry.consistent) 'Recorrente',
      'Aplicacao: sem dados ainda',
    ];
    final difficulty = _shortText(entry.recentDifficulty, maxLength: 64);
    final success = _shortText(entry.recentSuccess, maxLength: 64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.technique,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          details.join(' - '),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.66)),
        ),
        const SizedBox(height: 3),
        Text(
          statuses.join(' - '),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
        ),
        if (success != null) ...[
          const SizedBox(height: 3),
          Text(
            'Forca recente: $success',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
        ],
        if (difficulty != null) ...[
          const SizedBox(height: 3),
          Text(
            'Atencao: $difficulty',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
        ],
      ],
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
  final GameMapEntry entry;

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
  final GameMapTechniqueSummary summary;

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
