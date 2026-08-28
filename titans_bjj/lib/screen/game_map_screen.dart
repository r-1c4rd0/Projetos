import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';
import '../widgets/charts/titans_technical_radar.dart';
import '../widgets/titans_expandable_section.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

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
          final skillSummary = _SkillMatrixSummaryViewModel.from(skillMatrix);
          final visualMap = _GameMapVisualViewModel.from(entries, skillMatrix);
          final rtcaEvidence = _RtcaEvidenceViewModel.from(
            sessions: sessions,
            entries: entries,
            skillMatrix: skillMatrix,
          );
          final skillEvidences = TrainingAggregator.buildSkillEvidences(
            sessions,
          );
          final technicalRadar =
              _TechnicalRadarPreviewViewModel.fromSkillEvidences(
                skillEvidences,
              );
          final technicalEvidence = TrainingAggregator.buildTechnicalEvidence(
            sessions,
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
              _GameMapSummaryCard(stats: stats),
              const SizedBox(height: 12),
              StreamBuilder<List<CoachEvaluation>>(
                stream: _coachEvaluationsStream,
                builder: (context, evaluationSnapshot) {
                  final coachEvaluationCount = _coachEvaluatedTechniqueCount(
                    evaluationSnapshot.data ?? const <CoachEvaluation>[],
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
                        if (coachEvaluationCount > 0) ...[
                          const SizedBox(height: 8),
                          _CoachEvaluationRadarCounter(
                            evaluatedTechniqueCount: coachEvaluationCount,
                          ),
                        ],
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
                title: 'Evidências R/T/C/A',
                subtitle: rtcaEvidence.subtitle,
                child: _RtcaEvidencePanel(viewModel: rtcaEvidence),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Resumo da Skill Matrix',
                subtitle: skillSummary.subtitle,
                initiallyExpanded: true,
                child: _SkillMatrixVisualSummaryCard(viewModel: skillSummary),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Explorar técnicas',
                subtitle: _explorerSectionSummary(entries),
                initiallyExpanded: true,
                child: _GameMapExplorer(
                  entries: entries,
                  categories: skillMatrix,
                ),
              ),
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
                label: 'TÉCNICAS',
                value: stats.techniques.toString(),
                color: cs.primary,
              ),
              _MetricPill(
                label: 'RECORRENTES',
                value: stats.recurring.toString(),
                color: Colors.lightGreenAccent,
              ),
              _MetricPill(
                label: 'APLICAÇÕES +',
                value: stats.positiveApplications.toString(),
                color: Colors.amber,
              ),
              _MetricPill(
                label: 'SEM MEDIÇÃO',
                value: stats.unmeasured.toString(),
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats.dominantCategory == null
                ? 'Aguardando registros técnicos para montar o mapa.'
                : 'Categoria mais recorrente: ${stats.dominantCategory}. ${stats.positions} posições mapeadas nos debriefs registrados.',
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
      accent: cs.tertiary,
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
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.20)),
        color: cs.tertiary.withValues(alpha: 0.06),
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
                _MiniBadge(label: 'Precisa revisar', color: cs.tertiary),
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
      accent: cs.tertiary,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final node in viewModel.nodes)
                      SizedBox(
                        width: cardWidth,
                        child: _GameMapPositionCluster(node: node),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
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
        color: cs.tertiary,
      ),
    );
  }
}

class _GameMapPositionCluster extends StatelessWidget {
  final _GameMapPositionNode node;

  const _GameMapPositionCluster({required this.node});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weight = node.normalizedWeight.clamp(0.0, 1.0);

