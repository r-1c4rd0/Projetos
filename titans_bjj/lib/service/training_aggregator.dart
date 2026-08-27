import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../service/jiu_jitsu_taxonomy.dart';

class TrainingMetrics {
  final int total;
  final int month;
  final int year;
  final int recent;
  final double recentFrequency;

  const TrainingMetrics({
    required this.total,
    required this.month,
    required this.year,
    required this.recent,
    required this.recentFrequency,
  });
}

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

class TrainingAggregator {
  static const int recentWindowDays = 30;
  static const String undefinedPositionLabel = 'Sem posi\u00e7\u00e3o definida';

  static String sessionCountLabel(int count) {
    return count == 1 ? '1 sess\u00e3o' : '$count sess\u00f5es';
  }

  static String techniqueCountLabel(int count) {
    return count == 1 ? '1 t\u00e9cnica' : '$count t\u00e9cnicas';
  }

  static String recordCountLabel(int count) {
    return count == 1 ? '1 registro' : '$count registros';
  }

  static String? applicationContextLabel(String? value) {
    switch (_presentationKey(value)) {
      case TrainingSession.applicationContextDrill:
        return 'Drill';
      case TrainingSession.applicationContextPositionalSparring:
        return 'Treino posicional';
      case TrainingSession.applicationContextSparring:
        return 'Rola';
      case TrainingSession.applicationContextCompetition:
        return 'Competi\u00e7\u00e3o';
      case TrainingSession.applicationContextNotApplied:
        return 'N\u00e3o aplicada';
      default:
        return null;
    }
  }

  static String? techniqueOutcomeLabel(String? value) {
    switch (_presentationKey(value)) {
      case TrainingSession.techniqueOutcomeWorked:
        return 'Funcionou';
      case TrainingSession.techniqueOutcomeAlmost:
        return 'Quase funcionou';
      case TrainingSession.techniqueOutcomeFailed:
        return 'Falhou';
      case TrainingSession.techniqueOutcomeDefended:
        return 'Parceiro defendeu';
      case TrainingSession.techniqueOutcomeNotTested:
        return 'N\u00e3o testada';
      default:
        return null;
    }
  }

  static bool _isRealApplicationContext(String? value) {
    final clean = _presentationKey(value);
    return clean == TrainingSession.applicationContextPositionalSparring ||
        clean == TrainingSession.applicationContextSparring ||
        clean == TrainingSession.applicationContextCompetition;
  }

  static bool _isUsefulTechniqueOutcome(String? value) {
    final clean = _presentationKey(value);
    return clean == TrainingSession.techniqueOutcomeWorked ||
        clean == TrainingSession.techniqueOutcomeAlmost ||
        clean == TrainingSession.techniqueOutcomeFailed ||
        clean == TrainingSession.techniqueOutcomeDefended;
  }

  static String? _presentationKey(String? value) {
    final clean = _cleanText(value);
    if (clean == null) return null;
    final normalized = clean.toLowerCase();
    if (normalized == 'unknown' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == 'null') {
      return null;
    }
    return clean;
  }

  static List<_TechniqueEvidence> _techniqueEvidencesFor(
    TrainingSession session,
  ) {
    final evidences = <_TechniqueEvidence>[];
    final seen = <String>{};

    for (final entry in session.effectiveTechniqueEntries) {
      final techniqueLabel = _cleanText(entry.technique);
      if (techniqueLabel == null) continue;

      final positionLabel =
          _cleanText(entry.position) ?? _cleanText(session.position);
      final positionKey =
          positionLabel == null
              ? '__undefined_position'
              : JiuJitsuTaxonomy.normalizedKey(positionLabel);
      final techniqueKey = JiuJitsuTaxonomy.normalizedKey(techniqueLabel);
      if (techniqueKey.isEmpty) continue;

      final evidenceKey = '$positionKey:$techniqueKey';
      if (!seen.add(evidenceKey)) continue;

      evidences.add(
        _TechniqueEvidence(
          techniqueLabel: techniqueLabel,
          techniqueKey: techniqueKey,
          positionLabel: positionLabel,
          positionKey: positionKey,
          applicationContext:
              _presentationKey(entry.applicationContext) ??
              _presentationKey(session.applicationContext),
          techniqueOutcome:
              _presentationKey(entry.techniqueOutcome) ??
              _presentationKey(session.techniqueOutcome),
        ),
      );
    }

    return evidences;
  }

  static List<TrainingSession> uniqueSessions(List<TrainingSession> sessions) {
    final byKey = <String, TrainingSession>{};

    for (final session in sessions) {
      byKey[_dedupeKey(session)] = session;
    }

    final unique =
        byKey.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return unique;
  }

  static TrainingMetrics metrics(
    List<TrainingSession> sessions, {
    DateTime? now,
  }) {
    final unique = uniqueSessions(sessions);
    final resolvedNow = now ?? DateTime.now();
    final monthStart = DateTime(resolvedNow.year, resolvedNow.month, 1);
    final yearStart = DateTime(resolvedNow.year, 1, 1);
    final recentStart = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    ).subtract(const Duration(days: recentWindowDays - 1));

    final month = unique.where((s) => !s.date.isBefore(monthStart)).length;
    final year = unique.where((s) => !s.date.isBefore(yearStart)).length;
    final recent = unique.where((s) => !s.date.isBefore(recentStart)).length;

