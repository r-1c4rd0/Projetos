part of '../../screen/progress_screen.dart';

class _BeltProgressCard extends StatelessWidget {
  final _BeltProgress progress;

  const _BeltProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pctText = '${(progress.percentToNextBelt * 100).toStringAsFixed(0)}%';
    final sessionLabel =
        progress.hasOfficialRule
            ? '${progress.sessionsInCurrentBelt}/${progress.sessionsRequiredCurrentBelt} sess\u00f5es na faixa atual'
            : '${progress.sessionsInCurrentBelt} treinos registrados nesta faixa';

    return TitansBeltStatusCard(
      belt: progress.belt,
      degree: progress.degree,
      maxDegree: progress.maxDegree,
      progressPercent: progress.percentToNextBelt,
      progressValueLabel: pctText,
      subtitle:
          '$sessionLabel\nBaseado em sess\u00f5es registradas nesta faixa.',
    );
  }

  static String beltName(BeltColor belt) => TitansBeltStatusCard.beltName(belt);
}

class _TrainingMetricsCard extends StatelessWidget {
  final TrainingMetrics metrics;

  const _TrainingMetricsCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recentPercent =
        '${(metrics.recentFrequency * 100).toStringAsFixed(0)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volume de treino',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Cada n\u00famero mostra um escopo temporal diferente.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansCompactMetricGrid(
              fourColumnMinWidth: 560,
              children: [
                TitansCompactMetricCard(
                  label: 'Total da carreira',
                  value: metrics.total.toString(),
                ),
                TitansCompactMetricCard(
                  label: 'Este m\u00eas',
                  value: metrics.month.toString(),
                ),
                TitansCompactMetricCard(
                  label: 'Este ano',
                  value: metrics.year.toString(),
                ),
                TitansCompactMetricCard(
                  label: '\u00daltimos 30 dias',
                  value: metrics.recent.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Frequ\u00eancia recente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            TitansCompactMetricGrid(
              fourColumnMinWidth: 420,
              children: [
                TitansCompactMetricCard(
                  label: 'Regularidade 30 dias',
                  value: recentPercent,
                  color: cs.secondary,
                ),
                TitansCompactMetricCard(
                  label: 'Treinos nos 30 dias',
                  value: metrics.recent.toString(),
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Frequ\u00eancia recente \u00e9 um subconjunto dos \u00faltimos 30 dias, separado do total da carreira.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsistencySummaryCard extends StatelessWidget {
  final String title;
  final int totalInWindow;

  const _ConsistencySummaryCard({
    required this.title,
    required this.totalInWindow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consist\u00eancia',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Consist\u00eancia usa apenas o recorte selecionado no filtro.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansCompactMetricGrid(
              fourColumnMinWidth: 420,
              children: [
                TitansCompactMetricCard(
                  label: 'Treinos no recorte',
                  value: totalInWindow.toString(),
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: 'Recorte',
                  value: title,
                  color: cs.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsistencyChartCard extends StatelessWidget {
  final String title;
  final int totalInWindow;
  final ProgressPeriod period;
  final List<String> labels;
  final List<int> values;

  const _ConsistencyChartCard({
    required this.title,
    required this.totalInWindow,
    required this.period,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = _buildViewModel();
    final hasData = viewModel.points.any((point) => point.value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Constelação de consistência',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recorte: $totalInWindow',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.subtitle,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChartChip(label: viewModel.periodLabel, color: cs.primary),
                _ChartChip(label: viewModel.trendLabel, color: cs.secondary),
                if (viewModel.averageLine != null)
                  _ChartChip(
                    label:
                        'M\u00e9dia ${viewModel.averageLine!.toStringAsFixed(1)}',
                    color: cs.tertiary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              _ChartEmptyState(
                colorScheme: cs,
                message: viewModel.emptyStateLabel,
              )
            else
              _ProgressAreaChart(viewModel: viewModel),
          ],
        ),
      ),
    );
  }

  _ProgressChartViewModel _buildViewModel() {
    final points = <_ProgressChartPoint>[
      for (var index = 0; index < labels.length; index++) _buildPoint(index),
    ];

    final maxValue = points.fold<int>(0, (max, point) {
      return point.value > max ? point.value : max;
    });
    final highlightedIndex = points.lastIndexWhere(
      (point) => point.value == maxValue && point.value > 0,
    );
    final highlightedPoints = <_ProgressChartPoint>[
      for (var index = 0; index < points.length; index++)
        points[index].copyWith(isHighlighted: index == highlightedIndex),
    ];
    final hasData = points.any((point) => point.value > 0);
    final average =
        !hasData || points.isEmpty
            ? null
            : points.fold<int>(0, (sum, point) => sum + point.value) /
                points.length;

    return _ProgressChartViewModel(
      title: 'Pulso de evolução',
      subtitle:
          'Sess\u00f5es registradas dentro do recorte selecionado. O gr\u00e1fico mostra regularidade, n\u00e3o gradua\u00e7\u00e3o.',
      periodLabel: title,
      points: highlightedPoints,
      averageLine: average,
      trendLabel: _activityLabel(values),
      emptyStateLabel:
          'Registre treinos para visualizar sua regularidade no per\u00edodo selecionado.',
    );
  }

  _ProgressChartPoint _buildPoint(int index) {
    final date = _dateForPoint(index);
    final value = index < values.length ? values[index] : 0;

    return _ProgressChartPoint(
      label: labels[index],
      value: value,
      tooltipTitle: _tooltipTitle(date),
      tooltipBody: _sessionTooltip(value),
      isHighlighted: false,
    );
  }

  DateTime _dateForPoint(int index) {
    final now = DateTime.now();
    switch (period) {
      case ProgressPeriod.day:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: labels.length - 1 - index));
      case ProgressPeriod.month:
        return DateTime(now.year, now.month - (labels.length - 1 - index), 1);
      case ProgressPeriod.year:
        return DateTime(now.year - (labels.length - 1 - index), 1, 1);
    }
  }

  String _tooltipTitle(DateTime date) {
    switch (period) {
      case ProgressPeriod.day:
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      case ProgressPeriod.month:
        return '${date.month.toString().padLeft(2, '0')}/${date.year}';
      case ProgressPeriod.year:
        return date.year.toString();
    }
  }

  static String _sessionTooltip(int count) {
    return count == 1
        ? '1 sess\u00e3o registrada'
        : '$count sess\u00f5es registradas';
  }

  static String _activityLabel(List<int> values) {
    final activePeriods = values.where((value) => value > 0).length;
    if (activePeriods == 0) return 'Sem registros no per\u00edodo';
    if (activePeriods == 1) return '1 per\u00edodo com treino';
    return '$activePeriods per\u00edodos com treino';
  }
}