    return Tooltip(
      message:
          '${node.recurrenceCount} registros nesta posi\u00e7\u00e3o; peso visual relativo.',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.24)),
          color: cs.tertiary.withValues(alpha: 0.07 + (weight * 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    node.position,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MiniBadge(label: node.countLabel, color: cs.tertiary),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniBadge(label: node.categoryLabel, color: cs.primary),
                _MiniBadge(
                  label: '${(weight * 100).round()}% recorr\u00eancia relativa',
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 7,
                width: double.infinity,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: weight,
                  child: Container(color: cs.tertiary.withValues(alpha: 0.78)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final technique in node.techniques)
                  _GameMapTechniqueLinkChip(link: technique),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
          const _CompactHeader(title: 'EVID\u00caNCIAS R/T/C/A'),
          const SizedBox(height: 8),
          Text(
            viewModel.title,
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

class _SkillMatrixVisualSummaryCard extends StatelessWidget {
  final _SkillMatrixSummaryViewModel viewModel;

  const _SkillMatrixVisualSummaryCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _VisualCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CompactHeader(title: 'RESUMO DA SKILL MATRIX'),
          const SizedBox(height: 8),
          Text(
            viewModel.title,
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
          if (viewModel.stats.isEmpty)
            TitansEmptyState(
              icon: Icons.grid_view_outlined,
              title: 'Resumo t\u00e9cnico vazio',
              message: viewModel.emptyStateLabel,
              compact: true,
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final stat in viewModel.stats)
                  _SkillMatrixSummaryStatPill(stat: stat),
              ],
            ),
            if (viewModel.highlights.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final highlight in viewModel.highlights)
                    _SkillMatrixSummaryHighlightChip(highlight: highlight),
                ],
              ),
            ],
            if (viewModel.bars.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final bar in viewModel.bars) ...[
                _SkillMatrixSummaryBarRow(bar: bar),
                if (bar != viewModel.bars.last) const SizedBox(height: 10),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _SkillMatrixSummaryStatPill extends StatelessWidget {
  final _SkillMatrixSummaryStat stat;

  const _SkillMatrixSummaryStatPill({required this.stat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _skillSummaryColor(cs, stat.helper);

    return Tooltip(
      message: stat.helper,
      child: Container(
        constraints: const BoxConstraints(minWidth: 112, maxWidth: 168),
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
              stat.label,
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
              stat.value,
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
      ),
    );
  }
}

class _SkillMatrixSummaryHighlightChip extends StatelessWidget {
  final _SkillMatrixSummaryHighlight highlight;

  const _SkillMatrixSummaryHighlightChip({required this.highlight});

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

class _SkillMatrixSummaryBarRow extends StatelessWidget {
  final _SkillMatrixSummaryBar bar;

  const _SkillMatrixSummaryBarRow({required this.bar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _skillSummaryBarColor(cs, bar.kind);

    return Tooltip(
      message: bar.helper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bar.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                bar.valueLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              width: double.infinity,
              color: cs.onSurface.withValues(alpha: 0.08),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: bar.normalizedValue.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _skillSummaryColor(ColorScheme cs, String helper) {
  if (helper.contains('recorr')) return Colors.lightGreenAccent;
  if (helper.contains('Aplica')) return cs.secondary;
  return cs.primary;
}

Color _skillSummaryBarColor(ColorScheme cs, String kind) {
  switch (kind) {
    case 'category':
      return cs.primary;
    case 'technique':
      return cs.secondary;
    default:
      return Colors.lightGreenAccent;
  }
}

String _explorerSectionSummary(List<GameMapEntry> entries) {
  final techniquesCount = entries.fold<int>(
    0,
    (sum, entry) => sum + entry.techniques.length,
  );
  final positionsLabel = entries.length == 1 ? 'posição' : 'posições';
  final techniquesLabel = techniquesCount == 1 ? 'técnica' : 'técnicas';
  return '${entries.length} $positionsLabel • $techniquesCount $techniquesLabel';
}

enum _ExplorerMode { position, category }

class _GameMapExplorer extends StatefulWidget {
  final List<GameMapEntry> entries;
  final List<SkillMatrixCategoryEntry> categories;

  const _GameMapExplorer({required this.entries, required this.categories});

  @override
  State<_GameMapExplorer> createState() => _GameMapExplorerState();
}

class _GameMapExplorerState extends State<_GameMapExplorer> {
  _ExplorerMode _mode = _ExplorerMode.position;
  int? _openPositionIndex;
  int? _openCategoryIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final techniquesCount = widget.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.techniques.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniBadge(
              label: '${widget.entries.length} posições',
              color: cs.primary,
            ),
            _MiniBadge(label: '$techniquesCount técnicas', color: cs.secondary),
          ],
        ),
        const SizedBox(height: 12),
        _ExplorerModeSelector(
          mode: _mode,
          onChanged: (mode) {
            setState(() {
              _mode = mode;
              _openPositionIndex = null;
              _openCategoryIndex = null;
            });
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child:
              _mode == _ExplorerMode.position
                  ? _PositionExplorerList(
                    key: const ValueKey('position-explorer'),
                    entries: widget.entries,
                    openIndex: _openPositionIndex,
                    onToggle: (index) {
                      setState(() {
                        _openPositionIndex =
                            _openPositionIndex == index ? null : index;
                      });
                    },
                  )
                  : _CategoryExplorerList(
                    key: const ValueKey('category-explorer'),
                    categories: widget.categories,
                    openIndex: _openCategoryIndex,
                    onToggle: (index) {
                      setState(() {
                        _openCategoryIndex =
                            _openCategoryIndex == index ? null : index;
                      });
                    },
                  ),
        ),
      ],
    );
  }
}

class _ExplorerModeSelector extends StatelessWidget {
  final _ExplorerMode mode;
  final ValueChanged<_ExplorerMode> onChanged;

  const _ExplorerModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget option(_ExplorerMode value, String label, IconData icon) {
      final selected = mode == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    selected
                        ? cs.primary.withValues(alpha: 0.42)
                        : cs.onSurface.withValues(alpha: 0.1),
              ),
              color:
                  selected
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? cs.primary : cs.onSurface,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? cs.primary : cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(_ExplorerMode.position, 'Por posição', Icons.place_outlined),
        const SizedBox(width: 8),
        option(
          _ExplorerMode.category,
          'Por categoria',
          Icons.category_outlined,
        ),
      ],
    );
  }
}

class _PositionExplorerList extends StatelessWidget {
  final List<GameMapEntry> entries;
  final int? openIndex;
  final ValueChanged<int> onToggle;

  const _PositionExplorerList({
    super.key,
    required this.entries,
    required this.openIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _EmptyGameMapCard();

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _ExplorerPositionRow(
            entry: entries[i],
            expanded: openIndex == i,
            onTap: () => onToggle(i),
          ),
          if (i != entries.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CategoryExplorerList extends StatelessWidget {
  final List<SkillMatrixCategoryEntry> categories;
  final int? openIndex;
  final ValueChanged<int> onToggle;

  const _CategoryExplorerList({
    super.key,
    required this.categories,
    required this.openIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const TitansEmptyState(
        icon: Icons.grid_view_outlined,
        title: 'Categorias vazias',
        message: 'Registre técnicas nos debriefs para explorar por categoria.',
        compact: true,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _ExplorerCategoryRow(
            entry: categories[i],
            expanded: openIndex == i,
            onTap: () => onToggle(i),
          ),
          if (i != categories.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExplorerPositionRow extends StatelessWidget {
  final GameMapEntry entry;
  final bool expanded;
  final VoidCallback onTap;

  const _ExplorerPositionRow({
    required this.entry,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = entry.techniques
        .take(3)
        .map((technique) => technique.technique)
        .join(' • ');
    final metadata = <String>[
      '${entry.techniques.length} técnicas',
      TrainingAggregator.sessionCountLabel(entry.sessionsCount),
      'última ${_formatShortDate(entry.lastTrainedAt)}',
    ].join(' • ');

    return _ExplorerRowShell(
      title: entry.position,
      metadata: metadata,
      preview: preview.isEmpty ? 'Sem técnicas registradas' : preview,
      expanded: expanded,
      onTap: onTap,
      accent: cs.secondary,
      child: _GameMapPositionCard(entry: entry),
    );
  }
}

class _ExplorerCategoryRow extends StatelessWidget {
  final SkillMatrixCategoryEntry entry;
  final bool expanded;
  final VoidCallback onTap;

  const _ExplorerCategoryRow({
    required this.entry,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = entry.averageIntensity;
    final metadata = <String>[
      _skillCategorySubtitle(entry),
      if (intensity != null) 'intensidade ${intensity.toStringAsFixed(1)}/5',
    ].join(' • ');
    final preview = entry.techniques
        .take(3)
        .map((technique) => technique.technique)
        .join(' • ');

    return _ExplorerRowShell(
      title: entry.category.displayLabel,
      metadata: metadata,
      preview: preview.isEmpty ? 'Sem técnicas registradas' : preview,
      expanded: expanded,
      onTap: onTap,
      accent: cs.primary,
      child: _SkillMatrixCategoryBlock(entry: entry),
    );
  }
}

class _ExplorerRowShell extends StatelessWidget {
  final String title;
  final String metadata;
  final String preview;
  final bool expanded;
  final VoidCallback onTap;
  final Color accent;
  final Widget child;

  const _ExplorerRowShell({
    required this.title,
    required this.metadata,
    required this.preview,
    required this.expanded,
    required this.onTap,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.62),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

String _skillCategorySubtitle(SkillMatrixCategoryEntry entry) {
  final techniques =
      entry.techniquesCount == 1
          ? '${TrainingAggregator.techniqueCountLabel(entry.techniquesCount)} registrada'
          : '${TrainingAggregator.techniqueCountLabel(entry.techniquesCount)} registradas';
  return '$techniques • ${entry.consistencyCount} recorrentes';
}

class _SkillMatrixCategoryBlock extends StatelessWidget {
  final SkillMatrixCategoryEntry entry;

  const _SkillMatrixCategoryBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleTechniques = entry.techniques.take(5).toList();
    final hiddenTechniques = entry.techniques.length - visibleTechniques.length;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final technique in visibleTechniques) ...[
            _SkillMatrixTechniqueRow(entry: technique),
            if (technique != visibleTechniques.last) const SizedBox(height: 8),
          ],
          if (hiddenTechniques > 0) ...[
            const SizedBox(height: 8),
            _MiniBadge(
              label: '+$hiddenTechniques técnicas nesta categoria',
              color: cs.onSurface.withValues(alpha: 0.58),
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
    final positive = _hasPositiveApplicationEvidence(entry);
    final unmeasured = entry.application != true;
    final accent = entry.consistent ? cs.secondary : cs.primary;
    final metadata = <String>[
      if ((entry.position ?? '').trim().isNotEmpty) entry.position!.trim(),
      TrainingAggregator.sessionCountLabel(entry.sessionsCount),
      'última ${_formatShortDate(entry.lastTrainedAt)}',
      if (entry.averageIntensity != null)
        'intensidade ${entry.averageIntensity!.toStringAsFixed(1)}/5',
    ].join(' • ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        color: accent.withValues(alpha: 0.05),
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
              const SizedBox(height: 4),
              Text(
                metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (entry.consistent)
                    _MiniBadge(label: 'recorrente', color: cs.secondary),
                  if (positive)
                    const _MiniBadge(
                      label: 'resultado positivo',
                      color: Colors.lightGreenAccent,
                    ),
                  if (unmeasured)
                    _MiniBadge(
                      label: 'sem medição',
                      color: cs.onSurface.withValues(alpha: 0.52),
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
              children: [details, const SizedBox(height: 8), levels],
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
  const _EmptyGameMapCard();

  @override
  Widget build(BuildContext context) {
    return const TitansEmptyState(
      icon: Icons.account_tree_outlined,
      title: 'Game Map vazio',
      message:
          'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para montar o mapa.',
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
    final visibleTechniques = entry.techniques.take(6).toList();
    final hiddenTechniques = entry.techniques.length - visibleTechniques.length;
    final metadata = <String>[
      TrainingAggregator.sessionCountLabel(entry.sessionsCount),
      'última ${_formatShortDate(entry.lastTrainedAt)}',
      if (intensity != null) 'intensidade ${intensity.toStringAsFixed(1)}/5',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metadata,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.64),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final technique in visibleTechniques)
              _TechniqueChip(
                label: technique.technique,
                count: technique.sessionsCount,
              ),
            if (hiddenTechniques > 0)
              _MiniBadge(
                label: '+$hiddenTechniques técnicas',
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
          ],
        ),
        if (success != null || difficulty != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (success != null)
                _MiniBadge(
                  label: 'resultado positivo: $success',
                  color: Colors.lightGreenAccent,
                ),
              if (difficulty != null)
                _MiniBadge(label: 'atenção: $difficulty', color: cs.error),
            ],
          ),
        ],
      ],
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
          description:
              applicationMeasured
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
    if (!applicationMeasured) {
      return 'Aplica\u00e7\u00e3o ainda n\u00e3o medida';
    }
    final outcome =
        TrainingAggregator.techniqueOutcomeLabel(techniqueOutcome) ??
        'Aplica\u00e7\u00e3o medida';
    final context = TrainingAggregator.applicationContextLabel(
      applicationContext,
    );
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
    final alpha =
        neutral
            ? 0.42
            : active
            ? 0.9
            : 0.56;

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

  factory _TechnicalRadarPreviewViewModel.fromSkillEvidences(
    List<SkillEvidence> skillEvidences,
  ) {
    final axisEvidence = <TechnicalRadarAxis, int>{
      for (final axis in _technicalRadarAxisOrder) axis: 0,
    };
    final seenBySource = <String>{};
    final techniqueIds = <String>{};

    var classified = 0;
    var unclassified = 0;

    for (final evidence in skillEvidences) {
      final sourceKey =
          evidence.sourceId ??
          evidence.practicedAt.microsecondsSinceEpoch.toString();
      final dedupeKey = '${evidence.sourceType}:$sourceKey:${evidence.skillId}';
      if (!seenBySource.add(dedupeKey)) continue;

      techniqueIds.add(evidence.skillId);
      final axis = _technicalRadarAxisForEvidence(evidence);
      if (axis == TechnicalRadarAxis.unclassified) {
        unclassified += 1;
        continue;
      }

      classified += 1;
      axisEvidence[axis] = (axisEvidence[axis] ?? 0) + 1;
    }

    final topAxis = _topTechnicalRadarAxis(axisEvidence);
    final stateLabel =
        classified < 3
            ? 'Perfil técnico em formação'
            : 'Evidências técnicas distribuídas por eixo';
    final topAxisLabel =
        topAxis == null
            ? 'Em formação'
            : '${topAxis.displayLabel} (${axisEvidence[topAxis]} evidências)';

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
          value: techniqueIds.length.toString(),
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
      ],
    );
  }
}

class _CoachEvaluationRadarCounter extends StatelessWidget {
  final int evaluatedTechniqueCount;

  const _CoachEvaluationRadarCounter({required this.evaluatedTechniqueCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label =
        evaluatedTechniqueCount == 1
            ? '1 técnica com avaliação do professor'
            : '$evaluatedTechniqueCount técnicas com avaliação do professor';

    return _VisualCard(
      accent: cs.tertiary,
      child: Row(
        children: [
          Icon(Icons.rate_review_outlined, color: cs.tertiary, size: 18),
          const SizedBox(width: 8),
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
        ],
      ),
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

TechnicalRadarAxis _technicalRadarAxisForEvidence(SkillEvidence evidence) {
  if (evidence.skillId.startsWith('custom.')) {
    return TechnicalRadarAxis.unclassified;
  }
  return JiuJitsuTaxonomy.technicalRadarAxisForCategory(evidence.category);
}

const _technicalRadarAxisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
];

TechnicalRadarAxis? _topTechnicalRadarAxis(
  Map<TechnicalRadarAxis, int> axisEvidence,
) {
  TechnicalRadarAxis? selected;
  var selectedValue = 0;

  for (final axis in _technicalRadarAxisOrder) {
    final value = axisEvidence[axis] ?? 0;
    if (value > selectedValue) {
      selected = axis;
      selectedValue = value;
    }
  }

  return selectedValue > 0 ? selected : null;
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
        sessions.where((session) {
          return TrainingSession.isApplicationContextMeasured(
                session.applicationContext,
              ) &&
              TrainingSession.isTechniqueOutcomeUseful(
                session.techniqueOutcome,
              );
        }).length;

    return _RtcaEvidenceViewModel(
      title: 'Painel R/T/C/A',
      subtitle:
          'Evid\u00eancias dos treinos registrados, sem compara\u00e7\u00e3o entre atletas.',
      items: [
        _RtcaEvidenceItem(
          code: 'R',
          label: 'Recorr\u00eancia',
          value: _techniquePlural(recurring, 'recorrente'),
          helper: 'T\u00e9cnicas com registros repetidos na Skill Matrix.',
          icon: Icons.repeat_outlined,
          statusLabel: _statusForCount(recurring),
        ),
        _RtcaEvidenceItem(
          code: 'T',
          label: 'T\u00e9cnicas registradas',
          value: TrainingAggregator.techniqueCountLabel(techniques.length),
          helper: 'T\u00e9cnicas presentes nos treinos registrados.',
          icon: Icons.sports_mma_outlined,
          statusLabel: _statusForCount(techniques.length),
        ),
        _RtcaEvidenceItem(
          code: 'C',
          label: 'Consist\u00eancia',
          value: _dayPlural(trainingDays),
          helper: 'Dias com treino registrado nos \u00faltimos 84 dias.',
          icon: Icons.calendar_month_outlined,
          statusLabel: _statusForCount(trainingDays),
        ),
        _RtcaEvidenceItem(
          code: 'A',
          label: 'Aplica\u00e7\u00e3o registrada',
          value: _applicationPlural(applications),
          helper:
              'Treinos com contexto de aplica\u00e7\u00e3o e resultado registrados.',
          icon: Icons.fact_check_outlined,
          statusLabel: _statusForCount(applications),
        ),
      ],
      emptyStateLabel:
          'Registre treinos para preencher evid\u00eancias R/T/C/A com dados reais.',
    );
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
  final int recurring;
  final int positiveApplications;
  final int unmeasured;
  final String? dominantCategory;
  final double? averageIntensity;

  const _GameMapStats({
    required this.positions,
    required this.techniques,
    required this.recurring,
    required this.positiveApplications,
    required this.unmeasured,
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
    final techniques = skillMatrix.expand((entry) => entry.techniques).toList();

    return _GameMapStats(
      positions: entries.length,
      techniques: techniques.length,
      recurring: techniques.where((entry) => entry.consistent).length,
      positiveApplications:
          techniques.where(_hasPositiveApplicationEvidence).length,
      unmeasured: techniques.where((entry) => entry.application != true).length,
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

bool _hasPositiveApplicationEvidence(SkillMatrixTechniqueEntry entry) {
  final outcome = TrainingAggregator.techniqueOutcomeLabel(
    entry.techniqueOutcome,
  );
  return entry.application == true &&
      (outcome == 'Funcionou' || outcome == 'Quase funcionou');
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

class _SkillMatrixSummaryViewModel {
  final String title;
  final String subtitle;
  final List<_SkillMatrixSummaryStat> stats;
  final List<_SkillMatrixSummaryHighlight> highlights;
  final List<_SkillMatrixSummaryBar> bars;
  final String emptyStateLabel;

  const _SkillMatrixSummaryViewModel({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.highlights,
    required this.bars,
    required this.emptyStateLabel,
  });

  factory _SkillMatrixSummaryViewModel.from(
    List<SkillMatrixCategoryEntry> entries,
  ) {
    final techniques = entries.expand((entry) => entry.techniques).toList();
    if (techniques.isEmpty) {
      return const _SkillMatrixSummaryViewModel(
        title: 'Resumo t\u00e9cnico',
        subtitle: 'Baseado nas t\u00e9cnicas registradas nos debriefs.',
        stats: [],
        highlights: [],
        bars: [],
        emptyStateLabel:
            'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar um resumo seguro.',
      );
    }

    final recurringCount = techniques.where((entry) => entry.consistent).length;
    final measuredApplications =
        techniques.where((entry) => entry.application == true).length;
    final topCategories = List<SkillMatrixCategoryEntry>.from(entries)
      ..sort((a, b) {
        final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
        if (sessionsCompare != 0) return sessionsCompare;
        return b.techniquesCount.compareTo(a.techniquesCount);
      });
    final topTechniques = List<SkillMatrixTechniqueEntry>.from(techniques)
      ..sort((a, b) {
        final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
        if (sessionsCompare != 0) return sessionsCompare;
        return b.lastTrainedAt.compareTo(a.lastTrainedAt);
      });

    final bars = <_SkillMatrixSummaryBar>[
      ..._categoryBars(topCategories.take(3).toList()),
      ..._techniqueBars(topTechniques.take(3).toList()),
    ];
    final highlights = <_SkillMatrixSummaryHighlight>[
      if (topCategories.isNotEmpty)
        _SkillMatrixSummaryHighlight(
          label: 'Categoria mais recorrente',
          value: topCategories.first.category.displayLabel,
          helper: 'Categoria com mais sess\u00f5es registradas na matriz.',
        ),
      if (topTechniques.isNotEmpty)
        _SkillMatrixSummaryHighlight(
          label: 'T\u00e9cnica mais recorrente',
          value: topTechniques.first.technique,
          helper: 'T\u00e9cnica com mais registros na Skill Matrix.',
        ),
    ];

    return _SkillMatrixSummaryViewModel(
      title: 'Resumo t\u00e9cnico',
      subtitle:
          'Baseado nas t\u00e9cnicas registradas e na recorr\u00eancia dos debriefs.',
      stats: [
        _SkillMatrixSummaryStat(
          label: 'T\u00c9CNICAS',
          value: techniques.length.toString(),
          helper: 'T\u00e9cnicas registradas na Skill Matrix.',
        ),
        _SkillMatrixSummaryStat(
          label: 'RECORRENTES',
          value: recurringCount.toString(),
          helper: 'T\u00e9cnicas com 3 ou mais sess\u00f5es registradas.',
        ),
        _SkillMatrixSummaryStat(
          label: 'APLICA\u00c7\u00c3O',
          value: measuredApplications.toString(),
          helper:
              'T\u00e9cnicas com aplica\u00e7\u00e3o medida em treino posicional, rola ou competi\u00e7\u00e3o.',
        ),
      ],
      highlights: highlights,
      bars: bars,
      emptyStateLabel:
          'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar um resumo seguro.',
    );
  }

  static List<_SkillMatrixSummaryBar> _categoryBars(
    List<SkillMatrixCategoryEntry> entries,
  ) {
    final maxSessions = entries.fold<int>(
      0,
      (max, entry) => entry.sessionsCount > max ? entry.sessionsCount : max,
    );
    if (maxSessions == 0) return const [];

    return [
      for (final entry in entries)
        _SkillMatrixSummaryBar(
          label: entry.category.displayLabel,
          valueLabel: TrainingAggregator.sessionCountLabel(entry.sessionsCount),
          normalizedValue: entry.sessionsCount / maxSessions,
          helper:
              'Barra relativa \u00e0 categoria mais recorrente neste conjunto.',
          kind: 'category',
        ),
    ];
  }

  static List<_SkillMatrixSummaryBar> _techniqueBars(
    List<SkillMatrixTechniqueEntry> entries,
  ) {
    final maxSessions = entries.fold<int>(
      0,
      (max, entry) => entry.sessionsCount > max ? entry.sessionsCount : max,
    );
    if (maxSessions == 0) return const [];

    return [
      for (final entry in entries)
        _SkillMatrixSummaryBar(
          label: entry.technique,
          valueLabel: TrainingAggregator.sessionCountLabel(entry.sessionsCount),
          normalizedValue: entry.sessionsCount / maxSessions,
          helper:
              'Barra relativa \u00e0 t\u00e9cnica mais recorrente neste conjunto.',
          kind: 'technique',
        ),
    ];
  }
}

class _SkillMatrixSummaryStat {
  final String label;
  final String value;
  final String helper;

  const _SkillMatrixSummaryStat({
    required this.label,
    required this.value,
    required this.helper,
  });
}

class _SkillMatrixSummaryBar {
  final String label;
  final String valueLabel;
  final double normalizedValue;
  final String helper;
  final String kind;

  const _SkillMatrixSummaryBar({
    required this.label,
    required this.valueLabel,
    required this.normalizedValue,
    required this.helper,
    required this.kind,
  });
}

class _SkillMatrixSummaryHighlight {
  final String label;
  final String value;
  final String helper;

  const _SkillMatrixSummaryHighlight({
    required this.label,
    required this.value,
    required this.helper,
  });
}