    return TrainingMetrics(
      total: unique.length,
      month: month,
      year: year,
      recent: recent,
      recentFrequency: recent / recentWindowDays,
    );
  }

  static List<GameMapEntry> buildGameMap(
    List<TrainingSession> sessions, {
    int limit = 20,
  }) {
    final ordered = List<TrainingSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final byPosition = <String, _GameMapPositionDraft>{};

    for (final session in ordered.take(limit)) {
      for (final evidence in _techniqueEvidencesFor(session)) {
        final positionDraft = byPosition.putIfAbsent(
          evidence.positionKey,
          () => _GameMapPositionDraft(),
        );
        positionDraft.addLabel(
          evidence.positionLabel ?? undefinedPositionLabel,
          session.date,
        );

        final techniqueDraft = positionDraft.techniques.putIfAbsent(
          evidence.techniqueKey,
          () => _GameMapTechniqueDraft(),
        );
        techniqueDraft.addSession(
          session: session,
          techniqueLabel: evidence.techniqueLabel,
        );
      }
    }

    final entries =
        byPosition.values
            .map((draft) {
              final techniques =
                  draft.techniques.values
                      .map((technique) => technique.toSummary())
                      .toList()
                    ..sort(_compareTechniqueSummary);

              return GameMapEntry(
                position: draft.displayLabel,
                techniques: techniques,
              );
            })
            .where((entry) => entry.techniques.isNotEmpty)
            .toList()
          ..sort(_compareGameMapEntry);

    return entries;
  }

  static List<SkillMatrixCategoryEntry> buildSkillMatrix(
    List<TrainingSession> sessions, {
    int limit = 50,
  }) {
    final ordered = List<TrainingSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final byTechnique = <String, _SkillMatrixTechniqueDraft>{};

    for (final session in ordered.take(limit)) {
      for (final evidence in _techniqueEvidencesFor(session)) {
        final category = JiuJitsuTaxonomy.categoryFor(
          position: evidence.positionLabel,
          technique: evidence.techniqueLabel,
        );
        final key = '${category.name}:${evidence.techniqueKey}';
        final draft = byTechnique.putIfAbsent(
          key,
          () => _SkillMatrixTechniqueDraft(category: category),
        );
        draft.addSession(
          session: session,
          techniqueLabel: evidence.techniqueLabel,
          positionLabel: evidence.positionLabel,
          applicationContext: evidence.applicationContext,
          techniqueOutcome: evidence.techniqueOutcome,
        );
      }
    }

    final byCategory =
        <JiuJitsuSkillCategory, List<SkillMatrixTechniqueEntry>>{};
    for (final draft in byTechnique.values) {
      final entry = draft.toEntry();
      byCategory.putIfAbsent(entry.category, () => []).add(entry);
    }

    final categories =
        byCategory.entries.map((entry) {
            final techniques = entry.value..sort(_compareSkillTechniqueEntry);
            final attention = <String>[];
            final strengths = <String>[];

            for (final technique in techniques) {
              final difficulty = _cleanText(technique.recentDifficulty);
              if (difficulty != null && !attention.contains(difficulty)) {
                attention.add(difficulty);
              }
              final success = _cleanText(technique.recentSuccess);
              if (success != null && !strengths.contains(success)) {
                strengths.add(success);
              }
            }

            return SkillMatrixCategoryEntry(
              category: entry.key,
              techniques: techniques,
              attentionPoints: attention.take(3).toList(),
              strengths: strengths.take(3).toList(),
            );
          }).toList()
          ..sort(_compareSkillCategoryEntry);

    return categories;
  }

  static RecommendedTrainingFocus buildRecommendedFocus(
    List<TrainingSession> sessions, {
    int recentLimit = 20,
  }) {
    final ordered = uniqueSessions(sessions).reversed.toList();
    final byTechnique = <String, _RecommendedFocusDraft>{};

    for (final session in ordered.take(recentLimit)) {
      for (final evidence in _techniqueEvidencesFor(session)) {
        final key = '${evidence.positionKey}:${evidence.techniqueKey}';
        final draft = byTechnique.putIfAbsent(
          key,
          () => _RecommendedFocusDraft(),
        );
        draft.addSession(
          session: session,
          techniqueLabel: evidence.techniqueLabel,
          positionLabel: evidence.positionLabel,
          applicationContext: evidence.applicationContext,
          techniqueOutcome: evidence.techniqueOutcome,
        );
      }
    }

    if (byTechnique.isEmpty) {
      return const RecommendedTrainingFocus.empty();
    }

    final drafts = byTechnique.values.toList();

    final needsAdjustment =
        drafts
            .where((draft) => draft.hasFailedOrDefendedRealApplication)
            .toList()
          ..sort(_compareApplicationFocusDraft);
    if (needsAdjustment.isNotEmpty) {
      final selected = needsAdjustment.first;
      return selected.toFocus(
        titlePrefix: 'Revisar',
        reason:
            'Voc\u00ea tentou aplicar em ${selected.applicationContextLabel}, mas registrou ${selected.outcomeLabel}. Vale repetir com foco no ajuste de entrada e controle.',
        suggestedAction:
            'Repetir entrada e controle antes de buscar a finaliza\u00e7\u00e3o.',
        priority: RecommendedTrainingFocusPriority.high,
        recommendationType: RecommendedTrainingFocusType.applicationAdjustment,
        baseTags: [
          'Aplica\u00e7\u00e3o real',
          'Precisa ajuste',
          selected.applicationContextLabel,
        ],
        evidenceTags: [selected.outcomeLabel, 'Prioridade alta'],
        confidenceLabel: 'Alta confian\u00e7a',
        nextStepLabel: 'Ajustar aplica\u00e7\u00e3o real',
      );
    }

    final almostWorked =
        drafts.where((draft) => draft.hasAlmostRealApplication).toList()
          ..sort(_compareApplicationFocusDraft);
    if (almostWorked.isNotEmpty) {
      final selected = almostWorked.first;
      return selected.toFocus(
        titlePrefix: 'Consolidar',
        reason:
            'Ela quase funcionou em ${selected.applicationContextLabel}. O pr\u00f3ximo passo \u00e9 repetir com foco no detalhe que faltou.',
        suggestedAction:
            'Repetir o detalhe principal em rounds curtos e situa\u00e7\u00e3o controlada.',
        priority:
            selected.sessionsCount == 1
                ? RecommendedTrainingFocusPriority.high
                : RecommendedTrainingFocusPriority.medium,
        recommendationType: RecommendedTrainingFocusType.nearSuccess,
        baseTags: const [
          'Quase funcionou',
          'Boa evolu\u00e7\u00e3o',
          'Repetir detalhe',
        ],
        evidenceTags: [
          'Aplica\u00e7\u00e3o real',
          selected.applicationContextLabel,
        ],
        confidenceLabel: 'Boa evid\u00eancia',
        nextStepLabel: 'Consolidar detalhe',
      );
    }

    final workedLowConsistency =
        drafts
            .where(
              (draft) =>
                  draft.hasWorkedOutcome &&
                  !draft.hasDrillOnly &&
                  draft.sessionsCount < 3,
            )
            .toList()
          ..sort(_compareApplicationFocusDraft);
    if (workedLowConsistency.isNotEmpty) {
      final selected = workedLowConsistency.first;
      return selected.toFocus(
        titlePrefix: 'Repetir',
        reason:
            'Funcionou recentemente, mas ainda tem pouca repeti\u00e7\u00e3o registrada. Vale repetir para transformar em recurso consistente.',
        suggestedAction:
            'Repetir em mais uma sess\u00e3o e registrar se funcionou de novo.',
        priority: RecommendedTrainingFocusPriority.medium,
        recommendationType: RecommendedTrainingFocusType.recentSuccess,
        baseTags: const [
          'Funcionou',
          'Pouca repeti\u00e7\u00e3o',
          'Consolidar',
        ],
        evidenceTags: [selected.applicationContextLabel, selected.outcomeLabel],
        confidenceLabel: 'Evid\u00eancia recente',
        nextStepLabel: 'Repetir para consolidar',
      );
    }

    final drillOnly =
        drafts.where((draft) => draft.hasDrillOnly).toList()
          ..sort(_compareApplicationFocusDraft);
    if (drillOnly.isNotEmpty) {
      final selected = drillOnly.first;
      return selected.toFocus(
        titlePrefix: 'Testar',
        reason:
            'Essa t\u00e9cnica apareceu em drill, mas ainda n\u00e3o h\u00e1 registro de aplica\u00e7\u00e3o em rola ou treino posicional.',
        suggestedAction:
            'Testar em treino posicional antes de levar para a rola livre.',
        priority: RecommendedTrainingFocusPriority.medium,
        recommendationType: RecommendedTrainingFocusType.drillToApplication,
        baseTags: const [
          'Drill',
          'Testar aplica\u00e7\u00e3o',
          'Pr\u00f3ximo passo',
        ],
        evidenceTags: const ['Sem aplica\u00e7\u00e3o real'],
        confidenceLabel: 'Pr\u00f3ximo passo claro',
        nextStepLabel: 'Testar em situa\u00e7\u00e3o controlada',
      );
    }

    final withDifficulty =
        drafts.where((draft) => draft.difficultyCount > 0).toList();
    if (withDifficulty.isNotEmpty) {
      withDifficulty.sort(_compareDifficultyFocusDraft);
      final selected = withDifficulty.first;
      return selected.toFocus(
        titlePrefix: 'Revisar',
        reason:
            'Voc\u00ea registrou dificuldade recente nessa t\u00e9cnica. Vale repetir com foco em controle e finaliza\u00e7\u00e3o do movimento.',
        suggestedAction:
            'Separe rounds curtos para repetir a entrada, estabilizar o controle e fechar o movimento.',
        priority:
            selected.difficultyCount >= 2
                ? RecommendedTrainingFocusPriority.high
                : RecommendedTrainingFocusPriority.medium,
        recommendationType: RecommendedTrainingFocusType.difficulty,
        baseTags: [
          selected.difficultyCount >= 2
              ? 'Dificuldade recorrente'
              : 'Dificuldade recente',
        ],
        evidenceTags: const [],
        confidenceLabel: 'Fallback v1',
        nextStepLabel: 'Revisar dificuldade',
      );
    }

    final lowConsistency =
        drafts.where((draft) => draft.sessionsCount < 3).toList();
    if (lowConsistency.isNotEmpty) {
      lowConsistency.sort(_compareLowConsistencyFocusDraft);
      return lowConsistency.first.toFocus(
        titlePrefix: 'Consolidar',
        reason:
            'Essa t\u00e9cnica apareceu recentemente, mas ainda tem pouca repeti\u00e7\u00e3o registrada.',
        suggestedAction:
            'Repita a t\u00e9cnica no aquecimento t\u00e9cnico e registre o debrief ao final.',
        priority: RecommendedTrainingFocusPriority.medium,
        recommendationType: RecommendedTrainingFocusType.consistency,
        baseTags: const ['Pouca repeti\u00e7\u00e3o'],
        evidenceTags: const [],
        confidenceLabel: 'Fallback v1',
        nextStepLabel: 'Consolidar repeti\u00e7\u00e3o',
      );
    }

    drafts.sort(_compareMaintenanceFocusDraft);
    return drafts.first.toFocus(
      titlePrefix: 'Manter evolu\u00e7\u00e3o em',
      reason:
          'Seu hist\u00f3rico recente mostra boa recorr\u00eancia nesse ponto. Continue refinando.',
      suggestedAction:
          'Use o pr\u00f3ximo treino para variar entradas, pegadas e ajustes finos.',
      priority: RecommendedTrainingFocusPriority.low,
      recommendationType: RecommendedTrainingFocusType.maintenance,
      baseTags: const ['Manuten\u00e7\u00e3o'],
      evidenceTags: const [],
      confidenceLabel: 'Fallback v1',
      nextStepLabel: 'Manter evolu\u00e7\u00e3o',
    );
  }

  static NextTrainingRecommendation buildNextTrainingRecommendation(
    List<TrainingSession> sessions, {
    int recentLimit = 20,
  }) {
    final focus = buildRecommendedFocus(sessions, recentLimit: recentLimit);
    if (!focus.hasRecommendation) {
      return const NextTrainingRecommendation.empty();
    }

    final target = _focusTarget(focus);
    final position = focus.position ?? undefinedPositionLabel;
    final baseTags = _nextTrainingTags(focus);

    switch (focus.recommendationType) {
      case RecommendedTrainingFocusType.applicationAdjustment:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: revisar $target',
          subtitle: 'Ajuste para aplica\u00e7\u00e3o controlada',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective:
              'Corrigir entrada, base e controle antes de buscar a finaliza\u00e7\u00e3o.',
          warmupSuggestion:
              'Entradas leves para chegar em $position com postura est\u00e1vel.',
          technicalDrill:
              'Repetir ${focus.technique} pausando no ponto em que a defesa apareceu.',
          applicationSuggestion:
              'Testar em treino posicional antes de levar para a rola livre.',
          reflectionQuestion:
              'O ajuste impediu a falha ou a defesa do parceiro?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Comece leve e aumente a resist\u00eancia apenas quando houver controle.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.nearSuccess:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: consolidar $target',
          subtitle: 'Detalhe final da aplica\u00e7\u00e3o',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective:
              'Consolidar o detalhe que faltou para a t\u00e9cnica funcionar.',
          warmupSuggestion:
              'Repeti\u00e7\u00f5es leves de ${focus.technique} sem acelerar o movimento.',
          technicalDrill:
              'Fazer poucas repeti\u00e7\u00f5es com qualidade e pausa para ajuste.',
          applicationSuggestion:
              'Aplicar em situa\u00e7\u00e3o controlada e repetir o detalhe principal.',
          reflectionQuestion: 'Qual detalhe faltou quando quase funcionou?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Priorize precis\u00e3o antes de intensidade.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.recentSuccess:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: repetir $target',
          subtitle: 'Consolida\u00e7\u00e3o com resist\u00eancia progressiva',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective:
              'Transformar uma aplica\u00e7\u00e3o que funcionou em recurso recorrente.',
          warmupSuggestion:
              'Revisar a entrada de ${focus.technique} em ritmo controlado.',
          technicalDrill:
              'Repetir o movimento com parceiro oferecendo rea\u00e7\u00e3o gradual.',
          applicationSuggestion:
              'Testar com resist\u00eancia progressiva e registrar se funcionou de novo.',
          reflectionQuestion:
              'A t\u00e9cnica seguiu funcionando com mais resist\u00eancia?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Suba a intensidade aos poucos, mantendo qualidade nas repeti\u00e7\u00f5es.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.drillToApplication:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: testar $target',
          subtitle: 'Do drill para o treino posicional',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective: 'Levar o drill para uma situa\u00e7\u00e3o controlada.',
          warmupSuggestion:
              'Manter o drill de ${focus.technique} com repeti\u00e7\u00f5es limpas.',
          technicalDrill:
              'Repetir entrada, controle e sa\u00edda antes de adicionar resist\u00eancia.',
          applicationSuggestion:
              'Testar em treino posicional e registrar o resultado no debrief.',
          reflectionQuestion: 'Funcionou, quase funcionou ou foi defendida?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Use resist\u00eancia leve primeiro para medir o ajuste.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.difficulty:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: revisar $target',
          subtitle: 'Ajuste do ponto de dificuldade',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective: 'Melhorar o ponto de dificuldade registrado.',
          warmupSuggestion:
              'Chegar em $position e estabilizar antes de iniciar a t\u00e9cnica.',
          technicalDrill:
              'Separar rounds curtos para repetir entrada, controle e finaliza\u00e7\u00e3o.',
          applicationSuggestion:
              'Checar em situa\u00e7\u00e3o controlada se o ajuste melhorou.',
          reflectionQuestion: 'A dificuldade diminuiu depois do ajuste?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Mantenha intensidade moderada para perceber o erro com clareza.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.consistency:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: consolidar $target',
          subtitle: 'Mais repeti\u00e7\u00f5es com qualidade',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective:
              'Aumentar a consist\u00eancia sem mudar o foco t\u00e9cnico.',
          warmupSuggestion:
              'Usar ${focus.technique} como aquecimento t\u00e9cnico principal.',
          technicalDrill:
              'Fazer blocos curtos de repeti\u00e7\u00e3o e registrar o que melhorou.',
          applicationSuggestion:
              'Aplicar em situa\u00e7\u00e3o controlada se houver seguran\u00e7a no detalhe.',
          reflectionQuestion:
              'A repeti\u00e7\u00e3o deixou a t\u00e9cnica mais est\u00e1vel?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Use intensidade baixa a moderada para preservar qualidade.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.maintenance:
        return NextTrainingRecommendation(
          title: 'Pr\u00f3ximo treino: manter $target',
          subtitle: 'Refino de ponto recorrente',
          focusPosition: focus.position,
          focusTechnique: focus.technique,
          objective:
              'Refinar um ponto que j\u00e1 aparece com recorr\u00eancia.',
          warmupSuggestion:
              'Entrar em $position e variar pegadas antes do movimento principal.',
          technicalDrill:
              'Repetir ${focus.technique} alternando ritmo, entrada e ajuste fino.',
          applicationSuggestion:
              'Checar em treino posicional se as varia\u00e7\u00f5es seguem est\u00e1veis.',
          reflectionQuestion:
              'Qual varia\u00e7\u00e3o deixou a t\u00e9cnica mais forte?',
          intensityGuidance: _nextTrainingIntensityGuidance(
            focus,
            'Trabalhe com intensidade moderada e foco em refino.',
          ),
          tags: baseTags,
          priority: focus.priority,
        );
      case RecommendedTrainingFocusType.none:
        return const NextTrainingRecommendation.empty();
    }
  }

  static String _focusTarget(RecommendedTrainingFocus focus) {
    final technique = focus.technique ?? 't\u00e9cnica';
    final position = focus.position;
    if (position == null || position.trim().isEmpty) return technique;
    return '$technique em $position';
  }

  static List<String> _nextTrainingTags(RecommendedTrainingFocus focus) {
    return _dedupeStrings([
      _priorityTag(focus.priority),
      focus.nextStepLabel,
      focus.applicationLabel,
      focus.outcomeLabel,
      ...focus.tags,
    ]).take(5).toList();
  }

  static String _priorityTag(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return 'Prioridade alta';
      case RecommendedTrainingFocusPriority.medium:
        return 'Prioridade m\u00e9dia';
      case RecommendedTrainingFocusPriority.low:
        return 'Prioridade baixa';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }

  static String _nextTrainingIntensityGuidance(
    RecommendedTrainingFocus focus,
    String fallback,
  ) {
    final avgIntensity = focus.avgIntensity;
    if (avgIntensity == null) return fallback;
    if (avgIntensity >= 4) {
      return 'O hist\u00f3rico veio intenso; reduza um pouco para ajustar com qualidade.';
    }
    if (avgIntensity <= 2) {
      return 'O hist\u00f3rico veio leve; aumente resist\u00eancia de forma progressiva.';
    }
    return fallback;
  }

  static List<String> _dedupeStrings(Iterable<String?> values) {
    final seen = <String>{};
    final output = <String>[];
    for (final value in values) {
      final clean = _cleanText(value);
      if (clean == null) continue;
      if (seen.add(clean.toLowerCase())) output.add(clean);
    }
    return output;
  }

  /// Retorna uma lista de pontos ja agregados.
  static List<int> aggregate({
    required List<TrainingSession> sessions,
    required ProgressPeriod period,
  }) {
    final now = DateTime.now();
    final unique = uniqueSessions(sessions);

    switch (period) {
      case ProgressPeriod.day:
        return _byDay(unique, now);
      case ProgressPeriod.month:
        return _byMonth(unique, now);
      case ProgressPeriod.year:
        return _byYear(unique, now);
    }
  }

  static String _dedupeKey(TrainingSession session) {
    final attendanceSessionId = session.attendanceSessionId;
    final attendanceCheckInUid = session.attendanceCheckInUid ?? session.uid;

    if (attendanceSessionId != null &&
        attendanceSessionId.trim().isNotEmpty &&
        attendanceCheckInUid != null &&
        attendanceCheckInUid.trim().isNotEmpty) {
      return 'attendance:${attendanceSessionId.trim()}:${attendanceCheckInUid.trim()}';
    }

    return 'training:${session.id}';
  }

  static int _compareGameMapEntry(GameMapEntry a, GameMapEntry b) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.position.toLowerCase().compareTo(b.position.toLowerCase());
  }

  static int _compareTechniqueSummary(
    GameMapTechniqueSummary a,
    GameMapTechniqueSummary b,
  ) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.technique.toLowerCase().compareTo(b.technique.toLowerCase());
  }

  static int _compareSkillCategoryEntry(
    SkillMatrixCategoryEntry a,
    SkillMatrixCategoryEntry b,
  ) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final consistentCompare = b.consistencyCount.compareTo(a.consistencyCount);
    if (consistentCompare != 0) return consistentCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.category.displayLabel.compareTo(b.category.displayLabel);
  }

  static int _compareSkillTechniqueEntry(
    SkillMatrixTechniqueEntry a,
    SkillMatrixTechniqueEntry b,
  ) {
    if (a.consistent != b.consistent) return a.consistent ? -1 : 1;
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.technique.toLowerCase().compareTo(b.technique.toLowerCase());
  }

  static String? _cleanText(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _compareApplicationFocusDraft(
    _RecommendedFocusDraft a,
    _RecommendedFocusDraft b,
  ) {
    final dateCompare = b.applicationEvidenceAt.compareTo(
      a.applicationEvidenceAt,
    );
    if (dateCompare != 0) return dateCompare;
    final sessionsCompare = a.sessionsCount.compareTo(b.sessionsCount);
    if (sessionsCompare != 0) return sessionsCompare;
    return a.techniqueLabel.toLowerCase().compareTo(
      b.techniqueLabel.toLowerCase(),
    );
  }

  static int _compareDifficultyFocusDraft(
    _RecommendedFocusDraft a,
    _RecommendedFocusDraft b,
  ) {
    final difficultyCompare = b.difficultyCount.compareTo(a.difficultyCount);
    if (difficultyCompare != 0) return difficultyCompare;
    final consistencyCompare = a.sessionsCount.compareTo(b.sessionsCount);
    if (consistencyCompare != 0) return consistencyCompare;
    final intensityCompare = (b.averageIntensity ?? 0).compareTo(
      a.averageIntensity ?? 0,
    );
    if (intensityCompare != 0) return intensityCompare;
    return b.lastTrainedAt.compareTo(a.lastTrainedAt);
  }

  static int _compareLowConsistencyFocusDraft(
    _RecommendedFocusDraft a,
    _RecommendedFocusDraft b,
  ) {
    final sessionsCompare = a.sessionsCount.compareTo(b.sessionsCount);
    if (sessionsCompare != 0) return sessionsCompare;
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    return a.techniqueLabel.toLowerCase().compareTo(
      b.techniqueLabel.toLowerCase(),
    );
  }

  static int _compareMaintenanceFocusDraft(
    _RecommendedFocusDraft a,
    _RecommendedFocusDraft b,
  ) {
    final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (sessionsCompare != 0) return sessionsCompare;
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    return a.techniqueLabel.toLowerCase().compareTo(
      b.techniqueLabel.toLowerCase(),
    );
  }

  static List<int> _byDay(List<TrainingSession> sessions, DateTime now) {
    return List.generate(14, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 13 - i));

      return sessions
          .where(
            (e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .length;
    });
  }

  static List<int> _byMonth(List<TrainingSession> sessions, DateTime now) {
    return List.generate(12, (i) {
      final month = DateTime(now.year, now.month - (11 - i), 1);

      return sessions
          .where(
            (e) => e.date.year == month.year && e.date.month == month.month,
          )
          .length;
    });
  }

  static List<int> _byYear(List<TrainingSession> sessions, DateTime now) {
    return List.generate(5, (i) {
      final year = now.year - (4 - i);

      return sessions.where((e) => e.date.year == year).length;
    });
  }
}

