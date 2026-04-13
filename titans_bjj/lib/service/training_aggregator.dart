import '../model/training_session.dart';
import '../model/progress_period.dart';

class TrainingAggregator {
  /// Retorna uma lista de pontos já agregados
  /// Ex: [{x: 0, y: 2}, {x: 1, y: 4}]
  static List<int> aggregate({
    required List<TrainingSession> sessions,
    required ProgressPeriod period,
  }) {
    final now = DateTime.now();

    switch (period) {
      case ProgressPeriod.day:
        return _byDay(sessions, now);
      case ProgressPeriod.month:
        return _byMonth(sessions, now);
      case ProgressPeriod.year:
        return _byYear(sessions, now);
    }
  }

  static List<int> _byDay(List<TrainingSession> s, DateTime now) {
    // últimos 14 dias
    return List.generate(14, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));

      return s.where((e) =>
      e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day).length;
    });
  }

  static List<int> _byMonth(List<TrainingSession> s, DateTime now) {
    // últimos 12 meses
    return List.generate(12, (i) {
      final month = DateTime(now.year, now.month - (11 - i), 1);

      return s.where((e) =>
      e.date.year == month.year &&
          e.date.month == month.month).length;
    });
  }

  static List<int> _byYear(List<TrainingSession> s, DateTime now) {
    // últimos 5 anos
    return List.generate(5, (i) {
      final year = now.year - (4 - i);

      return s.where((e) => e.date.year == year).length;
    });
  }
}
