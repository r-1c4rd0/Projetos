import 'technical_taxonomy.dart';

class GameMapEntry {
  final String position;
  final List<GameMapTechniqueSummary> techniques;

  const GameMapEntry({required this.position, required this.techniques});

  int get sessionsCount {
    final keys = <String>{};
    for (final technique in techniques) {
      keys.addAll(technique.sessionKeys);
    }
    if (keys.isNotEmpty) return keys.length;

    return techniques.fold<int>(
      0,
      (sum, technique) => sum + technique.sessionsCount,
    );
  }

  DateTime get lastTrainedAt {
    return techniques
        .map((technique) => technique.lastTrainedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class GameMapTechniqueSummary {
  final String technique;
  final int sessionsCount;
  final Set<String> sessionKeys;
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;

  const GameMapTechniqueSummary({
    required this.technique,
    required this.sessionsCount,
    this.sessionKeys = const <String>{},
    required this.lastTrainedAt,
    required this.averageIntensity,
    required this.recentSuccess,
    required this.recentDifficulty,
  });
}

class SkillMatrixCategoryEntry {
  final JiuJitsuSkillCategory category;
  final List<SkillMatrixTechniqueEntry> techniques;
  final List<String> attentionPoints;
  final List<String> strengths;

  const SkillMatrixCategoryEntry({
    required this.category,
    required this.techniques,
    required this.attentionPoints,
    required this.strengths,
  });

  int get techniquesCount => techniques.length;

  int get sessionsCount {
    final keys = <String>{};
    for (final technique in techniques) {
      keys.addAll(technique.sessionKeys);
    }
    if (keys.isNotEmpty) return keys.length;

    return techniques.fold<int>(
      0,
      (sum, technique) => sum + technique.sessionsCount,
    );
  }

  int get knowledgeCount => techniques.where((entry) => entry.knowledge).length;

  int get drillCount => techniques.where((entry) => entry.drill).length;

  int get consistencyCount =>
      techniques.where((entry) => entry.consistent).length;

  DateTime get lastTrainedAt {
    return techniques
        .map((technique) => technique.lastTrainedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  double? get averageIntensity {
    final values =
        techniques
            .map((technique) => technique.averageIntensity)
            .whereType<double>()
            .toList();
    if (values.isEmpty) return null;
    return values.fold<double>(0, (sum, value) => sum + value) / values.length;
  }
}

class SkillMatrixTechniqueEntry {
  final JiuJitsuSkillCategory category;
  final String technique;
  final String? position;
  final int sessionsCount;
  final Set<String> sessionKeys;
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;
  final bool knowledge;
  final bool drill;
  final bool? application;
  final String? applicationContext;
  final String? techniqueOutcome;
  final bool consistent;

  const SkillMatrixTechniqueEntry({
    required this.category,
    required this.technique,
    required this.position,
    required this.sessionsCount,
    this.sessionKeys = const <String>{},
    required this.lastTrainedAt,
    required this.averageIntensity,
    required this.recentSuccess,
    required this.recentDifficulty,
    required this.knowledge,
    required this.drill,
    required this.application,
    required this.applicationContext,
    required this.techniqueOutcome,
    required this.consistent,
  });
}

class SkillEvidence {
  static const sourceTypeTrainingSession = 'training_session';

  final String skillId;
  final String techniqueName;
  final String normalizedTechniqueName;
  final String sourceType;
  final String? sourceId;
  final DateTime practicedAt;
  final String? position;
  final String? context;
  final JiuJitsuSkillCategory category;
  final String? techniqueOutcome;
  final int? attempts;
  final int? successes;

  const SkillEvidence({
    required this.skillId,
    required this.techniqueName,
    required this.normalizedTechniqueName,
    required this.sourceType,
    required this.sourceId,
    required this.practicedAt,
    required this.position,
    required this.context,
    required this.category,
    this.techniqueOutcome,
    this.attempts,
    this.successes,
  });
}

class TechnicalEvidenceSummary {
  final String skillId;
  final String techniqueName;
  final String normalizedTechniqueName;
  final int evidenceCount;
  final DateTime lastPracticedAt;
  final Set<String> positions;
  final Set<String> contexts;
  final Set<String> outcomes;
  final Set<String> sourceTypes;
  final Set<String> sourceIds;

  const TechnicalEvidenceSummary({
    required this.skillId,
    required this.techniqueName,
    required this.normalizedTechniqueName,
    required this.evidenceCount,
    required this.lastPracticedAt,
    this.positions = const <String>{},
    this.contexts = const <String>{},
    this.outcomes = const <String>{},
    this.sourceTypes = const <String>{},
    this.sourceIds = const <String>{},
  });
}

enum RecommendedTrainingFocusPriority { none, low, medium, high }

enum RecommendedTrainingFocusType {
  none,
  applicationAdjustment,
  nearSuccess,
  recentSuccess,
  drillToApplication,
  difficulty,
  consistency,
  maintenance,
}

class RecommendedTrainingFocus {
  final String? position;
  final String? technique;
  final String title;
  final String summary;
  final String reason;
  final String suggestedAction;
  final String evidenceLabel;
  final String? applicationLabel;
  final String? outcomeLabel;
  final RecommendedTrainingFocusType recommendationType;
  final String confidenceLabel;
  final List<String> evidenceTags;
  final String nextStepLabel;
  final RecommendedTrainingFocusPriority priority;
  final List<String> tags;
  final int sessionsCount;
  final int difficultyCount;
  final double? avgIntensity;
  final DateTime? lastTrainedAt;

  const RecommendedTrainingFocus({
    required this.position,
    required this.technique,
    required this.title,
    required this.summary,
    required this.reason,
    required this.suggestedAction,
    required this.evidenceLabel,
    required this.applicationLabel,
    required this.outcomeLabel,
    required this.recommendationType,
    required this.confidenceLabel,
    required this.evidenceTags,
    required this.nextStepLabel,
    required this.priority,
    required this.tags,
    required this.sessionsCount,
    required this.difficultyCount,
    required this.avgIntensity,
    required this.lastTrainedAt,
  });

  const RecommendedTrainingFocus.empty()
    : position = null,
      technique = null,
      title = 'Foco recomendado',
      summary = 'Sem t\u00e9cnica registrada',
      reason =
          'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar um foco recomendado.',
      suggestedAction =
          'No pr\u00f3ximo treino, preencha pelo menos a t\u00e9cnica trabalhada.',
      evidenceLabel = 'Sem dados t\u00e9cnicos',
      applicationLabel = null,
      outcomeLabel = null,
      recommendationType = RecommendedTrainingFocusType.none,
      confidenceLabel = 'Sem evid\u00eancia suficiente',
      evidenceTags = const [],
      nextStepLabel = 'Registrar debrief completo',
      priority = RecommendedTrainingFocusPriority.none,
      tags = const [],
      sessionsCount = 0,
      difficultyCount = 0,
      avgIntensity = null,
      lastTrainedAt = null;

  bool get hasRecommendation =>
      technique != null && technique!.trim().isNotEmpty;
}

class NextTrainingRecommendation {
  final String title;
  final String subtitle;
  final String? focusPosition;
  final String? focusTechnique;
  final String objective;
  final String warmupSuggestion;
  final String technicalDrill;
  final String applicationSuggestion;
  final String reflectionQuestion;
  final String intensityGuidance;
  final List<String> tags;
  final RecommendedTrainingFocusPriority priority;
  final String? emptyMessage;

  const NextTrainingRecommendation({
    required this.title,
    required this.subtitle,
    required this.focusPosition,
    required this.focusTechnique,
    required this.objective,
    required this.warmupSuggestion,
    required this.technicalDrill,
    required this.applicationSuggestion,
    required this.reflectionQuestion,
    required this.intensityGuidance,
    required this.tags,
    required this.priority,
    this.emptyMessage,
  });

  const NextTrainingRecommendation.empty()
    : title = 'Pr\u00f3ximo treino',
      subtitle = 'Aguardando debrief t\u00e9cnico',
      focusPosition = null,
      focusTechnique = null,
      objective = '',
      warmupSuggestion = '',
      technicalDrill = '',
      applicationSuggestion = '',
      reflectionQuestion = '',
      intensityGuidance = '',
      tags = const [],
      priority = RecommendedTrainingFocusPriority.none,
      emptyMessage =
          'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para gerar uma sugest\u00e3o de pr\u00f3ximo treino.';

  bool get hasRecommendation =>
      focusTechnique != null && focusTechnique!.trim().isNotEmpty;
}