class _TechniqueEvidence {
  final String techniqueLabel;
  final String techniqueKey;
  final String? positionLabel;
  final String positionKey;
  final String? applicationContext;
  final String? techniqueOutcome;

  const _TechniqueEvidence({
    required this.techniqueLabel,
    required this.techniqueKey,
    required this.positionLabel,
    required this.positionKey,
    required this.applicationContext,
    required this.techniqueOutcome,
  });
}

class _RecommendedFocusDraft {
  final techniqueLabels = <String, _GameMapLabelScore>{};
  final positionLabels = <String, _GameMapLabelScore>{};
  final intensities = <int>[];
  final sessionKeys = <String>{};
  int sessionsCount = 0;
  int difficultyCount = 0;
  int drillCount = 0;
  int realApplicationCount = 0;
  DateTime? _lastTrainedAt;
  _ApplicationEvidence? failedOrDefendedEvidence;
  _ApplicationEvidence? almostEvidence;
  _ApplicationEvidence? workedEvidence;
  _ApplicationEvidence? drillEvidence;

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
    required String? positionLabel,
    required String? applicationContext,
    required String? techniqueOutcome,
  }) {
    if (!sessionKeys.add(TrainingAggregator._dedupeKey(session))) return;
    sessionsCount += 1;
    techniqueLabels
        .putIfAbsent(techniqueLabel, () => _GameMapLabelScore(techniqueLabel))
        .add(session.date);

    if (positionLabel != null) {
      positionLabels
          .putIfAbsent(positionLabel, () => _GameMapLabelScore(positionLabel))
          .add(session.date);
    }

    if (_lastTrainedAt == null || session.date.isAfter(_lastTrainedAt!)) {
      _lastTrainedAt = session.date;
    }

    final intensity = session.intensity;
    if (intensity != null && intensity >= 1 && intensity <= 5) {
      intensities.add(intensity);
    }

    if (TrainingAggregator._cleanText(session.difficulties) != null) {
      difficultyCount += 1;
    }

    _addApplicationEvidence(session, applicationContext, techniqueOutcome);
  }

  void _addApplicationEvidence(
    TrainingSession session,
    String? applicationContext,
    String? techniqueOutcome,
  ) {
    final context = TrainingAggregator._presentationKey(applicationContext);
    final outcome = TrainingAggregator._presentationKey(techniqueOutcome);
    final isRealApplication = TrainingAggregator._isRealApplicationContext(
      context,
    );
    final isUsefulOutcome = TrainingAggregator._isUsefulTechniqueOutcome(
      outcome,
    );

    if (context == TrainingSession.applicationContextDrill) {
      drillCount += 1;
      drillEvidence = _latestEvidence(
        drillEvidence,
        _ApplicationEvidence(
          context: context,
          outcome: outcome,
          date: session.date,
        ),
      );
    }

    if (isRealApplication) {
      realApplicationCount += 1;
    }

    if (!isUsefulOutcome) return;

    final evidence = _ApplicationEvidence(
      context: context,
      outcome: outcome,
      date: session.date,
    );

    if (isRealApplication &&
        (outcome == TrainingSession.techniqueOutcomeFailed ||
            outcome == TrainingSession.techniqueOutcomeDefended)) {
      failedOrDefendedEvidence = _latestEvidence(
        failedOrDefendedEvidence,
        evidence,
      );
      return;
    }

    if (isRealApplication &&
        outcome == TrainingSession.techniqueOutcomeAlmost) {
      almostEvidence = _latestEvidence(almostEvidence, evidence);
      return;
    }

    if (outcome == TrainingSession.techniqueOutcomeWorked) {
      workedEvidence = _latestEvidence(workedEvidence, evidence);
    }
  }

  String get techniqueLabel => _bestLabel(techniqueLabels);

  String? get positionLabel =>
      positionLabels.isEmpty ? null : _bestLabel(positionLabels);

  DateTime get lastTrainedAt =>
      _lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  DateTime get applicationEvidenceAt {
    return failedOrDefendedEvidence?.date ??
        almostEvidence?.date ??
        workedEvidence?.date ??
        drillEvidence?.date ??
        lastTrainedAt;
  }

  bool get hasFailedOrDefendedRealApplication =>
      failedOrDefendedEvidence != null;

  bool get hasAlmostRealApplication => almostEvidence != null;

  bool get hasWorkedOutcome => workedEvidence != null;

  bool get hasDrillOnly => drillCount > 0 && realApplicationCount == 0;

  _ApplicationEvidence? get bestApplicationEvidence =>
      failedOrDefendedEvidence ??
      almostEvidence ??
      workedEvidence ??
      drillEvidence;

  String get applicationContextLabel {
    return TrainingAggregator.applicationContextLabel(
          bestApplicationEvidence?.context,
        ) ??
        'Sem aplica\u00e7\u00e3o real';
  }

  String get outcomeLabel {
    return TrainingAggregator.techniqueOutcomeLabel(
          bestApplicationEvidence?.outcome,
        ) ??
        'Sem resultado testado';
  }

  double? get averageIntensity {
    if (intensities.isEmpty) return null;
    return intensities.fold<int>(0, (sum, value) => sum + value) /
        intensities.length;
  }

  RecommendedTrainingFocus toFocus({
    required String titlePrefix,
    required String reason,
    required String suggestedAction,
    required RecommendedTrainingFocusPriority priority,
    required RecommendedTrainingFocusType recommendationType,
    required List<String> baseTags,
    required List<String> evidenceTags,
    required String confidenceLabel,
    required String nextStepLabel,
  }) {
    final position = positionLabel;
    final technique = techniqueLabel;
    final avgIntensity = averageIntensity;
    final tags = <String>[...baseTags];
    final evidence = <String>[...evidenceTags];
    final applicationLabel = TrainingAggregator.applicationContextLabel(
      bestApplicationEvidence?.context,
    );
    final outcomeLabel = TrainingAggregator.techniqueOutcomeLabel(
      bestApplicationEvidence?.outcome,
    );

    if (sessionsCount < 3 && !tags.contains('Pouca repeti\u00e7\u00e3o')) {
      tags.add('Pouca repeti\u00e7\u00e3o');
    }
    if (avgIntensity != null &&
        avgIntensity >= 4 &&
        !tags.contains('Intensidade alta')) {
      tags.add('Intensidade alta');
    }
    if (sessionsCount >= 3 && !tags.contains('Recorrente')) {
      tags.add('Recorrente');
    }
    if (applicationLabel != null && !evidence.contains(applicationLabel)) {
      evidence.add(applicationLabel);
    }
    if (outcomeLabel != null && !evidence.contains(outcomeLabel)) {
      evidence.add(outcomeLabel);
    }

    return RecommendedTrainingFocus(
      position: position,
      technique: technique,
      title: _focusTitle(titlePrefix, technique, position),
      summary: position == null ? technique : '$technique em $position',
      reason: reason,
      suggestedAction: suggestedAction,
      evidenceLabel:
          '$sessionsCount ${sessionsCount == 1 ? 'registro recente' : 'registros recentes'}',
      applicationLabel: applicationLabel,
      outcomeLabel: outcomeLabel,
      recommendationType: recommendationType,
      confidenceLabel: confidenceLabel,
      evidenceTags: evidence.take(3).toList(),
      nextStepLabel: nextStepLabel,
      priority: priority,
      tags: tags.take(3).toList(),
      sessionsCount: sessionsCount,
      difficultyCount: difficultyCount,
      avgIntensity: avgIntensity,
      lastTrainedAt: lastTrainedAt,
    );
  }
}

