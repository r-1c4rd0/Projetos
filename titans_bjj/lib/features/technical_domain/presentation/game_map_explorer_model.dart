import '../../../model/coach_evaluation.dart';
import '../../../model/training_session.dart';
import '../../../service/training_aggregator.dart';

class GameMapExplorerModel {
  final List<GameMapExplorerAxis> axes;

  const GameMapExplorerModel({required this.axes});

  bool get isEmpty => axes.every((axis) => axis.positions.isEmpty);

  GameMapExplorerAxis? axisFor(TechnicalRadarAxis axis) {
    for (final item in axes) {
      if (item.axis == axis) return item;
    }
    return null;
  }

  factory GameMapExplorerModel.from({
    required List<TrainingSession> sessions,
    required List<CoachEvaluation> evaluations,
  }) {
    final evaluationBySkillId = _latestEvaluationBySkillId(evaluations);
    final axisAccumulators = <TechnicalRadarAxis, _AxisAccumulator>{};
    final sessionsById = {
      for (final session in sessions)
        if (session.id.trim().isNotEmpty) session.id.trim(): session,
    };
    final seenPaths = <String>{};
    final evidences = TrainingAggregator.buildSkillEvidences(
      sessions,
      limit: 100,
    );

    for (final evidence in evidences) {
      final sourceId = evidence.sourceId?.trim() ?? '';
      final sourceKey =
          sourceId.isEmpty ? evidence.practicedAt.toIso8601String() : sourceId;
      final positionLabel =
          _cleanLabel(evidence.position) ??
          GameMapExplorerPosition.missingPositionLabel;
      final positionKey = JiuJitsuTaxonomy.normalizedKey(positionLabel);
      final axis =
          evidence.skillId.startsWith('custom.')
              ? TechnicalRadarAxis.unclassified
              : JiuJitsuTaxonomy.technicalRadarAxisForCategory(
                evidence.category,
              );
      final pathKey = '$axis|$positionKey|${evidence.skillId}|$sourceKey';
      if (!seenPaths.add(pathKey)) continue;

      final session = sessionsById[sourceId];
      final record = GameMapExplorerRecord(
        sessionId: sourceId,
        date: evidence.practicedAt,
        sourceLabel:
            session == null ? 'Registro de treino' : _sourceLabel(session),
        applicationContext: TrainingSession.applicationContextLabel(
          evidence.context,
        ),
        outcome: TrainingSession.techniqueOutcomeLabel(
          evidence.techniqueOutcome,
        ),
      );

      axisAccumulators
          .putIfAbsent(axis, () => _AxisAccumulator(axis))
          .add(
            positionKey: positionKey,
            positionLabel: positionLabel,
            skillId: evidence.skillId,
            techniqueLabel: evidence.techniqueName,
            category: evidence.category,
            record: record,
            evaluation: evaluationBySkillId[evidence.skillId],
          );
    }

    return GameMapExplorerModel(
      axes: [
        for (final axis in _axisOrder)
          if (axisAccumulators.containsKey(axis))
            axisAccumulators[axis]!.build(),
      ],
    );
  }
}

class GameMapExplorerAxis {
  final TechnicalRadarAxis axis;
  final List<GameMapExplorerPosition> positions;

  const GameMapExplorerAxis({required this.axis, required this.positions});

  int get recordCount =>
      positions.fold(0, (total, position) => total + position.recordCount);

  String get label =>
      axis == TechnicalRadarAxis.unclassified
          ? 'Sem classificação técnica'
          : axis.displayLabel;
}

class GameMapExplorerPosition {
  static const missingPositionLabel = 'Sem posição registrada';

  final String key;
  final String label;
  final List<GameMapExplorerTechnique> techniques;

  const GameMapExplorerPosition({
    required this.key,
    required this.label,
    required this.techniques,
  });

  bool get hasRecordedPosition => label != missingPositionLabel;

  int get recordCount => techniques.fold(
    0,
    (total, technique) => total + technique.records.length,
  );
}

class GameMapExplorerTechnique {
  final String skillId;
  final String label;
  final JiuJitsuSkillCategory category;
  final List<GameMapExplorerRecord> records;
  final CoachEvaluation? evaluation;

  const GameMapExplorerTechnique({
    required this.skillId,
    required this.label,
    required this.category,
    required this.records,
    required this.evaluation,
  });

  bool get hasCanonicalIdentity => !skillId.startsWith('custom.');
}

