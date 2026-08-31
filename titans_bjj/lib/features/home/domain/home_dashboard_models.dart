import '../../../features/technical_domain/domain/technical_models.dart';
import '../../../features/technical_domain/domain/technical_taxonomy.dart';
import '../../../model/training_session.dart';

class HomeTrainingMetrics {
  final int total;
  final int month;
  final int year;
  final int recent;
  final double recentFrequency;

  const HomeTrainingMetrics({
    required this.total,
    required this.month,
    required this.year,
    required this.recent,
    required this.recentFrequency,
  });
}

class HomeDebriefInsights {
  final String? technicalFocus;
  final String? attentionPoint;
  final String? strengthPoint;
  final double? averageIntensity;

  const HomeDebriefInsights({
    required this.technicalFocus,
    required this.attentionPoint,
    required this.strengthPoint,
    required this.averageIntensity,
  });
}

class HomeTechnicalRadarSummary {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final int sessionsCount;
  final TechnicalRadarAxis? topAxis;

  const HomeTechnicalRadarSummary({
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
    required this.sessionsCount,
    required this.topAxis,
  });
}

class HomeDashboardSummary {
  final List<TrainingSession> sessions;
  final List<TrainingSession> recentSessions;
  final List<TrainingSession> lastSessions;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final HomeDebriefInsights debriefInsights;
  final List<GameMapEntry> gameMapLite;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final HomeTechnicalRadarSummary technicalRadar;
  final RecommendedTrainingFocus recommendedFocus;
  final NextTrainingRecommendation nextTraining;

  const HomeDashboardSummary({
    required this.sessions,
    required this.recentSessions,
    required this.lastSessions,
    required this.metrics,
    required this.frequency,
    required this.debriefInsights,
    required this.gameMapLite,
    required this.skillMatrix,
    required this.technicalRadar,
    required this.recommendedFocus,
    required this.nextTraining,
  });
}
