import '../../../model/training_session.dart';
import '../domain/training_models.dart';

class GetTrainingDashboardSummary {
  final PrepareTrainingHistoryItems prepareHistoryItems;
  final GetTrainingSeries getTrainingSeries;
  final GetTrainingOverview getTrainingOverview;

  const GetTrainingDashboardSummary({
    this.prepareHistoryItems = const PrepareTrainingHistoryItems(),
    this.getTrainingSeries = const GetTrainingSeries(),
    this.getTrainingOverview = const GetTrainingOverview(),
  });

  TrainingDashboardSummary call(
    List<TrainingSession> sessions, {
    required TrainingChartPeriod selectedPeriod,
    DateTime? now,
  }) {
    final sortedSessions = List<TrainingSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final historyItems = prepareHistoryItems(sessions);
    final periodSessions = filterSessionsForChartPeriod(
      sortedSessions,
      selectedPeriod,
      now: now,
    );

    return TrainingDashboardSummary(
      sortedSessions: List<TrainingSession>.unmodifiable(sortedSessions),
      historyItems: historyItems,
      periodSessions: List<TrainingSession>.unmodifiable(periodSessions),
      overview: getTrainingOverview(periodSessions),
      chart: getTrainingSeries(
        sortedSessions,
        selectedPeriod: selectedPeriod,
        now: now,
      ),
      lastTrainingLabel:
          sortedSessions.isEmpty
              ? 'Último treino: sem registro'
              : 'Último treino: ${smartDateLabel(sortedSessions.last.date)}',
    );
  }
}

class PrepareTrainingHistoryItems {
  const PrepareTrainingHistoryItems();

  List<TrainingSessionHistoryItem> call(List<TrainingSession> sessions) {
    final sorted = List<TrainingSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return List<TrainingSessionHistoryItem>.unmodifiable(
      sorted.map(trainingSessionHistoryItemFromSession),
    );
  }
}

class GetTrainingOverview {
  const GetTrainingOverview();

  TrainingOverviewSummary call(List<TrainingSession> sessions) {
    final techniqueKeys = <String>{};
    var intensitySum = 0;
    var intensityCount = 0;
    var applicationCount = 0;

    for (final session in sessions) {
      for (final entry in session.effectiveTechniqueEntries) {
        final technique = cleanTrainingDisplayText(entry.technique);
        if (technique != null) techniqueKeys.add(technique.toLowerCase());
      }

      final intensity = session.intensity;
      if (intensity != null && intensity >= 1 && intensity <= 5) {
        intensitySum += intensity;
        intensityCount++;
      }

      if (sessionHasMeasuredApplication(session)) {
        applicationCount++;
      }
    }

    return TrainingOverviewSummary(
      total: sessions.length,
      techniques: techniqueKeys.length,
      averageIntensity:
          intensityCount == 0 ? null : intensitySum / intensityCount,
      applicationCount: applicationCount,
    );
  }
}

class GetTrainingSeries {
  const GetTrainingSeries();

