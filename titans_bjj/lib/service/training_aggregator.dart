import '../model/progress_period.dart';
import '../model/training_session.dart';

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

class TrainingAggregator {
  static const int recentWindowDays = 30;

  static List<TrainingSession> uniqueSessions(List<TrainingSession> sessions) {
    final byKey = <String, TrainingSession>{};

    for (final session in sessions) {
      byKey[_dedupeKey(session)] = session;
    }

    final unique = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return unique;
  }

  static TrainingMetrics metrics(List<TrainingSession> sessions, {DateTime? now}) {
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

  static List<int> _byDay(List<TrainingSession> sessions, DateTime now) {
    return List.generate(14, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));

      return sessions.where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day).length;
    });
  }

  static List<int> _byMonth(List<TrainingSession> sessions, DateTime now) {
    return List.generate(12, (i) {
      final month = DateTime(now.year, now.month - (11 - i), 1);

      return sessions.where((e) =>
          e.date.year == month.year &&
          e.date.month == month.month).length;
    });
  }

  static List<int> _byYear(List<TrainingSession> sessions, DateTime now) {
    return List.generate(5, (i) {
      final year = now.year - (4 - i);

      return sessions.where((e) => e.date.year == year).length;
    });
  }
}