class GameMapExplorerRecord {
  final String sessionId;
  final DateTime date;
  final String sourceLabel;
  final String? applicationContext;
  final String? outcome;

  const GameMapExplorerRecord({
    required this.sessionId,
    required this.date,
    required this.sourceLabel,
    required this.applicationContext,
    required this.outcome,
  });

  bool get canOpen => sessionId.isNotEmpty;
}

class GameMapExplorerSelection {
  final TechnicalRadarAxis? axis;
  final GameMapExplorerPosition? position;
  final GameMapExplorerTechnique? technique;

  const GameMapExplorerSelection({this.axis, this.position, this.technique});
}

const _axisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
  TechnicalRadarAxis.unclassified,
];

class _AxisAccumulator {
  final TechnicalRadarAxis axis;
  final Map<String, _PositionAccumulator> _positions = {};

  _AxisAccumulator(this.axis);

  void add({
    required String positionKey,
    required String positionLabel,
    required String skillId,
    required String techniqueLabel,
    required JiuJitsuSkillCategory category,
    required GameMapExplorerRecord record,
    required CoachEvaluation? evaluation,
  }) {
    _positions
        .putIfAbsent(
          positionKey,
          () => _PositionAccumulator(positionKey, positionLabel),
        )
        .add(
          skillId: skillId,
          techniqueLabel: techniqueLabel,
          category: category,
          record: record,
          evaluation: evaluation,
        );
  }

  GameMapExplorerAxis build() {
    final positions =
        _positions.values.map((item) => item.build()).toList()..sort((a, b) {
          final count = b.recordCount.compareTo(a.recordCount);
          return count != 0 ? count : a.label.compareTo(b.label);
        });
    return GameMapExplorerAxis(axis: axis, positions: positions);
  }
}

class _PositionAccumulator {
  final String key;
  final String label;
  final Map<String, _TechniqueAccumulator> _techniques = {};

  _PositionAccumulator(this.key, this.label);

  void add({
    required String skillId,
    required String techniqueLabel,
    required JiuJitsuSkillCategory category,
    required GameMapExplorerRecord record,
    required CoachEvaluation? evaluation,
  }) {
    _techniques
        .putIfAbsent(
          skillId,
          () => _TechniqueAccumulator(
            skillId: skillId,
            label: techniqueLabel,
            category: category,
          ),
        )
        .add(record, evaluation);
  }

  GameMapExplorerPosition build() {
    final techniques =
        _techniques.values.map((item) => item.build()).toList()..sort((a, b) {
          final count = b.records.length.compareTo(a.records.length);
          return count != 0 ? count : a.label.compareTo(b.label);
        });
    return GameMapExplorerPosition(
      key: key,
      label: label,
      techniques: techniques,
    );
  }
}

class _TechniqueAccumulator {
  final String skillId;
  final String label;
  final JiuJitsuSkillCategory category;
  final List<GameMapExplorerRecord> _records = [];
  CoachEvaluation? _evaluation;

  _TechniqueAccumulator({
    required this.skillId,
    required this.label,
    required this.category,
  });

  void add(GameMapExplorerRecord record, CoachEvaluation? evaluation) {
    _records.add(record);
    _evaluation = evaluation ?? _evaluation;
  }

  GameMapExplorerTechnique build() {
    _records.sort((a, b) => b.date.compareTo(a.date));
    return GameMapExplorerTechnique(
      skillId: skillId,
      label: label,
      category: category,
      records: List.unmodifiable(_records),
      evaluation: _evaluation,
    );
  }
}

Map<String, CoachEvaluation> _latestEvaluationBySkillId(
  List<CoachEvaluation> evaluations,
) {
  final bySkillId = <String, CoachEvaluation>{};
  for (final evaluation in evaluations) {
    final current = bySkillId[evaluation.skillId];
    if (current == null ||
        evaluation.evaluatedAt.isAfter(current.evaluatedAt)) {
      bySkillId[evaluation.skillId] = evaluation;
    }
  }
  return bySkillId;
}

String _sourceLabel(TrainingSession session) {
  final classType = _cleanLabel(session.classType);
  if (classType != null) return classType;
  final source = _cleanLabel(session.source);
  if (source != null) return source;
  return switch (session.place) {
    TrainingPlace.academy => 'Treino na academia',
    TrainingPlace.home => 'Treino em casa',
    TrainingPlace.other => 'Outro treino',
  };
}

String? _cleanLabel(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
