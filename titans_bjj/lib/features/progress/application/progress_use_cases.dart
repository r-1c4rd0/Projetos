import '../../../model/app_user.dart';
import '../../../model/grading_rules.dart';
import '../../../model/progress_period.dart';
import '../../../model/training_session.dart';
import '../../../model/user_progress_profile.dart';
import '../../../service/training_aggregator.dart'
    show TrainingAggregator, TrainingMetrics;
import '../domain/progress_models.dart';

class GetProgressOverview {
  const GetProgressOverview();

  TrainingMetrics call(List<TrainingSession> sessions) {
    return TrainingAggregator.metrics(sessions);
  }
}

class GetBeltProgressSummary {
  const GetBeltProgressSummary();

  BeltProgressSummary call({
    required GradingRules rules,
    required AppUser athlete,
    required UserProgressProfile profile,
    required List<TrainingSession> sessions,
  }) {
    final belt = athlete.belt;
    final maxDeg = rules.maxDegrees(belt).clamp(1, 12).toInt();
    final beltStart = profile.beltStartAt;
    final sessionsInBelt =
        sessions.where((session) => !session.date.isBefore(beltStart)).length;
    final degree = athlete.degree.clamp(0, maxDeg).toInt();
    final estimated = profile.estimatedSessionsInBelt;
    final requiredByRules = rules.requiredSessions(belt);
    final hasOfficialRule = rules.hasExplicitRule(belt);
    final safeFallback = sessionsInBelt > 0 ? sessionsInBelt : maxDeg;
    final sessionsRequired =
        (requiredByRules > 0 ? requiredByRules : (estimated ?? safeFallback))
            .clamp(1, 1 << 30)
            .toInt();
    final percent =
        hasOfficialRule
            ? (sessionsInBelt / sessionsRequired).clamp(0.0, 1.0).toDouble()
            : 0.0;

    return BeltProgressSummary(
      belt: belt,
      degree: degree,
      maxDegree: maxDeg,
      percentToNextBelt: percent,
      sessionsInCurrentBelt: sessionsInBelt,
      sessionsRequiredCurrentBelt: sessionsRequired,
      hasOfficialRule: hasOfficialRule,
    );
  }
}

class GetProgressSeries {
  const GetProgressSeries();

  ProgressSeriesSummary call(
    List<TrainingSession> sessions,
    ProgressPeriod period, {
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final map = <String, int>{};
    final labels = <String>[];

    if (period == ProgressPeriod.day) {
      for (var i = 13; i >= 0; i--) {
        final date = resolvedNow.subtract(Duration(days: i));
        final label = _shortDateLabel(date);
        labels.add(label);
        map[label] = 0;
      }
    } else if (period == ProgressPeriod.month) {
      for (var i = 11; i >= 0; i--) {
        final date = DateTime(resolvedNow.year, resolvedNow.month - i, 1);
        final label = '${date.month.toString().padLeft(2, '0')}/${date.year}';
        labels.add(label);
        map[label] = 0;
      }
    } else {
      for (var i = 4; i >= 0; i--) {
        final label = (resolvedNow.year - i).toString();
        labels.add(label);
        map[label] = 0;
      }
    }

    for (final session in sessions) {
      final date = session.date;
      final key = switch (period) {
        ProgressPeriod.day => _shortDateLabel(date),
        ProgressPeriod.month =>
          '${date.month.toString().padLeft(2, '0')}/${date.year}',
        ProgressPeriod.year => date.year.toString(),
      };

      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    return ProgressSeriesSummary(
      labels: labels,
      values: labels.map((label) => map[label] ?? 0).toList(),
    );
  }
}

class GetConsistencyHeatmap {
  const GetConsistencyHeatmap();

  ConsistencyHeatmapSummary call(
    List<TrainingSession> sessions, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(const Duration(days: 83));
    final countsByDay = <String, int>{};

    for (final session in sessions) {
      final day = _dateOnly(session.date);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      final key = _heatmapDateKey(day);
      countsByDay[key] = (countsByDay[key] ?? 0) + 1;
    }

    final weeks = <ConsistencyHeatmapWeekSummary>[];
    for (var weekIndex = 0; weekIndex < 12; weekIndex++) {
      final days = <ConsistencyHeatmapDaySummary>[];
      final weekStart = start.add(Duration(days: weekIndex * 7));

      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        final date = weekStart.add(Duration(days: dayIndex));
        final count = countsByDay[_heatmapDateKey(date)] ?? 0;
        final level = count >= 3 ? 3 : count;
        final dateLabel = _shortDateLabel(date);
        final countLabel = _heatmapCountLabel(count);

        days.add(
          ConsistencyHeatmapDaySummary(
            date: date,
            dayLabel: _weekdayLabel(date.weekday),
            count: count,
            intensityLevel: level,
            tooltipTitle: _dateOnly(date) == today ? 'Hoje' : dateLabel,
            tooltipBody: countLabel,
            isToday: _dateOnly(date) == today,
            isOutsideRange: false,
          ),
        );
      }

      weeks.add(
        ConsistencyHeatmapWeekSummary(
          label: _shortDateLabel(weekStart),
          days: days,
        ),
      );
    }

    final totalTrainingDays =
        countsByDay.values.where((count) => count > 0).length;

    return ConsistencyHeatmapSummary(
      title: 'Consistência diária (últimos 84 dias)',
      subtitle:
          'Cada quadrado representa treinos registrados em um dia do recorte.',
      weeks: weeks,
      weekdayLabels: weeks.first.days.map((day) => day.dayLabel).toList(),
      legendItems: const [
        ConsistencyHeatmapLegendSummary(label: '0', intensityLevel: 0),
        ConsistencyHeatmapLegendSummary(label: '1', intensityLevel: 1),
        ConsistencyHeatmapLegendSummary(label: '2', intensityLevel: 2),
        ConsistencyHeatmapLegendSummary(label: '3+', intensityLevel: 3),
      ],
      totalTrainingDays: totalTrainingDays,
      emptyStateLabel: 'Sem treino registrado nos últimos 84 dias.',
    );
  }
}

class PrepareProgressSessions {
  const PrepareProgressSessions();

  List<TrainingSession> call(
    List<TrainingSession> sessions, {
    required GradingRules rules,
  }) {
    final unique = TrainingAggregator.uniqueSessions(
      List<TrainingSession>.from(sessions),
    );
    final filtered =
        rules.onlyAcademyPlace
            ? unique
                .where((session) => session.place == TrainingPlace.academy)
                .toList()
            : List<TrainingSession>.from(unique);

    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _heatmapDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _shortDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _weekdayLabel(int weekday) {
  const labels = <int, String>{
    DateTime.monday: 'S',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'Q',
    DateTime.thursday: 'Q',
    DateTime.friday: 'S',
    DateTime.saturday: 'S',
    DateTime.sunday: 'D',
  };
  return labels[weekday] ?? '';
}

String _heatmapCountLabel(int count) {
  if (count <= 0) return 'Sem treino registrado';
  if (count == 1) return '1 treino registrado';
  if (count == 2) return '2 treinos registrados';
  return '3+ treinos registrados';
}
