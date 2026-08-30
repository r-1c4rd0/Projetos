import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
import '../widgets/titans_scaffold.dart';

class SkillDetailScreen extends StatelessWidget {
  final String academyId;
  final String uid;
  final AppUser? loggedUser;
  final String skillId;
  final String displayName;
  final JiuJitsuSkillCategory? category;
  final String? preferredPosition;
  final List<TrainingSession> sessions;
  final List<CoachEvaluation> evaluations;

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
  });

  @override
  Widget build(BuildContext context) {
    final vm = _SkillDetailViewModel.from(
      skillId: skillId,
      displayName: displayName,
      category: category,
      preferredPosition: preferredPosition,
      sessions: sessions,
      evaluations: evaluations,
    );

    return TitansScaffold(
      appBar: AppBar(title: Text(vm.displayName)),
      body: ListView(
        padding: TitansUI.listPadding(context),
        children: [
          _SkillDetailHeader(vm: vm),
          const SizedBox(height: 12),
          _EvidenceSummaryCard(vm: vm),
          const SizedBox(height: 12),
          _PositionsContextCard(vm: vm),
          const SizedBox(height: 12),
          _SkillHistoryCard(vm: vm),
          const SizedBox(height: 12),
          _CoachEvaluationDetailCard(vm: vm),
          const SizedBox(height: 12),
          _RecommendationCard(vm: vm),
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
}

class _SkillDetailHeader extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _SkillDetailHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  vm.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Evidências registradas nos treinos.',
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

class _EvidenceSummaryCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _EvidenceSummaryCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('RESUMO DE EVIDÊNCIAS'),
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
                childAspectRatio: compact ? 1.28 : 1.18,
                children: [
                  TitansMetricCard(
                    label: 'Registros',
                    value: vm.evidenceCount.toString(),
                    icon: Icons.fact_check_outlined,
                    color: cs.primary,
                  ),
                  TitansMetricCard(
                    label: 'Sessões',
                    value: vm.sessionCount.toString(),
                    icon: Icons.event_note_outlined,
                    color: cs.secondary,
                  ),
                  TitansMetricCard(
                    label: 'Última vez',
                    value: vm.lastPracticedLabel,
                    icon: Icons.schedule_outlined,
                    color: Colors.lightGreenAccent,
                  ),
                  TitansMetricCard(
                    label: 'Contextos',
                    value: vm.contextCount.toString(),
                    icon: Icons.account_tree_outlined,
                    color: Colors.amber,
                  ),
                ],
              );
            },
          ),
          if (vm.resultLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipWrap(labels: vm.resultLabels),
          ],
          if (vm.evidenceCount > 0 && vm.evidenceCount < 3) ...[
            const SizedBox(height: 12),
            Text(
              'Pouca evidência registrada. Mais treinos ajudam a formar uma leitura mais consistente.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.66),
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

class _PositionsContextCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _PositionsContextCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return TitansCard(
      accent: Colors.lightGreenAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('POSIÇÕES E CONTEXTOS'),
          const SizedBox(height: 12),
          if (vm.positionCounts.isEmpty)
            const TitansStateView.empty(
              title: 'Sem posição suficiente',
              message:
                  'Registre posição/contexto nos treinos para refinar esta visão.',
              compact: true,
            )
          else
            Column(
              children: [
                for (final entry in vm.positionCounts.entries) ...[
                  _CountLine(label: entry.key, value: entry.value),
                  if (entry.key != vm.positionCounts.keys.last)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          if (vm.contextLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipWrap(labels: vm.contextLabels),
          ],
        ],
      ),
    );
  }
}

class _SkillHistoryCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _SkillHistoryCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('HISTÓRICO'),
          const SizedBox(height: 12),
          if (vm.history.isEmpty)
            const TitansStateView.empty(
              title: 'Sem evidência registrada',
              message:
                  'Esta técnica ainda não apareceu nos treinos carregados.',
              compact: true,
            )
          else
            Column(
              children: [
                for (var i = 0; i < vm.history.length; i++) ...[
                  _HistoryRow(item: vm.history[i]),
                  if (i != vm.history.length - 1)
                    Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _SkillHistoryItem item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[
      if (item.position != null) item.position!,
      if (item.context != null) item.context!,
      if (item.outcome != null) item.outcome!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              _formatTimelineDate(item.date),
              style: TextStyle(
                color: cs.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.isEmpty ? 'Registro técnico' : details.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (item.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _CoachEvaluationDetailCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _CoachEvaluationDetailCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final evaluation = vm.evaluation;

    return TitansCard(
      accent: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('AVALIAÇÃO DO PROFESSOR'),
          const SizedBox(height: 12),
          if (evaluation == null)
            const TitansStateView.empty(
              title: 'Nenhuma avaliação registrada ainda.',
              message:
                  'A avaliação do professor aparecerá aqui quando existir.',
              compact: true,
            )
          else ...[
            _ChipWrap(labels: vm.evaluationLabels),
            if (_cleanText(evaluation.note) != null) ...[
              const SizedBox(height: 12),
              _TextBlock(label: 'Observação', text: evaluation.note!),
            ],
            if (_cleanText(evaluation.recommendation) != null) ...[
              const SizedBox(height: 12),
              _TextBlock(
                label: 'Recomendação',
                text: evaluation.recommendation!,
              ),
            ],
          ],
        ],
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

class _CountLine extends StatelessWidget {
  final String label;
  final int value;

  const _CountLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        _SmallPill(label: '${value}x', color: cs.primary),
      ],
    );
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
  final Color? color;

  const _SmallPill({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;

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
    final evidences =
        TrainingAggregator.buildSkillEvidences(
          sessions,
          limit: sessions.length,
        ).where((evidence) => evidence.skillId == skillId).toList();
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
  final ordered = List<TrainingSession>.from(sessions)
    ..sort((a, b) => b.date.compareTo(a.date));

  for (final session in ordered) {
    for (final entry in session.effectiveTechniqueEntries) {
      final technique = _cleanText(entry.technique);
      if (technique == null || _skillIdForTechnique(technique) != skillId) {
        continue;
      }

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
