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
import '../widgets/titans_expandable_section.dart';
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
              _SkillsCtaCard(onPressed: () => _openSkillsScreen(actor)),
              const SizedBox(height: 12),
              StreamBuilder<List<CoachEvaluation>>(
                stream: _coachEvaluationsStream,
                builder: (context, evaluationSnapshot) {
                  final coachEvaluationCount = _coachEvaluatedTechniqueCount(
                    evaluationSnapshot.data ?? const <CoachEvaluation>[],
                  );
                  final technicalRadar =
                      _TechnicalRadarPreviewViewModel.fromSummary(
                        radarSummary,
                        coachEvaluationCount: coachEvaluationCount,
                      );
                  return TitansExpandableSection(
                    title: 'Radar de Evidências Técnicas',
                    subtitle:
                        'Distribuição de evidências registradas, sem nota ou desempenho.',
                    initiallyExpanded: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TitansTechnicalRadar(
                          subtitle: technicalRadar.subtitle,
                          stateLabel: technicalRadar.stateLabel,
                          evidences: technicalRadar.evidences,
                          axisEvidence: technicalRadar.axisEvidence,
                          classifiedEvidenceCount:
                              technicalRadar.classifiedEvidenceCount,
                          awaitingClassificationCount:
                              technicalRadar.awaitingClassificationCount,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Evidências Técnicas',
                subtitle:
                    'Registros rastreáveis a partir dos treinos cadastrados.',
                child: _TechnicalEvidencePanel(items: technicalEvidence),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<CoachEvaluation>>(
                stream: _coachEvaluationsStream,
                builder: (context, evaluationSnapshot) {
                  final coachEvaluations =
                      evaluationSnapshot.data ?? const <CoachEvaluation>[];
                  return TitansExpandableSection(
                    title: 'Avaliação do Professor',
                    subtitle:
                        'A avaliação humana complementa as evidências dos treinos.',
                    child: _CoachEvaluationPanel(
                      items: coachEvaluations,
                      techniques: technicalEvidence,
                      canEdit: canEditCoachEvaluation,
                      isLoading:
                          evaluationSnapshot.connectionState ==
                          ConnectionState.waiting,
                      onRegister:
                          actor == null
                              ? null
                              : () => _openCoachEvaluationSheet(
                                actor: actor,
                                techniques: technicalEvidence,
                                evaluations: coachEvaluations,
                              ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Mapa por posições',
                subtitle: visualMap.subtitle,
                initiallyExpanded: true,
                child: _GameMapVisualClusterCard(viewModel: visualMap),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Posição x eixo técnico',
                subtitle: positionAxisMatrix.subtitle,
                initiallyExpanded: true,
                child: _PositionAxisMatrixCard(viewModel: positionAxisMatrix),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Distribuição de evidências',
                subtitle: evidenceDistribution.subtitle,
                initiallyExpanded: true,
                child: _EvidenceDistributionCard(
                  viewModel: evidenceDistribution,
                ),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Repertório registrado',
                subtitle: rtcaEvidence.subtitle,
                child: _RtcaEvidencePanel(viewModel: rtcaEvidence),
              ),
            ],
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
          const _CompactHeader(title: 'RESUMO DO GAME MAP'),
          const SizedBox(height: 12),

          TitansCompactMetricGrid(
            fourColumnMinWidth: 560,
            spacing: 10,
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
                color: cs.primary,
              ),
              _MetricPill(
                label: 'CLASSIFICADAS',
                value: stats.classifiedEvidence.toString(),
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.dominantCategory == null
                ? 'Aguardando registros técnicos para montar a visão do jogo.'
                : 'Eixo predominante: ${stats.dominantCategory}. ${stats.techniques} relações técnicas em ${stats.positions} posições mapeadas.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
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
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 156),
      child: TitansCompactMetricCard(label: label, value: value, color: color),
    );
  }
}

class _SkillsCtaCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _SkillsCtaCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.primary,
      padding: const EdgeInsets.all(14),
      onTap: onPressed,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.psychology_alt_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ver repertório técnico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Skills, posições e categorias em uma tela dedicada.',
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
          Icon(Icons.arrow_forward_rounded, color: cs.primary),
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

    return _VisualCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'AVALIAÇÃO DO PROFESSOR'),
          const SizedBox(height: 12),
          Text(
            'Esta avaliação complementa as evidências dos treinos.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const TitansSkeletonCard(lines: 2)
          else if (items.isEmpty)
            const TitansEmptyState(
              icon: Icons.rate_review_outlined,
              title: 'Nenhuma avaliação registrada ainda.',
              message: 'Avaliações do professor ainda não registradas.',
              compact: true,
            )
          else
            Column(
              children: [
                for (final item in items.take(6))
                  _CoachEvaluationCard(
                    evaluation: item,
                    techniqueName: techniqueNames[item.skillId] ?? item.skillId,
                  ),
              ],
            ),
          if (canEdit) ...[
            const SizedBox(height: 12),
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
                ),
              ),
          ],
        ],
      ),
    );
  }
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
    final levels = [
      _evaluationLevelText('Conhecimento', evaluation.knowledgeLevel),
      _evaluationLevelText('Drill', evaluation.drillLevel),
      _evaluationLevelText('Aplicação', evaluation.applicationLevel),
      _evaluationLevelText('Consistência', evaluation.consistencyLevel),
    ].whereType<String>().join(' - ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
        color: cs.primary.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  techniqueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (evaluation.needsReview)
                _MiniBadge(label: 'Precisa revisar', color: TitansUI.alertRed),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Avaliação humana registrada pelo professor.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (levels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(levels, style: const TextStyle(fontSize: 12)),
          ],
          if ((evaluation.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              evaluation.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if ((evaluation.recommendation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              evaluation.recommendation!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
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

String? _evaluationLevelText(String label, CoachEvaluationLevel? level) {
  if (level == null) return null;
  return '$label: ${_coachLevelLabel(level)}';
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

  const _TechnicalEvidencePanel({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'EVIDÊNCIAS TÉCNICAS'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const TitansEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Evidências encontradas',
              message: 'Ainda não há evidências técnicas suficientes.',
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                final visibleItems = items.take(12).toList();
                final hiddenItems = items.length - visibleItems.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in visibleItems)
                          SizedBox(
                            width: cardWidth,
                            child: _TechnicalEvidenceCard(item: item),
                          ),
                      ],
                    ),
                    if (hiddenItems > 0) ...[
                      const SizedBox(height: 12),
                      _MiniBadge(
                        label: '+$hiddenItems registros agrupados',
                        color: cs.onSurface.withValues(alpha: 0.58),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TechnicalEvidenceCard extends StatelessWidget {
  final TechnicalEvidenceSummary item;

  const _TechnicalEvidenceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positions = item.positions.take(2).join(' - ');
    final contexts = item.contexts.take(2).join(' - ');
    final outcomes = item.outcomes.take(2).join(' - ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.22)),
        color: cs.secondary.withValues(alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.techniqueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _MiniBadge(
                label: '${item.evidenceCount} evidencias',
                color: cs.secondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EvidenceDetailLine(
            icon: Icons.calendar_today_outlined,
            label: 'Última prática',
            value: _formatShortDate(item.lastPracticedAt),
          ),
          if (positions.isNotEmpty)
            _EvidenceDetailLine(
              icon: Icons.place_outlined,
              label: 'Posição',
              value: positions,
            ),
          if (contexts.isNotEmpty)
            _EvidenceDetailLine(
              icon: Icons.sports_mma_outlined,
              label: 'Contexto',
              value: contexts,
            ),
          if (outcomes.isNotEmpty)
            _EvidenceDetailLine(
              icon: Icons.check_circle_outline,
              label: 'Resultado registrado',
              value: outcomes,
            ),
        ],
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
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'MAPA T\u00c9CNICO VISUAL'),
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
            const SizedBox(height: 14),
            _GameMapPositionClusterGraph(viewModel: viewModel),
          ],
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
                    ? ((width - 10) / 2).clamp(132.0, 178.0)
                    : width >= 720
                    ? ((width - 24) / 3).clamp(172.0, 240.0)
                    : ((width - 12) / 2).clamp(150.0, 220.0))
                .toDouble();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.10),
                cs.secondary.withValues(alpha: 0.06),
                cs.surfaceContainerHighest.withValues(alpha: 0.12),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: 0.12),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.account_tree_outlined,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toque em uma posi\u00e7\u00e3o para abrir as t\u00e9cnicas e evid\u00eancias vinculadas.',
                          maxLines: isCompact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.66),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: isCompact ? 10 : 12,
                    runSpacing: isCompact ? 10 : 12,
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

    return Tooltip(
      message: highlight.helper,
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

    return Tooltip(
      message:
          '${node.recurrenceCount} registros nesta posi\u00e7\u00e3o; toque para detalhes.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showGameMapPositionDetail(context, node),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08 + (weight * 0.06)),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
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
                    height: 6,
                    width: double.infinity,
                    color: cs.onSurface.withValues(alpha: 0.08),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: weight,
                      child: Container(color: accent.withValues(alpha: 0.78)),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${node.techniques.length} t\u00e9cnicas vinculadas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontSize: 11,
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
    final size = 18.0 + (weight * 12.0);

    return Container(
      width: 32,
      height: 32,
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
              const SizedBox(height: 14),
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

    return Tooltip(
      message: details.join(' - '),
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
          const _CompactHeader(title: 'EVID\u00caNCIAS POR POSI\u00c7\u00c3O'),
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
      padding: const EdgeInsets.all(12),
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
                    : cs.surfaceContainerHighest.withValues(alpha: 0.12),
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
                  width: 42,
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
              const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 10),
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
          const _CompactHeader(
            title: 'DISTRIBUI\u00c7\u00c3O DE EVID\u00caNCIAS',
          ),
          const SizedBox(height: 8),
          Text(
            'Registros por eixo e posi\u00e7\u00e3o',
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
              title: 'Sem distribui\u00e7\u00e3o registrada',
              message:
                  'Registre posi\u00e7\u00f5es e t\u00e9cnicas nos treinos para visualizar a distribui\u00e7\u00e3o de evid\u00eancias.',
              compact: true,
            )
          else ...[
            _EvidenceDistributionGroup(
              title: 'Registros por eixo',
              items: viewModel.axisItems,
            ),
            const SizedBox(height: 14),
            _EvidenceDistributionGroup(
              title: 'Evid\u00eancias por posi\u00e7\u00e3o',
              items: viewModel.positionItems,
            ),
          ],
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
                : cs.surfaceContainerHighest.withValues(alpha: 0.12),
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

    return _VisualCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'REPERTÓRIO REGISTRADO'),
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
          if (viewModel.items.isEmpty)
            TitansEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Painel sem evid\u00eancias',
              message: viewModel.emptyStateLabel,
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    constraints.maxWidth >= 720
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in viewModel.items)
                      SizedBox(
                        width: cardWidth,
                        child: _RtcaEvidenceCard(item: item),
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

class _RtcaEvidenceCard extends StatelessWidget {
  final _RtcaEvidenceItem item;

  const _RtcaEvidenceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: item.helper,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
          color: cs.primary.withValues(alpha: 0.07),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
                color: cs.primary.withValues(alpha: 0.1),
              ),
              child: Text(
                item.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MiniBadge(label: item.statusLabel, color: cs.secondary),
                  const SizedBox(height: 6),
                  Text(
                    item.helper,
                    maxLines: 2,
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
          'Distribuição de recorrência, técnicas, consistência e aplicação.',
      items: [
        _RtcaEvidenceItem(
          code: '1',
          label: 'Recorr\u00eancia',
          value: _techniquePlural(recurring, 'recorrente'),
          helper: 'T\u00e9cnicas com registros repetidos na Skill Matrix.',
          icon: Icons.repeat_outlined,
          statusLabel: _statusForCount(recurring),
        ),
        _RtcaEvidenceItem(
          code: '2',
          label: 'T\u00e9cnicas registradas',
          value: TrainingAggregator.techniqueCountLabel(techniques.length),
          helper: 'T\u00e9cnicas presentes nos treinos registrados.',
          icon: Icons.sports_mma_outlined,
          statusLabel: _statusForCount(techniques.length),
        ),
        _RtcaEvidenceItem(
          code: '3',
          label: 'Consist\u00eancia',
          value: _dayPlural(trainingDays),
          helper: 'Dias com treino registrado nos \u00faltimos 84 dias.',
          icon: Icons.calendar_month_outlined,
          statusLabel: _statusForCount(trainingDays),
        ),
        _RtcaEvidenceItem(
          code: '4',
          label: 'Aplica\u00e7\u00e3o registrada',
          value: _applicationPlural(applications),
          helper:
              'Treinos com contexto de aplica\u00e7\u00e3o e resultado registrados.',
          icon: Icons.fact_check_outlined,
          statusLabel: _statusForCount(applications),
        ),
      ],
      emptyStateLabel:
          'Registre treinos para formar o repertório técnico com dados reais.',
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
    if (count == 1) return '1 t\u00e9cnica $suffix';
    return '$count t\u00e9cnicas ${suffix}s';
  }

  static String _dayPlural(int count) {
    if (count == 1) return '1 dia com treino';
    return '$count dias com treino';
  }

  static String _applicationPlural(int count) {
    if (count == 1) return '1 aplica\u00e7\u00e3o registrada';
    return '$count aplica\u00e7\u00f5es registradas';
  }

  static String _statusForCount(int count) {
    if (count <= 0) return 'Sem registros suficientes';
    if (count < 3) return 'Em constru\u00e7\u00e3o';
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
        title: 'Posi\u00e7\u00f5es e t\u00e9cnicas registradas',
        subtitle: 'Baseado nos treinos registrados.',
        nodes: [],
        highlights: [],
        emptyStateLabel:
            'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar um mapa visual seguro.',
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
      title: 'Posi\u00e7\u00f5es e t\u00e9cnicas registradas',
      subtitle:
          'Clusters por recorr\u00eancia nos debriefs; peso visual n\u00e3o indica desempenho.',
      nodes: nodes,
      highlights: [
        _GameMapHighlight(
          label: 'Posi\u00e7\u00f5es',
          value: entries.length.toString(),
          helper: 'Total de posi\u00e7\u00f5es com t\u00e9cnicas registradas.',
        ),
        _GameMapHighlight(
          label: 'T\u00e9cnicas associadas',
          value: techniquesCount.toString(),
          helper:
              'T\u00e9cnicas vis\u00edveis nos clusters desta se\u00e7\u00e3o.',
        ),
        if (topNode != null)
          _GameMapHighlight(
            label: 'Mais registrada',
            value: topNode.position,
            helper: 'Posi\u00e7\u00e3o com mais registros neste mapa visual.',
          ),
      ],
      emptyStateLabel:
          'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar um mapa visual seguro.',
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