class _ApplicationEvidence {
  final String? context;
  final String? outcome;
  final DateTime date;

  const _ApplicationEvidence({
    required this.context,
    required this.outcome,
    required this.date,
  });
}

_ApplicationEvidence _latestEvidence(
  _ApplicationEvidence? current,
  _ApplicationEvidence next,
) {
  if (current == null || next.date.isAfter(current.date)) return next;
  return current;
}

String _focusTitle(String prefix, String technique, String? position) {
  if (position == null || position.trim().isEmpty) return '$prefix $technique';
  return '$prefix $technique em $position';
}

class _GameMapPositionDraft {
  final labels = <String, _GameMapLabelScore>{};
  final techniques = <String, _GameMapTechniqueDraft>{};

  void addLabel(String label, DateTime date) {
    final score = labels.putIfAbsent(label, () => _GameMapLabelScore(label));
    score.add(date);
  }

  String get displayLabel => _bestLabel(labels);
}

class _GameMapTechniqueDraft {
  final labels = <String, _GameMapLabelScore>{};
  int sessionsCount = 0;
  final sessionKeys = <String>{};
  DateTime? lastTrainedAt;
  final List<int> intensities = [];
  String? recentSuccess;
  String? recentDifficulty;

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
  }) {
    if (!sessionKeys.add(TrainingAggregator._dedupeKey(session))) return;
    sessionsCount += 1;
    labels
        .putIfAbsent(techniqueLabel, () => _GameMapLabelScore(techniqueLabel))
        .add(session.date);

    if (lastTrainedAt == null || session.date.isAfter(lastTrainedAt!)) {
      lastTrainedAt = session.date;
    }

    final intensity = session.intensity;
    if (intensity != null && intensity >= 1 && intensity <= 5) {
      intensities.add(intensity);
    }

    final success = TrainingAggregator._cleanText(session.successes);
    if (success != null && recentSuccess == null) {
      recentSuccess = success;
    }

    final difficulty = TrainingAggregator._cleanText(session.difficulties);
    if (difficulty != null && recentDifficulty == null) {
      recentDifficulty = difficulty;
    }
  }

  GameMapTechniqueSummary toSummary() {
    final averageIntensity =
        intensities.isEmpty
            ? null
            : intensities.fold<int>(0, (sum, value) => sum + value) /
                intensities.length;

    return GameMapTechniqueSummary(
      technique: _bestLabel(labels),
      sessionsCount: sessionsCount,
      sessionKeys: Set.unmodifiable(sessionKeys),
      lastTrainedAt: lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      averageIntensity: averageIntensity,
      recentSuccess: recentSuccess,
      recentDifficulty: recentDifficulty,
    );
  }
}

