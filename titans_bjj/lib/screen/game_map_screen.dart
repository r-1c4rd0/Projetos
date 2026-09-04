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

Future<T?> _showGameMapSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;
      final cs = Theme.of(sheetContext).colorScheme;

      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}

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

    final draft = await _showGameMapSheet<_CoachEvaluationDraft>(
      context: context,
      builder:
          (_) => _CoachEvaluationSheet(
            techniques: techniques,
            evaluations: evaluations,
          ),
    );
    if (!mounted || draft == null) return;

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
                  TitansCard(
                    accent: cs.tertiary,
                    child: TitansTechnicalRadar(
                      subtitle: technicalRadar.subtitle,
                      stateLabel: technicalRadar.stateLabel,
                      evidences: technicalRadar.evidences,
                      axisEvidence: technicalRadar.axisEvidence,
                      classifiedEvidenceCount:
                          technicalRadar.classifiedEvidenceCount,
                      awaitingClassificationCount:
                          technicalRadar.awaitingClassificationCount,
                      interactive: true,
                      showMetrics: false,
                      contained: false,
                      enableHolographicMode: true,
                      enablePerspectiveControls: true,
                      initialPerspective: TitansRadarPerspective.live,
                      enableSweep: true,
                      enableHudDetails: true,
                    ),
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
            coachEvaluations: coachEvaluations,
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
  final List<CoachEvaluation> coachEvaluations;

  const _ClientReadingActions({
    required this.visualMap,
    required this.technicalEvidence,
    required this.rtcaEvidence,
    required this.canEditCoachEvaluation,
    required this.onOpenCoachEvaluationSheet,
    required this.onOpenSkills,
    required this.positionAxisMatrix,
    required this.evidenceDistribution,
    required this.coachEvaluations,
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
          onTap:
              () => _showAllTechnicalEvidences(
                context,
                technicalEvidence,
                coachEvaluations,
              ),
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
    _showGameMapSheet<void>(
      context: context,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GameMapSheetHandle(color: cs.onSurface.withValues(alpha: 0.18)),
              const SizedBox(height: 16),
              Text(
                'Mapa visual de posi\u00e7\u00f5es',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _GameMapPositionClusterGraph(viewModel: visualMap),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRepertoireBottomSheet(BuildContext context) {
    _showGameMapSheet<void>(
      context: context,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GameMapSheetHandle(color: cs.onSurface.withValues(alpha: 0.18)),
              const SizedBox(height: 16),
              Text(
                'Repert\u00f3rio registrado',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                rtcaEvidence.subtitle,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.64),
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
                      for (int i = 0; i < rtcaEvidence.items.length; i++) ...[
                        _CompactEvidenceBar(
                          label: rtcaEvidence.items[i].label,
                          count: _extractCount(rtcaEvidence.items[i].value),
                          maxCount: _maxCountForItems(rtcaEvidence.items),
                          color: _colorForIndex(i, sheetContext),
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
        );
      },
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                  onChanged:
                      (value) => setState(() => _applicationLevel = value),
                ),
                const SizedBox(height: 12),
                _CoachLevelDropdown(
                  label: 'Consistência',
                  value: _consistencyLevel,
                  onChanged:
                      (value) => setState(() => _consistencyLevel = value),
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

  _showGameMapSheet<void>(
    context: context,
    builder:
        (sheetContext) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
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
                        const _CompactHeader(title: 'DETALHE DA POSIÇÃO'),
                        const SizedBox(height: 6),
                        Text(
                          node.position,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Fechar',
                    button: true,
                    child: IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
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
              Flexible(
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

void _showTechnicalEvidenceDetails(
  BuildContext context,
  TechnicalEvidenceSummary item,
) {
  final cs = Theme.of(context).colorScheme;
  final positions = item.positions.take(3).join(', ');
  final contexts = item.contexts.take(3).join(', ');
  final outcomes = item.outcomes.take(3).join(', ');
  final sources = item.sourceTypes.take(3).join(', ');

  _showGameMapSheet<void>(
    context: context,
    builder:
        (sheetContext) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GameMapSheetHandle(
                  color: cs.onSurface.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 16),
                Text(
                  item.techniqueName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    sheetContext,
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
                      _MiniBadge(
                        label: 'Posição: $positions',
                        color: cs.primary,
                      ),
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
        ),
  );
}

void _showAllTechnicalEvidences(
  BuildContext context,
  List<TechnicalEvidenceSummary> items,
  List<CoachEvaluation> evaluations,
) {
  final parentContext = context;
  _showGameMapSheet<void>(
    context: context,
    builder:
        (_) => _EvidenceCenterSheet(
          items: items,
          evaluations: evaluations,
          parentContext: parentContext,
        ),
  );
}

class _EvidenceCenterSheet extends StatefulWidget {
  final List<TechnicalEvidenceSummary> items;
  final List<CoachEvaluation> evaluations;
  final BuildContext parentContext;

  const _EvidenceCenterSheet({
    required this.items,
    required this.evaluations,
    required this.parentContext,
  });

  @override
  State<_EvidenceCenterSheet> createState() => _EvidenceCenterSheetState();
}

class _EvidenceCenterSheetState extends State<_EvidenceCenterSheet> {
  TechnicalRadarAxis? _axisFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final evaluatedIds = widget.evaluations.map((e) => e.skillId).toSet();
    final filteredItems =
        widget.items.where((item) {
            if (_axisFilter == null) return true;
            return _axisForTechnicalEvidence(item) == _axisFilter;
          }).toList()
          ..sort(_compareEvidenceItems);
    final totalEvidences = widget.items.fold<int>(
      0,
      (sum, item) => sum + item.evidenceCount,
    );
    final lastEvidence =
        widget.items.isEmpty
            ? null
            : widget.items
                .map((item) => item.lastPracticedAt)
                .reduce((a, b) => a.isAfter(b) ? a : b);
    final axisCounts = _axisEvidenceCounts(widget.items);
    final maxAxisCount = axisCounts.values.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );
    final topPosition = _topEvidencePosition(widget.items);
    final topTechnique =
        widget.items.isEmpty
            ? null
            : widget.items.reduce(
              (a, b) => _compareEvidenceItems(a, b) <= 0 ? a : b,
            );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        _GameMapSheetHandle(color: cs.onSurface.withValues(alpha: 0.18)),
        const SizedBox(height: 16),
        Text(
          'Central de Evidências',
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
              label: '$totalEvidences evidências',
              color: cs.secondary,
            ),
            _MiniBadge(
              label: '${widget.items.length} técnicas',
              color: cs.primary,
            ),
            if (lastEvidence != null)
              _MiniBadge(
                label: 'Última ${_formatShortDate(lastEvidence)}',
                color: TitansUI.actionGold,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _EvidenceAxisFilterChip(
              label: 'Todas',
              selected: _axisFilter == null,
              color: cs.primary,
              onTap: () => setState(() => _axisFilter = null),
            ),
            for (final axis in _evidenceCenterAxes)
              _EvidenceAxisFilterChip(
                label: axis.displayLabel,
                selected: _axisFilter == axis,
                color: _axisColor(context, axis),
                onTap: () => setState(() => _axisFilter = axis),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _EvidenceCenterSummary(
          axisCounts: axisCounts,
          maxAxisCount: maxAxisCount == 0 ? 1 : maxAxisCount,
          topPosition: topPosition,
          topTechnique: topTechnique?.techniqueName,
        ),
        const SizedBox(height: 16),
        if (filteredItems.isEmpty)
          Text(
            'Nenhuma evidência neste filtro.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          for (int i = 0; i < filteredItems.length; i++) ...[
            _EvidenceCenterCard(
              item: filteredItems[i],
              axis: _axisForTechnicalEvidence(filteredItems[i]),
              evaluated: evaluatedIds.contains(filteredItems[i].skillId),
              onTap: () {
                final item = filteredItems[i];
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!widget.parentContext.mounted) return;
                  _showTechnicalEvidenceDetails(widget.parentContext, item);
                });
              },
            ),
            if (i < filteredItems.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _GameMapSheetHandle extends StatelessWidget {
  final Color color;

  const _GameMapSheetHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 30,
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color,
        ),
      ),
    );
  }
}

class _EvidenceAxisFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _EvidenceAxisFilterChip({
    required this.label,
    required this.selected,
    required this.color,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color:
                selected
                    ? color.withValues(alpha: 0.16)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.22),
            border: Border.all(
              color:
                  selected
                      ? color.withValues(alpha: 0.38)
                      : cs.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : cs.onSurface.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceCenterSummary extends StatelessWidget {
  final Map<TechnicalRadarAxis, int> axisCounts;
  final int maxAxisCount;
  final String? topPosition;
  final String? topTechnique;

  const _EvidenceCenterSummary({
    required this.axisCounts,
    required this.maxAxisCount,
    required this.topPosition,
    required this.topTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.14)),
        color: cs.secondary.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final axis in _evidenceCenterAxes) ...[
            _EvidenceCenterAxisBar(
              axis: axis,
              count: axisCounts[axis] ?? 0,
              maxCount: maxAxisCount,
            ),
            if (axis != _evidenceCenterAxes.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: 'Top posição: ${topPosition ?? 'sem dados'}',
                color: cs.primary,
              ),
              _MiniBadge(
                label: 'Top técnica: ${topTechnique ?? 'sem dados'}',
                color: TitansUI.actionGold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCenterAxisBar extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int count;
  final int maxCount;

  const _EvidenceCenterAxisBar({
    required this.axis,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _axisColor(context, axis);
    final fraction = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            axis.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceCenterCard extends StatelessWidget {
  final TechnicalEvidenceSummary item;
  final TechnicalRadarAxis axis;
  final bool evaluated;
  final VoidCallback onTap;

  const _EvidenceCenterCard({
    required this.item,
    required this.axis,
    required this.evaluated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _axisColor(context, axis);
    final position =
        item.positions.isEmpty ? 'Sem posição' : item.positions.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            color: color.withValues(alpha: 0.055),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(label: position, color: cs.primary),
                        _MiniBadge(label: axis.displayLabel, color: color),
                        _MiniBadge(
                          label: '${item.evidenceCount} registros',
                          color: cs.secondary,
                        ),
                        _MiniBadge(
                          label: evaluated ? 'Avaliada' : 'Sem avaliação',
                          color:
                              evaluated
                                  ? TitansUI.successGreen
                                  : cs.onSurface.withValues(alpha: 0.52),
                        ),
                      ],
                    ),
                  ],
                ),
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

const _evidenceCenterAxes = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
];

TechnicalRadarAxis _axisForTechnicalEvidence(TechnicalEvidenceSummary item) {
  if (item.skillId.startsWith('custom.')) {
    return TechnicalRadarAxis.unclassified;
  }
  final identity =
      JiuJitsuTaxonomy.resolveSkillIdentity(item.techniqueName) ??
      JiuJitsuTaxonomy.resolveSkillIdentity(item.normalizedTechniqueName);
  if (identity == null) return TechnicalRadarAxis.unclassified;
  return JiuJitsuTaxonomy.technicalRadarAxisForCategory(identity.category);
}

Map<TechnicalRadarAxis, int> _axisEvidenceCounts(
  List<TechnicalEvidenceSummary> items,
) {
  final counts = <TechnicalRadarAxis, int>{
    for (final axis in _evidenceCenterAxes) axis: 0,
  };
  for (final item in items) {
    final axis = _axisForTechnicalEvidence(item);
    if (!counts.containsKey(axis)) continue;
    counts[axis] = (counts[axis] ?? 0) + item.evidenceCount;
  }
  return counts;
}

String? _topEvidencePosition(List<TechnicalEvidenceSummary> items) {
  final counts = <String, int>{};
  for (final item in items) {
    for (final position in item.positions) {
      counts[position] = (counts[position] ?? 0) + item.evidenceCount;
    }
  }
  if (counts.isEmpty) return null;
  final entries =
      counts.entries.toList()..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
  return entries.first.key;
}

int _compareEvidenceItems(
  TechnicalEvidenceSummary a,
  TechnicalEvidenceSummary b,
) {
  final countCompare = b.evidenceCount.compareTo(a.evidenceCount);
  if (countCompare != 0) return countCompare;
  return b.lastPracticedAt.compareTo(a.lastPracticedAt);
}
