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
