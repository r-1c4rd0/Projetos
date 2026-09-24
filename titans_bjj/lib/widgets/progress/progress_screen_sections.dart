part of '../../screen/progress_screen.dart';

class ProgressScreenContent extends StatelessWidget {
  final BeltProgressSummary beltProgress;
  final TrainingMetrics metrics;
  final ProgressSeriesSummary series;
  final ConsistencyHeatmapSummary heatmap;
  final int totalInWindow;
  final ProgressPeriod period;
  final String periodTitle;
  final VoidCallback? onEditGraduation;

  const ProgressScreenContent({
    super.key,
    required this.beltProgress,
    required this.metrics,
    required this.series,
    required this.heatmap,
    required this.totalInWindow,
    required this.period,
    required this.periodTitle,
    this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    final visualBeltProgress = _BeltProgress.fromSummary(beltProgress);
    final visualSeries = _Series.fromSummary(series);
    final visualHeatmap = _ConsistencyHeatmapViewModel.fromSummary(heatmap);

    return Column(
      key: const ValueKey('progress-screen-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressBeltHero(
          progress: visualBeltProgress,
          onEditGraduation: onEditGraduation,
        ),
        const SizedBox(height: 10),
        _ProgressCompactMetrics(
          progress: visualBeltProgress,
          metrics: metrics,
          totalInWindow: totalInWindow,
          periodTitle: periodTitle,
        ),
        const SizedBox(height: 10),
        _ProgressVisualPanel(
          heatmap: visualHeatmap,
          series: visualSeries,
          totalInWindow: totalInWindow,
          period: period,
          periodTitle: periodTitle,
        ),
        const SizedBox(height: 10),
        _ProgressDetailsSection(
          metrics: metrics,
          totalInWindow: totalInWindow,
          periodTitle: periodTitle,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TitansEmptyState(
          icon: Icons.insights_outlined,
          title: title,
          message: subtitle,
          compact: true,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBeltHero extends StatelessWidget {
  final _BeltProgress progress;
  final VoidCallback? onEditGraduation;

  const _ProgressBeltHero({required this.progress, this.onEditGraduation});

  @override
  Widget build(BuildContext context) {
    final beltKey = progress.belt.name.toLowerCase();
    final beltColor = TitansUI.beltColor(beltKey);
    final beltLabel = TitansUI.beltLabel(beltKey);
    final percent = progress.percentToNextBelt.clamp(0.0, 1.0).toDouble();
    final pctText = '${(percent * 100).toStringAsFixed(0)}%';
    final sessionLabel =
        '${progress.sessionsInCurrentBelt} de ${progress.sessionsRequiredCurrentBelt} sessões';

    return glassCard(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return _ProgressBeltHeroIntegrated(
            beltLabel: beltLabel,
            degree: progress.degree,
            maxDegree: progress.maxDegree,
            sessionLabel: sessionLabel,
            hasOfficialRule: progress.hasOfficialRule,
            percent: percent,
            pctText: pctText,
            beltColor: beltColor,
            onEditGraduation: onEditGraduation,
            compact: compact,
          );
        },
      ),
      accent: beltColor.withValues(alpha: 0.32),
    );
  }
}

class _ProgressBeltHeroIntegrated extends StatelessWidget {
  final String beltLabel;
  final int degree;
  final int maxDegree;
  final String sessionLabel;
  final bool hasOfficialRule;
  final double percent;
  final String pctText;
  final Color beltColor;
  final VoidCallback? onEditGraduation;
  final bool compact;

  const _ProgressBeltHeroIntegrated({
    required this.beltLabel,
    required this.degree,
    required this.maxDegree,
    required this.sessionLabel,
    required this.hasOfficialRule,
    required this.percent,
    required this.pctText,
    required this.beltColor,
    required this.onEditGraduation,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final degreeText = degree > 0 ? '$degreeº grau' : 'Grau inicial';
    final ringSize = compact ? 128.0 : 142.0;
    final innerSize = ringSize - 28;

    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: ringSize + 22,
              height: ringSize + 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    beltColor.withValues(alpha: 0.18),
                    cs.primary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.58, 1.0],
                ),
              ),
            ),
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: compact ? 8 : 9,
                backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(beltColor),
              ),
            ),
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.34, -0.38),
                  radius: 0.98,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    beltColor.withValues(alpha: 0.14),
                    cs.surface.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
                border: Border.all(color: beltColor.withValues(alpha: 0.32)),
                boxShadow: [
                  BoxShadow(
                    color: beltColor.withValues(alpha: 0.16),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    beltLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: beltColor,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pctText,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'na faixa',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.54),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ProgressHeroChip(label: degreeText, color: beltColor),
            _ProgressHeroChip(label: sessionLabel, color: cs.primary),
            _ProgressDegreeDots(degree: degree, maxDegree: maxDegree),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          hasOfficialRule
              ? 'Sua evolução está em construção com base nos treinos registrados.'
              : 'Referência infantil pendente. Acompanhe a evolução com o professor.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.66),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(TitansUI.radiusPill),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 5,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(beltColor),
          ),
        ),
        if (onEditGraduation != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEditGraduation,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar graduação'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressHeroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ProgressHeroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.78),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProgressDegreeDots extends StatelessWidget {
  final int degree;
  final int maxDegree;

  const _ProgressDegreeDots({required this.degree, required this.maxDegree});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = maxDegree <= 0 ? 4 : maxDegree;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i < degree
                      ? TitansUI.actionGold
                      : cs.onSurface.withValues(alpha: 0.16),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ProgressCompactMetrics extends StatelessWidget {
  final _BeltProgress progress;
  final TrainingMetrics metrics;
  final int totalInWindow;
  final String periodTitle;

  const _ProgressCompactMetrics({
    required this.progress,
    required this.metrics,
    required this.totalInWindow,
    required this.periodTitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = TitansUI.beltColor(progress.belt.name.toLowerCase());
    final recentPercent =
        '${(metrics.recentFrequency * 100).toStringAsFixed(0)}%';

    return glassCard(
      context,
      TitansCompactMetricGrid(
        fourColumnMinWidth: 560,
        spacing: TitansUI.spaceXs,
        children: [
          TitansCompactMetricCard(
            label: 'NA FAIXA',
            value: progress.sessionsInCurrentBelt.toString(),
            subtitle:
                progress.hasOfficialRule
                    ? '/${progress.sessionsRequiredCurrentBelt}'
                    : 'registrados',
            color: beltColor,
          ),
          TitansCompactMetricCard(
            label: 'CONSISTÊNCIA',
            value: recentPercent,
            subtitle: '30 dias',
            color: cs.secondary,
          ),
          TitansCompactMetricCard(
            label: 'ÚLTIMO RECORTE',
            value: totalInWindow.toString(),
            subtitle: periodTitle,
            color: cs.primary,
          ),
          TitansCompactMetricCard(
            label: 'CARREIRA',
            value: metrics.total.toString(),
            subtitle: 'total',
            color: cs.onSurface.withValues(alpha: 0.70),
          ),
        ],
      ),
    );
  }
}

class _ProgressVisualPanel extends StatelessWidget {
  final _ConsistencyHeatmapViewModel heatmap;
  final _Series series;
  final int totalInWindow;
  final ProgressPeriod period;
  final String periodTitle;

  const _ProgressVisualPanel({
    required this.heatmap,
    required this.series,
    required this.totalInWindow,
    required this.period,
    required this.periodTitle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ConsistencyHeatmapCard(viewModel: heatmap),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _ConsistencyChartCard(
                      title: periodTitle,
                      totalInWindow: totalInWindow,
                      period: period,
                      labels: series.labels,
                      values: series.values,
                    ),
                  ),
                ],
              )
            else ...[
              _ConsistencyHeatmapCard(viewModel: heatmap),
              const SizedBox(height: 12),
              _ConsistencyChartCard(
                title: periodTitle,
                totalInWindow: totalInWindow,
                period: period,
                labels: series.labels,
                values: series.values,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProgressDetailsSection extends StatefulWidget {
  final TrainingMetrics metrics;
  final int totalInWindow;
  final String periodTitle;

  const _ProgressDetailsSection({
    required this.metrics,
    required this.totalInWindow,
    required this.periodTitle,
  });

  @override
  State<_ProgressDetailsSection> createState() =>
      _ProgressDetailsSectionState();
}

class _ProgressDetailsSectionState extends State<_ProgressDetailsSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leitura da evolução',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _expanded
                                ? 'Recolher detalhes'
                                : 'Abrir consistência, volume e marcos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TitansUI.spaceSm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: SizeTransition(
              sizeFactor: _heightFactor,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConsistencySummaryCard(
                      title: widget.periodTitle,
                      totalInWindow: widget.totalInWindow,
                    ),
                    const SizedBox(height: 12),
                    _TrainingMetricsCard(metrics: widget.metrics),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyHeatmapViewModel {
  final String title;
  final String subtitle;
  final List<_ConsistencyHeatmapWeek> weeks;
  final List<String> weekdayLabels;
  final List<_ConsistencyHeatmapLegendItem> legendItems;
  final int totalTrainingDays;
  final String emptyStateLabel;

  const _ConsistencyHeatmapViewModel({
    required this.title,
    required this.subtitle,
    required this.weeks,
    required this.weekdayLabels,
    required this.legendItems,
    required this.totalTrainingDays,
    required this.emptyStateLabel,
  });

  factory _ConsistencyHeatmapViewModel.fromSummary(
    ConsistencyHeatmapSummary summary,
  ) {
    return _ConsistencyHeatmapViewModel(
      title: summary.title,
      subtitle: summary.subtitle,
      weeks: summary.weeks.map(_ConsistencyHeatmapWeek.fromSummary).toList(),
      weekdayLabels: summary.weekdayLabels,
      legendItems:
          summary.legendItems
              .map(_ConsistencyHeatmapLegendItem.fromSummary)
              .toList(),
      totalTrainingDays: summary.totalTrainingDays,
      emptyStateLabel: summary.emptyStateLabel,
    );
  }
}

class _ConsistencyHeatmapWeek {
  final String label;
  final List<_ConsistencyHeatmapDay> days;

  const _ConsistencyHeatmapWeek({required this.label, required this.days});

  factory _ConsistencyHeatmapWeek.fromSummary(
    ConsistencyHeatmapWeekSummary summary,
  ) {
    return _ConsistencyHeatmapWeek(
      label: summary.label,
      days: summary.days.map(_ConsistencyHeatmapDay.fromSummary).toList(),
    );
  }
}

class _ConsistencyHeatmapDay {
  final DateTime date;
  final String dayLabel;
  final int count;
  final int intensityLevel;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isToday;
  final bool isOutsideRange;

  const _ConsistencyHeatmapDay({
    required this.date,
    required this.dayLabel,
    required this.count,
    required this.intensityLevel,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isToday,
    required this.isOutsideRange,
  });

  factory _ConsistencyHeatmapDay.fromSummary(
    ConsistencyHeatmapDaySummary summary,
  ) {
    return _ConsistencyHeatmapDay(
      date: summary.date,
      dayLabel: summary.dayLabel,
      count: summary.count,
      intensityLevel: summary.intensityLevel,
      tooltipTitle: summary.tooltipTitle,
      tooltipBody: summary.tooltipBody,
      isToday: summary.isToday,
      isOutsideRange: summary.isOutsideRange,
    );
  }
}

class _ConsistencyHeatmapLegendItem {
  final String label;
  final int intensityLevel;

  const _ConsistencyHeatmapLegendItem({
    required this.label,
    required this.intensityLevel,
  });

  factory _ConsistencyHeatmapLegendItem.fromSummary(
    ConsistencyHeatmapLegendSummary summary,
  ) {
    return _ConsistencyHeatmapLegendItem(
      label: summary.label,
      intensityLevel: summary.intensityLevel,
    );
  }
}

class _ProgressChartViewModel {
  final String title;
  final String subtitle;
  final String periodLabel;
  final List<_ProgressChartPoint> points;
  final double? averageLine;
  final String trendLabel;
  final String emptyStateLabel;

  const _ProgressChartViewModel({
    required this.title,
    required this.subtitle,
    required this.periodLabel,
    required this.points,
    required this.averageLine,
    required this.trendLabel,
    required this.emptyStateLabel,
  });
}

class _ProgressChartPoint {
  final String label;
  final int value;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isHighlighted;

  const _ProgressChartPoint({
    required this.label,
    required this.value,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isHighlighted,
  });

  _ProgressChartPoint copyWith({bool? isHighlighted}) {
    return _ProgressChartPoint(
      label: label,
      value: value,
      tooltipTitle: tooltipTitle,
      tooltipBody: tooltipBody,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}

class _Series {
  final List<String> labels;
  final List<int> values;
  _Series({required this.labels, required this.values});

  factory _Series.fromSummary(ProgressSeriesSummary summary) {
    return _Series(labels: summary.labels, values: summary.values);
  }
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;
  final int sessionsInCurrentBelt;
  final int sessionsRequiredCurrentBelt;
  final bool hasOfficialRule;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
    required this.sessionsInCurrentBelt,
    required this.sessionsRequiredCurrentBelt,
    required this.hasOfficialRule,
  });

  factory _BeltProgress.fromSummary(BeltProgressSummary summary) {
    return _BeltProgress(
      belt: summary.belt,
      degree: summary.degree,
      maxDegree: summary.maxDegree,
      percentToNextBelt: summary.percentToNextBelt,
      sessionsInCurrentBelt: summary.sessionsInCurrentBelt,
      sessionsRequiredCurrentBelt: summary.sessionsRequiredCurrentBelt,
      hasOfficialRule: summary.hasOfficialRule,
    );
  }
}
