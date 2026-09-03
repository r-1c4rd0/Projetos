import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../repository/training_repository.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';
import '../widgets/charts/titans_technical_radar.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

import 'skills_screen.dart';

class GameMapScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? title;
  final String? targetName;
  final AppUser? loggedUser;
  final bool embedded;

  const GameMapScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.title,
    this.targetName,
    this.loggedUser,
    this.embedded = false,
  });

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

enum _GameMapViewMode { cluster, matrix, evidence }

class _GameMapScreenState extends State<GameMapScreen> {
  late final TrainingRepository _repository = TrainingRepository.instance;
  late final CoachEvaluationRepository _coachEvaluationRepository =
      CoachEvaluationRepository.instance;
  late final Stream<List<TrainingSession>> _sessionsStream;
  late final Stream<List<CoachEvaluation>> _coachEvaluationsStream;
  late final GetTechnicalRadarSummary _getTechnicalRadarSummary =
      const GetTechnicalRadarSummary();
  late final GetSkillMatrixSummary _getSkillMatrixSummary =
      const GetSkillMatrixSummary();
  late final GetGameMapEvidenceSummary _getGameMapEvidenceSummary =
      const GetGameMapEvidenceSummary();
  late final GetTechnicalEvidenceSummary _getTechnicalEvidenceSummary =
      const GetTechnicalEvidenceSummary();

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

  Future<void> _openCoachEvaluationSheet({
    required AppUser actor,
    required List<TechnicalEvidenceSummary> techniques,
    required List<CoachEvaluation> evaluations,
  }) async {
    if (techniques.isEmpty) return;

    final draft = await showModalBottomSheet<_CoachEvaluationDraft>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _CoachEvaluationSheet(
            techniques: techniques,
            evaluations: evaluations,
          ),
    );
    if (draft == null) return;

    final evaluation = CoachEvaluation(
      skillId: draft.technique.skillId,
      athleteUid: widget.uid,
      academyId: widget.academyId,
      evaluatorUid: actor.uid,
      evaluatedAt: DateTime.now(),
      knowledgeLevel: draft.knowledgeLevel,
      drillLevel: draft.drillLevel,
      applicationLevel: draft.applicationLevel,
      consistencyLevel: draft.consistencyLevel,
      note: draft.note,
      recommendation: draft.recommendation,
      needsReview: draft.needsReview,
    );

