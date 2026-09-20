List<DateTime> generateRecurringDates({
  required DateTime startDate,
  required DateTime endDate,
  required Set<int> selectedWeekdays,
  DateTime? earliestDate,
  DateTime? latestDate,
}) {
  final start = _dateOnly(startDate);
  final end = _dateOnly(endDate);
  if (end.isBefore(start) || selectedWeekdays.isEmpty) {
    return const <DateTime>[];
  }

  final earliest = earliestDate == null ? null : _dateOnly(earliestDate);
  final latest = latestDate == null ? null : _dateOnly(latestDate);
  final dates = <DateTime>[];

  var current = start;
  while (!current.isAfter(end)) {
    final isInsideLowerBound = earliest == null || !current.isBefore(earliest);
    final isInsideUpperBound = latest == null || !current.isAfter(latest);
    if (selectedWeekdays.contains(current.weekday) &&
        isInsideLowerBound &&
        isInsideUpperBound) {
      dates.add(current);
    }
    current = current.add(const Duration(days: 1));
  }

  return List.unmodifiable(dates);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

class RecurrenceGenerator {
  /// Gera datas (00:00) inclusivas de start..end, filtrando por weekdays.
  /// weekdays usa DateTime.monday..DateTime.sunday
  static List<DateTime> generateDates({
    required DateTime start,
    required DateTime end,
    required Set<int> weekdays,
  }) {
    return generateRecurringDates(
      startDate: start,
      endDate: end,
      selectedWeekdays: weekdays,
    );
  }
}
