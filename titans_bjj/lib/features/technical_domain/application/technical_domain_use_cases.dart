import '../../../model/training_session.dart';
import '../../../service/training_aggregator.dart' show TrainingAggregator;
import '../domain/technical_models.dart';
import '../domain/technical_taxonomy.dart';

class TechnicalRadarSummary {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int totalEvidences;
  final int classifiedEvidences;
  final int techniqueCount;
  final int sessionsCount;
  final int unclassifiedEvidences;
  final TechnicalRadarAxis? topAxis;

  const TechnicalRadarSummary({
    required this.axisEvidence,
    required this.totalEvidences,
    required this.classifiedEvidences,
    this.techniqueCount = 0,
    required this.sessionsCount,
    required this.unclassifiedEvidences,
    required this.topAxis,
  });

  int get activeAxisCount =>
      axisEvidence.values.where((count) => count > 0).length;
}

class GetTechnicalRadarSummary {
  static const axisOrder = <TechnicalRadarAxis>[
    TechnicalRadarAxis.retention,
    TechnicalRadarAxis.transition,
    TechnicalRadarAxis.control,
    TechnicalRadarAxis.attack,
  ];

  const GetTechnicalRadarSummary();

  TechnicalRadarSummary call(
    List<TrainingSession> sessions, {
    int limit = 100,
  }) {
    final axisEvidence = <TechnicalRadarAxis, int>{
      for (final axis in axisOrder) axis: 0,
    };
    final seenEvidence = <String>{};
    final sourceKeys = <String>{};
    final techniqueIds = <String>{};
    var classifiedEvidences = 0;
    var unclassifiedEvidences = 0;

    final evidences = TrainingAggregator.buildSkillEvidences(
      sessions,
      limit: limit,
    );

    for (final evidence in evidences) {
      final sourceKey =
          evidence.sourceId ?? evidence.practicedAt.toIso8601String();
      final dedupeKey = '${evidence.sourceType}:$sourceKey:${evidence.skillId}';
      if (!seenEvidence.add(dedupeKey)) continue;

      techniqueIds.add(evidence.skillId);
      final axis = _axisForEvidence(evidence);
      if (axis == TechnicalRadarAxis.unclassified) {
        unclassifiedEvidences += 1;
        continue;
      }

      classifiedEvidences += 1;
      sourceKeys.add(sourceKey);
      axisEvidence[axis] = (axisEvidence[axis] ?? 0) + 1;
    }

    return TechnicalRadarSummary(
      axisEvidence: Map.unmodifiable(axisEvidence),
      totalEvidences: classifiedEvidences + unclassifiedEvidences,
      classifiedEvidences: classifiedEvidences,
      techniqueCount: techniqueIds.length,
      sessionsCount: sourceKeys.length,
      unclassifiedEvidences: unclassifiedEvidences,
      topAxis: _topAxis(axisEvidence),
    );
  }

  TechnicalRadarAxis _axisForEvidence(SkillEvidence evidence) {
    if (evidence.skillId.startsWith('custom.')) {
      return TechnicalRadarAxis.unclassified;
    }
    return JiuJitsuTaxonomy.technicalRadarAxisForCategory(evidence.category);
  }

  TechnicalRadarAxis? _topAxis(Map<TechnicalRadarAxis, int> axisEvidence) {
    TechnicalRadarAxis? selected;
    var selectedCount = 0;

    for (final axis in axisOrder) {
      final count = axisEvidence[axis] ?? 0;
      if (count > selectedCount) {
        selected = axis;
        selectedCount = count;
      }
    }

    return selectedCount == 0 ? null : selected;
  }
}

class GetSkillMatrixSummary {
  const GetSkillMatrixSummary();

  List<SkillMatrixCategoryEntry> call(
    List<TrainingSession> sessions, {
    int limit = 50,
  }) {
    return TrainingAggregator.buildSkillMatrix(sessions, limit: limit);
  }
}

class GetGameMapEvidenceSummary {
  const GetGameMapEvidenceSummary();

  List<GameMapEntry> call(List<TrainingSession> sessions, {int limit = 20}) {
    return TrainingAggregator.buildGameMap(sessions, limit: limit);
  }
}

class GetSkillEvidences {
  const GetSkillEvidences();

  List<SkillEvidence> call(List<TrainingSession> sessions, {int limit = 100}) {
    return TrainingAggregator.buildSkillEvidences(sessions, limit: limit);
  }
}

class GetTechnicalEvidenceSummary {
  const GetTechnicalEvidenceSummary();

  List<TechnicalEvidenceSummary> call(
    List<TrainingSession> sessions, {
    int limit = 100,
  }) {
    return TrainingAggregator.buildTechnicalEvidence(sessions, limit: limit);
  }
}
