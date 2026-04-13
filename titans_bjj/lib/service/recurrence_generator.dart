class RecurrenceGenerator {
  /// Gera datas (00:00) inclusivas de start..end, filtrando por weekdays.
  /// weekdays usa DateTime.monday..DateTime.sunday
  static List<DateTime> generateDates({
    required DateTime start,
    required DateTime end,
    required Set<int> weekdays,
  }) {
    if (end.isBefore(start)) return [];

    final result = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!d.isAfter(last)) {
      if (weekdays.contains(d.weekday)) {
        result.add(d);
      }
      d = d.add(const Duration(days: 1));
    }

    return result;
  }
}
