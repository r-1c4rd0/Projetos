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

  const GameMapEntry({
    required this.position,
    required this.techniques,
  });

  int get sessionsCount => techniques.fold<int>(
        0,
        (sum, technique) => sum + technique.sessionsCount,
      );

  DateTime get lastTrainedAt {
    return techniques
        .map((technique) => technique.lastTrainedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class GameMapTechniqueSummary {
  final String technique;
  final int sessionsCount;
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;

  const GameMapTechniqueSummary({
    required this.technique,
    required this.sessionsCount,
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

  int get sessionsCount => techniques.fold<int>(
        0,
        (sum, technique) => sum + technique.sessionsCount,
      );

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
    final values = techniques
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
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;
  final bool knowledge;
  final bool drill;
  final bool? application;
  final bool consistent;

  const SkillMatrixTechniqueEntry({
    required this.category,
    required this.technique,
    required this.position,
    required this.sessionsCount,
    required this.lastTrainedAt,
    required this.averageIntensity,
    required this.recentSuccess,
    required this.recentDifficulty,
    required this.knowledge,
    required this.drill,
    required this.application,
    required this.consistent,
  });
}

enum RecommendedTrainingFocusPriority { none, low, medium, high }

class RecommendedTrainingFocus {
  final String? position;
  final String? technique;
  final String title;
  final String summary;
  final String reason;
  final String suggestedAction;
  final String evidenceLabel;
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
        summary = 'Sem tecnica registrada',
        reason =
            'Registre posicao e tecnica nos debriefs para gerar um foco recomendado.',
        suggestedAction =
            'No proximo treino, preencha pelo menos a tecnica trabalhada.',
        evidenceLabel = 'Sem dados tecnicos',
        priority = RecommendedTrainingFocusPriority.none,
        tags = const [],
        sessionsCount = 0,
        difficultyCount = 0,
        avgIntensity = null,
        lastTrainedAt = null;

  bool get hasRecommendation =>
      technique != null && technique!.trim().isNotEmpty;
}

class TrainingAggregator {
  static const int recentWindowDays = 30;
  static const String undefinedPositionLabel = 'Sem posicao definida';

  static List<TrainingSession> uniqueSessions(List<TrainingSession> sessions) {
    final byKey = <String, TrainingSession>{};

    for (final session in sessions) {
      byKey[_dedupeKey(session)] = session;
    }

    final unique = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
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
      final techniqueLabel = _cleanText(session.technique);
      if (techniqueLabel == null) continue;

      final positionLabel = _cleanText(session.position);
      final positionKey = positionLabel == null
          ? '__undefined_position'
          : JiuJitsuTaxonomy.normalizedKey(positionLabel);
      final techniqueKey = JiuJitsuTaxonomy.normalizedKey(techniqueLabel);
      if (techniqueKey.isEmpty) continue;

      final positionDraft = byPosition.putIfAbsent(
        positionKey,
        () => _GameMapPositionDraft(),
      );
      positionDraft.addLabel(
        positionLabel ?? undefinedPositionLabel,
        session.date,
      );

      final techniqueDraft = positionDraft.techniques.putIfAbsent(
        techniqueKey,
        () => _GameMapTechniqueDraft(),
      );
      techniqueDraft.addSession(
        session: session,
        techniqueLabel: techniqueLabel,
      );
    }

    final entries = byPosition.values.map((draft) {
      final techniques = draft.techniques.values
          .map((technique) => technique.toSummary())
          .toList()
        ..sort(_compareTechniqueSummary);

      return GameMapEntry(
        position: draft.displayLabel,
        techniques: techniques,
      );
    }).where((entry) => entry.techniques.isNotEmpty).toList()
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
      final techniqueLabel = _cleanText(session.technique);
      if (techniqueLabel == null) continue;

      final positionLabel = _cleanText(session.position);
      final category = JiuJitsuTaxonomy.categoryFor(
        position: positionLabel,
        technique: techniqueLabel,
      );
      final techniqueKey = JiuJitsuTaxonomy.normalizedKey(techniqueLabel);
      if (techniqueKey.isEmpty) continue;

      final key = '${category.name}:$techniqueKey';
      final draft = byTechnique.putIfAbsent(
        key,
        () => _SkillMatrixTechniqueDraft(category: category),
      );
      draft.addSession(
        session: session,
        techniqueLabel: techniqueLabel,
        positionLabel: positionLabel,
      );
    }

    final byCategory = <JiuJitsuSkillCategory, List<SkillMatrixTechniqueEntry>>{};
    for (final draft in byTechnique.values) {
      final entry = draft.toEntry();
      byCategory.putIfAbsent(entry.category, () => []).add(entry);
    }

    final categories = byCategory.entries.map((entry) {
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
      final techniqueLabel = _cleanText(session.technique);
      if (techniqueLabel == null) continue;

      final positionLabel = _cleanText(session.position);
      final positionKey = positionLabel == null
          ? '__undefined_position'
          : JiuJitsuTaxonomy.normalizedKey(positionLabel);
      final techniqueKey = JiuJitsuTaxonomy.normalizedKey(techniqueLabel);
      if (techniqueKey.isEmpty) continue;

      final key = '$positionKey:$techniqueKey';
      final draft = byTechnique.putIfAbsent(
        key,
        () => _RecommendedFocusDraft(),
      );
      draft.addSession(
        session: session,
        techniqueLabel: techniqueLabel,
        positionLabel: positionLabel,
      );
    }

    if (byTechnique.isEmpty) {
      return const RecommendedTrainingFocus.empty();
    }

    final drafts = byTechnique.values.toList();
    final withDifficulty =
        drafts.where((draft) => draft.difficultyCount > 0).toList();
    if (withDifficulty.isNotEmpty) {
      withDifficulty.sort(_compareDifficultyFocusDraft);
      final selected = withDifficulty.first;
      return selected.toFocus(
        titlePrefix: 'Revisar',
        reason:
            'Voce registrou dificuldade recente nessa tecnica. Vale repetir com foco em controle e finalizacao do movimento.',
        suggestedAction:
            'Separe rounds curtos para repetir a entrada, estabilizar o controle e fechar o movimento.',
        priority: selected.difficultyCount >= 2
            ? RecommendedTrainingFocusPriority.high
            : RecommendedTrainingFocusPriority.medium,
        baseTags: [
          selected.difficultyCount >= 2
              ? 'Dificuldade recorrente'
              : 'Dificuldade recente',
        ],
      );
    }

    final lowConsistency =
        drafts.where((draft) => draft.sessionsCount < 3).toList();
    if (lowConsistency.isNotEmpty) {
      lowConsistency.sort(_compareLowConsistencyFocusDraft);
      return lowConsistency.first.toFocus(
        titlePrefix: 'Consolidar',
        reason:
            'Essa tecnica apareceu recentemente, mas ainda tem pouca repeticao registrada.',
        suggestedAction:
            'Repita a tecnica no aquecimento tecnico e registre o debrief ao final.',
        priority: RecommendedTrainingFocusPriority.medium,
        baseTags: const ['Pouca repeticao'],
      );
    }

    drafts.sort(_compareMaintenanceFocusDraft);
    return drafts.first.toFocus(
      titlePrefix: 'Manter evolucao em',
      reason:
          'Seu historico recente mostra boa recorrencia nesse ponto. Continue refinando.',
      suggestedAction:
          'Use o proximo treino para variar entradas, pegadas e ajustes finos.',
      priority: RecommendedTrainingFocusPriority.low,
      baseTags: const ['Manutencao'],
    );
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
    return a.category.label.compareTo(b.category.label);
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

  static int _compareDifficultyFocusDraft(
    _RecommendedFocusDraft a,
    _RecommendedFocusDraft b,
  ) {
    final difficultyCompare = b.difficultyCount.compareTo(a.difficultyCount);
    if (difficultyCompare != 0) return difficultyCompare;
    final consistencyCompare = a.sessionsCount.compareTo(b.sessionsCount);
    if (consistencyCompare != 0) return consistencyCompare;
    final intensityCompare =
        (b.averageIntensity ?? 0).compareTo(a.averageIntensity ?? 0);
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
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));

      return sessions
          .where((e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .length;
    });
  }

  static List<int> _byMonth(List<TrainingSession> sessions, DateTime now) {
    return List.generate(12, (i) {
      final month = DateTime(now.year, now.month - (11 - i), 1);

      return sessions
          .where((e) => e.date.year == month.year && e.date.month == month.month)
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

class _RecommendedFocusDraft {
  final techniqueLabels = <String, _GameMapLabelScore>{};
  final positionLabels = <String, _GameMapLabelScore>{};
  final intensities = <int>[];
  int sessionsCount = 0;
  int difficultyCount = 0;
  DateTime? _lastTrainedAt;

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
    required String? positionLabel,
  }) {
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
  }

  String get techniqueLabel => _bestLabel(techniqueLabels);

  String? get positionLabel =>
      positionLabels.isEmpty ? null : _bestLabel(positionLabels);

  DateTime get lastTrainedAt =>
      _lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

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
    required List<String> baseTags,
  }) {
    final position = positionLabel;
    final technique = techniqueLabel;
    final avgIntensity = averageIntensity;
    final tags = <String>[...baseTags];

    if (sessionsCount < 3 && !tags.contains('Pouca repeticao')) {
      tags.add('Pouca repeticao');
    }
    if (avgIntensity != null &&
        avgIntensity >= 4 &&
        !tags.contains('Intensidade alta')) {
      tags.add('Intensidade alta');
    }
    if (sessionsCount >= 3 && !tags.contains('Recorrente')) {
      tags.add('Recorrente');
    }

    return RecommendedTrainingFocus(
      position: position,
      technique: technique,
      title: '$titlePrefix $technique',
      summary: position == null ? technique : '$technique em $position',
      reason: reason,
      suggestedAction: suggestedAction,
      evidenceLabel:
          '$sessionsCount ${sessionsCount == 1 ? 'registro recente' : 'registros recentes'}',
      priority: priority,
      tags: tags.take(3).toList(),
      sessionsCount: sessionsCount,
      difficultyCount: difficultyCount,
      avgIntensity: avgIntensity,
      lastTrainedAt: lastTrainedAt,
    );
  }
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
  DateTime? lastTrainedAt;
  final List<int> intensities = [];
  String? recentSuccess;
  String? recentDifficulty;

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
  }) {
    sessionsCount += 1;
    labels.putIfAbsent(
      techniqueLabel,
      () => _GameMapLabelScore(techniqueLabel),
    ).add(session.date);

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
    final averageIntensity = intensities.isEmpty
        ? null
        : intensities.fold<int>(0, (sum, value) => sum + value) /
            intensities.length;

    return GameMapTechniqueSummary(
      technique: _bestLabel(labels),
      sessionsCount: sessionsCount,
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
  int sessionsCount = 0;
  DateTime? lastTrainedAt;
  String? recentSuccess;
  String? recentDifficulty;

  _SkillMatrixTechniqueDraft({required this.category});

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
    required String? positionLabel,
  }) {
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
  }

  SkillMatrixTechniqueEntry toEntry() {
    final averageIntensity = intensities.isEmpty
        ? null
        : intensities.fold<int>(0, (sum, value) => sum + value) /
            intensities.length;

    return SkillMatrixTechniqueEntry(
      category: category,
      technique: _bestLabel(techniqueLabels),
      position: positionLabels.isEmpty ? null : _bestLabel(positionLabels),
      sessionsCount: sessionsCount,
      lastTrainedAt: lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      averageIntensity: averageIntensity,
      recentSuccess: recentSuccess,
      recentDifficulty: recentDifficulty,
      knowledge: sessionsCount >= 1,
      drill: sessionsCount >= 1,
      application: null,
      consistent: sessionsCount >= 3,
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
            (best.latestAt == null || score.latestAt!.isAfter(best.latestAt!)))) {
      best = score;
    }
  }
  return best?.label ?? TrainingAggregator.undefinedPositionLabel;
}
