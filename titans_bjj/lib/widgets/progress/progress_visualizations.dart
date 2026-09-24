part of '../../screen/progress_screen.dart';

class _ProgressAreaChart extends StatefulWidget {
  final _ProgressChartViewModel viewModel;

  const _ProgressAreaChart({required this.viewModel});

  @override
  State<_ProgressAreaChart> createState() => _ProgressAreaChartState();
}

class _ProgressAreaChartState extends State<_ProgressAreaChart> {
  static const _motion = TitansMotionSpec.emphasis();
  bool _entrancePlayed = false;
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _ProgressAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pointsLength = widget.viewModel.points.length;
    final selectedIndex = _selectedIndex;
    if (selectedIndex != null && selectedIndex >= pointsLength) {
      _selectedIndex = pointsLength <= 0 ? null : pointsLength - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero) {
      return _buildChart(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _entrancePlayed ? 1 : 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () {
        _entrancePlayed = true;
      },
      builder: (context, progress, child) {
        return _buildChart(context, progress.clamp(0.0, 1.0).toDouble());
      },
    );
  }

  Widget _buildChart(BuildContext context, double revealProgress) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final compact = chartWidth < 390;
        final chartHeight = compact ? 200.0 : 232.0;
        final values = viewModel.points.map((point) => point.value).toList();
        final maxY = _maxY(values);
        final leftInterval = _leftInterval(maxY);
        final bottomInterval = _bottomInterval(
          viewModel.points.length,
          chartWidth,
        );
        final spots = _spots(viewModel.points);
        final animatedSpots = _animatedSpots(spots, revealProgress);
        final currentIndex =
            viewModel.points.isEmpty ? null : viewModel.points.length - 1;
        final selectedIndex = _selectedIndex;
        final barData = _lineBarData(
          context,
          viewModel,
          animatedSpots,
          compact: compact,
          currentIndex: currentIndex,
          selectedIndex: selectedIndex,
        );

