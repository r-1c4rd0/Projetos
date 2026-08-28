import 'package:cloud_firestore/cloud_firestore.dart';

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
  final bool needsReview;
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
    this.needsReview = false,
  });

  factory CoachEvaluation.fromDoc(String id, Map<String, dynamic> data) {
    return CoachEvaluation(
      skillId: _string(data['skillId']) ?? id,
      athleteUid: _string(data['athleteUid']) ?? '',
      academyId: _string(data['academyId']) ?? '',
      evaluatorUid: _string(data['evaluatorUid']) ?? '',
      knowledgeLevel: _level(data['knowledgeLevel']),
      drillLevel: _level(data['drillLevel']),
      applicationLevel: _level(data['applicationLevel']),
      consistencyLevel: _level(data['consistencyLevel']),
      note: _string(data['note']),
      recommendation: _string(data['recommendation']),
      needsReview: data['needsReview'] == true,
      evaluatedAt: _date(data['evaluatedAt']),
    );
  }

  Map<String, dynamic> toMap({Object? evaluatedAtOverride}) {
    return {
      'skillId': skillId,
      'athleteUid': athleteUid,
      'academyId': academyId,
      'evaluatorUid': evaluatorUid,
      if (knowledgeLevel != null) 'knowledgeLevel': knowledgeLevel!.name,
      if (drillLevel != null) 'drillLevel': drillLevel!.name,
      if (applicationLevel != null) 'applicationLevel': applicationLevel!.name,
      if (consistencyLevel != null) 'consistencyLevel': consistencyLevel!.name,
      if (_string(note) != null) 'note': _string(note),
      if (_string(recommendation) != null)
        'recommendation': _string(recommendation),
      'needsReview': needsReview,
      'evaluatedAt': evaluatedAtOverride ?? Timestamp.fromDate(evaluatedAt),
    };
  }

  bool get hasQualitativeInput {
    return knowledgeLevel != null ||
        drillLevel != null ||
        applicationLevel != null ||
        consistencyLevel != null ||
        note != null ||
        recommendation != null ||
        needsReview;
  }

  static CoachEvaluationLevel? _level(Object? value) {
    final name = _string(value);
    if (name == null) return null;
    return CoachEvaluationLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => CoachEvaluationLevel.observed,
    );
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
