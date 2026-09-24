import '../../../model/coach_evaluation.dart';
import '../../../model/training_session.dart';
import '../../../service/training_aggregator.dart';

enum SkillsLibraryMode { position, category }

class SkillsLibraryModel {
  final List<SkillsLibraryGroup> positionGroups;
  final List<SkillsLibraryGroup> categoryGroups;

  const SkillsLibraryModel({
    required this.positionGroups,
    required this.categoryGroups,
  });

  List<SkillsLibraryGroup> groupsFor(SkillsLibraryMode mode) =>
      mode == SkillsLibraryMode.position ? positionGroups : categoryGroups;

  factory SkillsLibraryModel.from({
    required List<TrainingSession> sessions,
    required List<CoachEvaluation> evaluations,
  }) {
    return SkillsLibraryModel(
      positionGroups: _buildGroups(
        sessions: sessions,
        evaluations: evaluations,
        mode: SkillsLibraryMode.position,
        limit: 20,
      ),
      categoryGroups: _buildGroups(
        sessions: sessions,
        evaluations: evaluations,
        mode: SkillsLibraryMode.category,
        limit: 50,
      ),
    );
  }
}

class SkillsLibraryGroup {
  final String key;
  final String label;
  final String scopeLabel;
  final List<SkillsLibraryTechnique> techniques;

  const SkillsLibraryGroup({
    required this.key,
    required this.label,
    required this.scopeLabel,
    required this.techniques,
  });

  int get sessionCount {
    final ids = <String>{};
    for (final technique in techniques) {
      ids.addAll(technique.records.map((record) => record.sessionId));
    }
    return ids.length;
  }

