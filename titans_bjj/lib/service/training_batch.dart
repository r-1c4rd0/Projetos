// lib/service/training_batch.dart
class TrainingBatch {
  /// Gera datas entre [start] e [end] (inclusive), filtrando por dias da semana.
  /// weekdays: `Set<int>` usando DateTime.monday..DateTime.sunday
  static List<DateTime> generateDates({
    required DateTime start,
    required DateTime end,
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) {
    if (end.isBefore(start)) return [];

    final result = <DateTime>[];
    DateTime d = DateTime(start.year, start.month, start.day);

    final last = DateTime(end.year, end.month, end.day);

    while (!d.isAfter(last)) {
      if (weekdays.contains(d.weekday)) {
        result.add(DateTime(d.year, d.month, d.day, hour, minute));
      }
      d = d.add(const Duration(days: 1));
    }
    return result;
  }
}
