import '../../../model/training_session.dart';

class TrainingTechniqueDisplayEntry {
  final String technique;
  final String? position;
  final String? applicationContext;
  final String? techniqueOutcome;
  final String? notes;

  const TrainingTechniqueDisplayEntry({
    required this.technique,
    required this.position,
    required this.applicationContext,
    required this.techniqueOutcome,
    required this.notes,
  });

  String get label {
    final positionLabel = position;
    if (positionLabel == null) return technique;
    return '$technique em $positionLabel';
  }
}

class TrainingPrimarySessionNote {
  final String label;
  final String text;

  const TrainingPrimarySessionNote({required this.label, required this.text});
}

enum TrainingHistoryContextBucket {
  academy,
  home,
  drill,
  sparring,
  competition,
}

enum TrainingHistoryResultBucket { worked, partial, review, none }

class TrainingSessionHistoryItem {
  final TrainingSession session;
  final String id;
  final DateTime date;
  final String dateLabel;
  final String contextLabel;
  final String summary;
  final List<TrainingTechniqueDisplayEntry> techniques;
  final List<String> positions;
  final List<String> techniqueNames;
  final Set<String> positionKeys;
  final Set<String> techniqueKeys;
  final Set<TrainingHistoryContextBucket> contextBuckets;
  final TrainingHistoryResultBucket resultBucket;
  final String searchText;

  const TrainingSessionHistoryItem({
    required this.session,
    required this.id,
    required this.date,
    required this.dateLabel,
    required this.contextLabel,
    required this.summary,
    required this.techniques,
    required this.positions,
    required this.techniqueNames,
    required this.positionKeys,
    required this.techniqueKeys,
    required this.contextBuckets,
    required this.resultBucket,
    required this.searchText,
  });

  int get techniqueCount => techniques.length;

  String get techniqueCountLabel {
    if (techniqueCount == 0) return 'Sem t\u00e9cnica';
    if (techniqueCount == 1) return '1 t\u00e9cnica';
    return '$techniqueCount t\u00e9cnicas';
  }
}

class TrainingOverviewSummary {
  final int total;
  final int techniques;
  final double? averageIntensity;
  final int applicationCount;

  const TrainingOverviewSummary({
    required this.total,
    required this.techniques,
    required this.averageIntensity,
    required this.applicationCount,
  });
}

enum TrainingChartPeriod { sevenDays, thirtyDays, threeMonths, twelveMonths }

enum TrainingChartAggregationMode { day, week, month }

class TrainingChartPeriodOption {
  final TrainingChartPeriod id;
  final String label;
  final TrainingChartAggregationMode aggregationMode;

  const TrainingChartPeriodOption({
    required this.id,
    required this.label,
    required this.aggregationMode,
  });

  static const defaults = [
    TrainingChartPeriodOption(
      id: TrainingChartPeriod.sevenDays,
      label: '7 dias',
      aggregationMode: TrainingChartAggregationMode.day,
    ),
    TrainingChartPeriodOption(
      id: TrainingChartPeriod.thirtyDays,
      label: '30 dias',
      aggregationMode: TrainingChartAggregationMode.week,
    ),
    TrainingChartPeriodOption(
      id: TrainingChartPeriod.threeMonths,
      label: '3 meses',
      aggregationMode: TrainingChartAggregationMode.week,
    ),
    TrainingChartPeriodOption(
      id: TrainingChartPeriod.twelveMonths,
      label: '12 meses',
      aggregationMode: TrainingChartAggregationMode.month,
    ),
  ];

  static TrainingChartPeriodOption byId(TrainingChartPeriod id) {
    return defaults.firstWhere((option) => option.id == id);
  }
}

class TrainingChartPoint {
  final DateTime date;
  final String label;
  final int value;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isHighlighted;

  const TrainingChartPoint({
    required this.date,
    required this.label,
    required this.value,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isHighlighted,
  });
}

class TrainingChartSummary {
  final String title;
  final String subtitle;
  final TrainingChartPeriod selectedPeriod;
  final List<TrainingChartPeriodOption> periods;
  final List<TrainingChartPoint> points;
  final String totalLabel;
  final String emptyStateLabel;

  const TrainingChartSummary({
    required this.title,
    required this.subtitle,
    required this.selectedPeriod,
    required this.periods,
    required this.points,
    required this.totalLabel,
    required this.emptyStateLabel,
  });

  bool get isEmpty => points.every((point) => point.value == 0);
}

class TrainingDashboardSummary {
  final List<TrainingSession> sortedSessions;
  final List<TrainingSessionHistoryItem> historyItems;
  final List<TrainingSession> periodSessions;
  final TrainingOverviewSummary overview;
  final TrainingChartSummary chart;
  final String lastTrainingLabel;

  const TrainingDashboardSummary({
    required this.sortedSessions,
    required this.historyItems,
    required this.periodSessions,
    required this.overview,
    required this.chart,
    required this.lastTrainingLabel,
  });
}
