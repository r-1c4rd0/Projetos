import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../repository/training_repository.dart';
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
  late final GetSkillMatrixSummary _getSkillMatrixSummary =
      const GetSkillMatrixSummary();
  late final GetGameMapEvidenceSummary _getGameMapEvidenceSummary =
      const GetGameMapEvidenceSummary();

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
          final skillMatrix = _getSkillMatrixSummary(sessions, limit: 50);
          final entries = _getGameMapEvidenceSummary(sessions, limit: 20);

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
                    title: 'Matriz de repertorio',
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
  String? _selectedNodeKey;

  @override
  Widget build(BuildContext context) {
    final nodes =
        _mode == _ExplorerMode.position
            ? _positionMatrixNodes(widget.entries)
            : _categoryMatrixNodes(widget.categories);
    final selectedNode = _selectedMatrixNode(nodes, _selectedNodeKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExplorerModeSelector(
          selected: _mode,
          onChanged:
              (mode) => setState(() {
                _mode = mode;
                _selectedNodeKey = null;
              }),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child:
              nodes.isEmpty
                  ? _SkillsMatrixEmptyState(mode: _mode)
                  : _SkillsMatrixExplorer(
                    key: ValueKey(_mode),
                    mode: _mode,
                    nodes: nodes,
                    selectedNode: selectedNode,
                    onSelectNode:
                        (node) => setState(() => _selectedNodeKey = node.key),
                    onOpenTechnique: widget.onOpenTechnique,
                  ),
        ),
      ],
    );
  }
}

class _SkillsMatrixExplorer extends StatelessWidget {
  final _ExplorerMode mode;
  final List<_SkillsMatrixNode> nodes;
  final _SkillsMatrixNode? selectedNode;
  final ValueChanged<_SkillsMatrixNode> onSelectNode;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _SkillsMatrixExplorer({
    super.key,
    required this.mode,
    required this.nodes,
    required this.selectedNode,
    required this.onSelectNode,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedNode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkillsMatrixGrid(
          nodes: nodes,
          selectedKey: selected?.key,
          onSelectNode: onSelectNode,
        ),
        const SizedBox(height: 12),
        if (selected == null)
          _SkillsMatrixHint(mode: mode)
        else
          _SkillsMatrixDetailPanel(
            node: selected,
            onOpenTechnique: onOpenTechnique,
          ),
      ],
    );
  }
}

class _SkillsMatrixGrid extends StatelessWidget {
  final List<_SkillsMatrixNode> nodes;
  final String? selectedKey;
  final ValueChanged<_SkillsMatrixNode> onSelectNode;

  const _SkillsMatrixGrid({
    required this.nodes,
    required this.selectedKey,
    required this.onSelectNode,
  });

