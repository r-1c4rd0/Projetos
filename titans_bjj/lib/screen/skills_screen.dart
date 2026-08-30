import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
import '../widgets/titans_expandable_section.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import 'skill_detail_screen.dart';

class SkillsScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? title;
  final String? targetName;
  final AppUser? loggedUser;
  final bool embedded;

  const SkillsScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.title,
    this.targetName,
    this.loggedUser,
    this.embedded = false,
  });

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  late final TrainingRepository _repository = TrainingRepository.instance;
  late final CoachEvaluationRepository _coachEvaluationRepository =
      CoachEvaluationRepository.instance;
  late final Stream<List<TrainingSession>> _sessionsStream;
  late final Stream<List<CoachEvaluation>> _coachEvaluationsStream;

  @override
  void initState() {
    super.initState();
    _sessionsStream = _repository.watchSessions(
      academyId: widget.academyId,
      uid: widget.uid,
    );
    _coachEvaluationsStream = _coachEvaluationRepository.watchEvaluations(
      academyId: widget.academyId,
      athleteUid: widget.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _wrapModule(
      appBar: AppBar(title: Text(widget.title ?? 'Skills')),
      body: StreamBuilder<List<TrainingSession>>(
        stream: _sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
          }
          if (snapshot.hasError) {
            return TitansStateView.error(
              title: 'Erro ao carregar Skills',
              message: snapshot.error.toString(),
            );
          }

          final sessions = snapshot.data ?? const <TrainingSession>[];
          final skillMatrix = TrainingAggregator.buildSkillMatrix(
            sessions,
            limit: 50,
          );
          final entries = TrainingAggregator.buildGameMap(sessions, limit: 20);

          return StreamBuilder<List<CoachEvaluation>>(
            stream: _coachEvaluationsStream,
            builder: (context, evaluationSnapshot) {
              final evaluations =
                  evaluationSnapshot.data ?? const <CoachEvaluation>[];
              final summary = _SkillsSummaryViewModel.from(
                entries: entries,
                categories: skillMatrix,
                evaluations: evaluations,
              );

              void openSkillDetail(_SkillNavigationTarget skill) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => SkillDetailScreen(
                          academyId: widget.academyId,
                          uid: widget.uid,
                          loggedUser: widget.loggedUser,
                          skillId: skill.skillId,
                          displayName: skill.displayName,
                          category: skill.category,
                          preferredPosition: skill.position,
                          sessions: sessions,
                          evaluations: evaluations,
                        ),
                  ),
                );
              }

              return ListView(
                padding:
                    widget.embedded
                        ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                        : TitansUI.listPadding(context),
                children: [
                  if (!widget.embedded) ...[
                    _SkillsHeaderCard(targetName: widget.targetName),
                    const SizedBox(height: 12),
                  ],
                  _SkillsSummaryCard(summary: summary),
                  const SizedBox(height: 12),
                  TitansExpandableSection(
                    title: 'Visão do repertório',
                    subtitle: 'Técnicas registradas a partir dos treinos.',
                    initiallyExpanded: true,
                    child: _SkillsOverviewCard(summary: summary),
                  ),
                  const SizedBox(height: 12),
                  TitansExpandableSection(
                    title: 'Explorar',
                    subtitle: _explorerSectionSummary(entries),
                    initiallyExpanded: true,
                    child: _SkillsExplorer(
                      entries: entries,
                      categories: skillMatrix,
                      onOpenTechnique: openSkillDetail,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _wrapModule({PreferredSizeWidget? appBar, required Widget body}) {
    if (widget.embedded) return body;
    return TitansScaffold(appBar: appBar, body: body);
  }
}

class _SkillsHeaderCard extends StatelessWidget {
  final String? targetName;

  const _SkillsHeaderCard({required this.targetName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = targetName?.trim();

    return TitansCard(
      accent: cs.primary,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.psychology_alt_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skills',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name == null || name.isEmpty
                      ? 'Repertório técnico do atleta.'
                      : 'Repertório técnico de $name.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.68),
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

class _SkillsSummaryCard extends StatelessWidget {
  final _SkillsSummaryViewModel summary;

  const _SkillsSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkillsSectionEyebrow('SEU REPERTÓRIO TÉCNICO'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              return GridView.count(
                crossAxisCount: compact ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: compact ? 1.32 : 1.22,
                children: [
                  TitansMetricCard(
                    label: 'Técnicas registradas',
                    value: summary.registeredTechniques.toString(),
                    icon: Icons.format_list_bulleted_outlined,
                    color: cs.primary,
                  ),
                  TitansMetricCard(
                    label: 'Técnicas aplicadas',
                    value: summary.appliedTechniques.toString(),
                    icon: Icons.track_changes_outlined,
                    color: cs.secondary,
                  ),
                  TitansMetricCard(
                    label: 'Categorias/posições',
                    value:
                        '${summary.mappedCategories}/${summary.mappedPositions}',
                    icon: Icons.account_tree_outlined,
                    color: Colors.lightGreenAccent,
                  ),
                  TitansMetricCard(
                    label: 'Avaliações',
                    value: summary.evaluatedTechniques.toString(),
                    icon: Icons.rate_review_outlined,
                    color: Colors.amber,
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

class _SkillsOverviewCard extends StatelessWidget {
  final _SkillsSummaryViewModel summary;

  const _SkillsOverviewCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverviewLine(
            label: 'Técnicas registradas',
            value: summary.registeredTechniques,
            maxValue: summary.maxOverviewValue,
            color: cs.primary,
          ),
          const SizedBox(height: 10),
          _OverviewLine(
            label: 'Técnicas aplicadas',
            value: summary.appliedTechniques,
            maxValue: summary.maxOverviewValue,
            color: cs.secondary,
          ),
          const SizedBox(height: 10),
          _OverviewLine(
            label: 'Posições mapeadas',
            value: summary.mappedPositions,
            maxValue: summary.maxOverviewValue,
            color: Colors.lightGreenAccent,
          ),
          const SizedBox(height: 10),
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
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: fraction,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SkillNavigationTarget {
  final String skillId;
  final String displayName;
  final JiuJitsuSkillCategory category;
  final String? position;

  const _SkillNavigationTarget({
    required this.skillId,
    required this.displayName,
    required this.category,
    required this.position,
  });

  factory _SkillNavigationTarget.fromGameMap({
    required GameMapTechniqueSummary technique,
    required String position,
  }) {
    return _SkillNavigationTarget(
      skillId: _skillIdForTechnique(technique.technique),
      displayName: technique.technique,
      category: JiuJitsuTaxonomy.categoryFor(
        position: position,
        technique: technique.technique,
      ),
      position: position,
    );
  }

  factory _SkillNavigationTarget.fromSkillMatrix(
    SkillMatrixTechniqueEntry technique,
  ) {
    return _SkillNavigationTarget(
      skillId: _skillIdForTechnique(technique.technique),
      displayName: technique.technique,
      category: technique.category,
      position: technique.position,
    );
  }
}

String _skillIdForTechnique(String technique) {
  final identity = JiuJitsuTaxonomy.resolveSkillIdentity(technique);
  final normalizedName =
      identity?.normalizedName ?? JiuJitsuTaxonomy.normalizedKey(technique);
  return identity?.skillId ?? 'custom.${normalizedName.replaceAll(' ', '_')}';
}

enum _ExplorerMode { position, category }

class _SkillsExplorer extends StatefulWidget {
  final List<GameMapEntry> entries;
  final List<SkillMatrixCategoryEntry> categories;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _SkillsExplorer({
    required this.entries,
    required this.categories,
    required this.onOpenTechnique,
  });

  @override
  State<_SkillsExplorer> createState() => _SkillsExplorerState();
}

class _SkillsExplorerState extends State<_SkillsExplorer> {
  _ExplorerMode _mode = _ExplorerMode.position;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExplorerModeSelector(
          selected: _mode,
          onChanged: (mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child:
              _mode == _ExplorerMode.position
                  ? _PositionExplorerList(
                    entries: widget.entries,
                    onOpenTechnique: widget.onOpenTechnique,
                  )
                  : _CategoryExplorerList(
                    categories: widget.categories,
                    onOpenTechnique: widget.onOpenTechnique,
                  ),
        ),
      ],
    );
  }
}

class _ExplorerModeSelector extends StatelessWidget {
  final _ExplorerMode selected;
  final ValueChanged<_ExplorerMode> onChanged;

  const _ExplorerModeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Por posição',
              selected: selected == _ExplorerMode.position,
              onTap: () => onChanged(_ExplorerMode.position),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Por categoria',
              selected: selected == _ExplorerMode.category,
              onTap: () => onChanged(_ExplorerMode.category),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? cs.primary.withValues(alpha: 0.18) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selected ? cs.primary : cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionExplorerList extends StatelessWidget {
  final List<GameMapEntry> entries;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _PositionExplorerList({
    required this.entries,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const TitansStateView.empty(
        title: 'Sem posições mapeadas',
        message:
            'Registre treinos com posição e técnica para montar o repertório.',
        compact: true,
      );
    }

    return Column(
      children: [
        for (final entry in entries) ...[
          _ExplorerPositionTile(entry: entry, onOpenTechnique: onOpenTechnique),
          if (entry != entries.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CategoryExplorerList extends StatelessWidget {
  final List<SkillMatrixCategoryEntry> categories;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _CategoryExplorerList({
    required this.categories,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const TitansStateView.empty(
        title: 'Sem categorias mapeadas',
        message: 'As categorias aparecem conforme os treinos ganham técnicas.',
        compact: true,
      );
    }

    return Column(
      children: [
        for (final category in categories) ...[
          _ExplorerCategoryTile(
            category: category,
            onOpenTechnique: onOpenTechnique,
          ),
          if (category != categories.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ExplorerPositionTile extends StatelessWidget {
  final GameMapEntry entry;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _ExplorerPositionTile({
    required this.entry,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    return _ExplorerTileShell(
      title: entry.position,
      subtitle:
          '${TrainingAggregator.techniqueCountLabel(entry.techniques.length)} · ${TrainingAggregator.sessionCountLabel(entry.sessionsCount)}',
      preview: [
        for (final technique in entry.techniques.take(3)) technique.technique,
      ],
      children: [
        for (final technique in entry.techniques)
          _TechniqueMiniRow(
            name: technique.technique,
            count: technique.sessionsCount,
            detail: _formatShortDate(technique.lastTrainedAt),
            onTap:
                () => onOpenTechnique(
                  _SkillNavigationTarget.fromGameMap(
                    technique: technique,
                    position: entry.position,
                  ),
                ),
          ),
      ],
    );
  }
}

class _ExplorerCategoryTile extends StatelessWidget {
  final SkillMatrixCategoryEntry category;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _ExplorerCategoryTile({
    required this.category,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    return _ExplorerTileShell(
      title: category.category.label,
      subtitle:
          '${TrainingAggregator.techniqueCountLabel(category.techniquesCount)} · ${TrainingAggregator.sessionCountLabel(category.sessionsCount)}',
      preview: [
        for (final technique in category.techniques.take(3))
          technique.technique,
      ],
      children: [
        for (final technique in category.techniques)
          _TechniqueMiniRow(
            name: technique.technique,
            count: technique.sessionsCount,
            detail: technique.position ?? 'Posição não informada',
            onTap:
                () => onOpenTechnique(
                  _SkillNavigationTarget.fromSkillMatrix(technique),
                ),
          ),
      ],
    );
  }
}

class _ExplorerTileShell extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> preview;
  final List<Widget> children;

  const _ExplorerTileShell({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.children,
  });

  @override
  State<_ExplorerTileShell> createState() => _ExplorerTileShellState();
}

class _ExplorerTileShellState extends State<_ExplorerTileShell> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: _expanded ? cs.secondary : cs.primary,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
          if (widget.preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in widget.preview) _TechniqueChip(label: name),
              ],
            ),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(children: widget.children),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechniqueMiniRow extends StatelessWidget {
  final String name;
  final int count;
  final String detail;
  final VoidCallback onTap;

  const _TechniqueMiniRow({
    required this.name,
    required this.count,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TechniqueChip(label: '${count}x'),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.58),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _TechniqueChip extends StatelessWidget {
  final String label;

  const _TechniqueChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.primary.withValues(alpha: 0.10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.76),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SkillsSectionEyebrow extends StatelessWidget {
  final String label;

  const _SkillsSectionEyebrow(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.58),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SkillsSummaryViewModel {
  final int registeredTechniques;
  final int appliedTechniques;
  final int mappedCategories;
  final int mappedPositions;
  final int evaluatedTechniques;

  const _SkillsSummaryViewModel({
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

  factory _SkillsSummaryViewModel.from({
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

    return _SkillsSummaryViewModel(
      registeredTechniques: techniques.length,
      appliedTechniques:
          techniques.where((entry) => entry.application == true).length,
      mappedCategories: categories.length,
      mappedPositions: entries.length,
      evaluatedTechniques: evaluatedSkillIds.length,
    );
  }
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _explorerSectionSummary(List<GameMapEntry> entries) {
  final techniquesCount = entries.fold<int>(
    0,
    (sum, entry) => sum + entry.techniques.length,
  );
  if (entries.isEmpty) return 'Nenhuma posição mapeada ainda.';
  return '${TrainingAggregator.techniqueCountLabel(techniquesCount)} em ${entries.length} posições.';
}