    try {
      await _coachEvaluationRepository.upsertEvaluation(evaluation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação humana registrada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar avaliação: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    final isStaffActor =
        actor?.role == UserRole.admin || actor?.role == UserRole.professor;
    final isViewingAnotherUser = actor != null && actor.uid != widget.uid;
    final canEditCoachEvaluation = isStaffActor && isViewingAnotherUser;

    return _wrapModule(
      appBar: AppBar(
        title: Text(widget.title ?? 'Game Map'),
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
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
          final skillMatrix = _getSkillMatrixSummary(sessions, limit: 50);
          final entries = _getGameMapEvidenceSummary(sessions, limit: 20);
          final stats = _GameMapStats.from(entries, skillMatrix);
          final visualMap = _GameMapVisualViewModel.from(entries, skillMatrix);
          final positionAxisMatrix = _PositionAxisMatrixViewModel.from(
            sessions,
          );
          final evidenceDistribution = _EvidenceDistributionViewModel.from(
            positionAxisMatrix,
          );
          final rtcaEvidence = _RtcaEvidenceViewModel.from(
            sessions: sessions,
            entries: entries,
            skillMatrix: skillMatrix,
          );
          final radarSummary = _getTechnicalRadarSummary(sessions);
          final technicalEvidence = _getTechnicalEvidenceSummary(sessions);

          return StreamBuilder<List<CoachEvaluation>>(
            stream: _coachEvaluationsStream,
            builder: (context, evaluationSnapshot) {
              final coachEvaluations =
                  evaluationSnapshot.data ?? const <CoachEvaluation>[];
              final coachEvaluatedCount = _coachEvaluatedTechniqueCount(
                coachEvaluations,
              );

              final technicalRadar =
                  _TechnicalRadarPreviewViewModel.fromSummary(
                    radarSummary,
                    coachEvaluationCount: coachEvaluatedCount,
                  );

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
                  TitansTechnicalRadar(
                    subtitle: technicalRadar.subtitle,
                    stateLabel: technicalRadar.stateLabel,
                    evidences: technicalRadar.evidences,
                    axisEvidence: technicalRadar.axisEvidence,
                    classifiedEvidenceCount:
                        technicalRadar.classifiedEvidenceCount,
                    awaitingClassificationCount:
                        technicalRadar.awaitingClassificationCount,
                    showMetrics: false,
                  ),
                  const SizedBox(height: 12),
                  _GameMapClientReadingSection(
                    stats: stats,
                    radarSummary: radarSummary,
                    visualMap: visualMap,
                    positionAxisMatrix: positionAxisMatrix,
                    evidenceDistribution: evidenceDistribution,
                    rtcaEvidence: rtcaEvidence,
                    technicalEvidence: technicalEvidence,
                    coachEvaluations: coachEvaluations,
                    canEditCoachEvaluation: canEditCoachEvaluation,
                    actor: actor,
                    onOpenCoachEvaluationSheet:
                        actor == null
                            ? null
                            : () => _openCoachEvaluationSheet(
                              actor: actor,
                              techniques: technicalEvidence,
                              evaluations: coachEvaluations,
                            ),
                    onOpenSkills: () => _openSkillsScreen(actor),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openSkillsScreen(AppUser? actor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SkillsScreen(
              academyId: widget.academyId,
              uid: widget.uid,
              title: 'Skills',
              targetName: widget.targetName,
              loggedUser: actor,
            ),
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

// Leitura do jogo - Client-first unified section below radar
class _GameMapClientReadingSection extends StatelessWidget {
  final _GameMapStats stats;
  final TechnicalRadarSummary radarSummary;
  final _GameMapVisualViewModel visualMap;
  final _PositionAxisMatrixViewModel positionAxisMatrix;
  final _EvidenceDistributionViewModel evidenceDistribution;
  final _RtcaEvidenceViewModel rtcaEvidence;
  final List<TechnicalEvidenceSummary> technicalEvidence;
  final List<CoachEvaluation> coachEvaluations;
  final bool canEditCoachEvaluation;
  final AppUser? actor;
  final VoidCallback? onOpenCoachEvaluationSheet;
  final VoidCallback onOpenSkills;

  const _GameMapClientReadingSection({
    required this.stats,
    required this.radarSummary,
    required this.visualMap,
    required this.positionAxisMatrix,
    required this.evidenceDistribution,
    required this.rtcaEvidence,
    required this.technicalEvidence,
    required this.coachEvaluations,
    required this.canEditCoachEvaluation,
    required this.actor,
    required this.onOpenCoachEvaluationSheet,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topAxis = radarSummary.topAxis;
    final topAxisLabel = topAxis?.displayLabel ?? '—';
    final needsReviewCount =
        coachEvaluations.where((e) => e.needsReview).length;
    final topPositions = _getTopPositions(positionAxisMatrix);
    final topTechniques = _getTopTechniques(technicalEvidence);
    final axisBarsData = _getAxisBarsData(radarSummary);

    return TitansCard(
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leitura do jogo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Resumo unificado do seu jogo baseado nos registros',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini boxes row
          _ClientReadingMiniBoxes(
            stats: stats,
            topAxisLabel: topAxisLabel,
            needsReviewCount: needsReviewCount,
            coachEvaluationsCount: coachEvaluations.length,
          ),
          const SizedBox(height: 12),
          // Mini charts row
          _ClientReadingMiniCharts(
            axisBarsData: axisBarsData,
            topPositions: topPositions,
            topTechniques: topTechniques,
          ),
          const SizedBox(height: 12),
          // Discrete actions
          _ClientReadingActions(
            visualMap: visualMap,
            technicalEvidence: technicalEvidence,
            rtcaEvidence: rtcaEvidence,
            canEditCoachEvaluation: canEditCoachEvaluation,
            onOpenCoachEvaluationSheet: onOpenCoachEvaluationSheet,
            onOpenSkills: onOpenSkills,
            positionAxisMatrix: positionAxisMatrix,
            evidenceDistribution: evidenceDistribution,
          ),
        ],
      ),
    );
  }

  List<_TopPositionItem> _getTopPositions(_PositionAxisMatrixViewModel matrix) {
    final items = <_TopPositionItem>[];
    for (final row in matrix.rows.take(5)) {
      final topAxis = _topAxisForRow(row);
      items.add(
        _TopPositionItem(
          position: row.position,
          count: row.sessionCount,
          countLabel: row.countLabel,
          topAxis: topAxis?.displayLabel,
        ),
      );
    }
    return items;
  }

  List<_TopTechniqueItem> _getTopTechniques(
    List<TechnicalEvidenceSummary> evidence,
  ) {
    final sorted = List<TechnicalEvidenceSummary>.from(evidence)
      ..sort((a, b) => b.evidenceCount.compareTo(a.evidenceCount));
    return sorted
        .take(5)
        .map(
          (e) => _TopTechniqueItem(
            name: e.techniqueName,
            count: e.evidenceCount,
            positions: e.positions.take(2).toList(),
          ),
        )
        .toList();
  }

  List<_AxisBarData> _getAxisBarsData(TechnicalRadarSummary summary) {
    const axes = <TechnicalRadarAxis>[
      TechnicalRadarAxis.attack,
      TechnicalRadarAxis.retention,
      TechnicalRadarAxis.transition,
      TechnicalRadarAxis.control,
    ];
    var maxValue = 0;
    for (final axis in axes) {
      final count = summary.axisEvidence[axis] ?? 0;
      if (count > maxValue) maxValue = count;
    }
    return axes
        .map(
          (axis) => _AxisBarData(
            axis: axis,
            count: summary.axisEvidence[axis] ?? 0,
            maxCount: maxValue,
          ),
        )
        .toList();
  }

  TechnicalRadarAxis? _topAxisForRow(_PositionAxisMatrixRow row) {
    TechnicalRadarAxis? selected;
    var selectedCount = 0;
    for (final cell in row.cells) {
      if (cell.sessionCount > selectedCount) {
        selected = cell.axis;
        selectedCount = cell.sessionCount;
      }
    }
    return selectedCount == 0 ? null : selected;
  }
}

class _ClientReadingMiniBoxes extends StatelessWidget {
  final _GameMapStats stats;
  final String topAxisLabel;
  final int needsReviewCount;
  final int coachEvaluationsCount;

  const _ClientReadingMiniBoxes({
    required this.stats,
    required this.topAxisLabel,
    required this.needsReviewCount,
    required this.coachEvaluationsCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _MiniBox(
            label: 'Posições',
            value: stats.positions.toString(),
            icon: Icons.place_outlined,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniBox(
            label: 'Técnicas',
            value: stats.techniques.toString(),
            icon: Icons.sports_mma_outlined,
            color: TitansUI.successGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniBox(
            label: 'Eixo principal',
            value: topAxisLabel,
            icon: Icons.radar_outlined,
            color: TitansUI.actionGold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniBox(
            label:
                coachEvaluationsCount > 0 ? 'Observações' : 'Sem observações',
            value:
                needsReviewCount > 0
                    ? '$needsReviewCount p/ revisar'
                    : 'Em dia',
            icon: Icons.rate_review_outlined,
            color:
                needsReviewCount > 0
                    ? TitansUI.alertRed
                    : TitansUI.successGreen,
          ),
        ),
      ],
    );
  }
}

class _MiniBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientReadingMiniCharts extends StatelessWidget {
  final List<_AxisBarData> axisBarsData;
  final List<_TopPositionItem> topPositions;
  final List<_TopTechniqueItem> topTechniques;

  const _ClientReadingMiniCharts({
    required this.axisBarsData,
    required this.topPositions,
    required this.topTechniques,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Axis bars
        Text(
          'Registros por eixo',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < axisBarsData.length; i++) ...[
          _AxisMiniBar(data: axisBarsData[i]),
          if (i < axisBarsData.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 12),
        // Top positions & techniques side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TopListMiniChart(
                title: 'Top posições',
                items:
                    topPositions
                        .map(
                          (e) => _TopListItem(
                            label: e.position,
                            count: e.count,
                            countLabel: e.countLabel,
                            subtitle: e.topAxis,
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TopListMiniChart(
                title: 'Top técnicas',
                items:
                    topTechniques
                        .map(
                          (e) => _TopListItem(
                            label: e.name,
                            count: e.count,
                            countLabel: TrainingAggregator.sessionCountLabel(
                              e.count,
                            ),
                            subtitle: e.positions.join(', '),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AxisMiniBar extends StatelessWidget {
  final _AxisBarData data;

  const _AxisMiniBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _axisColor(context, data.axis);
    final fraction =
        data.maxCount <= 0 ? 0.0 : (data.count / data.maxCount).clamp(0.0, 1.0);
    final active = data.count > 0;

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            data.axis.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: active ? 0.78 : 0.44),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.toDouble(),
                  child: Container(
                    height: 5,
                    color:
                        active ? color : cs.onSurface.withValues(alpha: 0.14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            data.count.toString(),
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? color : cs.onSurface.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopListMiniChart extends StatelessWidget {
  final String title;
  final List<_TopListItem> items;

  const _TopListMiniChart({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Sem dados',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _TopListRow(item: items[i], rank: i + 1),
                if (i < items.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
      ],
    );
  }
}

class _TopListItem {
  final String label;
  final int count;
  final String countLabel;
  final String? subtitle;

  const _TopListItem({
    required this.label,
    required this.count,
    required this.countLabel,
    this.subtitle,
  });
}

class _TopListRow extends StatelessWidget {
  final _TopListItem item;
  final int rank;

  const _TopListRow({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = rank <= 3 ? TitansUI.actionGold : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty)
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.countLabel,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientReadingActions extends StatelessWidget {
  final _GameMapVisualViewModel visualMap;
  final List<TechnicalEvidenceSummary> technicalEvidence;
  final _RtcaEvidenceViewModel rtcaEvidence;
  final bool canEditCoachEvaluation;
  final VoidCallback? onOpenCoachEvaluationSheet;
  final VoidCallback onOpenSkills;
  final _PositionAxisMatrixViewModel positionAxisMatrix;
  final _EvidenceDistributionViewModel evidenceDistribution;

  const _ClientReadingActions({
    required this.visualMap,
    required this.technicalEvidence,
    required this.rtcaEvidence,
    required this.canEditCoachEvaluation,
    required this.onOpenCoachEvaluationSheet,
    required this.onOpenSkills,
    required this.positionAxisMatrix,
    required this.evidenceDistribution,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = <Widget>[];

    // Explorar mapa
    if (visualMap.nodes.isNotEmpty) {
      actions.add(
        _ActionChip(
          label: 'Explorar mapa',
          icon: Icons.account_tree_outlined,
          color: cs.primary,
          onTap: () => _showVisualMapBottomSheet(context),
        ),
      );
    }

    // Ver detalhes técnicos
    if (technicalEvidence.isNotEmpty) {
      actions.add(
        _ActionChip(
          label: 'Ver detalhes técnicos',
          icon: Icons.fact_check_outlined,
          color: cs.secondary,
          onTap: () => _showAllTechnicalEvidences(context, technicalEvidence),
        ),
      );
    }

    // Ver repertório
    if (rtcaEvidence.items.isNotEmpty) {
      actions.add(
        _ActionChip(
          label: 'Ver repertório',
          icon: Icons.inventory_2_outlined,
          color: cs.tertiary,
          onTap: () => _showRepertoireBottomSheet(context),
        ),
      );
    }

    // Registrar avaliação
    if (canEditCoachEvaluation &&
        onOpenCoachEvaluationSheet != null &&
        technicalEvidence.isNotEmpty) {
      actions.add(
        _ActionChip(
          label: 'Registrar avaliação',
          icon: Icons.rate_review_outlined,
          color: TitansUI.actionGold,
          onTap: onOpenCoachEvaluationSheet!,
        ),
      );
    }

    // Skills CTA
    actions.add(
      _ActionChip(
        label: 'Ver repertório técnico',
        icon: Icons.psychology_alt_outlined,
        color: cs.primary,
        onTap: onOpenSkills,
        isPrimary: true,
      ),
    );

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  void _showVisualMapBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 30,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mapa visual de posições',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: _GameMapPositionClusterGraph(viewModel: visualMap),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showRepertoireBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 30,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Repertório registrado',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rtcaEvidence.subtitle,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.64),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            int i = 0;
                            i < rtcaEvidence.items.length;
                            i++
                          ) ...[
                            _CompactEvidenceBar(
                              label: rtcaEvidence.items[i].label,
                              count: _extractCount(rtcaEvidence.items[i].value),
                              maxCount: _maxCountForItems(rtcaEvidence.items),
                              color: _colorForIndex(i, context),
                              helper: rtcaEvidence.items[i].helper,
                            ),
                            if (i < rtcaEvidence.items.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  int _extractCount(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  int _maxCountForItems(List<_RtcaEvidenceItem> items) {
    int max = 0;
    for (final item in items) {
      final count = _extractCount(item.value);
      if (count > max) max = count;
    }
    return max == 0 ? 1 : max;
  }

  Color _colorForIndex(int index, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (index) {
      case 0:
        return cs.primary;
      case 1:
        return TitansUI.successGreen;
      case 2:
        return TitansUI.technicalBlue;
      case 3:
        return TitansUI.actionGold;
      default:
        return cs.primary;
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = isPrimary ? color : color.withValues(alpha: 0.12);
    final borderColor = isPrimary ? color : color.withValues(alpha: 0.25);
    final textColor = isPrimary ? cs.onPrimary : color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            color: bgColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPositionItem {
  final String position;
  final int count;
  final String countLabel;
  final String? topAxis;

  const _TopPositionItem({
    required this.position,
    required this.count,
    required this.countLabel,
    this.topAxis,
  });
}

class _TopTechniqueItem {
  final String name;
  final int count;
  final List<String> positions;

  const _TopTechniqueItem({
    required this.name,
    required this.count,
    required this.positions,
  });
}

class _AxisBarData {
  final TechnicalRadarAxis axis;
  final int count;
  final int maxCount;

  const _AxisBarData({
    required this.axis,
    required this.count,
    required this.maxCount,
  });
}

// Unified Client-First Cluster for Game Map
class _GameMapUnifiedCluster extends StatelessWidget {
  final _GameMapVisualViewModel visualMap;
  final _TechnicalRadarPreviewViewModel technicalRadar;
  final _GameMapStats stats;
  final List<TechnicalEvidenceSummary> technicalEvidence;
  final TechnicalRadarSummary radarSummary;
  final _RtcaEvidenceViewModel rtcaEvidence;
  final List<CoachEvaluation> coachEvaluations;
  final bool canEditCoachEvaluation;
  final AppUser? actor;
  final VoidCallback? onOpenCoachEvaluationSheet;
  final VoidCallback onOpenSkills;

  const _GameMapUnifiedCluster({
    required this.visualMap,
    required this.technicalRadar,
    required this.stats,
    required this.technicalEvidence,
    required this.radarSummary,
    required this.rtcaEvidence,
    required this.coachEvaluations,
    required this.canEditCoachEvaluation,
    required this.actor,
    required this.onOpenCoachEvaluationSheet,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Technical Radar - Visual Overview
        TitansTechnicalRadar(
          subtitle: technicalRadar.subtitle,
          stateLabel: technicalRadar.stateLabel,
          evidences: technicalRadar.evidences,
          axisEvidence: technicalRadar.axisEvidence,
          classifiedEvidenceCount: technicalRadar.classifiedEvidenceCount,
          awaitingClassificationCount:
              technicalRadar.awaitingClassificationCount,
          showMetrics: false,
        ),
        const SizedBox(height: 12),
        // Hero Metrics Strip
        _GameMapHeroMetricStrip(stats: stats, onOpenSkills: onOpenSkills),
        const SizedBox(height: 12),
        // Cluster: Where am I strong / Where do I need to evolve
        _ClusterStrengthsAndGaps(
          visualMap: visualMap,
          radarSummary: radarSummary,
          stats: stats,
        ),
        const SizedBox(height: 12),
        // Cluster: Evidence Summary with Mini Charts
        _ClusterEvidenceSummary(
          technicalEvidence: technicalEvidence,
          radarSummary: radarSummary,
          stats: stats,
        ),
        const SizedBox(height: 12),
        // Cluster: Coach Evaluation Highlights
        _ClusterCoachEvaluation(
          coachEvaluations: coachEvaluations,
          canEdit: canEditCoachEvaluation,
          onRegister: onOpenCoachEvaluationSheet,
        ),
        const SizedBox(height: 12),
        // Cluster: Repertoire Summary
        _ClusterRepertoire(rtcaEvidence: rtcaEvidence),
      ],
    );
  }
}

// Cluster: Strengths and Gaps
class _ClusterStrengthsAndGaps extends StatelessWidget {
  final _GameMapVisualViewModel visualMap;
  final TechnicalRadarSummary radarSummary;
  final _GameMapStats stats;

  const _ClusterStrengthsAndGaps({
    required this.visualMap,
    required this.radarSummary,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topAxis = radarSummary.topAxis;
    final topAxisLabel = topAxis?.displayLabel ?? '—';
    final weakAxes =
        radarSummary.axisEvidence.entries
            .where((e) => e.value == 0)
            .map((e) => e.key.displayLabel)
            .toList();

    return _ClusterCard(
      title: 'Onde estou forte / Onde evoluir',
      subtitle: 'Leitura baseada nos seus registros de treino',
      icon: Icons.trending_up,
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strongest axis
          _ClusterMetricRow(
            label: 'Eixo mais forte',
            value: topAxisLabel,
            icon: Icons.star_outline,
            color: TitansUI.actionGold,
          ),
          const SizedBox(height: 8),
          // Total positions/techniques
          Row(
            children: [
              Expanded(
                child: _ClusterMetricRow(
                  label: 'Posições',
                  value: stats.positions.toString(),
                  icon: Icons.place_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClusterMetricRow(
                  label: 'Técnicas',
                  value: stats.techniques.toString(),
                  icon: Icons.sports_mma_outlined,
                  color: TitansUI.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Axes without evidence
          if (weakAxes.isNotEmpty) ...[
            Text(
              'Sem evidências: ${weakAxes.join(', ')}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Visual cluster mini-map
          if (visualMap.nodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mapa visual de posições',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            _GameMapPositionClusterGraph(viewModel: visualMap),
          ],
        ],
      ),
    );
  }
}

// Cluster: Evidence Summary with Mini Charts
class _ClusterEvidenceSummary extends StatelessWidget {
  final List<TechnicalEvidenceSummary> technicalEvidence;
  final TechnicalRadarSummary radarSummary;
  final _GameMapStats stats;

  const _ClusterEvidenceSummary({
    required this.technicalEvidence,
    required this.radarSummary,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewItems = technicalEvidence.take(3).toList();
    final hasMore = technicalEvidence.length > previewItems.length;

    return _ClusterCard(
      title: 'Evidências técnicas',
      subtitle: 'O que já apareceu nos seus treinos',
      icon: Icons.fact_check_outlined,
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Axis evidence bars
          _TechnicalAxisEvidenceBars(axisEvidence: radarSummary.axisEvidence),
          const SizedBox(height: 12),
          // Recent techniques
          if (previewItems.isNotEmpty) ...[
            Text(
              'Registros recentes (${technicalEvidence.length})',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < previewItems.length; i++) ...[
              _TechnicalEvidencePreviewTile(
                item: previewItems[i],
                onTap:
                    () =>
                        _showTechnicalEvidenceDetails(context, previewItems[i]),
              ),
              if (i < previewItems.length - 1) const SizedBox(height: 8),
            ],
            if (hasMore) ...[
              const SizedBox(height: 8),
              _ViewAllTechnicalEvidencesButton(
                count: technicalEvidence.length,
                onPressed:
                    () =>
                        _showAllTechnicalEvidences(context, technicalEvidence),
              ),
            ],
          ] else if (technicalEvidence.isEmpty) ...[
            Text(
              'Registre treinos com técnica e posição para ver evidências.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Cluster: Coach Evaluation Highlights
class _ClusterCoachEvaluation extends StatelessWidget {
  final List<CoachEvaluation> coachEvaluations;
  final bool canEdit;
  final VoidCallback? onRegister;

  const _ClusterCoachEvaluation({
    required this.coachEvaluations,
    required this.canEdit,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final techniqueNames = <String, String>{};
    final needsReviewCount =
        coachEvaluations.where((e) => e.needsReview).length;
    final lastEvaluation = _lastCoachEvaluation(coachEvaluations);
    final previewItems = coachEvaluations.take(2).toList();

    final children = <Widget>[
      if (coachEvaluations.isEmpty)
        Text(
          'Avaliações do professor complementam suas evidências de treino.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        )
      else ...[
        // Quick metrics
        Row(
          children: [
            Expanded(
              child: _ClusterMetricRow(
                label: 'Total',
                value: coachEvaluations.length.toString(),
                icon: Icons.rate_review_outlined,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ClusterMetricRow(
                label: 'Revisar',
                value: needsReviewCount.toString(),
                icon: Icons.warning_amber_outlined,
                color:
                    needsReviewCount > 0
                        ? TitansUI.alertRed
                        : TitansUI.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ClusterMetricRow(
                label: 'Última',
                value:
                    lastEvaluation != null
                        ? _formatShortDate(lastEvaluation.evaluatedAt)
                        : '—',
                icon: Icons.calendar_today_outlined,
                color: TitansUI.actionGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Preview evaluations
        ...previewItems
            .map(
              (item) => _CoachEvaluationCard(
                evaluation: item,
                techniqueName: techniqueNames[item.skillId] ?? item.skillId,
              ),
            )
            .toList(),
        if (coachEvaluations.length > previewItems.length) ...[
          const SizedBox(height: 8),
          _MiniBadge(
            label:
                '${coachEvaluations.length - previewItems.length} avaliações adicionais',
            color: cs.primary,
          ),
        ],
      ],
      // Register button
      if (canEdit && onRegister != null) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Registrar avaliação'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    ];

    return _ClusterCard(
      title: 'Avaliação do professor',
      subtitle:
          coachEvaluations.isEmpty
              ? 'Nenhuma avaliação registrada ainda'
              : '${coachEvaluations.length} avaliação${coachEvaluations.length > 1 ? 's' : ''} • ${needsReviewCount > 0 ? '$needsReviewCount para revisar' : 'todas em dia'}',
      icon: Icons.rate_review_outlined,
      accent: TitansUI.actionGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// Cluster: Repertoire Summary
class _ClusterRepertoire extends StatelessWidget {
  final _RtcaEvidenceViewModel rtcaEvidence;

  const _ClusterRepertoire({required this.rtcaEvidence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxCount = _maxCountForItems(rtcaEvidence.items);
    final totalRecords = _totalCountForItems(rtcaEvidence.items);
    final topItem = _topItemForItems(rtcaEvidence.items);

    final children = <Widget>[];

    // Quick metrics
    children.add(
      Row(
        children: [
          Expanded(
            child: _ClusterMetricRow(
              label: 'Itens',
              value: rtcaEvidence.items.length.toString(),
              icon: Icons.list_alt_outlined,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ClusterMetricRow(
              label: 'Registros',
              value: totalRecords.toString(),
              icon: Icons.fact_check_outlined,
              color: TitansUI.successGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ClusterMetricRow(
              label: 'Destaque',
              value: topItem?.label ?? '—',
              icon: Icons.star_outline,
              color: TitansUI.actionGold,
            ),
          ),
        ],
      ),
    );

    children.add(const SizedBox(height: 12));

    // RTCA bars
    for (int i = 0; i < rtcaEvidence.items.length; i++) {
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactEvidenceBar(
              label: rtcaEvidence.items[i].label,
              count: _extractCount(rtcaEvidence.items[i].value),
              maxCount: maxCount,
              color: _colorForIndex(i, context),
              helper: rtcaEvidence.items[i].helper,
            ),
            if (i < rtcaEvidence.items.length - 1) const SizedBox(height: 8),
          ],
        ),
      );
    }

    return _ClusterCard(
      title: 'Repertório registrado',
      subtitle: 'Retenção, Transição, Controle, Ataque',
      icon: Icons.inventory_2_outlined,
      accent: cs.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  int _extractCount(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  int _maxCountForItems(List<_RtcaEvidenceItem> items) {
    int max = 0;
    for (final item in items) {
      final count = _extractCount(item.value);
      if (count > max) max = count;
    }
    return max == 0 ? 1 : max;
  }

  int _totalCountForItems(List<_RtcaEvidenceItem> items) {
    var total = 0;
    for (final item in items) {
      total += _extractCount(item.value);
    }
    return total;
  }

  _RtcaEvidenceItem? _topItemForItems(List<_RtcaEvidenceItem> items) {
    _RtcaEvidenceItem? selected;
    var selectedCount = 0;
    for (final item in items) {
      final count = _extractCount(item.value);
      if (count > selectedCount) {
        selected = item;
        selectedCount = count;
      }
    }
    return selected;
  }

  Color _colorForIndex(int index, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (index) {
      case 0:
        return cs.primary;
      case 1:
        return TitansUI.successGreen;
      case 2:
        return TitansUI.technicalBlue;
      case 3:
        return TitansUI.actionGold;
      default:
        return cs.primary;
    }
  }
}

// Shared Cluster Card Widget
class _ClusterCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _ClusterCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// Shared Metric Row for Cluster
class _ClusterMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ClusterMetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String? targetName;

  const _HeaderCard({required this.colorScheme, required this.targetName});

  @override
  Widget build(BuildContext context) {
    final name =
        (targetName?.trim().isNotEmpty ?? false)
            ? targetName!.trim()
            : 'Atleta';

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TitansUI.surfaceColor(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Game Map',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 11,
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

class _GameMapExpandableSection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final Widget child;

  const _GameMapExpandableSection({
    super.key,
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    required this.child,
  });

  @override
  State<_GameMapExpandableSection> createState() =>
      _GameMapExpandableSectionState();
}

class _GameMapExpandableSectionState extends State<_GameMapExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      padding: EdgeInsets.zero,
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.all(TitansUI.spaceMd),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.64),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: TitansUI.spaceSm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child:
                _expanded
                    ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TitansUI.spaceMd,
                        0,
                        TitansUI.spaceMd,
                        TitansUI.spaceMd,
                      ),
                      child: widget.child,
                    )
                    : const SizedBox.shrink(),
          ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 136),
      child: TitansCompactMetricCard(label: label, value: value, color: color),
    );
  }
}

class _GameMapHeroMetricStrip extends StatelessWidget {
  final _GameMapStats stats;
  final VoidCallback onOpenSkills;

  const _GameMapHeroMetricStrip({
    required this.stats,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.34),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitansCompactMetricGrid(
            fourColumnMinWidth: 620,
            spacing: 8,
            children: [
              _MetricPill(
                label: 'POSIÇÕES',
                value: stats.positions.toString(),
                color: cs.primary,
              ),
              _MetricPill(
                label: 'RELAÇÕES',
                value: stats.techniques.toString(),
                color: TitansUI.successGreen,
              ),
              _MetricPill(
                label: 'EIXO BASE',
                value: stats.dominantCategory ?? '-',
                color: TitansUI.actionGold,
              ),
              _MetricPill(
                label: 'EVIDÊNCIAS',
                value: stats.classifiedEvidence.toString(),
                color: cs.onSurface.withValues(alpha: 0.68),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onOpenSkills,
            icon: const Icon(Icons.psychology_alt_outlined, size: 18),
            label: const Text('Ver repertório técnico'),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              iconColor: cs.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachEvaluationPanel extends StatelessWidget {
  final List<CoachEvaluation> items;
  final List<TechnicalEvidenceSummary> techniques;
  final bool canEdit;
  final bool isLoading;
  final VoidCallback? onRegister;

  const _CoachEvaluationPanel({
    required this.items,
    required this.techniques,
    required this.canEdit,
    required this.isLoading,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final techniqueNames = {
      for (final technique in techniques)
        technique.skillId: technique.techniqueName,
    };
    final needsReviewCount =
        items.where((evaluation) => evaluation.needsReview).length;
    final lastEvaluation = _lastCoachEvaluation(items);
    final previewItems = items.take(2).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.28),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observações do professor baseadas nos seus treinos.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const TitansSkeletonCard(lines: 2)
          else ...[
            TitansCompactMetricGrid(
              maxColumns: 3,
              fourColumnMinWidth: 560,
              spacing: 8,
              children: [
                TitansCompactMetricCard(
                  label: 'AVALIAÇÕES',
                  value: items.length.toString(),
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: 'REVISAR',
                  value: needsReviewCount.toString(),
                  color:
                      needsReviewCount > 0
                          ? TitansUI.alertRed
                          : TitansUI.successGreen,
                ),
                TitansCompactMetricCard(
                  label: 'ÚLTIMA',
                  value:
                      lastEvaluation == null
                          ? '-'
                          : _formatShortDate(lastEvaluation.evaluatedAt),
                  color: TitansUI.actionGold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const TitansEmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Nenhuma avaliação registrada ainda.',
                message: 'Avaliações do professor ainda não registradas.',
                compact: true,
              )
            else ...[
              Text(
                'Mais recentes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in previewItems)
                _CoachEvaluationCard(
                  evaluation: item,
                  techniqueName: techniqueNames[item.skillId] ?? item.skillId,
                ),
              if (items.length > previewItems.length)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _MiniBadge(
                    label:
                        '${items.length - previewItems.length} avaliações adicionais',
                    color: cs.primary,
                  ),
                ),
            ],
          ],
          if (canEdit) ...[
            const SizedBox(height: 10),
            if (techniques.isEmpty)
              Text(
                'Registre treinos/técnicas antes de avaliar.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Registrar avaliação'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

CoachEvaluation? _lastCoachEvaluation(List<CoachEvaluation> items) {
  CoachEvaluation? selected;
  for (final item in items) {
    if (selected == null || item.evaluatedAt.isAfter(selected.evaluatedAt)) {
      selected = item;
    }
  }
  return selected;
}

class _CoachEvaluationCard extends StatelessWidget {
  final CoachEvaluation evaluation;
  final String techniqueName;

  const _CoachEvaluationCard({
    required this.evaluation,
    required this.techniqueName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final levelChips = <Widget>[
      if (evaluation.knowledgeLevel != null)
        _CoachLevelChip(
          label:
              'Conhecimento: ${_coachLevelLabel(evaluation.knowledgeLevel!)}',
        ),
      if (evaluation.drillLevel != null)
        _CoachLevelChip(
          label: 'Drill: ${_coachLevelLabel(evaluation.drillLevel!)}',
        ),
      if (evaluation.applicationLevel != null)
        _CoachLevelChip(
          label: 'Aplicação: ${_coachLevelLabel(evaluation.applicationLevel!)}',
        ),
      if (evaluation.consistencyLevel != null)
        _CoachLevelChip(
          label:
              'Consistência: ${_coachLevelLabel(evaluation.consistencyLevel!)}',
        ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
        color: cs.primary.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  techniqueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              if (evaluation.needsReview)
                _MiniBadge(label: 'Precisa revisar', color: TitansUI.alertRed),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Avaliação do professor.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (levelChips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: levelChips),
          ],
          if ((evaluation.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              evaluation.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if ((evaluation.recommendation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              evaluation.recommendation!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachLevelChip extends StatelessWidget {
  final String label;

  const _CoachLevelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.78),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CoachEvaluationDraft {
  final TechnicalEvidenceSummary technique;
  final CoachEvaluationLevel? knowledgeLevel;
  final CoachEvaluationLevel? drillLevel;
  final CoachEvaluationLevel? applicationLevel;
  final CoachEvaluationLevel? consistencyLevel;
  final String? note;
  final String? recommendation;
  final bool needsReview;

  const _CoachEvaluationDraft({
    required this.technique,
    required this.knowledgeLevel,
    required this.drillLevel,
    required this.applicationLevel,
    required this.consistencyLevel,
    required this.note,
    required this.recommendation,
    required this.needsReview,
  });
}

class _CoachEvaluationSheet extends StatefulWidget {
  final List<TechnicalEvidenceSummary> techniques;
  final List<CoachEvaluation> evaluations;

  const _CoachEvaluationSheet({
    required this.techniques,
    required this.evaluations,
  });

  @override
  State<_CoachEvaluationSheet> createState() => _CoachEvaluationSheetState();
}

class _CoachEvaluationSheetState extends State<_CoachEvaluationSheet> {
  late TechnicalEvidenceSummary _selectedTechnique = widget.techniques.first;
  CoachEvaluationLevel? _knowledgeLevel;
  CoachEvaluationLevel? _drillLevel;
  CoachEvaluationLevel? _applicationLevel;
  CoachEvaluationLevel? _consistencyLevel;
  bool _needsReview = false;
  final _noteController = TextEditingController();
  final _recommendationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyExistingEvaluation();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  void _applyExistingEvaluation() {
    final existing = _evaluationFor(_selectedTechnique.skillId);
    if (existing == null) return;
    _knowledgeLevel = existing.knowledgeLevel;
    _drillLevel = existing.drillLevel;
    _applicationLevel = existing.applicationLevel;
    _consistencyLevel = existing.consistencyLevel;
    _needsReview = existing.needsReview;
    _noteController.text = existing.note ?? '';
    _recommendationController.text = existing.recommendation ?? '';
  }

  CoachEvaluation? _evaluationFor(String skillId) {
    for (final evaluation in widget.evaluations) {
      if (evaluation.skillId == skillId) return evaluation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar avaliação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('Avaliação humana registrada pelo professor.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<TechnicalEvidenceSummary>(
                initialValue: _selectedTechnique,
                decoration: const InputDecoration(labelText: 'Técnica'),
                items: [
                  for (final technique in widget.techniques)
                    DropdownMenuItem(
                      value: technique,
                      child: Text(technique.techniqueName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedTechnique = value;
                    _knowledgeLevel = null;
                    _drillLevel = null;
                    _applicationLevel = null;
                    _consistencyLevel = null;
                    _needsReview = false;
                    _noteController.clear();
                    _recommendationController.clear();
                    _applyExistingEvaluation();
                  });
                },
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Conhecimento',
                value: _knowledgeLevel,
                onChanged: (value) => setState(() => _knowledgeLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Execução em drill',
                value: _drillLevel,
                onChanged: (value) => setState(() => _drillLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Aplicação',
                value: _applicationLevel,
                onChanged: (value) => setState(() => _applicationLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Consistência',
                value: _consistencyLevel,
                onChanged: (value) => setState(() => _consistencyLevel = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Observação'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _recommendationController,
                decoration: const InputDecoration(labelText: 'Recomendação'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Precisa revisar'),
                value: _needsReview,
                onChanged: (value) => setState(() => _needsReview = value),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _CoachEvaluationDraft(
                        technique: _selectedTechnique,
                        knowledgeLevel: _knowledgeLevel,
                        drillLevel: _drillLevel,
                        applicationLevel: _applicationLevel,
                        consistencyLevel: _consistencyLevel,
                        note: _cleanSheetText(_noteController.text),
                        recommendation: _cleanSheetText(
                          _recommendationController.text,
                        ),
                        needsReview: _needsReview,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Salvar avaliação'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachLevelDropdown extends StatelessWidget {
  final String label;
  final CoachEvaluationLevel? value;
  final ValueChanged<CoachEvaluationLevel?> onChanged;

  const _CoachLevelDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CoachEvaluationLevel>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final level in CoachEvaluationLevel.values)
          DropdownMenuItem(value: level, child: Text(_coachLevelLabel(level))),
      ],
      onChanged: onChanged,
    );
  }
}

String _coachLevelLabel(CoachEvaluationLevel level) {
  switch (level) {
    case CoachEvaluationLevel.observed:
      return 'Observado';
    case CoachEvaluationLevel.needsPractice:
      return 'Precisa praticar';
    case CoachEvaluationLevel.progressing:
      return 'Em evolução';
    case CoachEvaluationLevel.readyForReview:
      return 'Pronto para revisão';
  }
}

String? _cleanSheetText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

class _TechnicalEvidencePanel extends StatelessWidget {
  final List<TechnicalEvidenceSummary> items;
  final TechnicalRadarSummary radarSummary;
  final _GameMapStats stats;

  const _TechnicalEvidencePanel({
    required this.items,
    required this.radarSummary,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final previewItems = items.take(3).toList();
    final hasMore = items.length > previewItems.length;
    final hasEvidence =
        stats.positions > 0 ||
        stats.techniques > 0 ||
        radarSummary.classifiedEvidences > 0 ||
        radarSummary.unclassifiedEvidences > 0;
    final topAxis = radarSummary.topAxis;
    final topAxisLabel = topAxis?.displayLabel ?? 'Em formação';
    final relationText =
        topAxis == null
            ? 'Registre mais treinos para destacar padrões do seu jogo.'
            : 'Seu eixo mais presente é $topAxisLabel, a partir dos registros já cadastrados.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.32),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leitura do seu jogo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            'Um resumo simples do que já apareceu nos treinos.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasEvidence && items.isEmpty)
            const TitansEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Mapa em construção',
              message:
                  'Registre treinos com técnica e posição para destacar padrões reais.',
              compact: true,
            )
          else ...[
            TitansCompactMetricGrid(
              fourColumnMinWidth: 620,
              spacing: 8,
              children: [
                TitansCompactMetricCard(
                  label: 'TÉCNICAS',
                  value: stats.techniques.toString(),
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: 'POSIÇÕES',
                  value: stats.positions.toString(),
                  color: TitansUI.successGreen,
                ),
                TitansCompactMetricCard(
                  label: 'REGISTROS',
                  value: radarSummary.classifiedEvidences.toString(),
                  color: cs.onSurface.withValues(alpha: 0.64),
                ),
                TitansCompactMetricCard(
                  label: 'EIXO',
                  value: topAxisLabel,
                  color: TitansUI.actionGold,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TechnicalAxisEvidenceBars(axisEvidence: radarSummary.axisEvidence),
            const SizedBox(height: 10),
            Text(
              relationText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (previewItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registros recentes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.56),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _MiniBadge(
                    label: '${items.length} registros',
                    color: cs.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < previewItems.length; i++) ...[
                _TechnicalEvidencePreviewTile(
                  item: previewItems[i],
                  onTap:
                      () => _showTechnicalEvidenceDetails(
                        context,
                        previewItems[i],
                      ),
                ),
                if (i < previewItems.length - 1) const SizedBox(height: 8),
              ],
              if (hasMore) ...[
                const SizedBox(height: 8),
                _ViewAllTechnicalEvidencesButton(
                  count: items.length,
                  onPressed: () => _showAllTechnicalEvidences(context, items),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _TechnicalAxisEvidenceBars extends StatelessWidget {
  final Map<TechnicalRadarAxis, int> axisEvidence;

  const _TechnicalAxisEvidenceBars({required this.axisEvidence});

  @override
  Widget build(BuildContext context) {
    const axes = <TechnicalRadarAxis>[
      TechnicalRadarAxis.attack,
      TechnicalRadarAxis.retention,
      TechnicalRadarAxis.transition,
      TechnicalRadarAxis.control,
    ];
    var maxValue = 0;
    for (final axis in axes) {
      final count = axisEvidence[axis] ?? 0;
      if (count > maxValue) maxValue = count;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registros por eixo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final axis in axes) ...[
          _TechnicalAxisEvidenceBar(
            axis: axis,
            count: axisEvidence[axis] ?? 0,
            maxCount: maxValue,
          ),
          if (axis != axes.last) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _TechnicalAxisEvidenceBar extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int count;
  final int maxCount;

  const _TechnicalAxisEvidenceBar({
    required this.axis,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _axisColor(context, axis);
    final fraction = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    final active = count > 0;

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            axis.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: active ? 0.78 : 0.44),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: cs.onSurface.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.toDouble(),
                  child: Container(
                    height: 5,
                    color:
                        active ? color : cs.onSurface.withValues(alpha: 0.14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            count.toString(),
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? color : cs.onSurface.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnicalEvidencePreviewTile extends StatelessWidget {
  final TechnicalEvidenceSummary item;
  final VoidCallback onTap;

  const _TechnicalEvidencePreviewTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positions = item.positions.take(1).join(', ');
    final contexts = item.contexts.take(1).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
            border: Border.all(color: cs.secondary.withValues(alpha: 0.18)),
            color: cs.secondary.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.techniqueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MiniBadge(
                          label: '${item.evidenceCount} evidências',
                          color: cs.secondary,
                        ),
                        if (positions.isNotEmpty)
                          _EvidencePreviewChip(
                            icon: Icons.place_outlined,
                            label: positions,
                          ),
                        if (contexts.isNotEmpty)
                          _EvidencePreviewChip(
                            icon: Icons.sports_mma_outlined,
                            label: contexts,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EvidenceDetailLine(
                icon: Icons.calendar_today_outlined,
                label: 'Última',
                value: _formatShortDate(item.lastPracticedAt),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.48),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidencePreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EvidencePreviewChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.58)),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAllTechnicalEvidencesButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _ViewAllTechnicalEvidencesButton({
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.list_alt_outlined, size: 16, color: cs.primary),
        label: Text(
          'Ver detalhes técnicos ($count)',
          style: TextStyle(
            color: cs.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _EvidenceDetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EvidenceDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.58)),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapVisualClusterCard extends StatelessWidget {
  final _GameMapVisualViewModel viewModel;

  const _GameMapVisualClusterCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CompactHeader(title: 'MAPA TÉCNICO VISUAL'),
        const SizedBox(height: 8),
        Text(
          viewModel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 12),
        if (viewModel.nodes.isEmpty)
          TitansEmptyState(
            icon: Icons.account_tree_outlined,
            title: 'Mapa visual vazio',
            message: viewModel.emptyStateLabel,
            compact: true,
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final highlight in viewModel.highlights)
                _GameMapHighlightChip(highlight: highlight),
            ],
          ),
          const SizedBox(height: 10),
          _GameMapPositionClusterGraph(viewModel: viewModel),
        ],
      ],
    );
  }
}

class _GameMapPositionClusterGraph extends StatelessWidget {
  final _GameMapVisualViewModel viewModel;

  const _GameMapPositionClusterGraph({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 420;
        final nodeWidth =
            (isCompact
                    ? ((width - 8) / 2).clamp(124.0, 164.0)
                    : width >= 720
                    ? ((width - 20) / 3).clamp(156.0, 220.0)
                    : ((width - 10) / 2).clamp(144.0, 204.0))
                .toDouble();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 10 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.05),
                cs.secondary.withValues(alpha: 0.03),
                cs.surfaceContainerHighest.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GameMapClusterBackdropPainter(
                      primary: cs.primary,
                      secondary: cs.secondary,
                      lineColor: cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.account_tree_outlined,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toque em uma posi\u00e7\u00e3o para abrir as t\u00e9cnicas e evid\u00eancias vinculadas.',
                          maxLines: isCompact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.66),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: isCompact ? 8 : 10,
                    runSpacing: isCompact ? 8 : 10,
                    children: [
                      for (final node in viewModel.nodes)
                        SizedBox(
                          width: nodeWidth,
                          child: _GameMapPositionClusterNode(node: node),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GameMapClusterBackdropPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color lineColor;

  const _GameMapClusterBackdropPainter({
    required this.primary,
    required this.secondary,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.54);
    final radius = (size.shortestSide * 0.32).clamp(48.0, 118.0).toDouble();
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              primary.withValues(alpha: 0.18),
              secondary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6));

    canvas.drawCircle(center, radius * 1.6, glowPaint);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, linePaint);
    }
    canvas.drawLine(
      Offset(center.dx - radius * 1.35, center.dy),
      Offset(center.dx + radius * 1.35, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GameMapClusterBackdropPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.lineColor != lineColor;
  }
}

class _GameMapHighlightChip extends StatelessWidget {
  final _GameMapHighlight highlight;

  const _GameMapHighlightChip({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: highlight.helper,
      child: _MiniBadge(
        label: '${highlight.label}: ${highlight.value}',
        color: cs.secondary,
      ),
    );
  }
}

class _GameMapPositionClusterNode extends StatelessWidget {
  final _GameMapPositionNode node;

  const _GameMapPositionClusterNode({required this.node});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weight = node.normalizedWeight.clamp(0.0, 1.0).toDouble();
    final accent = weight >= 0.76 ? TitansUI.actionGold : cs.primary;

    return Semantics(
      button: true,
      label:
          '${node.recurrenceCount} registros nesta posicao; toque para detalhes.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showGameMapPositionDetail(context, node),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
              color: TitansUI.subtleFillColor(context, alpha: 0.30),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08 + (weight * 0.06)),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GameMapNodeOrb(weight: weight, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.position,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniBadge(label: node.countLabel, color: accent),
                    _MiniBadge(label: node.categoryLabel, color: cs.primary),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    color: cs.onSurface.withValues(alpha: 0.08),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: weight,
                      child: Container(color: accent.withValues(alpha: 0.78)),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${node.techniques.length} tecnicas vinculadas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: accent.withValues(alpha: 0.92),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameMapNodeOrb extends StatelessWidget {
  final double weight;
  final Color color;

  const _GameMapNodeOrb({required this.weight, required this.color});

  @override
  Widget build(BuildContext context) {
    final size = 12.0 + (weight * 8.0);

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18 + (weight * 0.20)),
          border: Border.all(color: color.withValues(alpha: 0.52)),
        ),
      ),
    );
  }
}

void _showGameMapPositionDetail(
  BuildContext context,
  _GameMapPositionNode node,
) {
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CompactHeader(
                          title: 'DETALHE DA POSI\u00c7\u00c3O',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          node.position,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(label: node.countLabel, color: cs.primary),
                  _MiniBadge(label: node.categoryLabel, color: cs.secondary),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final technique in node.techniques) ...[
                        _GameMapTechniqueLinkChip(link: technique),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GameMapTechniqueLinkChip extends StatelessWidget {
  final _GameMapTechniqueLink link;

  const _GameMapTechniqueLinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width < 420 ? 168.0 : 220.0;
    final details = <String>[
      '${link.recurrenceCount} registros associados',
      if (link.applicationLabel != null) link.applicationLabel!,
      if (link.outcomeLabel != null) link.outcomeLabel!,
    ];

    return Semantics(
      label: details.join(' - '),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
          color: cs.primary.withValues(
            alpha: 0.06 + (link.normalizedWeight.clamp(0.0, 1.0) * 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              link.technique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              link.countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionAxisMatrixCard extends StatelessWidget {
  final _PositionAxisMatrixViewModel viewModel;

  const _PositionAxisMatrixCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'POSI\u00c7\u00d5ES MAPEADAS'),
          const SizedBox(height: 8),
          Text(
            'Registros por eixo t\u00e9cnico inferido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (viewModel.rows.isEmpty)
            TitansEmptyState(
              icon: Icons.grid_on_outlined,
              title: 'Sem matriz por posi\u00e7\u00e3o',
              message:
                  'Registre posi\u00e7\u00e3o e t\u00e9cnica nos treinos para inferir eixos t\u00e9cnicos com seguran\u00e7a.',
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                if (compact) {
                  return Column(
                    children: [
                      for (final row in viewModel.rows) ...[
                        _PositionAxisStackedRow(row: row),
                        if (row != viewModel.rows.last)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                }

                return _PositionAxisWideMatrix(viewModel: viewModel);
              },
            ),
        ],
      ),
    );
  }
}

class _PositionAxisStackedRow extends StatelessWidget {
  final _PositionAxisMatrixRow row;

  const _PositionAxisStackedRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _MiniBadge(label: row.countLabel, color: cs.primary),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final cellWidth = ((constraints.maxWidth - gap) / 2).clamp(
                120.0,
                constraints.maxWidth,
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final cell in row.cells)
                    SizedBox(
                      width: cellWidth.toDouble(),
                      child: _PositionAxisCell(row: row, cell: cell),
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

class _PositionAxisWideMatrix extends StatelessWidget {
  final _PositionAxisMatrixViewModel viewModel;

  const _PositionAxisWideMatrix({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 150),
            for (final axis in _PositionAxisMatrixViewModel.axes)
              Expanded(
                child: Text(
                  axis.displayLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in viewModel.rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  row.position,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              for (final cell in row.cells)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _PositionAxisCell(row: row, cell: cell),
                  ),
                ),
            ],
          ),
          if (row != viewModel.rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PositionAxisCell extends StatelessWidget {
  final _PositionAxisMatrixRow row;
  final _PositionAxisMatrixCell cell;

  const _PositionAxisCell({required this.row, required this.cell});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _axisColor(context, cell.axis);
    final active = cell.sessionCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            active ? () => _showPositionAxisDetail(context, row, cell) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  active
                      ? color.withValues(alpha: 0.28)
                      : cs.onSurface.withValues(alpha: 0.07),
            ),
            color:
                active
                    ? color.withValues(alpha: 0.10)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                cell.axis.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? color : cs.onSurface.withValues(alpha: 0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cell.countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      active
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.46),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPositionAxisDetail(
  BuildContext context,
  _PositionAxisMatrixRow row,
  _PositionAxisMatrixCell cell,
) {
  if (cell.sessionCount <= 0) return;
  final cs = Theme.of(context).colorScheme;
  final axisColor = _axisColor(context, cell.axis);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                row.position,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(
                    label:
                        'Eixo t\u00e9cnico inferido: ${cell.axis.displayLabel}',
                    color: axisColor,
                  ),
                  _MiniBadge(label: cell.countLabel, color: cs.primary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Inferido por posi\u00e7\u00e3o e t\u00e9cnica registradas nos treinos. Leitura visual baseada apenas em registros reais.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final detail in cell.details) ...[
                        _PositionAxisTechniqueDetail(detail: detail),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PositionAxisTechniqueDetail extends StatelessWidget {
  final _PositionAxisTechniqueDetailItem detail;

  const _PositionAxisTechniqueDetail({required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.technique,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          _MiniBadge(label: detail.countLabel, color: cs.primary),
        ],
      ),
    );
  }
}

class _PositionAxisMatrixViewModel {
  static const axes = <TechnicalRadarAxis>[
    TechnicalRadarAxis.retention,
    TechnicalRadarAxis.transition,
    TechnicalRadarAxis.control,
    TechnicalRadarAxis.attack,
  ];

  final String subtitle;
  final List<_PositionAxisMatrixRow> rows;

  const _PositionAxisMatrixViewModel({
    required this.subtitle,
    required this.rows,
  });

  factory _PositionAxisMatrixViewModel.from(List<TrainingSession> sessions) {
    final accumulators = <String, _PositionAxisRowAccumulator>{};

    for (final session in sessions) {
      for (final entry in session.effectiveTechniqueEntries) {
        final position = _cleanTechnicalLabel(
          entry.position ?? session.position,
        );
        final technique = _cleanTechnicalLabel(entry.technique);
        if (position == null || technique == null) continue;

        final category = JiuJitsuTaxonomy.categoryFor(
          position: position,
          technique: technique,
        );
        final axis = JiuJitsuTaxonomy.technicalRadarAxisForCategory(category);
        if (axis == TechnicalRadarAxis.unclassified) continue;

        final key = JiuJitsuTaxonomy.normalizedKey(position);
        final accumulator = accumulators.putIfAbsent(
          key,
          () => _PositionAxisRowAccumulator(position),
        );
        accumulator.add(axis: axis, session: session, technique: technique);
      }
    }

    final rows =
        accumulators.values.map((accumulator) => accumulator.build()).toList()
          ..sort((a, b) {
            final countCompare = b.sessionCount.compareTo(a.sessionCount);
            if (countCompare != 0) return countCompare;
            return a.position.compareTo(b.position);
          });

    return _PositionAxisMatrixViewModel(
      subtitle:
          rows.isEmpty
              ? 'A matriz aparece quando h\u00e1 posi\u00e7\u00e3o e t\u00e9cnica classific\u00e1vel nos treinos.'
              : 'Eixo t\u00e9cnico inferido pelos registros de treino; sem percentual ou nota.',
      rows: rows,
    );
  }
}

class _PositionAxisMatrixRow {
  final String position;
  final int sessionCount;
  final String countLabel;
  final List<_PositionAxisMatrixCell> cells;

  const _PositionAxisMatrixRow({
    required this.position,
    required this.sessionCount,
    required this.countLabel,
    required this.cells,
  });
}

class _PositionAxisMatrixCell {
  final TechnicalRadarAxis axis;
  final int sessionCount;
  final String countLabel;
  final Set<String> sessionKeys;
  final List<_PositionAxisTechniqueDetailItem> details;

  _PositionAxisMatrixCell({
    required this.axis,
    required this.sessionCount,
    required this.countLabel,
    required Set<String> sessionKeys,
    required this.details,
  }) : sessionKeys = Set.unmodifiable(sessionKeys);
}

class _PositionAxisTechniqueDetailItem {
  final String technique;
  final String countLabel;

  const _PositionAxisTechniqueDetailItem({
    required this.technique,
    required this.countLabel,
  });
}

class _PositionAxisRowAccumulator {
  final String position;
  final Map<TechnicalRadarAxis, _PositionAxisCellAccumulator> _cells = {
    for (final axis in _PositionAxisMatrixViewModel.axes)
      axis: _PositionAxisCellAccumulator(),
  };

  _PositionAxisRowAccumulator(this.position);

  void add({
    required TechnicalRadarAxis axis,
    required TrainingSession session,
    required String technique,
  }) {
    _cells[axis]?.add(session: session, technique: technique);
  }

  _PositionAxisMatrixRow build() {
    final cells = [
      for (final axis in _PositionAxisMatrixViewModel.axes)
        _cells[axis]!.build(axis),
    ];
    final sessionKeys = <String>{};
    for (final cell in _cells.values) {
      sessionKeys.addAll(cell.sessionKeys);
    }

    return _PositionAxisMatrixRow(
      position: position,
      sessionCount: sessionKeys.length,
      countLabel: TrainingAggregator.sessionCountLabel(sessionKeys.length),
      cells: cells,
    );
  }
}

class _PositionAxisCellAccumulator {
  final Set<String> sessionKeys = <String>{};
  final Map<String, int> techniqueCounts = <String, int>{};

  void add({required TrainingSession session, required String technique}) {
    final sessionKey =
        session.id.trim().isEmpty
            ? '${session.date.toIso8601String()}:$technique'
            : session.id;
    sessionKeys.add(sessionKey);
    techniqueCounts[technique] = (techniqueCounts[technique] ?? 0) + 1;
  }

  _PositionAxisMatrixCell build(TechnicalRadarAxis axis) {
    final details =
        techniqueCounts.entries.toList()..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });

    return _PositionAxisMatrixCell(
      axis: axis,
      sessionCount: sessionKeys.length,
      countLabel: TrainingAggregator.sessionCountLabel(sessionKeys.length),
      sessionKeys: sessionKeys,
      details: [
        for (final detail in details.take(6))
          _PositionAxisTechniqueDetailItem(
            technique: detail.key,
            countLabel: '${detail.value} registros',
          ),
      ],
    );
  }
}

String? _cleanTechnicalLabel(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return null;
  return clean;
}

Color _axisColor(BuildContext context, TechnicalRadarAxis axis) {
  final cs = Theme.of(context).colorScheme;
  switch (axis) {
    case TechnicalRadarAxis.retention:
      return cs.primary;
    case TechnicalRadarAxis.transition:
      return TitansUI.technicalBlue;
    case TechnicalRadarAxis.control:
      return TitansUI.successGreen;
    case TechnicalRadarAxis.attack:
      return TitansUI.actionGold;
    case TechnicalRadarAxis.unclassified:
      return cs.onSurface.withValues(alpha: 0.46);
  }
}

class _EvidenceDistributionCard extends StatelessWidget {
  final _EvidenceDistributionViewModel viewModel;

  const _EvidenceDistributionCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: TitansUI.technicalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'REGISTROS POR EIXO'),
          const SizedBox(height: 8),
          Text(
            'Distribuição das evidências por eixo técnico',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (viewModel.isEmpty)
            TitansEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Sem distribuição registrada',
              message:
                  'Registre posições e técnicas nos treinos para visualizar a distribuição de evidências.',
              compact: true,
            )
          else
            _EvidenceDistributionGroup(
              title: 'Registros por eixo',
              items: viewModel.axisItems,
            ),
        ],
      ),
    );
  }
}

class _EvidenceDistributionGroup extends StatelessWidget {
  final String title;
  final List<_EvidenceDistributionItem> items;

  const _EvidenceDistributionGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 620;
            final itemWidth =
                twoColumns
                    ? ((constraints.maxWidth - 10) / 2).clamp(220.0, 360.0)
                    : constraints.maxWidth;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth.toDouble(),
                    child: _EvidenceDistributionBar(item: item),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EvidenceDistributionBar extends StatelessWidget {
  final _EvidenceDistributionItem item;

  const _EvidenceDistributionBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = item.count;
    final maxValue = item.maxCount <= 0 ? 1 : item.maxCount;
    final fraction = (value / maxValue).clamp(0.0, 1.0).toDouble();
    final active = value > 0;
    final color = item.color(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              active
                  ? color.withValues(alpha: 0.24)
                  : cs.onSurface.withValues(alpha: 0.07),
        ),
        color:
            active
                ? color.withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? color : cs.onSurface.withValues(alpha: 0.48),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              color: active ? color : cs.onSurface.withValues(alpha: 0.16),
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            ),
          ),
          if (item.helper != null) ...[
            const SizedBox(height: 6),
            Text(
              item.helper!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceDistributionViewModel {
  final String subtitle;
  final List<_EvidenceDistributionItem> axisItems;
  final List<_EvidenceDistributionItem> positionItems;

  const _EvidenceDistributionViewModel({
    required this.subtitle,
    required this.axisItems,
    required this.positionItems,
  });

  bool get isEmpty =>
      axisItems.every((item) => item.count == 0) && positionItems.isEmpty;

  factory _EvidenceDistributionViewModel.from(
    _PositionAxisMatrixViewModel matrix,
  ) {
    final axisSessionKeys = <TechnicalRadarAxis, Set<String>>{
      for (final axis in _PositionAxisMatrixViewModel.axes) axis: <String>{},
    };

    for (final row in matrix.rows) {
      for (final cell in row.cells) {
        axisSessionKeys[cell.axis]?.addAll(cell.sessionKeys);
      }
    }

    final maxAxisCount = axisSessionKeys.values.fold<int>(
      1,
      (max, keys) => keys.length > max ? keys.length : max,
    );
    final maxPositionCount = matrix.rows.fold<int>(
      1,
      (max, row) => row.sessionCount > max ? row.sessionCount : max,
    );

    return _EvidenceDistributionViewModel(
      subtitle:
          matrix.rows.isEmpty
              ? 'A distribui\u00e7\u00e3o aparece quando h\u00e1 registros classific\u00e1veis.'
              : 'Baseada apenas em sess\u00f5es registradas por grupo, sem percentual.',
      axisItems: [
        for (final axis in _PositionAxisMatrixViewModel.axes)
          _EvidenceDistributionItem(
            label: axis.displayLabel,
            count: axisSessionKeys[axis]!.length,
            countLabel: TrainingAggregator.sessionCountLabel(
              axisSessionKeys[axis]!.length,
            ),
            maxCount: maxAxisCount,
            colorBuilder: _axisColor,
            axis: axis,
          ),
      ],
      positionItems: [
        for (final row in matrix.rows.take(6))
          _EvidenceDistributionItem(
            label: row.position,
            count: row.sessionCount,
            countLabel: row.countLabel,
            maxCount: maxPositionCount,
            helper: _topAxisLabelForRow(row),
            colorBuilder: _axisColor,
            axis: _topAxisForRow(row) ?? TechnicalRadarAxis.unclassified,
          ),
      ],
    );
  }
}

class _EvidenceDistributionItem {
  final String label;
  final int count;
  final String countLabel;
  final int maxCount;
  final String? helper;
  final Color Function(BuildContext, TechnicalRadarAxis) colorBuilder;
  final TechnicalRadarAxis axis;

  const _EvidenceDistributionItem({
    required this.label,
    required this.count,
    required this.countLabel,
    required this.maxCount,
    required this.colorBuilder,
    required this.axis,
    this.helper,
  });

  Color color(BuildContext context) => colorBuilder(context, axis);
}

TechnicalRadarAxis? _topAxisForRow(_PositionAxisMatrixRow row) {
  TechnicalRadarAxis? selected;
  var selectedCount = 0;
  for (final cell in row.cells) {
    if (cell.sessionCount > selectedCount) {
      selected = cell.axis;
      selectedCount = cell.sessionCount;
    }
  }
  return selectedCount == 0 ? null : selected;
}

String? _topAxisLabelForRow(_PositionAxisMatrixRow row) {
  final axis = _topAxisForRow(row);
  if (axis == null) return null;
  return 'Eixo t\u00e9cnico inferido: ${axis.displayLabel}';
}

class _RtcaEvidencePanel extends StatelessWidget {
  final _RtcaEvidenceViewModel viewModel;

  const _RtcaEvidencePanel({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxCount = _maxCountForItems(viewModel.items);
    final totalRecords = _totalCountForItems(viewModel.items);
    final topItem = _topItemForItems(viewModel.items);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.28),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (viewModel.items.isEmpty)
            TitansEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Painel sem evidências',
              message: viewModel.emptyStateLabel,
              compact: true,
            )
          else ...[
            TitansCompactMetricGrid(
              maxColumns: 3,
              fourColumnMinWidth: 560,
              spacing: 8,
              children: [
                TitansCompactMetricCard(
                  label: 'ITENS',
                  value: viewModel.items.length.toString(),
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: 'REGISTROS',
                  value: totalRecords.toString(),
                  color: TitansUI.successGreen,
                ),
                TitansCompactMetricCard(
                  label: 'MAIS PRESENTE',
                  value: topItem?.label ?? '-',
                  color: TitansUI.actionGold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < viewModel.items.length; i++) ...[
              _CompactEvidenceBar(
                label: viewModel.items[i].label,
                count: _extractCount(viewModel.items[i].value),
                maxCount: maxCount,
                color: _colorForIndex(i, context),
                helper: viewModel.items[i].helper,
              ),
              if (i < viewModel.items.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  int _extractCount(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  int _maxCountForItems(List<_RtcaEvidenceItem> items) {
    int max = 0;
    for (final item in items) {
      final count = _extractCount(item.value);
      if (count > max) max = count;
    }
    return max == 0 ? 1 : max;
  }

  int _totalCountForItems(List<_RtcaEvidenceItem> items) {
    var total = 0;
    for (final item in items) {
      total += _extractCount(item.value);
    }
    return total;
  }

  _RtcaEvidenceItem? _topItemForItems(List<_RtcaEvidenceItem> items) {
    _RtcaEvidenceItem? selected;
    var selectedCount = 0;
    for (final item in items) {
      final count = _extractCount(item.value);
      if (count > selectedCount) {
        selected = item;
        selectedCount = count;
      }
    }
    return selected;
  }

  Color _colorForIndex(int index, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (index) {
      case 0:
        return cs.primary;
      case 1:
        return TitansUI.successGreen;
      case 2:
        return TitansUI.technicalBlue;
      case 3:
        return TitansUI.actionGold;
      default:
        return cs.primary;
    }
  }
}

class _CompactEvidenceBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color color;
  final String? helper;

  const _CompactEvidenceBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    final active = count > 0;

    return Semantics(
      label: helper ?? '$label: $count registros',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          border: Border.all(
            color:
                active
                    ? color.withValues(alpha: 0.20)
                    : cs.onSurface.withValues(alpha: 0.07),
          ),
          color:
              active
                  ? color.withValues(alpha: 0.06)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  count.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        active ? color : cs.onSurface.withValues(alpha: 0.48),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 4,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.toDouble(),
                  child: Container(
                    height: 4,
                    color:
                        active ? color : cs.onSurface.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Text(
                helper!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
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

class _TechnicalRadarPreviewViewModel {
  final String subtitle;
  final String stateLabel;
  final List<TitansTechnicalRadarEvidence> evidences;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;

  const _TechnicalRadarPreviewViewModel({
    required this.subtitle,
    required this.stateLabel,
    required this.evidences,
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
  });

  factory _TechnicalRadarPreviewViewModel.fromSummary(
    TechnicalRadarSummary summary, {
    int coachEvaluationCount = 0,
  }) {
    final axisEvidence = summary.axisEvidence;
    final classified = summary.classifiedEvidences;
    final unclassified = summary.unclassifiedEvidences;
    final topAxis = summary.topAxis;
    final topAxisLabel =
        topAxis == null
            ? 'Em formação'
            : '${topAxis.displayLabel} (${axisEvidence[topAxis]} evidências)';
    final stateLabel =
        classified < 3
            ? 'Perfil técnico em formação'
            : 'Evidências técnicas distribuídas por eixo';

    return _TechnicalRadarPreviewViewModel(
      subtitle:
          'Distribuição de evidências registradas, sem nota ou desempenho.',
      stateLabel: stateLabel,
      axisEvidence: axisEvidence,
      classifiedEvidenceCount: classified,
      awaitingClassificationCount: unclassified,
      evidences: [
        TitansTechnicalRadarEvidence(
          label: 'Técnicas evidenciadas',
          value: summary.techniqueCount.toString(),
          helper: 'Técnicas agrupadas por identidade técnica local.',
          icon: Icons.sports_mma_outlined,
        ),
        TitansTechnicalRadarEvidence(
          label: 'Evidências classificadas',
          value: classified.toString(),
          helper:
              'Registros ligados a técnicas com identidade e eixo conservador.',
          icon: Icons.verified_outlined,
        ),
        TitansTechnicalRadarEvidence(
          label: 'Aguardando classificação',
          value: unclassified.toString(),
          helper:
              'Registros de técnicas sem identidade local ou sem eixo seguro.',
          icon: Icons.pending_outlined,
        ),
        TitansTechnicalRadarEvidence(
          label: 'Eixo mais evidenciado',
          value: topAxisLabel,
          helper:
              'Eixo com mais evidências registradas. Não indica desempenho.',
          icon: Icons.radar_outlined,
        ),
        if (coachEvaluationCount > 0)
          TitansTechnicalRadarEvidence(
            label: 'Avaliações registradas',
            value: coachEvaluationCount.toString(),
            helper: 'Técnicas com avaliação humana do professor.',
            icon: Icons.rate_review_outlined,
          ),
      ],
    );
  }
}

int _coachEvaluatedTechniqueCount(List<CoachEvaluation> evaluations) {
  final skillIds = <String>{};
  for (final evaluation in evaluations) {
    final skillId = evaluation.skillId.trim();
    if (skillId.isNotEmpty) skillIds.add(skillId);
  }
  return skillIds.length;
}

class _RtcaEvidenceViewModel {
  final String title;
  final String subtitle;
  final List<_RtcaEvidenceItem> items;
  final String emptyStateLabel;

  const _RtcaEvidenceViewModel({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyStateLabel,
  });

  factory _RtcaEvidenceViewModel.from({
    required List<TrainingSession> sessions,
    required List<GameMapEntry> entries,
    required List<SkillMatrixCategoryEntry> skillMatrix,
  }) {
    final techniques = skillMatrix.expand((entry) => entry.techniques).toList();
    final recurring =
        entries
            .expand((entry) => entry.techniques)
            .where((technique) => technique.sessionsCount >= 3)
            .length;
    final trainingDays = _recentTrainingDays(sessions, days: 84);
    final applications =
        sessions.where(_hasMeasuredTechniqueApplication).length;

    return _RtcaEvidenceViewModel(
      title: 'Repertório registrado',
      subtitle:
          'O que aparece nos seus treinos: recorrência, técnicas, consistência e aplicação.',
      items: [
        _RtcaEvidenceItem(
          code: '1',
          label: 'Recorrência',
          value: _techniquePlural(recurring, 'recorrente'),
          helper: 'Técnicas que você praticou várias vezes.',
          icon: Icons.repeat_outlined,
          statusLabel: _statusForCount(recurring),
        ),
        _RtcaEvidenceItem(
          code: '2',
          label: 'Técnicas registradas',
          value: TrainingAggregator.techniqueCountLabel(techniques.length),
          helper: 'Técnicas que apareceram nos seus treinos.',
          icon: Icons.sports_mma_outlined,
          statusLabel: _statusForCount(techniques.length),
        ),
        _RtcaEvidenceItem(
          code: '3',
          label: 'Consistência',
          value: _dayPlural(trainingDays),
          helper: 'Dias com treino nos últimos 84 dias.',
          icon: Icons.calendar_month_outlined,
          statusLabel: _statusForCount(trainingDays),
        ),
        _RtcaEvidenceItem(
          code: '4',
          label: 'Aplicação registrada',
          value: _applicationPlural(applications),
          helper: 'Treinos com contexto e resultado anotados.',
          icon: Icons.fact_check_outlined,
          statusLabel: _statusForCount(applications),
        ),
      ],
      emptyStateLabel:
          'Registre treinos para formar seu repertório com dados reais.',
    );
  }

  static bool _hasMeasuredTechniqueApplication(TrainingSession session) {
    for (final entry in session.effectiveTechniqueEntries) {
      final applicationContext =
          entry.applicationContext ?? session.applicationContext;
      final techniqueOutcome =
          entry.techniqueOutcome ?? session.techniqueOutcome;

      if (TrainingSession.isApplicationContextMeasured(applicationContext) &&
          TrainingSession.isTechniqueOutcomeUseful(techniqueOutcome)) {
        return true;
      }
    }

    return false;
  }

  static int _recentTrainingDays(
    List<TrainingSession> sessions, {
    required int days,
  }) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final trainingDays = <String>{};

    for (final session in sessions) {
      final day = _dateOnly(session.date);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      trainingDays.add(_dateKey(day));
    }

    return trainingDays.length;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _techniquePlural(int count, String suffix) {
    if (count == 1) return '1 técnica $suffix';
    return '$count técnicas ${suffix}s';
  }

  static String _dayPlural(int count) {
    if (count == 1) return '1 dia com treino';
    return '$count dias com treino';
  }

  static String _applicationPlural(int count) {
    if (count == 1) return '1 aplicação registrada';
    return '$count aplicações registradas';
  }

  static String _statusForCount(int count) {
    if (count <= 0) return 'Sem registros suficientes';
    if (count < 3) return 'Em construção';
    return 'Registrado';
  }
}

class _RtcaEvidenceItem {
  final String code;
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final String statusLabel;

  const _RtcaEvidenceItem({
    required this.code,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.statusLabel,
  });
}

class _GameMapVisualViewModel {
  final String title;
  final String subtitle;
  final List<_GameMapPositionNode> nodes;
  final List<_GameMapHighlight> highlights;
  final String emptyStateLabel;

  const _GameMapVisualViewModel({
    required this.title,
    required this.subtitle,
    required this.nodes,
    required this.highlights,
    required this.emptyStateLabel,
  });

  factory _GameMapVisualViewModel.from(
    List<GameMapEntry> entries,
    List<SkillMatrixCategoryEntry> skillMatrix,
  ) {
    if (entries.isEmpty) {
      return const _GameMapVisualViewModel(
        title: 'Posições e técnicas registradas',
        subtitle: 'Baseado nos treinos registrados.',
        nodes: [],
        highlights: [],
        emptyStateLabel:
            'Registre posição e técnica nos debriefs para gerar um mapa visual seguro.',
      );
    }

    final orderedEntries = List<GameMapEntry>.from(entries)..sort((a, b) {
      final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
      if (countCompare != 0) return countCompare;
      return b.lastTrainedAt.compareTo(a.lastTrainedAt);
    });
    final maxPositionCount = orderedEntries.fold<int>(
      0,
      (max, entry) => entry.sessionsCount > max ? entry.sessionsCount : max,
    );
    final nodes = [
      for (final entry in orderedEntries.take(4))
        _GameMapPositionNode.from(
          entry,
          skillMatrix,
          maxPositionCount: maxPositionCount,
        ),
    ];
    final techniquesCount = nodes.fold<int>(
      0,
      (sum, node) => sum + node.techniques.length,
    );
    final topNode = nodes.isEmpty ? null : nodes.first;

    return _GameMapVisualViewModel(
      title: 'Posições e técnicas registradas',
      subtitle:
          'Clusters por recorrência nos debriefs; peso visual não indica desempenho.',
      nodes: nodes,
      highlights: [
        _GameMapHighlight(
          label: 'Posições',
          value: entries.length.toString(),
          helper: 'Total de posições com técnicas registradas.',
        ),
        _GameMapHighlight(
          label: 'Técnicas associadas',
          value: techniquesCount.toString(),
          helper: 'Técnicas visíveis nos clusters desta seção.',
        ),
        if (topNode != null)
          _GameMapHighlight(
            label: 'Mais registrada',
            value: topNode.position,
            helper: 'Posição com mais registros neste mapa visual.',
          ),
      ],
      emptyStateLabel:
          'Registre posição e técnica nos debriefs para gerar um mapa visual seguro.',
    );
  }
}

class _GameMapPositionNode {
  final String position;
  final String categoryLabel;
  final String countLabel;
  final int recurrenceCount;
  final double normalizedWeight;
  final List<_GameMapTechniqueLink> techniques;

  const _GameMapPositionNode({
    required this.position,
    required this.categoryLabel,
    required this.countLabel,
    required this.recurrenceCount,
    required this.normalizedWeight,
    required this.techniques,
  });

  factory _GameMapPositionNode.from(
    GameMapEntry entry,
    List<SkillMatrixCategoryEntry> skillMatrix, {
    required int maxPositionCount,
  }) {
    final category = _categoryLabelForPosition(entry.position, skillMatrix);
    final maxTechniqueCount = entry.techniques.fold<int>(
      0,
      (max, technique) =>
          technique.sessionsCount > max ? technique.sessionsCount : max,
    );

    return _GameMapPositionNode(
      position: entry.position,
      categoryLabel: category,
      countLabel: TrainingAggregator.sessionCountLabel(entry.sessionsCount),
      recurrenceCount: entry.sessionsCount,
      normalizedWeight:
          maxPositionCount == 0 ? 0 : entry.sessionsCount / maxPositionCount,
      techniques: [
        for (final technique in entry.techniques.take(5))
          _GameMapTechniqueLink.from(
            technique,
            entry.position,
            skillMatrix,
            maxTechniqueCount: maxTechniqueCount,
          ),
      ],
    );
  }
}

class _GameMapTechniqueLink {
  final String technique;
  final String countLabel;
  final int recurrenceCount;
  final double normalizedWeight;
  final String? applicationLabel;
  final String? outcomeLabel;

  const _GameMapTechniqueLink({
    required this.technique,
    required this.countLabel,
    required this.recurrenceCount,
    required this.normalizedWeight,
    required this.applicationLabel,
    required this.outcomeLabel,
  });

  factory _GameMapTechniqueLink.from(
    GameMapTechniqueSummary technique,
    String position,
    List<SkillMatrixCategoryEntry> skillMatrix, {
    required int maxTechniqueCount,
  }) {
    final skillEntry = _findSkillEntry(
      skillMatrix,
      position,
      technique.technique,
    );

    return _GameMapTechniqueLink(
      technique: technique.technique,
      countLabel: TrainingAggregator.sessionCountLabel(technique.sessionsCount),
      recurrenceCount: technique.sessionsCount,
      normalizedWeight:
          maxTechniqueCount == 0
              ? 0
              : technique.sessionsCount / maxTechniqueCount,
      applicationLabel: TrainingAggregator.applicationContextLabel(
        skillEntry?.applicationContext,
      ),
      outcomeLabel: TrainingAggregator.techniqueOutcomeLabel(
        skillEntry?.techniqueOutcome,
      ),
    );
  }
}

class _GameMapHighlight {
  final String label;
  final String value;
  final String helper;

  const _GameMapHighlight({
    required this.label,
    required this.value,
    required this.helper,
  });
}

String _categoryLabelForPosition(
  String position,
  List<SkillMatrixCategoryEntry> skillMatrix,
) {
  final positionKey = JiuJitsuTaxonomy.normalizedKey(position);

  for (final category in skillMatrix) {
    for (final technique in category.techniques) {
      final techniquePosition = technique.position;
      if (techniquePosition == null) continue;
      if (JiuJitsuTaxonomy.normalizedKey(techniquePosition) == positionKey) {
        return category.category.displayLabel;
      }
    }
  }

  return JiuJitsuTaxonomy.categoryFor(position: position).displayLabel;
}

SkillMatrixTechniqueEntry? _findSkillEntry(
  List<SkillMatrixCategoryEntry> skillMatrix,
  String position,
  String technique,
) {
  final positionKey = JiuJitsuTaxonomy.normalizedKey(position);
  final techniqueKey = JiuJitsuTaxonomy.normalizedKey(technique);
  SkillMatrixTechniqueEntry? techniqueOnlyMatch;

  for (final category in skillMatrix) {
    for (final entry in category.techniques) {
      if (JiuJitsuTaxonomy.normalizedKey(entry.technique) != techniqueKey) {
        continue;
      }
      final entryPosition = entry.position;
      if (entryPosition != null &&
          JiuJitsuTaxonomy.normalizedKey(entryPosition) == positionKey) {
        return entry;
      }
      techniqueOnlyMatch ??= entry;
    }
  }

  return techniqueOnlyMatch;
}

class _GameMapStats {
  final int positions;
  final int techniques;
  final String? dominantCategory;
  final int classifiedEvidence;

  const _GameMapStats({
    required this.positions,
    required this.techniques,
    required this.dominantCategory,
    required this.classifiedEvidence,
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
    final techniques = skillMatrix.expand((entry) => entry.techniques).toList();

    return _GameMapStats(
      positions: entries.length,
      techniques: techniques.length,
      dominantCategory: _dominantTechnicalRadarAxisLabel(activeCategories),
      classifiedEvidence: techniques
          .where((entry) => entry.category != JiuJitsuSkillCategory.other)
          .fold<int>(0, (sum, entry) => sum + entry.sessionsCount),
    );
  }
}

String? _dominantTechnicalRadarAxisLabel(
  List<SkillMatrixCategoryEntry> activeCategories,
) {
  for (final category in activeCategories) {
    final axis = JiuJitsuTaxonomy.technicalRadarAxisForCategory(
      category.category,
    );
    if (axis != TechnicalRadarAxis.unclassified) return axis.displayLabel;
  }
  return null;
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

class _GameMapTechnicalMapSwitcher extends StatelessWidget {
  final _GameMapViewMode selected;
  final ValueChanged<_GameMapViewMode> onChanged;

  const _GameMapTechnicalMapSwitcher({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final mode in _GameMapViewMode.values)
          _GameMapModeChip(
            label: _modeLabel(mode),
            selected: selected == mode,
            onTap: () => onChanged(mode),
          ),
      ],
    );
  }

  String _modeLabel(_GameMapViewMode mode) {
    switch (mode) {
      case _GameMapViewMode.cluster:
        return 'Visual';
      case _GameMapViewMode.matrix:
        return 'Por posição';
      case _GameMapViewMode.evidence:
        return 'Por eixo';
    }
  }
}

class _GameMapModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GameMapModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurface.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansUI.radiusPill),
            border: Border.all(
              color: selected ? color : cs.onSurface.withValues(alpha: 0.12),
            ),
            color:
                selected
                    ? color.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : cs.onSurface.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameMapTechnicalMapPanel extends StatelessWidget {
  final _GameMapViewMode selectedMode;
  final ValueChanged<_GameMapViewMode> onModeChanged;
  final _GameMapVisualViewModel visualMap;
  final _PositionAxisMatrixViewModel positionAxisMatrix;
  final _EvidenceDistributionViewModel evidenceDistribution;

  const _GameMapTechnicalMapPanel({
    required this.selectedMode,
    required this.onModeChanged,
    required this.visualMap,
    required this.positionAxisMatrix,
    required this.evidenceDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GameMapTechnicalMapSwitcher(
          selected: selectedMode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 12),
        _buildSelectedView(context),
      ],
    );
  }

  Widget _buildSelectedView(BuildContext context) {
    switch (selectedMode) {
      case _GameMapViewMode.cluster:
        return _GameMapVisualClusterCard(viewModel: visualMap);
      case _GameMapViewMode.matrix:
        return _PositionAxisMatrixCard(viewModel: positionAxisMatrix);
      case _GameMapViewMode.evidence:
        return _EvidenceDistributionCard(viewModel: evidenceDistribution);
    }
  }
}

void _showTechnicalEvidenceDetails(
  BuildContext context,
  TechnicalEvidenceSummary item,
) {
  final cs = Theme.of(context).colorScheme;
  final positions = item.positions.take(3).join(', ');
  final contexts = item.contexts.take(3).join(', ');
  final outcomes = item.outcomes.take(3).join(', ');
  final sources = item.sourceTypes.take(3).join(', ');

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.techniqueName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(
                    label: '${item.evidenceCount} evidências',
                    color: cs.secondary,
                  ),
                  if (positions.isNotEmpty)
                    _MiniBadge(label: 'Posição: $positions', color: cs.primary),
                  if (contexts.isNotEmpty)
                    _MiniBadge(
                      label: 'Contexto: $contexts',
                      color: TitansUI.technicalBlue,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _EvidenceDetailLine(
                icon: Icons.calendar_today_outlined,
                label: 'Última prática',
                value: _formatShortDate(item.lastPracticedAt),
              ),
              if (positions.isNotEmpty)
                _EvidenceDetailLine(
                  icon: Icons.place_outlined,
                  label: 'Posições',
                  value: item.positions.join(', '),
                ),
              if (contexts.isNotEmpty)
                _EvidenceDetailLine(
                  icon: Icons.sports_mma_outlined,
                  label: 'Contextos',
                  value: item.contexts.join(', '),
                ),
              if (outcomes.isNotEmpty)
                _EvidenceDetailLine(
                  icon: Icons.check_circle_outline,
                  label: 'Resultados',
                  value: item.outcomes.join(', '),
                ),
              if (sources.isNotEmpty)
                _EvidenceDetailLine(
                  icon: Icons.source_outlined,
                  label: 'Fontes',
                  value: item.sourceTypes.join(', '),
                ),
              const SizedBox(height: 12),
              Text(
                'Dados baseados nos treinos registrados. Sem nota ou desempenho.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showAllTechnicalEvidences(
  BuildContext context,
  List<TechnicalEvidenceSummary> items,
) {
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Todas as evidências técnicas (${items.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _TechnicalEvidencePreviewTile(
                      item: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showTechnicalEvidenceDetails(context, item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