        return RepaintBoundary(
          child: SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineTouchData: _touchData(
                  context,
                  viewModel,
                  onPointSelected: _selectPoint,
                ),
                showingTooltipIndicators: _tooltipIndicators(
                  barData,
                  selectedIndex,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: leftInterval,
                  getDrawingHorizontalLine:
                      (_) => FlLine(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: compact ? 24 : 30,
                      interval: leftInterval,
                      getTitlesWidget: (v, _) {
                        if (v < 0 || v > maxY) return const SizedBox.shrink();
                        if (v != v.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.58),
                            fontSize: compact ? 10 : 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: compact ? 42 : 38,
                      interval: bottomInterval,
                      getTitlesWidget: (v, _) {
                        final idx = v.round();
                        if (v != idx.toDouble() ||
                            idx < 0 ||
                            idx >= viewModel.points.length ||
                            !_showBottomLabel(
                              idx,
                              viewModel.points.length,
                              bottomInterval,
                            )) {
                          return const SizedBox.shrink();
                        }

                        final text = viewModel.points[idx].label;
                        final rotate = compact || text.length >= 6;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Transform.rotate(
                            angle: rotate ? -0.68 : 0,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 54),
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.58),
                                  fontSize: compact ? 9 : 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [barData],
                extraLinesData:
                    viewModel.averageLine == null
                        ? null
                        : ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: viewModel.averageLine!.clamp(0, maxY),
                              color: cs.secondary.withValues(alpha: 0.42),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectPoint(int index) {
    if (index < 0 || index >= widget.viewModel.points.length) return;
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  static LineChartBarData _lineBarData(
    BuildContext context,
    _ProgressChartViewModel viewModel,
    List<FlSpot> spots, {
    required bool compact,
    required int? currentIndex,
    required int? selectedIndex,
  }) {
    final cs = Theme.of(context).colorScheme;
    final glowColor = Color.lerp(cs.primary, cs.secondary, 0.34)!;

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      barWidth: compact ? 3.0 : 3.8,
      gradient: LinearGradient(
        colors: [
          cs.primary.withValues(alpha: 0.90),
          glowColor,
          cs.secondary.withValues(alpha: 0.92),
        ],
      ),
      shadow: Shadow(color: glowColor.withValues(alpha: 0.28), blurRadius: 10),
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, _) {
          final index = spot.x.round();
          if (index < 0 || index >= viewModel.points.length) {
            return false;
          }
          return index == selectedIndex ||
              index == currentIndex ||
              viewModel.points[index].isHighlighted ||
              viewModel.points.length <= 7;
        },
        getDotPainter: (spot, percent, barData, index) {
          final selected = index == selectedIndex;
          final current = index == currentIndex;
          final highlighted =
              index >= 0 &&
              index < viewModel.points.length &&
              viewModel.points[index].isHighlighted;
          final color =
              selected
                  ? cs.tertiary
                  : highlighted || current
                  ? cs.secondary
                  : cs.primary;
          final isSpecial = selected || highlighted || current;
          return _ProgressPulseDotPainter(
            color: color,
            surfaceColor: cs.surface,
            haloColor: isSpecial ? color : glowColor,
            radius:
                selected
                    ? 5.6
                    : isSpecial
                    ? 4.8
                    : 3.2,
            haloRadius:
                selected
                    ? 11
                    : isSpecial
                    ? 9
                    : 6.5,
            haloAlpha: selected ? 0.30 : 0.18,
            strokeWidth: selected ? 2.2 : 1.7,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glowColor.withValues(alpha: 0.20),
            cs.primary.withValues(alpha: 0.055),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
      ),
    );
  }

  static LineTouchData _touchData(
    BuildContext context,
    _ProgressChartViewModel viewModel, {
    required ValueChanged<int> onPointSelected,
  }) {
    final cs = Theme.of(context).colorScheme;

    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchSpotThreshold: 18,
      touchCallback: (event, response) {
        if (!event.isInterestedForInteractions) return;
        final spots = response?.lineBarSpots;
        if (spots == null || spots.isEmpty) return;
        onPointSelected(spots.first.spotIndex);
      },
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        maxContentWidth: 160,
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tooltipMargin: 10,
        tooltipBorder: BorderSide(color: cs.primary.withValues(alpha: 0.28)),
        getTooltipColor:
            (_) => cs.surfaceContainerHighest.withValues(alpha: 0.96),
        getTooltipItems: (spots) {
          return spots.map((spot) {
            final index = spot.x.round();
            if (index < 0 || index >= viewModel.points.length) return null;
            final point = viewModel.points[index];
            return LineTooltipItem(
              '${point.tooltipTitle}\n',
              TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              textAlign: TextAlign.left,
              children: [
                TextSpan(
                  text: point.tooltipBody,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  static List<ShowingTooltipIndicators> _tooltipIndicators(
    LineChartBarData barData,
    int? selectedIndex,
  ) {
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= barData.spots.length) {
      return const [];
    }
    return [
      ShowingTooltipIndicators([
        LineBarSpot(barData, 0, barData.spots[selectedIndex]),
      ]),
    ];
  }

  static List<FlSpot> _animatedSpots(List<FlSpot> spots, double progress) {
    return spots.map((spot) => FlSpot(spot.x, spot.y * progress)).toList();
  }

  static List<FlSpot> _spots(List<_ProgressChartPoint> points) {
    return points
        .asMap()
        .entries
        .map(
          (entry) => FlSpot(entry.key.toDouble(), entry.value.value.toDouble()),
        )
        .toList();
  }

  static double _maxY(List<int> values) {
    if (values.isEmpty) return 4;
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final padded = maxValue + 1;
    return padded < 4 ? 4 : padded;
  }

  static double _leftInterval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    return 10;
  }

  static double _bottomInterval(int len, double width) {
    if (len <= 5) return 1;
    if (width < 390) return len > 10 ? 4 : 2;
    if (width < 430) return len > 10 ? 3 : 2;
    if (len <= 14) return 2;
    return 3;
  }

  static bool _showBottomLabel(int index, int len, double interval) {
    if (index == 0 || index == len - 1) return true;
    return index % interval.toInt() == 0;
  }
}

class _ProgressPulseDotPainter extends FlDotPainter {
  final Color color;
  final Color surfaceColor;
  final Color haloColor;
  final double radius;
  final double haloRadius;
  final double haloAlpha;
  final double strokeWidth;

  const _ProgressPulseDotPainter({
    required this.color,
    required this.surfaceColor,
    required this.haloColor,
    required this.radius,
    required this.haloRadius,
    required this.haloAlpha,
    required this.strokeWidth,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    canvas.drawCircle(
      offsetInCanvas,
      haloRadius,
      Paint()
        ..color = haloColor.withValues(alpha: haloAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      offsetInCanvas,
      radius + strokeWidth,
      Paint()..color = surfaceColor.withValues(alpha: 0.94),
    );
    canvas.drawCircle(offsetInCanvas, radius, Paint()..color = color);
    canvas.drawCircle(
      offsetInCanvas.translate(-radius * 0.28, -radius * 0.28),
      math.max(1.0, radius * 0.30),
      Paint()..color = Colors.white.withValues(alpha: 0.58),
    );
  }

  @override
  Size getSize(FlSpot spot) => Size.square(haloRadius * 2);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [
    color,
    surfaceColor,
    haloColor,
    radius,
    haloRadius,
    haloAlpha,
    strokeWidth,
  ];
}

class _ConsistencyHeatmapCard extends StatelessWidget {
  final _ConsistencyHeatmapViewModel viewModel;

  const _ConsistencyHeatmapCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = viewModel.totalTrainingDays > 0;

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
                if (hasData)
                  Text(
                    '${viewModel.totalTrainingDays} dias',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _ConsistencyHeatmapGrid(viewModel: viewModel),
            const SizedBox(height: 12),
            _ConsistencyHeatmapLegend(items: viewModel.legendItems),
            if (!hasData) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.emptyStateLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsistencyHeatmapGrid extends StatefulWidget {
  final _ConsistencyHeatmapViewModel viewModel;

  const _ConsistencyHeatmapGrid({required this.viewModel});

  @override
  State<_ConsistencyHeatmapGrid> createState() =>
      _ConsistencyHeatmapGridState();
}

class _ConsistencyHeatmapGridState extends State<_ConsistencyHeatmapGrid> {
  static final _motion = TitansMotionSpec.emphasis();

  bool _entrancePlayed = false;
  _ConsistencyHeatmapDay? _selectedDay;

  @override
  void didUpdateWidget(covariant _ConsistencyHeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedDay;
    if (selected == null) return;

    final stillExists = widget.viewModel.weeks.any(
      (week) => week.days.any((day) => _isSameDay(day.date, selected.date)),
    );
    if (!stillExists) _selectedDay = null;
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero || _entrancePlayed) {
      return _buildGrid(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () => _entrancePlayed = true,
      builder: (context, progress, _) => _buildGrid(context, progress),
    );
  }

  Widget _buildGrid(BuildContext context, double revealProgress) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;
    final totalCells = viewModel.weeks.fold<int>(
      0,
      (total, week) => total + week.days.length,
    );
    final progress = revealProgress.clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        const weekCount = 12;
        final compact = constraints.maxWidth < 390;
        final labelWidth = compact ? 16.0 : 20.0;
        final gap = compact ? 3.0 : 4.0;
        final availableWidth = constraints.maxWidth - labelWidth - gap;
        final rawCellSize =
            (availableWidth - (gap * (weekCount - 1))) / weekCount;
        final cellSize = rawCellSize.clamp(10.0, 20.0).toDouble();

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Padding(
                      padding: EdgeInsets.only(top: compact ? 0 : 1),
                      child: Column(
                        children: [
                          for (final label in viewModel.weekdayLabels)
                            SizedBox(
                              height: cellSize,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.46),
                                    fontSize: compact ? 8 : 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var weekIndex = 0;
                          weekIndex < viewModel.weeks.length;
                          weekIndex++
                        )
                          _ConsistencyHeatmapWeekColumn(
                            week: viewModel.weeks[weekIndex],
                            weekIndex: weekIndex,
                            totalCells: totalCells,
                            revealProgress: progress,
                            selectedDay: _selectedDay,
                            onDaySelected: _selectDay,
                            cellSize: cellSize,
                            compact: compact,
                            showLabel: _showHeatmapWeekLabel(weekIndex),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_selectedDay != null) ...[
                const SizedBox(height: 10),
                _ConsistencyHeatmapSelection(day: _selectedDay!),
              ],
            ],
          ),
        );
      },
    );
  }

  void _selectDay(_ConsistencyHeatmapDay day) {
    final selected = _selectedDay;
    if (selected != null && _isSameDay(selected.date, day.date)) return;
    setState(() => _selectedDay = day);
  }

  static bool _showHeatmapWeekLabel(int index) {
    return index == 0 || index == 11 || index % 3 == 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ConsistencyHeatmapWeekColumn extends StatelessWidget {
  final _ConsistencyHeatmapWeek week;
  final int weekIndex;
  final int totalCells;
  final double revealProgress;
  final _ConsistencyHeatmapDay? selectedDay;
  final ValueChanged<_ConsistencyHeatmapDay> onDaySelected;
  final double cellSize;
  final bool compact;
  final bool showLabel;

  const _ConsistencyHeatmapWeekColumn({
    required this.week,
    required this.weekIndex,
    required this.totalCells,
    required this.revealProgress,
    required this.selectedDay,
    required this.onDaySelected,
    required this.cellSize,
    required this.compact,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: cellSize,
      child: Column(
        children: [
          for (var dayIndex = 0; dayIndex < week.days.length; dayIndex++)
            _ConsistencyHeatmapCell(
              day: week.days[dayIndex],
              size: cellSize,
              animationProgress: _cellProgress(
                (weekIndex * 7) + dayIndex,
                totalCells,
                revealProgress,
              ),
              isSelected: _isSelected(week.days[dayIndex]),
              onTap: () => onDaySelected(week.days[dayIndex]),
            ),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: Text(
              showLabel ? week.label : '',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.40),
                fontSize: compact ? 7 : 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(_ConsistencyHeatmapDay day) {
    final selected = selectedDay;
    if (selected == null) return false;
    return selected.date.year == day.date.year &&
        selected.date.month == day.date.month &&
        selected.date.day == day.date.day;
  }

  double _cellProgress(int index, int total, double reveal) {
    if (total <= 1 || reveal >= 1) return 1;
    final start = (index / total).clamp(0.0, 1.0) * 0.42;
    final local = ((reveal - start) / (1 - start)).clamp(0.0, 1.0).toDouble();
    return Curves.easeOutCubic.transform(local);
  }
}

class _ConsistencyHeatmapCell extends StatelessWidget {
  final _ConsistencyHeatmapDay day;
  final double size;
  final double animationProgress;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConsistencyHeatmapCell({
    required this.day,
    required this.size,
    required this.animationProgress,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _cellColor(cs, day.intensityLevel);
    final borderColor =
        isSelected
            ? cs.primary.withValues(alpha: 0.94)
            : day.isToday
            ? cs.secondary.withValues(alpha: 0.88)
            : cs.onSurface.withValues(alpha: day.isOutsideRange ? 0.05 : 0.10);
    final opacity =
        (0.34 + (animationProgress * 0.66)).clamp(0.0, 1.0).toDouble();
    final scale =
        (0.70 + (animationProgress * 0.30)).clamp(0.0, 1.0).toDouble();
    final glowAlpha = _glowAlpha(day.intensityLevel, isSelected, day.isToday);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${day.dayLabel}, ${day.tooltipTitle}: ${day.tooltipBody}',
        value: day.count.toString(),
        hint: _semanticDate(day.date),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.38),
                    radius: 0.95,
                    colors: [
                      Colors.white.withValues(
                        alpha: day.intensityLevel == 0 ? 0.05 : 0.38,
                      ),
                      color,
                      color.withValues(
                        alpha: day.intensityLevel == 0 ? 0.24 : 0.88,
                      ),
                    ],
                    stops: const [0.0, 0.44, 1.0],
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || day.isToday ? 1.6 : 1,
                  ),
                  boxShadow:
                      glowAlpha <= 0
                          ? null
                          : [
                            BoxShadow(
                              color: color.withValues(alpha: glowAlpha),
                              blurRadius: isSelected ? 12 : 8,
                              spreadRadius: isSelected ? 1.2 : 0.2,
                            ),
                          ],
                ),
                child:
                    day.intensityLevel <= 0
                        ? null
                        : Center(
                          child: Container(
                            width: math.max(2.4, size * 0.22),
                            height: math.max(2.4, size * 0.22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static double _glowAlpha(int intensity, bool selected, bool today) {
    if (selected) return 0.28;
    if (today) return 0.18;
    if (intensity >= 3) return 0.16;
    if (intensity == 2) return 0.10;
    return 0;
  }

  static Color _cellColor(ColorScheme cs, int intensity) {
    switch (intensity) {
      case 0:
        return cs.surfaceContainerHighest.withValues(alpha: 0.24);
      case 1:
        return Color.lerp(
          cs.primary,
          cs.surface,
          0.34,
        )!.withValues(alpha: 0.48);
      case 2:
        return Color.lerp(
          cs.primary,
          cs.secondary,
          0.20,
        )!.withValues(alpha: 0.72);
      case 3:
        return Color.lerp(
          cs.primary,
          cs.secondary,
          0.42,
        )!.withValues(alpha: 0.92);
      default:
        return cs.primary;
    }
  }
}

class _ConsistencyHeatmapSelection extends StatelessWidget {
  final _ConsistencyHeatmapDay day;

  const _ConsistencyHeatmapSelection({required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _ConsistencyHeatmapCell._cellColor(cs, day.intensityLevel),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color:
                    day.isToday
                        ? cs.secondary.withValues(alpha: 0.86)
                        : cs.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.tooltipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.tooltipBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (day.isToday) ...[
            const SizedBox(width: 8),
            Text(
              'Hoje',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsistencyHeatmapLegend extends StatelessWidget {
  final List<_ConsistencyHeatmapLegendItem> items;

  const _ConsistencyHeatmapLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Treinos por dia',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConsistencyHeatmapLegendDot(level: item.intensityLevel),
              const SizedBox(width: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ConsistencyHeatmapLegendDot extends StatelessWidget {
  final int level;

  const _ConsistencyHeatmapLegendDot({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _ConsistencyHeatmapCell._cellColor(cs, level),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _ChartChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: TitansStatusChip(label: label, color: color, compact: true),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  final String? message;

  const _ChartEmptyState({required this.colorScheme, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_outlined, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            message ??
                'Registre treinos para visualizar sua consist\u00eancia.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'O gr\u00e1fico aparece quando houver sess\u00f5es no per\u00edodo selecionado.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
