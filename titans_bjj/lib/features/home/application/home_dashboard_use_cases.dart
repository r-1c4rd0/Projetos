import '../../../model/training_session.dart';
import '../../../service/training_aggregator.dart' show TrainingAggregator;
import '../../technical_domain/application/technical_domain_use_cases.dart';
import '../domain/home_dashboard_models.dart';

class GetHomeDashboardSummary {
  final GetTechnicalRadarSummary getTechnicalRadarSummary;
  final GetSkillMatrixSummary getSkillMatrixSummary;
  final GetGameMapEvidenceSummary getGameMapEvidenceSummary;

  const GetHomeDashboardSummary({
    this.getTechnicalRadarSummary = const GetTechnicalRadarSummary(),
    this.getSkillMatrixSummary = const GetSkillMatrixSummary(),
    this.getGameMapEvidenceSummary = const GetGameMapEvidenceSummary(),
  });

  HomeDashboardSummary call(
    List<TrainingSession> sessions, {
    DateTime? now,
  }) {
    final stableSessions = List<TrainingSession>.unmodifiable(sessions);
    final recentSessions = List<TrainingSession>.unmodifiable(
      stableSessions.reversed.take(10),
    );
    final lastSessions = List<TrainingSession>.unmodifiable(
      recentSessions.take(5),
    );
    final metrics = TrainingAggregator.metrics(stableSessions, now: now);
    final radarSummary = getTechnicalRadarSummary(
      stableSessions,
      limit: stableSessions.length,
    );

    return HomeDashboardSummary(
      sessions: stableSessions,
      recentSessions: recentSessions,
      lastSessions: lastSessions,
      metrics: HomeTrainingMetrics(
        total: metrics.total,
        month: metrics.month,
        year: metrics.year,
        recent: metrics.recent,
        recentFrequency: metrics.recentFrequency,
      ),
      frequency: _calculateFrequency(stableSessions, now: now),
      debriefInsights: _buildDebriefInsights(recentSessions),
      gameMapLite: List.unmodifiable(
        getGameMapEvidenceSummary(recentSessions, limit: 10),
      ),
      skillMatrix: List.unmodifiable(
        getSkillMatrixSummary(stableSessions, limit: 50),
      ),
      technicalRadar: HomeTechnicalRadarSummary(
        axisEvidence: radarSummary.axisEvidence,
        classifiedEvidenceCount: radarSummary.classifiedEvidences,
        awaitingClassificationCount: radarSummary.unclassifiedEvidences,
        sessionsCount: radarSummary.sessionsCount,
        topAxis: radarSummary.topAxis,
      ),
      recommendedFocus: TrainingAggregator.buildRecommendedFocus(
        stableSessions,
        recentLimit: 20,
      ),
      nextTraining: TrainingAggregator.buildNextTrainingRecommendation(
        stableSessions,
        recentLimit: 20,
      ),
    );
  }

  int _calculateFrequency(List<TrainingSession> sessions, {DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final weeks = <String, bool>{};
    for (var i = 0; i < 8; i++) {
      final date = resolvedNow.subtract(Duration(days: i * 7));
      weeks[_weekKey(date)] = false;
    }
    for (final session in sessions) {
      final key = _weekKey(session.date);
      if (weeks.containsKey(key)) weeks[key] = true;
    }
    final total = weeks.length;
    final hit = weeks.values.where((value) => value).length;
    if (total == 0) return 0;
    return ((hit / total) * 100).round();
  }

  HomeDebriefInsights _buildDebriefInsights(List<TrainingSession> sessions) {
    final focus = <String>[];
    final attention = <String>[];
    final strength = <String>[];
    final intensities = <int>[];

    for (final session in sessions) {
      for (final entry in session.effectiveTechniqueEntries) {
        final technique = _cleanDebriefText(entry.technique);
        if (technique == null) continue;
        final position =
            _cleanDebriefText(entry.position) ??
            _cleanDebriefText(session.position);
        focus.add(position == null ? technique : '$technique em $position');
      }

      final difficulties = _cleanDebriefText(session.difficulties);
      if (difficulties != null) attention.add(difficulties);

      final successes = _cleanDebriefText(session.successes);
      if (successes != null) strength.add(successes);

      final intensity = session.intensity;
      if (intensity != null && intensity >= 1 && intensity <= 5) {
        intensities.add(intensity);
      }
    }

    final intensityAverage =
        intensities.isEmpty
            ? null
            : intensities.fold<int>(0, (sum, value) => sum + value) /
                intensities.length;

    return HomeDebriefInsights(
      technicalFocus: _mostRecurringRecent(focus),
      attentionPoint: _mostRecurringRecent(attention),
      strengthPoint: _mostRecurringRecent(strength),
      averageIntensity: intensityAverage,
    );
  }

  String? _mostRecurringRecent(List<String> values) {
    final scores = <String, _InsightScore>{};

    for (var index = 0; index < values.length; index++) {
      final value = values[index].trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      final score = scores[key];
      if (score == null) {
        scores[key] = _InsightScore(value: value, count: 1, firstIndex: index);
      } else {
        score.count += 1;
      }
    }

    _InsightScore? best;
    for (final score in scores.values) {
      if (best == null ||
          score.count > best.count ||
          (score.count == best.count && score.firstIndex < best.firstIndex)) {
        best = score;
      }
    }

    return best?.value;
  }

  String _weekKey(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDay).inDays;
    final week = (diff / 7).floor();
    return '${date.year}-$week';
  }

  String? _cleanDebriefText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class _InsightScore {
  final String value;
  final int firstIndex;
  int count;

  _InsightScore({
    required this.value,
    required this.firstIndex,
    required this.count,
  });
}