class _SkillMatrixTechniqueDraft {
  final JiuJitsuSkillCategory category;
  final techniqueLabels = <String, _GameMapLabelScore>{};
  final positionLabels = <String, _GameMapLabelScore>{};
  final intensities = <int>[];
  final sessionKeys = <String>{};
  int sessionsCount = 0;
  DateTime? lastTrainedAt;
  String? recentSuccess;
  String? recentDifficulty;
  String? applicationContext;
  String? techniqueOutcome;
  bool applicationMeasured = false;

  _SkillMatrixTechniqueDraft({required this.category});

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
    required String? positionLabel,
    required String? applicationContext,
    required String? techniqueOutcome,
  }) {
    if (!sessionKeys.add(TrainingAggregator._dedupeKey(session))) return;
    sessionsCount += 1;
    techniqueLabels
        .putIfAbsent(techniqueLabel, () => _GameMapLabelScore(techniqueLabel))
        .add(session.date);

    if (positionLabel != null) {
      positionLabels
          .putIfAbsent(positionLabel, () => _GameMapLabelScore(positionLabel))
          .add(session.date);
    }

    if (lastTrainedAt == null || session.date.isAfter(lastTrainedAt!)) {
      lastTrainedAt = session.date;
    }

    final intensity = session.intensity;
    if (intensity != null && intensity >= 1 && intensity <= 5) {
      intensities.add(intensity);
    }

    final success = TrainingAggregator._cleanText(session.successes);
    if (success != null && recentSuccess == null) {
      recentSuccess = success;
    }

    final difficulty = TrainingAggregator._cleanText(session.difficulties);
    if (difficulty != null && recentDifficulty == null) {
      recentDifficulty = difficulty;
    }

    final hasMeasuredApplication =
        TrainingSession.isApplicationContextMeasured(applicationContext) &&
        TrainingSession.isTechniqueOutcomeUseful(techniqueOutcome);
    if (hasMeasuredApplication) {
      applicationMeasured = true;
      if (this.applicationContext == null && this.techniqueOutcome == null) {
        this.applicationContext = applicationContext;
        this.techniqueOutcome = techniqueOutcome;
      }
    }
  }

  SkillMatrixTechniqueEntry toEntry() {
    final averageIntensity =
        intensities.isEmpty
            ? null
            : intensities.fold<int>(0, (sum, value) => sum + value) /
                intensities.length;

    return SkillMatrixTechniqueEntry(
      category: category,
      technique: _bestLabel(techniqueLabels),
      position: positionLabels.isEmpty ? null : _bestLabel(positionLabels),
      sessionsCount: sessionsCount,
      sessionKeys: Set.unmodifiable(sessionKeys),
      lastTrainedAt: lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      averageIntensity: averageIntensity,
      recentSuccess: recentSuccess,
      recentDifficulty: recentDifficulty,
      knowledge: sessionsCount >= 1,
      drill: sessionsCount >= 1,
      application: applicationMeasured,
      consistent: sessionsCount >= 3,
      applicationContext: applicationContext,
      techniqueOutcome: techniqueOutcome,
    );
  }
}

class _GameMapLabelScore {
  final String label;
  int count = 0;
  DateTime? latestAt;

  _GameMapLabelScore(this.label);

  void add(DateTime date) {
    count += 1;
    if (latestAt == null || date.isAfter(latestAt!)) {
      latestAt = date;
    }
  }
}

String _bestLabel(Map<String, _GameMapLabelScore> labels) {
  _GameMapLabelScore? best;
  for (final score in labels.values) {
    if (best == null ||
        score.count > best.count ||
        (score.count == best.count &&
            score.latestAt != null &&
            (best.latestAt == null ||
                score.latestAt!.isAfter(best.latestAt!)))) {
      best = score;
    }
  }
  return best?.label ?? TrainingAggregator.undefinedPositionLabel;
}
