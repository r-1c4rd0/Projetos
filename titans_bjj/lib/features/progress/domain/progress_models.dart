import '../../../model/grading_rules.dart';

class BeltProgressSummary {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;
  final int sessionsInCurrentBelt;
  final int sessionsRequiredCurrentBelt;
  final bool hasOfficialRule;

  const BeltProgressSummary({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
    required this.sessionsInCurrentBelt,
    required this.sessionsRequiredCurrentBelt,
    required this.hasOfficialRule,
  });
}

class ProgressSeriesSummary {
  final List<String> labels;
  final List<int> values;

  const ProgressSeriesSummary({required this.labels, required this.values});

  int get total => values.fold<int>(0, (sum, value) => sum + value);
}

class ConsistencyHeatmapSummary {
  final String title;
  final String subtitle;
  final List<ConsistencyHeatmapWeekSummary> weeks;
  final List<String> weekdayLabels;
  final List<ConsistencyHeatmapLegendSummary> legendItems;
  final int totalTrainingDays;
  final String emptyStateLabel;

  const ConsistencyHeatmapSummary({
    required this.title,
    required this.subtitle,
    required this.weeks,
    required this.weekdayLabels,
    required this.legendItems,
    required this.totalTrainingDays,
    required this.emptyStateLabel,
  });
}

class ConsistencyHeatmapWeekSummary {
  final String label;
  final List<ConsistencyHeatmapDaySummary> days;

  const ConsistencyHeatmapWeekSummary({
    required this.label,
    required this.days,
  });
}

class ConsistencyHeatmapDaySummary {
  final DateTime date;
  final String dayLabel;
  final int count;
  final int intensityLevel;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isToday;
  final bool isOutsideRange;

  const ConsistencyHeatmapDaySummary({
    required this.date,
    required this.dayLabel,
    required this.count,
    required this.intensityLevel,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isToday,
    required this.isOutsideRange,
  });
}

class ConsistencyHeatmapLegendSummary {
  final String label;
  final int intensityLevel;

  const ConsistencyHeatmapLegendSummary({
    required this.label,
    required this.intensityLevel,
  });
}