  DateTime get lastRegisteredAt => techniques
      .map((technique) => technique.lastRegisteredAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

class SkillsLibraryTechnique {
  final String skillId;
  final String normalizedName;
  final String name;
  final JiuJitsuSkillCategory category;
  final List<String> positions;
  final String scopeLabel;
  final List<SkillsLibraryRecord> records;
  final CoachEvaluation? evaluation;

  const SkillsLibraryTechnique({
    required this.skillId,
    required this.normalizedName,
    required this.name,
    required this.category,
    required this.positions,
    required this.scopeLabel,
    required this.records,
    required this.evaluation,
  });

  DateTime get lastRegisteredAt => records.first.date;

  bool matches(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final searchable = <String>{
      normalizedName,
      JiuJitsuTaxonomy.normalizedKey(name),
      JiuJitsuTaxonomy.normalizedKey(skillId),
      JiuJitsuTaxonomy.normalizedKey(category.displayLabel),
      for (final position in positions)
        JiuJitsuTaxonomy.normalizedKey(position),
    };
    return searchable.any((value) => value.contains(normalizedQuery));
  }
}

class SkillsLibraryRecord {
  final String sessionId;
  final DateTime date;
  final String? position;
  final String? context;
  final String? outcome;
  final String? note;

  const SkillsLibraryRecord({
    required this.sessionId,
    required this.date,
    required this.position,
    required this.context,
    required this.outcome,
    required this.note,
  });

  bool get canOpen => sessionId.isNotEmpty;
}

class SkillsLibrarySelection {
  final SkillsLibraryMode mode;
  final SkillsLibraryGroup group;
  final SkillsLibraryTechnique technique;

  const SkillsLibrarySelection({
    required this.mode,
    required this.group,
    required this.technique,
  });
}

List<SkillsLibraryGroup> _buildGroups({
  required List<TrainingSession> sessions,
  required List<CoachEvaluation> evaluations,
  required SkillsLibraryMode mode,
  required int limit,
}) {
  final latestEvaluation = _latestEvaluations(evaluations);
  final sessionsById = {
    for (final session in sessions)
      if (session.id.trim().isNotEmpty) session.id.trim(): session,
  };
  final groups = <String, _GroupDraft>{};
  final evidences = TrainingAggregator.buildSkillEvidences(
    sessions,
    limit: limit,
  );

  for (final evidence in evidences) {
    final position = _clean(evidence.position);
    final groupKey =
        mode == SkillsLibraryMode.position
            ? 'position:${JiuJitsuTaxonomy.normalizedKey(position ?? '')}'
            : 'category:${evidence.category.name}';
    final groupLabel =
        mode == SkillsLibraryMode.position
            ? position ?? 'Sem posição registrada'
            : evidence.category.displayLabel;
    final sessionId = evidence.sourceId?.trim() ?? '';
    final session = sessionsById[sessionId];
    final record = SkillsLibraryRecord(
      sessionId: sessionId,
      date: evidence.practicedAt,
      position: position,
      context: TrainingSession.applicationContextLabel(evidence.context),
      outcome: TrainingSession.techniqueOutcomeLabel(evidence.techniqueOutcome),
      note: _sessionNote(session),
    );

    groups
        .putIfAbsent(
          groupKey,
          () => _GroupDraft(
            key: groupKey,
            label: groupLabel,
            scopeLabel: _scopeLabel(mode, limit),
          ),
        )
        .add(
          evidence: evidence,
          record: record,
          evaluation: latestEvaluation[evidence.skillId],
          scopeLabel: _scopeLabel(mode, limit),
        );
  }

  final result = groups.values.map((draft) => draft.build()).toList();
  result.sort((a, b) {
    final date = b.lastRegisteredAt.compareTo(a.lastRegisteredAt);
    return date != 0 ? date : a.label.compareTo(b.label);
  });
  return List.unmodifiable(result);
}

String _scopeLabel(SkillsLibraryMode mode, int limit) {
  final dimension =
      mode == SkillsLibraryMode.position ? 'por posição' : 'por categoria';
  return 'Últimas $limit sessões concluídas e únicas · $dimension';
}

Map<String, CoachEvaluation> _latestEvaluations(
  List<CoachEvaluation> evaluations,
) {
  final result = <String, CoachEvaluation>{};
  for (final evaluation in evaluations) {
    final skillId = evaluation.skillId.trim();
    if (skillId.isEmpty) continue;
    final current = result[skillId];
    if (current == null ||
        evaluation.evaluatedAt.isAfter(current.evaluatedAt)) {
      result[skillId] = evaluation;
    }
  }
  return result;
}

String? _sessionNote(TrainingSession? session) {
  if (session == null) return null;
  return _clean(session.debriefNotes) ?? _clean(session.notes);
}

String? _clean(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}

class _GroupDraft {
  final String key;
  final String label;
  final String scopeLabel;
  final Map<String, _TechniqueDraft> techniques = {};

  _GroupDraft({
    required this.key,
    required this.label,
    required this.scopeLabel,
  });

  void add({
    required SkillEvidence evidence,
    required SkillsLibraryRecord record,
    required CoachEvaluation? evaluation,
    required String scopeLabel,
  }) {
    techniques
        .putIfAbsent(
          evidence.skillId,
          () => _TechniqueDraft(
            skillId: evidence.skillId,
            normalizedName: evidence.normalizedTechniqueName,
            name: evidence.techniqueName,
            category: evidence.category,
            scopeLabel: scopeLabel,
          ),
        )
        .add(record, evaluation);
  }

  SkillsLibraryGroup build() {
    final built = techniques.values.map((draft) => draft.build()).toList();
    built.sort((a, b) {
      final date = b.lastRegisteredAt.compareTo(a.lastRegisteredAt);
      return date != 0 ? date : a.name.compareTo(b.name);
    });
    return SkillsLibraryGroup(
      key: key,
      label: label,
      scopeLabel: scopeLabel,
      techniques: List.unmodifiable(built),
    );
  }
}

class _TechniqueDraft {
  final String skillId;
  final String normalizedName;
  final String name;
  final JiuJitsuSkillCategory category;
  final String scopeLabel;
  final Map<String, SkillsLibraryRecord> records = {};
  final Set<String> positions = {};
  CoachEvaluation? evaluation;

  _TechniqueDraft({
    required this.skillId,
    required this.normalizedName,
    required this.name,
    required this.category,
    required this.scopeLabel,
  });

  void add(SkillsLibraryRecord record, CoachEvaluation? candidateEvaluation) {
    final recordKey =
        record.sessionId.isEmpty
            ? record.date.toIso8601String()
            : record.sessionId;
    records.putIfAbsent(recordKey, () => record);
    final position = record.position;
    if (position != null) positions.add(position);
    evaluation = candidateEvaluation ?? evaluation;
  }

  SkillsLibraryTechnique build() {
    final orderedRecords =
        records.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    final orderedPositions = positions.toList()..sort();
    return SkillsLibraryTechnique(
      skillId: skillId,
      normalizedName: normalizedName,
      name: name,
      category: category,
      positions: List.unmodifiable(orderedPositions),
      scopeLabel: scopeLabel,
      records: List.unmodifiable(orderedRecords),
      evaluation: evaluation,
    );
  }
}