  TrainingChartSummary call(
    List<TrainingSession> sessions, {
    required TrainingChartPeriod selectedPeriod,
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final option = TrainingChartPeriodOption.byId(selectedPeriod);
    final window = TrainingChartWindow.forPeriod(selectedPeriod, resolvedNow);
    final buckets = TrainingChartBucket.build(window, option.aggregationMode);
    final counts = {for (final bucket in buckets) bucket.key: 0};

    for (final session in sessions) {
      final date = dateOnly(session.date);
      if (date.isBefore(window.start) || date.isAfter(window.end)) continue;
      final key = TrainingChartBucket.keyFor(
        date,
        window,
        option.aggregationMode,
      );
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final maxValue = counts.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final points = [
      for (final bucket in buckets)
        TrainingChartPoint(
          date: bucket.date,
          label: bucket.label,
          value: counts[bucket.key] ?? 0,
          tooltipTitle: bucket.tooltipTitle,
          tooltipBody: trainingCountLabel(counts[bucket.key] ?? 0),
          isHighlighted: maxValue > 0 && counts[bucket.key] == maxValue,
        ),
    ];
    final total = points.fold<int>(0, (sum, point) => sum + point.value);

    return TrainingChartSummary(
      title: 'Treinos registrados',
      subtitle: _subtitleFor(option),
      selectedPeriod: selectedPeriod,
      periods: TrainingChartPeriodOption.defaults,
      points: points,
      totalLabel: 'Total no período: ${trainingCountLabel(total)}',
      emptyStateLabel: 'Nenhum treino registrado neste período.',
    );
  }

  String _subtitleFor(TrainingChartPeriodOption option) {
    switch (option.aggregationMode) {
      case TrainingChartAggregationMode.day:
        return 'Contagem por dia, usando apenas datas dos treinos.';
      case TrainingChartAggregationMode.week:
        return 'Contagem por semana, usando apenas datas dos treinos.';
      case TrainingChartAggregationMode.month:
        return 'Contagem por mês, usando apenas datas dos treinos.';
    }
  }
}

List<TrainingSession> filterSessionsForChartPeriod(
  List<TrainingSession> sessions,
  TrainingChartPeriod period, {
  DateTime? now,
}) {
  final window = TrainingChartWindow.forPeriod(period, now ?? DateTime.now());
  return sessions.where((session) {
    final date = dateOnly(session.date);
    return !date.isBefore(window.start) && !date.isAfter(window.end);
  }).toList();
}

TrainingSessionHistoryItem trainingSessionHistoryItemFromSession(
  TrainingSession session,
) {
  final techniques = List<TrainingTechniqueDisplayEntry>.unmodifiable(
    trainingTechniqueDisplayEntries(session),
  );
  final dateLabel = smartDateLabel(session.date);
  final primaryNote = primarySessionNote(session);
  final summary =
      primaryNote?.text ??
      cleanTrainingDisplayText(session.notes) ??
      'Sem resumo informado';
  final contextLabel = sessionContextLabel(session, techniques);
  final positions = dedupeTrainingDisplayValues(
    techniques.map((entry) => entry.position).whereType<String>(),
  );
  final techniqueNames = dedupeTrainingDisplayValues(
    techniques.map((entry) => entry.technique),
  );
  final searchParts = <String>[
    dateLabel,
    placeLabel(session.place),
    contextLabel,
    summary,
    if (session.notes != null) session.notes!,
    if (session.successes != null) session.successes!,
    if (session.difficulties != null) session.difficulties!,
    if (session.debriefNotes != null) session.debriefNotes!,
    for (final entry in techniques) ...[
      entry.technique,
      if (entry.position != null) entry.position!,
      if (entry.applicationContext != null)
        applicationContextLabel(entry.applicationContext) ??
            entry.applicationContext!,
      if (entry.techniqueOutcome != null)
        techniqueOutcomeLabel(entry.techniqueOutcome) ??
            entry.techniqueOutcome!,
      if (entry.notes != null) entry.notes!,
    ],
  ];

  return TrainingSessionHistoryItem(
    session: session,
    id: session.id,
    date: session.date,
    dateLabel: dateLabel,
    contextLabel: contextLabel,
    summary: summary,
    techniques: techniques,
    positions: positions,
    techniqueNames: techniqueNames,
    positionKeys: positions.map(trainingHistoryKey).toSet(),
    techniqueKeys: techniqueNames.map(trainingHistoryKey).toSet(),
    contextBuckets: contextBucketsFor(session, techniques),
    resultBucket: resultBucketFor(techniques),
    searchText: searchParts.map(trainingHistoryKey).join(' '),
  );
}

List<TrainingTechniqueDisplayEntry> trainingTechniqueDisplayEntries(
  TrainingSession session,
) {
  return [
    for (final entry in session.effectiveTechniqueEntries)
      if (cleanTrainingDisplayText(entry.technique) != null)
        TrainingTechniqueDisplayEntry(
          technique: cleanTrainingDisplayText(entry.technique)!,
          position:
              cleanTrainingDisplayText(entry.position) ??
              cleanTrainingDisplayText(session.position),
          applicationContext:
              cleanTrainingDisplayText(entry.applicationContext) ??
              cleanTrainingDisplayText(session.applicationContext),
          techniqueOutcome:
              cleanTrainingDisplayText(entry.techniqueOutcome) ??
              cleanTrainingDisplayText(session.techniqueOutcome),
          notes: cleanTrainingDisplayText(entry.notes),
        ),
  ];
}

List<String> dedupeTrainingDisplayValues(Iterable<String> values) {
  final byKey = <String, String>{};
  for (final value in values) {
    final clean = cleanTrainingDisplayText(value);
    if (clean == null) continue;
    byKey.putIfAbsent(trainingHistoryKey(clean), () => clean);
  }
  return List<String>.unmodifiable(byKey.values);
}

String trainingHistoryKey(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

Set<TrainingHistoryContextBucket> contextBucketsFor(
  TrainingSession session,
  List<TrainingTechniqueDisplayEntry> techniques,
) {
  final buckets = <TrainingHistoryContextBucket>{};
  switch (session.place) {
    case TrainingPlace.academy:
      buckets.add(TrainingHistoryContextBucket.academy);
      break;
    case TrainingPlace.home:
      buckets.add(TrainingHistoryContextBucket.home);
      break;
    case TrainingPlace.other:
      break;
  }

  for (final entry in techniques) {
    switch (entry.applicationContext) {
      case TrainingSession.applicationContextDrill:
        buckets.add(TrainingHistoryContextBucket.drill);
        break;
      case TrainingSession.applicationContextPositionalSparring:
      case TrainingSession.applicationContextSparring:
        buckets.add(TrainingHistoryContextBucket.sparring);
        break;
      case TrainingSession.applicationContextCompetition:
        buckets.add(TrainingHistoryContextBucket.competition);
        break;
    }
  }

  return buckets;
}

TrainingHistoryResultBucket resultBucketFor(
  List<TrainingTechniqueDisplayEntry> techniques,
) {
  var hasPartial = false;
  var hasReview = false;

  for (final entry in techniques) {
    switch (entry.techniqueOutcome) {
      case TrainingSession.techniqueOutcomeWorked:
        return TrainingHistoryResultBucket.worked;
      case TrainingSession.techniqueOutcomeAlmost:
        hasPartial = true;
        break;
      case TrainingSession.techniqueOutcomeFailed:
      case TrainingSession.techniqueOutcomeDefended:
        hasReview = true;
        break;
    }
  }

  if (hasPartial) return TrainingHistoryResultBucket.partial;
  if (hasReview) return TrainingHistoryResultBucket.review;
  return TrainingHistoryResultBucket.none;
}

bool matchesTrainingHistoryPeriod(
  DateTime date,
  TrainingHistoryPeriod period,
  DateTime now,
) {
  final day = dateOnly(date);
  final today = dateOnly(now);
  final start = switch (period) {
    TrainingHistoryPeriod.sevenDays => today.subtract(const Duration(days: 6)),
    TrainingHistoryPeriod.thirtyDays => today.subtract(
      const Duration(days: 29),
    ),
    TrainingHistoryPeriod.threeMonths => DateTime(
      today.year,
      today.month - 2,
      1,
    ),
    TrainingHistoryPeriod.all => null,
  };

  if (start == null) return true;
  return !day.isBefore(start) && !day.isAfter(today);
}

enum TrainingHistoryPeriod { sevenDays, thirtyDays, threeMonths, all }

String sessionContextLabel(
  TrainingSession session,
  List<TrainingTechniqueDisplayEntry> techniques,
) {
  final place = placeLabel(session.place);

  for (final entry in techniques) {
    final context = applicationContextLabel(entry.applicationContext);
    if (context != null) return '$place - $context';
  }

  return place;
}

TrainingPrimarySessionNote? primarySessionNote(TrainingSession session) {
  final difficulty = cleanTrainingDisplayText(session.difficulties);
  if (difficulty != null) {
    return TrainingPrimarySessionNote(label: 'Dificuldade:', text: difficulty);
  }

  final success = cleanTrainingDisplayText(session.successes);
  if (success != null) {
    return TrainingPrimarySessionNote(label: 'Sucesso:', text: success);
  }

  final debrief = cleanTrainingDisplayText(session.debriefNotes);
  if (debrief != null) {
    return TrainingPrimarySessionNote(label: 'Debrief:', text: debrief);
  }

  final notes = cleanTrainingDisplayText(session.notes);
  if (notes != null) {
    return TrainingPrimarySessionNote(label: 'Nota:', text: notes);
  }

  return null;
}

String? cleanTrainingDisplayText(String? value) {
  final clean = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean == null || clean.isEmpty) return null;
  final normalized = clean.toLowerCase();
  if (normalized == 'unknown' ||
      normalized == 'n/a' ||
      normalized == 'na' ||
      normalized == 'null') {
    return null;
  }
  return clean;
}

String smartDateLabel(DateTime date) {
  final base = '${fmt2(date.day)} ${monthLabel(date.month)} ${date.year}';
  if (date.hour == 0 && date.minute == 0) return base;
  return '$base ${fmt2(date.hour)}:${fmt2(date.minute)}';
}

String fmt2(int value) => value.toString().padLeft(2, '0');

String monthLabel(int month) {
  const labels = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  final index = (month - 1).clamp(0, labels.length - 1).toInt();
  return labels[index];
}

String placeLabel(TrainingPlace place) {
  switch (place) {
    case TrainingPlace.academy:
      return 'Academia';
    case TrainingPlace.home:
      return 'Casa';
    case TrainingPlace.other:
      return 'Outro local';
  }
}

String? applicationContextLabel(String? value) {
  return TrainingSession.applicationContextLabel(value);
}

String? techniqueOutcomeLabel(String? value) {
  return TrainingSession.techniqueOutcomeLabel(value);
}

bool sessionHasMeasuredApplication(TrainingSession session) {
  for (final entry in session.effectiveTechniqueEntries) {
    final applicationContext =
        cleanTrainingDisplayText(entry.applicationContext) ??
        cleanTrainingDisplayText(session.applicationContext);
    final techniqueOutcome =
        cleanTrainingDisplayText(entry.techniqueOutcome) ??
        cleanTrainingDisplayText(session.techniqueOutcome);
    if (TrainingSession.isApplicationContextMeasured(applicationContext) ||
        TrainingSession.isTechniqueOutcomeUseful(techniqueOutcome)) {
      return true;
    }
  }
  return false;
}

String trainingCountLabel(int count) {
  if (count == 1) return '1 treino registrado';
  return '$count treinos registrados';
}

class TrainingChartWindow {
  final DateTime start;
  final DateTime end;

  const TrainingChartWindow({required this.start, required this.end});

  static TrainingChartWindow forPeriod(
    TrainingChartPeriod period,
    DateTime now,
  ) {
    final today = dateOnly(now);
    final start = switch (period) {
      TrainingChartPeriod.sevenDays => today.subtract(const Duration(days: 6)),
      TrainingChartPeriod.thirtyDays => today.subtract(
        const Duration(days: 29),
      ),
      TrainingChartPeriod.threeMonths => DateTime(
        today.year,
        today.month - 2,
        1,
      ),
      TrainingChartPeriod.twelveMonths => DateTime(
        today.year,
        today.month - 11,
        1,
      ),
    };
    return TrainingChartWindow(start: start, end: today);
  }
}

class TrainingChartBucket {
  final DateTime date;
  final String key;
  final String label;
  final String tooltipTitle;

  const TrainingChartBucket({
    required this.date,
    required this.key,
    required this.label,
    required this.tooltipTitle,
  });

  static List<TrainingChartBucket> build(
    TrainingChartWindow window,
    TrainingChartAggregationMode mode,
  ) {
    switch (mode) {
      case TrainingChartAggregationMode.day:
        return _dayBuckets(window);
      case TrainingChartAggregationMode.week:
        return _weekBuckets(window);
      case TrainingChartAggregationMode.month:
        return _monthBuckets(window);
    }
  }

  static String keyFor(
    DateTime date,
    TrainingChartWindow window,
    TrainingChartAggregationMode mode,
  ) {
    switch (mode) {
      case TrainingChartAggregationMode.day:
        return _dayKey(date);
      case TrainingChartAggregationMode.week:
        final offset = date.difference(window.start).inDays ~/ 7;
        return _dayKey(window.start.add(Duration(days: offset * 7)));
      case TrainingChartAggregationMode.month:
        return _monthKey(date);
    }
  }

  static List<TrainingChartBucket> _dayBuckets(TrainingChartWindow window) {
    final buckets = <TrainingChartBucket>[];
    var cursor = window.start;
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        TrainingChartBucket(
          date: cursor,
          key: _dayKey(cursor),
          label: shortDayLabel(cursor),
          tooltipTitle: shortDayLabel(cursor),
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return buckets;
  }

  static List<TrainingChartBucket> _weekBuckets(TrainingChartWindow window) {
    final buckets = <TrainingChartBucket>[];
    var cursor = window.start;
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        TrainingChartBucket(
          date: cursor,
          key: _dayKey(cursor),
          label: shortDayLabel(cursor),
          tooltipTitle: 'Semana ${shortDayLabel(cursor)}',
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }
    return buckets;
  }

  static List<TrainingChartBucket> _monthBuckets(TrainingChartWindow window) {
    final buckets = <TrainingChartBucket>[];
    var cursor = DateTime(window.start.year, window.start.month, 1);
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        TrainingChartBucket(
          date: cursor,
          key: _monthKey(cursor),
          label: monthYearLabel(cursor),
          tooltipTitle: monthYearLabel(cursor),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return buckets;
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${fmt2(date.month)}-${fmt2(date.day)}';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${fmt2(date.month)}';
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String shortDayLabel(DateTime date) {
  return '${fmt2(date.day)}/${fmt2(date.month)}';
}

String monthYearLabel(DateTime date) {
  return '${monthLabel(date.month)} ${date.year}';
}
