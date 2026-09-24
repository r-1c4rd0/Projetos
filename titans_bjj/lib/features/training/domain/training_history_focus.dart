import 'training_models.dart';

class TrainingHistoryFocusSelection {
  final DateTime month;
  final DateTime day;
  final String sessionId;

  const TrainingHistoryFocusSelection({
    required this.month,
    required this.day,
    required this.sessionId,
  });
}

TrainingHistoryFocusSelection? resolveTrainingHistoryFocus({
  required Iterable<TrainingSessionHistoryItem> items,
  required String? focusedSessionId,
}) {
  if (focusedSessionId == null) return null;
  for (final item in items) {
    if (item.id != focusedSessionId) continue;
    return TrainingHistoryFocusSelection(
      month: DateTime(item.date.year, item.date.month),
      day: DateTime(item.date.year, item.date.month, item.date.day),
      sessionId: item.id,
    );
  }
  return null;
}

int visibleTrainingHistoryCount({
  required Iterable<String> orderedSessionIds,
  required String? focusedSessionId,
  required int defaultVisibleCount,
}) {
  if (focusedSessionId == null) return defaultVisibleCount;

  var index = 0;
  for (final sessionId in orderedSessionIds) {
    if (sessionId == focusedSessionId) {
      final requiredCount = index + 1;
      return requiredCount > defaultVisibleCount
          ? requiredCount
          : defaultVisibleCount;
    }
    index++;
  }
  return defaultVisibleCount;
}
