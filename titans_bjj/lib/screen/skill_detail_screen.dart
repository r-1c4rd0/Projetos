import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../features/technical_domain/domain/technical_context.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../service/training_aggregator.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';
import 'training_screen.dart';

part '../widgets/skill_detail/skill_detail_evaluation.dart';
part '../widgets/skill_detail/skill_detail_history.dart';
part '../widgets/skill_detail/skill_detail_overview.dart';

class SkillDetailScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final AppUser? loggedUser;
  final String skillId;
  final String displayName;
  final JiuJitsuSkillCategory? category;
  final String? preferredPosition;
  final List<TrainingSession> sessions;
  final List<CoachEvaluation> evaluations;
  final ValueChanged<String>? onOpenTrainingRecord;
  final Future<void> Function(CoachEvaluation)? onSaveCoachEvaluation;

  const SkillDetailScreen({
    super.key,
    required this.academyId,
    required this.uid,
    required this.skillId,
    required this.displayName,
    required this.sessions,
    required this.evaluations,
    this.loggedUser,
    this.category,
    this.preferredPosition,
    this.onOpenTrainingRecord,
    this.onSaveCoachEvaluation,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  late List<CoachEvaluation> _evaluations = List<CoachEvaluation>.from(
    widget.evaluations,
  );
  bool _isSavingEvaluation = false;
  String? _contextKey;
  bool _hasAlignedAcademyContext = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncContext();
  }

  @override
  void didUpdateWidget(covariant SkillDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncContext(
      refreshEvaluations: !identical(oldWidget.evaluations, widget.evaluations),
    );
  }

  AppUser? get _actor => UserScope.maybeOf(context) ?? widget.loggedUser;

  UserScope? get _userScope => UserScope.maybeScopeOf(context);

  TechnicalScreenContext _resolveContext() {
    final actor = _actor;
    final scope = _userScope;
    final activeAcademyId = scope?.activeAcademyId.trim();
    final workspaceAcademyId =
        activeAcademyId == null || activeAcademyId.isEmpty
            ? widget.academyId.trim()
            : activeAcademyId;
    final membership = scope?.activeMembership;

    return TechnicalScreenContext(
      actorUid: actor?.uid.trim() ?? '',
      actorRole: actor?.role.name ?? '',
      targetUid: widget.uid.trim(),
      targetAcademyId: widget.academyId.trim(),
      workspaceKey: 'academy:$workspaceAcademyId',
      membershipState: [
        scope?.membershipSnapshot.status.name ?? 'legacy',
        membership?.academyId ?? '',
        membership?.role.name ?? '',
        membership?.isActive.toString() ?? '',
      ].join(':'),
    );
  }

  void _syncContext({bool refreshEvaluations = false}) {
    final resolvedContext = _resolveContext();
    final detailContextKey =
        '${resolvedContext.key}|skill:${widget.skillId.trim()}';
    if (_contextKey == detailContextKey && !refreshEvaluations) return;

    final activeAcademyId = _userScope?.activeAcademyId.trim();
    _hasAlignedAcademyContext =
        activeAcademyId == null ||
        activeAcademyId.isEmpty ||
        activeAcademyId == widget.academyId.trim();
    _contextKey = detailContextKey;
    _evaluations = List<CoachEvaluation>.from(widget.evaluations);
    _isSavingEvaluation = false;
  }

  bool get _canEditCoachEvaluation {
    final scope = _userScope;
    return CoachEvaluationAuthorization.canEvaluate(
      actor: _actor,
      targetUid: widget.uid,
      targetAcademyId: widget.academyId,
      activeAcademyId: scope?.activeAcademyId,
      activeMembership: scope?.activeMembership,
      membershipSnapshot: scope?.membershipSnapshot,
    );
  }

  bool get _canOpenTargetHistory {
    final actor = _actor;
    if (actor?.uid.trim() == widget.uid.trim()) return true;
    final scope = _userScope;
    return CoachEvaluationAuthorization.canEvaluate(
      actor: actor,
      targetUid: widget.uid,
      targetAcademyId: widget.academyId,
      activeAcademyId: scope?.activeAcademyId,
      activeMembership: scope?.activeMembership,
      membershipSnapshot: scope?.membershipSnapshot,
    );
  }

  Future<void> _openEvaluationSheet(_SkillDetailViewModel vm) async {
    if (!_canEditCoachEvaluation || _isSavingEvaluation) return;
    final operationContextKey = _contextKey;

    final draft = await showModalBottomSheet<_CoachEvaluationDraft>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _CoachEvaluationSheet(
            displayName: vm.displayName,
            existing: vm.evaluation,
          ),
    );
    if (draft == null ||
        !mounted ||
        _contextKey != operationContextKey ||
        !_canEditCoachEvaluation) {
      return;
    }

    final actor = _actor;
    if (actor == null) return;

    final evaluation = CoachEvaluation(
      skillId: widget.skillId,
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

    setState(() => _isSavingEvaluation = true);
    try {
      final onSaveCoachEvaluation = widget.onSaveCoachEvaluation;
      if (onSaveCoachEvaluation != null) {
        await onSaveCoachEvaluation(evaluation);
      } else {
        await CoachEvaluationRepository.instance.upsertEvaluation(evaluation);
      }
      if (!mounted || _contextKey != operationContextKey) return;
      setState(() {
        _evaluations = [
          evaluation,
          ..._evaluations.where((item) => item.skillId != widget.skillId),
        ];
        _isSavingEvaluation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação do professor salva.')),
      );
    } catch (error) {
      if (!mounted || _contextKey != operationContextKey) return;
      setState(() => _isSavingEvaluation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar avaliação: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAlignedAcademyContext) {
      return TitansScaffold(
        appBar: AppBar(title: Text(widget.displayName)),
        body: const TitansStateView.error(
          title: 'Contexto de academia alterado',
          message: 'Abra novamente esta técnica no workspace ativo.',
        ),
      );
    }

    final contextKey = _contextKey ?? _resolveContext().key;

    final vm = _SkillDetailViewModel.from(
      skillId: widget.skillId,
      displayName: widget.displayName,
      category: widget.category,
      preferredPosition: widget.preferredPosition,
      sessions: widget.sessions,
      evaluations: _evaluations,
    );

    return TitansScaffold(
      appBar: AppBar(title: Text(vm.displayName)),
      body: ListView(
        key: ValueKey('skill-detail:$contextKey'),
        padding: TitansUI.listPadding(context),
        children: [
          _SkillDetailHeader(vm: vm),
          const SizedBox(height: 12),
          _EvidenceSummaryCard(vm: vm),
          const SizedBox(height: 12),
          _PositionsContextCard(vm: vm),
          const SizedBox(height: 12),
          _SkillHistoryCard(
            vm: vm,
            onOpenRecord:
                (sessionId) => _openTrainingRecord(
                  sessionId,
                  expectedContextKey: contextKey,
                ),
          ),
          const SizedBox(height: 12),
          _CoachEvaluationDetailCard(
            vm: vm,
            canEdit: _canEditCoachEvaluation,
            isSaving: _isSavingEvaluation,
            onEdit: () => _openEvaluationSheet(vm),
          ),
          const SizedBox(height: 12),
          _RecommendationCard(vm: vm),
          const SizedBox(height: 12),
          _EvidenceReadingCard(vm: vm),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Voltar para Skills'),
            ),
          ),
        ],
      ),
    );
  }

  void _openTrainingRecord(
    String sessionId, {
    required String expectedContextKey,
  }) {
    final recordId = sessionId.trim();
    final actor = _actor;
    if (recordId.isEmpty ||
        actor == null ||
        _contextKey != expectedContextKey ||
        !_canOpenTargetHistory) {
      return;
    }

    final onOpenTrainingRecord = widget.onOpenTrainingRecord;
    if (onOpenTrainingRecord != null) {
      onOpenTrainingRecord(recordId);
      return;
    }

    final isSelf = actor.uid.trim() == widget.uid.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TrainingScreen(
              titleOverride: isSelf ? 'Treinos' : 'Treinos do aluno',
              targetMode: isSelf ? TargetMode.self : TargetMode.selectedStudent,
              explicitTarget: TargetProfile(
                uid: widget.uid,
                academyId: widget.academyId,
              ),
              loggedUser: actor,
              focusSessionId: recordId,
            ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _RecommendationCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('RECOMENDAÇÕES'),
          const SizedBox(height: 10),
          Text(
            vm.recommendationText,
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

class _EvidenceReadingCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _EvidenceReadingCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final insights = _buildInsights();

    if (insights.isEmpty) return const SizedBox.shrink();

    return TitansCard(
      accent: cs.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('LEITURA DE EVIDÊNCIAS'),
          const SizedBox(height: 8),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 13,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildInsights() {
    final insights = <String>[];

    if (vm.evidenceCount > 0) {
      insights.add('${vm.evidenceCount} registros associados a esta técnica.');
    }

    if (vm.lastPracticedAt != null) {
      insights.add('Último registro em ${vm.lastPracticedLabel}.');
    }

    if (vm.positionCounts.isNotEmpty) {
      final topPosition = vm.positionCounts.keys.first;
      final topCount = vm.positionCounts.values.first;
      if (vm.positionCounts.length == 1) {
        insights.add('Aparece exclusivamente em $topPosition ($topCount×).');
      } else {
        insights.add(
          'Mais frequente em $topPosition ($topCount× de ${vm.evidenceCount}).',
        );
      }
    }

    if (vm.contextLabels.isNotEmpty) {
      insights.add('Contextos: ${vm.contextLabels.take(3).join(', ')}.');
    }

    return insights.take(4).toList();
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;

  const _TextBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.76),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final Iterable<String> labels;

  const _ChipWrap({required this.labels});

  @override
  Widget build(BuildContext context) {
    final items = labels.where((label) => label.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final label in items) _SmallPill(label: label)],
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String label;

  const _SmallPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.78),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailEyebrow extends StatelessWidget {
  final String label;

  const _DetailEyebrow(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.58),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SkillDetailViewModel {
  final String skillId;
  final String displayName;
  final JiuJitsuSkillCategory category;
  final int evidenceCount;
  final int sessionCount;
  final DateTime? lastPracticedAt;
  final Map<String, int> positionCounts;
  final List<String> contextLabels;
  final List<String> resultLabels;
  final List<_SkillHistoryItem> history;
  final CoachEvaluation? evaluation;
  final String? preferredPosition;

  const _SkillDetailViewModel({
    required this.skillId,
    required this.displayName,
    required this.category,
    required this.evidenceCount,
    required this.sessionCount,
    required this.lastPracticedAt,
    required this.positionCounts,
    required this.contextLabels,
    required this.resultLabels,
    required this.history,
    required this.evaluation,
    required this.preferredPosition,
  });

  String get categoryLabel => category.label;

  String get lastPracticedLabel {
    if (lastPracticedAt == null) return '—';
    return _formatShortDate(lastPracticedAt!);
  }

  int get contextCount => contextLabels.length;

  List<String> get evaluationLabels {
    final current = evaluation;
    if (current == null) return const <String>[];
    return [
      _evaluationLevelText('Conhecimento', current.knowledgeLevel),
      _evaluationLevelText('Drill', current.drillLevel),
      _evaluationLevelText('Aplicação', current.applicationLevel),
      _evaluationLevelText('Recorrência', current.consistencyLevel),
      if (current.needsReview) 'Pede revisão',
    ].whereType<String>().toList();
  }

  String get recommendationText {
    final text = _cleanText(evaluation?.recommendation);
    if (text != null) return text;
    return 'Ainda não há recomendação específica para esta técnica.';
  }

  factory _SkillDetailViewModel.from({
    required String skillId,
    required String displayName,
    required JiuJitsuSkillCategory? category,
    required String? preferredPosition,
    required List<TrainingSession> sessions,
    required List<CoachEvaluation> evaluations,
  }) {
    final seenEvidence = <String>{};
    final evidences =
        const GetSkillEvidences()(sessions, limit: sessions.length)
            .where((evidence) => evidence.skillId == skillId)
            .where((evidence) {
              final sourceKey =
                  evidence.sourceId ?? evidence.practicedAt.toIso8601String();
              return seenEvidence.add(
                '${evidence.sourceType}:$sourceKey:${evidence.skillId}',
              );
            })
            .toList();
    final history = _buildHistory(sessions, skillId);
    final positionCounts = <String, int>{};
    final contexts = <String>{};
    final results = <String>{};
    final sessionKeys = <String>{};
    DateTime? lastPracticedAt;

    for (final evidence in evidences) {
      final position = _cleanText(evidence.position) ?? preferredPosition;
      if (position != null) {
        positionCounts[position] = (positionCounts[position] ?? 0) + 1;
      }

      final context = TrainingAggregator.applicationContextLabel(
        evidence.context,
      );
      if (context != null) contexts.add(context);

      final outcome = TrainingAggregator.techniqueOutcomeLabel(
        evidence.techniqueOutcome,
      );
      if (outcome != null) results.add(outcome);

      final sourceKey =
          evidence.sourceId ?? evidence.practicedAt.toIso8601String();
      sessionKeys.add(sourceKey);
      if (lastPracticedAt == null ||
          evidence.practicedAt.isAfter(lastPracticedAt)) {
        lastPracticedAt = evidence.practicedAt;
      }
    }

    history.sort((a, b) => b.date.compareTo(a.date));
    final resolvedCategory =
        category ??
        (evidences.isNotEmpty
            ? evidences.first.category
            : JiuJitsuTaxonomy.categoryFor(
              position: preferredPosition,
              technique: displayName,
            ));
    final resolvedDisplayName =
        evidences.isNotEmpty ? evidences.first.techniqueName : displayName;

    CoachEvaluation? evaluation;
    for (final item in evaluations) {
      if (item.skillId != skillId) continue;
      if (evaluation == null ||
          item.evaluatedAt.isAfter(evaluation.evaluatedAt)) {
        evaluation = item;
      }
    }

    return _SkillDetailViewModel(
      skillId: skillId,
      displayName: resolvedDisplayName,
      category: resolvedCategory,
      evidenceCount: evidences.length,
      sessionCount: sessionKeys.length,
      lastPracticedAt: lastPracticedAt,
      positionCounts: _sortCounts(positionCounts),
      contextLabels: contexts.toList()..sort(),
      resultLabels: results.toList()..sort(),
      history: history,
      evaluation: evaluation,
      preferredPosition: preferredPosition,
    );
  }
}

class _SkillHistoryItem {
  final DateTime date;
  final String? sourceId;
  final String? position;
  final String? context;
  final String? outcome;
  final String? note;

  const _SkillHistoryItem({
    required this.date,
    required this.sourceId,
    required this.position,
    required this.context,
    required this.outcome,
    required this.note,
  });
}

List<_SkillHistoryItem> _buildHistory(
  List<TrainingSession> sessions,
  String skillId,
) {
  final items = <_SkillHistoryItem>[];
  final ordered = TrainingAggregator.uniqueCompletedSessions(sessions)
    ..sort((a, b) => b.date.compareTo(a.date));

  for (final session in ordered) {
    var sessionAdded = false;
    for (final entry in session.effectiveTechniqueEntries) {
      final technique = _cleanText(entry.technique);
      if (technique == null || _skillIdForTechnique(technique) != skillId) {
        continue;
      }
      if (sessionAdded) continue;
      sessionAdded = true;

      items.add(
        _SkillHistoryItem(
          date: session.date,
          sourceId: _cleanText(session.id),
          position: _cleanText(entry.position) ?? _cleanText(session.position),
          context:
              TrainingAggregator.applicationContextLabel(
                entry.applicationContext,
              ) ??
              TrainingAggregator.applicationContextLabel(
                session.applicationContext,
              ),
          outcome:
              TrainingAggregator.techniqueOutcomeLabel(
                entry.techniqueOutcome,
              ) ??
              TrainingAggregator.techniqueOutcomeLabel(
                session.techniqueOutcome,
              ),
          note:
              _cleanText(entry.notes) ??
              _cleanText(session.debriefNotes) ??
              _cleanText(session.notes),
        ),
      );
    }
  }

  return items;
}

Map<String, int> _sortCounts(Map<String, int> counts) {
  final entries =
      counts.entries.toList()..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
  return {for (final entry in entries) entry.key: entry.value};
}

String _skillIdForTechnique(String technique) {
  final identity = JiuJitsuTaxonomy.resolveSkillIdentity(technique);
  final normalizedName =
      identity?.normalizedName ?? JiuJitsuTaxonomy.normalizedKey(technique);
  return identity?.skillId ?? 'custom.${normalizedName.replaceAll(' ', '_')}';
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
      return 'Pronto para revisar';
  }
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatTimelineDate(DateTime date) {
  const months = <String>[
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${months[date.month - 1]}';
}

String? _cleanText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