  @override
  Widget build(BuildContext context) {
    final maxEvidence = nodes.fold<int>(
      1,
      (max, node) => node.evidenceCount > max ? node.evidenceCount : max,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 300 ? 1 : (width >= 720 ? 3 : 2);
        final gap = TitansUI.spaceSm;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final node in nodes)
              SizedBox(
                width: itemWidth.clamp(132.0, width).toDouble(),
                child: _SkillsMatrixNodeCard(
                  node: node,
                  maxEvidence: maxEvidence,
                  selected: selectedKey == node.key,
                  onTap: () => onSelectNode(node),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SkillsMatrixNodeCard extends StatelessWidget {
  final _SkillsMatrixNode node;
  final int maxEvidence;
  final bool selected;
  final VoidCallback onTap;

  const _SkillsMatrixNodeCard({
    required this.node,
    required this.maxEvidence,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = selected ? TitansUI.actionGold : node.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.52 : 0.22),
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.13),
                      border: Border.all(color: accent.withValues(alpha: 0.28)),
                    ),
                    child: Icon(node.icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.primaryValue,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                node.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _EvidenceBar(
                label: node.evidenceLabel,
                value: node.evidenceCount,
                maxValue: maxEvidence,
                color: accent,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _TechniqueChip(label: node.statusLabel),
                  if (node.preview.isNotEmpty)
                    _TechniqueChip(label: node.preview.first),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillsMatrixHint extends StatelessWidget {
  final _ExplorerMode mode;

  const _SkillsMatrixHint({required this.mode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = mode == _ExplorerMode.position ? 'posicao' : 'categoria';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
        border: Border.all(color: TitansUI.navBorder(context)),
      ),
      child: Text(
        'Toque em uma $label para ver tecnicas e evidencias registradas.',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.66),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SkillsMatrixDetailPanel extends StatelessWidget {
  final _SkillsMatrixNode node;
  final ValueChanged<_SkillNavigationTarget> onOpenTechnique;

  const _SkillsMatrixDetailPanel({
    required this.node,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxTechniqueEvidence = node.techniques.fold<int>(
      1,
      (max, technique) => technique.count > max ? technique.count : max,
    );

    return TitansCard(
      accent: TitansUI.actionGold,
      padding: const EdgeInsets.all(12),
      child: Column(
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
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      node.subtitle,
                      maxLines: 2,
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
              const SizedBox(width: 8),
              _TechniqueChip(label: node.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          _EvidenceBar(
            label: node.evidenceLabel,
            value: node.evidenceCount,
            maxValue: node.evidenceCount.clamp(1, 999999).toInt(),
            color: TitansUI.actionGold,
          ),
          if (node.preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in node.preview.take(4))
                  _TechniqueChip(label: name),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final technique in node.techniques)
            _TechniqueMiniRow(
              name: technique.name,
              count: technique.count,
              detail: technique.detail,
              evidenceLabel: technique.evidenceLabel,
              lastRegisteredLabel: technique.lastRegisteredLabel,
              maxCount: maxTechniqueEvidence,
              onTap: () => onOpenTechnique(technique.target),
            ),
        ],
      ),
    );
  }
}

class _SkillsMatrixEmptyState extends StatelessWidget {
  final _ExplorerMode mode;

  const _SkillsMatrixEmptyState({required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == _ExplorerMode.position) {
      return const TitansStateView.empty(
        title: 'Sem posicoes mapeadas',
        message:
            'Registre treinos com posicao e tecnica para montar o repertorio.',
        compact: true,
      );
    }

    return const TitansStateView.empty(
      title: 'Sem categorias mapeadas',
      message: 'As categorias aparecem conforme os treinos ganham tecnicas.',
      compact: true,
    );
  }
}

class _SkillsMatrixNode {
  final String key;
  final String title;
  final String subtitle;
  final String primaryValue;
  final String statusLabel;
  final IconData icon;
  final Color accent;
  final List<String> preview;
  final int evidenceCount;
  final String evidenceLabel;
  final List<_SkillsMatrixTechnique> techniques;

  const _SkillsMatrixNode({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    required this.statusLabel,
    required this.icon,
    required this.accent,
    required this.preview,
    required this.evidenceCount,
    required this.evidenceLabel,
    required this.techniques,
  });
}

class _SkillsMatrixTechnique {
  final String name;
  final int count;
  final String detail;
  final String evidenceLabel;
  final String lastRegisteredLabel;
  final _SkillNavigationTarget target;

  const _SkillsMatrixTechnique({
    required this.name,
    required this.count,
    required this.detail,
    required this.evidenceLabel,
    required this.lastRegisteredLabel,
    required this.target,
  });
}

List<_SkillsMatrixNode> _positionMatrixNodes(List<GameMapEntry> entries) {
  return [
    for (final entry in entries)
      _SkillsMatrixNode(
        key: 'position:${entry.position}',
        title: entry.position,
        subtitle:
            '${TrainingAggregator.techniqueCountLabel(entry.techniques.length)} · ${TrainingAggregator.sessionCountLabel(entry.sessionsCount)}',
        primaryValue: entry.techniques.length.toString(),
        statusLabel: _matrixStatusLabel(entry.sessionsCount),
        icon: Icons.account_tree_outlined,
        accent: TitansUI.technicalBlue,
        preview: [
          for (final technique in entry.techniques.take(3)) technique.technique,
        ],
        evidenceCount: entry.sessionsCount,
        evidenceLabel: TrainingAggregator.sessionCountLabel(
          entry.sessionsCount,
        ),
        techniques: [
          for (final technique in entry.techniques)
            _SkillsMatrixTechnique(
              name: technique.technique,
              count: technique.sessionsCount,
              detail: _formatShortDate(technique.lastTrainedAt),
              evidenceLabel: TrainingAggregator.sessionCountLabel(
                technique.sessionsCount,
              ),
              lastRegisteredLabel:
                  'Último registro ${_formatShortDate(technique.lastTrainedAt)}',
              target: _SkillNavigationTarget.fromGameMap(
                technique: technique,
                position: entry.position,
              ),
            ),
        ],
      ),
  ];
}

List<_SkillsMatrixNode> _categoryMatrixNodes(
  List<SkillMatrixCategoryEntry> categories,
) {
  return [
    for (final category in categories)
      _SkillsMatrixNode(
        key: 'category:${category.category.name}',
        title: category.category.label,
        subtitle:
            '${TrainingAggregator.techniqueCountLabel(category.techniquesCount)} · ${TrainingAggregator.sessionCountLabel(category.sessionsCount)}',
        primaryValue: category.techniquesCount.toString(),
        statusLabel: _matrixStatusLabel(category.sessionsCount),
        icon: Icons.grid_view_rounded,
        accent: TitansUI.success,
        preview: [
          for (final technique in category.techniques.take(3))
            technique.technique,
        ],
        evidenceCount: category.sessionsCount,
        evidenceLabel: TrainingAggregator.sessionCountLabel(
          category.sessionsCount,
        ),
        techniques: [
          for (final technique in category.techniques)
            _SkillsMatrixTechnique(
              name: technique.technique,
              count: technique.sessionsCount,
              detail: technique.position ?? 'Posicao nao informada',
              evidenceLabel: TrainingAggregator.sessionCountLabel(
                technique.sessionsCount,
              ),
              lastRegisteredLabel:
                  'Último registro ${_formatShortDate(technique.lastTrainedAt)}',
              target: _SkillNavigationTarget.fromSkillMatrix(technique),
            ),
        ],
      ),
  ];
}

_SkillsMatrixNode? _selectedMatrixNode(
  List<_SkillsMatrixNode> nodes,
  String? selectedKey,
) {
  if (selectedKey == null) return null;
  for (final node in nodes) {
    if (node.key == selectedKey) return node;
  }
  return null;
}

String _matrixStatusLabel(int sessionsCount) {
  if (sessionsCount <= 0) return 'Sem evidencia';
  if (sessionsCount == 1) return '1 sessao';
  return '$sessionsCount sessoes';
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: TitansUI.navUnselectedBackground(context),
        border: Border.all(color: TitansUI.navBorder(context)),
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
            color: selected ? TitansUI.navSelectedBackground(context) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selected
                      ? TitansUI.navSelectedForeground(context)
                      : TitansUI.navUnselectedForeground(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _EvidenceBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final fraction = (value / safeMax).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Evidencia registrada',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            color: color,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _TechniqueMiniRow extends StatelessWidget {
  final String name;
  final int count;
  final String detail;
  final String evidenceLabel;
  final String lastRegisteredLabel;
  final int maxCount;
  final VoidCallback onTap;

  const _TechniqueMiniRow({
    required this.name,
    required this.count,
    required this.detail,
    required this.evidenceLabel,
    required this.lastRegisteredLabel,
    required this.maxCount,
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
          color: TitansUI.navUnselectedBackground(context),
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
                  const SizedBox(height: 2),
                  Text(
                    lastRegisteredLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.46),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EvidenceBar(
                    label: evidenceLabel,
                    value: count,
                    maxValue: maxCount,
                    color: TitansUI.actionGold,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
