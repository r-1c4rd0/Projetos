enum CoachEvaluationLevel {
  observed,
  needsPractice,
  progressing,
  readyForReview,
}

class CoachEvaluation {
  final String skillId;
  final String athleteUid;
  final String academyId;
  final String evaluatorUid;
  final CoachEvaluationLevel? knowledgeLevel;
  final CoachEvaluationLevel? drillLevel;
  final CoachEvaluationLevel? applicationLevel;
  final CoachEvaluationLevel? consistencyLevel;
  final String? note;
  final String? recommendation;
  final bool? needsReview;
  final DateTime evaluatedAt;

  const CoachEvaluation({
    required this.skillId,
    required this.athleteUid,
    required this.academyId,
    required this.evaluatorUid,
    required this.evaluatedAt,
    this.knowledgeLevel,
    this.drillLevel,
    this.applicationLevel,
    this.consistencyLevel,
    this.note,
    this.recommendation,
    this.needsReview,
  });

  bool get hasQualitativeInput {
    return knowledgeLevel != null ||
        drillLevel != null ||
        applicationLevel != null ||
        consistencyLevel != null ||
        note != null ||
        recommendation != null ||
        needsReview != null;
  }
}
