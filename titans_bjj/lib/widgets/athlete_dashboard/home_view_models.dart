import '../../features/home/domain/home_dashboard_models.dart';
import '../../features/technical_domain/domain/technical_models.dart';
import '../../features/technical_domain/domain/technical_taxonomy.dart';
import '../../model/grading_rules.dart';
import '../../model/training_session.dart';

class HomeDashboardViewModel {
  final List<TrainingSession> sessions;
  final List<TrainingSession> recentSessions;
  final List<TrainingSession> lastSessions;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final HomeDebriefInsights debriefInsights;
  final List<GameMapEntry> gameMapLite;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final HomeTechnicalRadarViewModel technicalRadar;
  final RecommendedTrainingFocus recommendedFocus;
  final NextTrainingRecommendation nextTraining;
  final TrainingSession? pendingConfirmation;

  const HomeDashboardViewModel({
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
    required this.pendingConfirmation,
  });

  factory HomeDashboardViewModel.fromSummary(
    HomeDashboardSummary summary, {
    HomeTechnicalRadarSummary? technicalRadarOverride,
  }) {
    return HomeDashboardViewModel(
      sessions: summary.sessions,
      recentSessions: summary.recentSessions,
      lastSessions: summary.lastSessions,
      metrics: summary.metrics,
      frequency: summary.frequency,
      debriefInsights: summary.debriefInsights,
      gameMapLite: summary.gameMapLite,
      skillMatrix: summary.skillMatrix,
      technicalRadar: HomeTechnicalRadarViewModel.fromSummary(
        technicalRadarOverride ?? summary.technicalRadar,
      ),
      recommendedFocus: summary.recommendedFocus,
      nextTraining: summary.nextTraining,
      pendingConfirmation: summary.pendingConfirmation,
    );
  }
}

class BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final int sessionsInBelt;
  final int sessionsRequired;
  final bool hasOfficialRule;
  final double percentToNextBelt;

  const BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    required this.hasOfficialRule,
    required this.percentToNextBelt,
  });
}

class HomeTechnicalRadarViewModel {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final int sessionsCount;
  final TechnicalRadarAxis? topAxis;

  const HomeTechnicalRadarViewModel({
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
    required this.sessionsCount,
    required this.topAxis,
  });

  bool get hasClassifiedEvidence => classifiedEvidenceCount > 0;

  int get occupiedAxisCount {
    return axisEvidence.values.where((value) => value > 0).length;
  }

  bool get hasRadarChart => occupiedAxisCount >= 2;

  bool get hasEvidenceSummary => classifiedEvidenceCount > 0;

  String get evidenceLabel {
    final suffix = classifiedEvidenceCount == 1 ? 'evidência' : 'evidências';
    return '$classifiedEvidenceCount $suffix';
  }

  String get sessionLabel {
    final suffix = sessionsCount == 1 ? 'sessão' : 'sessões';
    return '$sessionsCount $suffix';
  }

  String get classifiedEvidenceLabel {
    final suffix =
        classifiedEvidenceCount == 1
            ? 'evidência classificada'
            : 'evidências classificadas';
    return '$classifiedEvidenceCount $suffix';
  }

  String get topAxisLabel {
    final axis = topAxis;
    if (axis == null) return 'Evidências em construção';
    return '${axis.displayLabel} mais presente';
  }

  String get dominantAxisName {
    final axis = topAxis;
    return axis?.displayLabel ?? 'em formação';
  }

  String get awaitingEvidenceLabel {
    final suffix =
        awaitingClassificationCount == 1
            ? 'evidência aguardando classificação'
            : 'evidências aguardando classificação';
    return '$awaitingClassificationCount $suffix';
  }

  String get readingLabel {
    final axis = topAxis;
    if (axis == null) {
      return 'Sua leitura técnica ainda está sendo construída pelos treinos.';
    }
    return '${axis.displayLabel} aparece com mais frequência nas suas evidências.';
  }

  String get nextStepLabel {
    if (!hasClassifiedEvidence) {
      return 'Registre treinos para construir sua leitura técnica.';
    }
    return 'Use o mapa para entender onde seu jogo aparece com mais frequência.';
  }

  factory HomeTechnicalRadarViewModel.fromSummary(
    HomeTechnicalRadarSummary summary,
  ) {
    return HomeTechnicalRadarViewModel(
      axisEvidence: summary.axisEvidence,
      classifiedEvidenceCount: summary.classifiedEvidenceCount,
      awaitingClassificationCount: summary.awaitingClassificationCount,
      sessionsCount: summary.sessionsCount,
      topAxis: summary.topAxis,
    );
  }
}
