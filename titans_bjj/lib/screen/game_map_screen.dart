import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

class GameMapScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? title;
  final String? targetName;
  final bool embedded;

  const GameMapScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.title,
    this.targetName,
    this.embedded = false,
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

    return _wrapModule(
      appBar: AppBar(title: Text(widget.title ?? 'Game Map')),
      body: StreamBuilder<List<TrainingSession>>(
        stream: _sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
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
          final entries = TrainingAggregator.buildGameMap(sessions, limit: 20);
          final stats = _GameMapStats.from(entries, skillMatrix);

          return ListView(
            padding:
                widget.embedded
                    ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                    : TitansUI.listPadding(context),
            children: [
              if (!widget.embedded) ...[
                _HeaderCard(colorScheme: cs, targetName: widget.targetName),
                const SizedBox(height: 12),
              ],
              _GameMapSummaryCard(stats: stats),
              const SizedBox(height: 12),
              _SkillMatrixCard(colorScheme: cs, entries: skillMatrix),
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

  Widget _wrapModule({
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    required Widget body,
  }) {
    if (widget.embedded) return body;
    return TitansScaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? targetName;

  const _HeaderCard({required this.colorScheme, required this.targetName});

  @override
  Widget build(BuildContext context) {
    final name = targetName?.trim();

    return _VisualCard(
      accent: colorScheme.primary,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game Map',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
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

class _GameMapSummaryCard extends StatelessWidget {
  final _GameMapStats stats;

  const _GameMapSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'RESUMO T\u00c9CNICO'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'POSI\u00c7\u00d5ES',
                value: stats.positions.toString(),
                color: cs.secondary,
              ),
              _MetricPill(
                label: 'T\u00c9CNICAS',
                value: stats.techniques.toString(),
                color: cs.primary,
              ),
              _MetricPill(
                label: 'DOMINANTE',
                value: stats.dominantCategory ?? '--',
                color: Colors.lightGreenAccent,
              ),
              _MetricPill(
                label: 'INTENSIDADE',
                value:
                    stats.averageIntensity == null
                        ? '--'
                        : '${stats.averageIntensity!.toStringAsFixed(1)}/5',
                color: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillMatrixCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<SkillMatrixCategoryEntry> entries;

  const _SkillMatrixCard({required this.colorScheme, required this.entries});

  @override
  Widget build(BuildContext context) {
    return _VisualCard(
      accent: colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'SKILL MATRIX'),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const TitansEmptyState(
              icon: Icons.grid_view_outlined,
              title: 'Skill Matrix vazia',
              message: 'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para montar sua Skill Matrix.',
              compact: true,
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _SkillMatrixCategoryBlock(entry: entries[i]),
              if (i != entries.length - 1)
                Divider(color: colorScheme.onSurface.withValues(alpha: 0.08)),
            ],
        ],
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
    final visibleTechniques = entry.techniques.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.category.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniBadge(
                label: _plural(entry.techniquesCount, 't\u00e9cnica registrada', 't\u00e9cnicas registradas'),
                color: cs.primary,
              ),
              _MiniBadge(
                label: '${entry.consistencyCount} recorrentes',
                color: Colors.lightGreenAccent,
              ),
              if (intensity != null)
                _MiniBadge(
                  label: '${intensity.toStringAsFixed(1)}/5',
                  color: Colors.amber,
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final technique in visibleTechniques) ...[
            _SkillMatrixTechniqueRow(entry: technique),
            if (technique != visibleTechniques.last) const SizedBox(height: 8),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: Colors.black.withValues(alpha: 0.16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.technique,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniBadge(
                    label: entry.category.displayLabel,
                    color: cs.primary,
                  ),
                  if ((entry.position ?? '').trim().isNotEmpty)
                    _MiniBadge(
                      label: entry.position!.trim(),
                      color: cs.secondary,
                    ),
                  _MiniBadge(
                    label: _plural(entry.sessionsCount, 'sess\u00e3o', 'sess\u00f5es'),
                    color: cs.secondary,
                  ),
                  _MiniBadge(
                    label: '\u00faltima ${_formatShortDate(entry.lastTrainedAt)}',
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  if (entry.averageIntensity != null)
                    _MiniBadge(
                      label:
                          'intensidade ${entry.averageIntensity!.toStringAsFixed(1)}/5',
                      color: Colors.amber,
                    ),
                ],
              ),
            ],
          );
          final levels = SkillLevelDots(
            registered: entry.knowledge,
            trained: entry.drill,
            consistent: entry.consistent,
            applicationMeasured: entry.application == true,
            applicationContext: entry.applicationContext,
            techniqueOutcome: entry.techniqueOutcome,
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 10), levels],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 10),
              Flexible(
                child: Align(alignment: Alignment.topRight, child: levels),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyGameMapCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyGameMapCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return const TitansEmptyState(
      icon: Icons.account_tree_outlined,
      title: 'Game Map vazio',
      message: 'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para montar o mapa.',
      compact: true,
    );
  }
}

class _GameMapPositionCard extends StatelessWidget {
  final GameMapEntry entry;

  const _GameMapPositionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = _averageEntryIntensity(entry);
    final success = _firstShortText(
      entry.techniques.map((technique) => technique.recentSuccess),
      maxLength: 44,
    );
    final difficulty = _firstShortText(
      entry.techniques.map((technique) => technique.recentDifficulty),
      maxLength: 44,
    );

    return _VisualCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              _MiniBadge(
                label: _plural(entry.sessionsCount, 'sess\u00e3o', 'sess\u00f5es'),
                color: cs.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: '\u00faltima ${_formatShortDate(entry.lastTrainedAt)}',
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              if (intensity != null)
                _MiniBadge(
                  label: 'intensidade ${intensity.toStringAsFixed(1)}/5',
                  color: Colors.amber,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final technique in entry.techniques.take(10))
                _TechniqueChip(
                  label: technique.technique,
                  count: technique.sessionsCount,
                ),
            ],
          ),
          if (success != null || difficulty != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (success != null)
                  _MiniBadge(
                    label: 'forte: $success',
                    color: Colors.lightGreenAccent,
                  ),
                if (difficulty != null)
                  _MiniBadge(label: 'aten\u00e7\u00e3o: $difficulty', color: cs.error),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VisualCard extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _VisualCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glow = accent ?? cs.primary;

    return TitansAnimatedSection(
      child: TitansPressableCard(accent: glow, child: child),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final String title;

  const _CompactHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Text(
      title,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.75),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 156),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechniqueChip extends StatelessWidget {
  final String label;
  final int count;

  const _TechniqueChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxLabelWidth =
        MediaQuery.sizeOf(context).width < 420 ? 150.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
        color: cs.primary.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.86)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width < 420 ? 210.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: color.withValues(alpha: 0.08),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.82),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class SkillLevelDots extends StatelessWidget {
  final bool registered;
  final bool trained;
  final bool consistent;
  final bool applicationMeasured;
  final String? applicationContext;
  final String? techniqueOutcome;

  const SkillLevelDots({
    super.key,
    required this.registered,
    required this.trained,
    required this.consistent,
    required this.applicationMeasured,
    required this.applicationContext,
    required this.techniqueOutcome,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SkillStagePill(
          label: 'Registrada',
          description: 'T\u00e9cnica registrada em pelo menos um debrief.',
          active: registered,
          color: cs.primary,
        ),
        _SkillStagePill(
          label: 'Treinada',
          description:
              'T\u00e9cnica apareceu em sess\u00e3o registrada; no MVP acompanha o registro.',
          active: trained,
          color: cs.secondary,
        ),
        _SkillStagePill(
          label: 'Recorrente',
          description: 'Aparece em 3 ou mais sess\u00f5es registradas.',
          active: consistent,
          color: Colors.lightGreenAccent,
        ),
        _SkillStagePill(
          label: _applicationStageLabel(),
          description: applicationMeasured
              ? 'Aplica\u00e7\u00e3o registrada como evid\u00eancia auxiliar.'
              : 'Sem dados de rola/competi\u00e7\u00e3o nesta vers\u00e3o.',
          active: applicationMeasured,
          color: applicationMeasured ? Colors.lightGreenAccent : cs.onSurface,
          neutral: !applicationMeasured,
        ),
      ],
    );
  }

  String _applicationStageLabel() {
    if (!applicationMeasured) return 'Aplica\u00e7\u00e3o ainda n\u00e3o medida';
    final outcome = _techniqueOutcomeDisplayLabel(techniqueOutcome) ??
        'Aplica\u00e7\u00e3o medida';
    final context = _applicationContextDisplayLabel(applicationContext);
    if (context == null) return outcome;
    return '$outcome em $context';
  }
}

class _SkillStagePill extends StatelessWidget {
  final String label;
  final String description;
  final bool active;
  final Color color;
  final bool neutral;

  const _SkillStagePill({
    required this.label,
    required this.description,
    required this.active,
    required this.color,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = active ? color : cs.onSurface;
    final alpha = neutral ? 0.42 : active ? 0.9 : 0.56;

    return Tooltip(
      message: description,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: resolved.withValues(alpha: active ? 0.35 : 0.16),
          ),
          color: resolved.withValues(alpha: active ? 0.1 : 0.06),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: resolved.withValues(alpha: alpha),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameMapStats {
  final int positions;
  final int techniques;
  final String? dominantCategory;
  final double? averageIntensity;

  const _GameMapStats({
    required this.positions,
    required this.techniques,
    required this.dominantCategory,
    required this.averageIntensity,
  });

  factory _GameMapStats.from(
    List<GameMapEntry> entries,
    List<SkillMatrixCategoryEntry> skillMatrix,
  ) {
    final activeCategories = List<SkillMatrixCategoryEntry>.from(skillMatrix)
      ..sort((a, b) {
        final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
        if (sessionsCompare != 0) return sessionsCompare;
        return b.techniquesCount.compareTo(a.techniquesCount);
      });

    return _GameMapStats(
      positions: entries.length,
      techniques: entries.fold<int>(
        0,
        (sum, entry) => sum + entry.techniques.length,
      ),
      dominantCategory:
          activeCategories.isEmpty
              ? null
              : activeCategories.first.category.label,
      averageIntensity: _weightedGameMapIntensity(entries),
    );
  }
}

double? _weightedGameMapIntensity(List<GameMapEntry> entries) {
  var weighted = 0.0;
  var sessions = 0;

  for (final entry in entries) {
    for (final technique in entry.techniques) {
      final intensity = technique.averageIntensity;
      if (intensity == null) continue;
      weighted += intensity * technique.sessionsCount;
      sessions += technique.sessionsCount;
    }
  }

  if (sessions == 0) return null;
  return weighted / sessions;
}

double? _averageEntryIntensity(GameMapEntry entry) {
  var weighted = 0.0;
  var sessions = 0;

  for (final technique in entry.techniques) {
    final intensity = technique.averageIntensity;
    if (intensity == null) continue;
    weighted += intensity * technique.sessionsCount;
    sessions += technique.sessionsCount;
  }

  if (sessions == 0) return null;
  return weighted / sessions;
}

String? _cleanText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String? _firstShortText(Iterable<String?> values, {int maxLength = 96}) {
  for (final value in values) {
    final text = _shortText(value, maxLength: maxLength);
    if (text != null) return text;
  }
  return null;
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

String _plural(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

String? _applicationContextDisplayLabel(String? value) {
  switch (value) {
    case TrainingSession.applicationContextDrill:
      return 'Drill';
    case TrainingSession.applicationContextPositionalSparring:
      return 'Treino posicional';
    case TrainingSession.applicationContextSparring:
      return 'Rola';
    case TrainingSession.applicationContextCompetition:
      return 'Competi\u00e7\u00e3o';
    case TrainingSession.applicationContextNotApplied:
      return 'N\u00e3o aplicada';
    default:
      final clean = value?.trim();
      return clean == null || clean.isEmpty ? null : clean;
  }
}

String? _techniqueOutcomeDisplayLabel(String? value) {
  switch (value) {
    case TrainingSession.techniqueOutcomeWorked:
      return 'Funcionou';
    case TrainingSession.techniqueOutcomeAlmost:
      return 'Quase funcionou';
    case TrainingSession.techniqueOutcomeFailed:
      return 'Falhou';
    case TrainingSession.techniqueOutcomeDefended:
      return 'Parceiro defendeu';
    case TrainingSession.techniqueOutcomeNotTested:
      return 'N\u00e3o testada';
    default:
      final clean = value?.trim();
      return clean == null || clean.isEmpty ? null : clean;
  }
}
