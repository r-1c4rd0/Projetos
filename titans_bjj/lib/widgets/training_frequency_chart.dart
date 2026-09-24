import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/training/domain/training_models.dart';
import 'glass_card.dart';
import 'titans_feedback.dart';

enum TrainingChartMode { bar, line, pie }

extension _TrainingChartModeUi on TrainingChartMode {
  IconData get icon {
    switch (this) {
      case TrainingChartMode.bar:
        return Icons.bar_chart_rounded;
      case TrainingChartMode.line:
        return Icons.show_chart_rounded;
      case TrainingChartMode.pie:
        return Icons.donut_large_rounded;
    }
  }
}

class _TrainingPeriodInlineSelector extends StatelessWidget {
  final TrainingChartPeriod selectedPeriod;
  final ValueChanged<TrainingChartPeriod> onChanged;

  const _TrainingPeriodInlineSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = TitansUI.navSelectedForeground(context);

    return Semantics(
      label: 'Alterar periodo',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(_nextPeriod(selectedPeriod)),
          borderRadius: BorderRadius.circular(TitansUI.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitansUI.radiusPill),
              color: TitansUI.navSelectedBackground(
                context,
              ).withValues(alpha: 0.86),
              border: Border.all(
                color: TitansUI.navBorder(context, selected: true),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.secondary.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: Text(
                _compactPeriodLabel(selectedPeriod),
                key: ValueKey(selectedPeriod),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TrainingChartPeriod _nextPeriod(TrainingChartPeriod period) {
    switch (period) {
      case TrainingChartPeriod.sevenDays:
        return TrainingChartPeriod.thirtyDays;
      case TrainingChartPeriod.thirtyDays:
        return TrainingChartPeriod.threeMonths;
      case TrainingChartPeriod.threeMonths:
        return TrainingChartPeriod.twelveMonths;
      case TrainingChartPeriod.twelveMonths:
        return TrainingChartPeriod.sevenDays;
    }
  }

  String _compactPeriodLabel(TrainingChartPeriod period) {
    switch (period) {
      case TrainingChartPeriod.sevenDays:
        return '7d';
      case TrainingChartPeriod.thirtyDays:
        return '30d';
      case TrainingChartPeriod.threeMonths:
        return '3m';
      case TrainingChartPeriod.twelveMonths:
        return '12m';
    }
  }
}

class _TrainingChartModeSwitcher extends StatelessWidget {
  final TrainingChartMode selectedMode;
  final ValueChanged<TrainingChartMode> onChanged;

  const _TrainingChartModeSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = TitansUI.navSelectedForeground(context);

    return Semantics(
      label: 'Alterar grafico',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(_nextMode(selectedMode)),
          borderRadius: BorderRadius.circular(TitansUI.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 32,
            decoration: BoxDecoration(
              color: TitansUI.navUnselectedBackground(
                context,
              ).withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(TitansUI.radiusPill),
              border: Border.all(
                color: TitansUI.navBorder(context, selected: false),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: Icon(
                selectedMode.icon,
                key: ValueKey(selectedMode),
                size: 18,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TrainingChartMode _nextMode(TrainingChartMode mode) {
    switch (mode) {
      case TrainingChartMode.bar:
        return TrainingChartMode.line;
      case TrainingChartMode.line:
        return TrainingChartMode.pie;
      case TrainingChartMode.pie:
        return TrainingChartMode.bar;
    }
  }
}

class _TrainingChartView extends StatelessWidget {
  final TrainingChartMode mode;
  final List<TrainingChartPoint> points;

  const _TrainingChartView({required this.mode, required this.points});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case TrainingChartMode.bar:
        return _TrainingBarChart(points: points);
      case TrainingChartMode.line:
        return _TrainingLineChart(points: points);
      case TrainingChartMode.pie:
        return _TrainingDonutChart(points: points);
    }
  }
}

class _TrainingLineChart extends StatelessWidget {
  final List<TrainingChartPoint> points;

  const _TrainingLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return _TrainingParticleLineChart(points: points, revealProgress: 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder:
          (context, revealProgress, _) => _TrainingParticleLineChart(
            points: points,
            revealProgress: revealProgress,
          ),
    );
  }
}

class _TrainingParticleLineChart extends StatelessWidget {
  final List<TrainingChartPoint> points;
  final double revealProgress;

  const _TrainingParticleLineChart({
    required this.points,
    required this.revealProgress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glowColor = Color.lerp(cs.primary, cs.secondary, 0.35)!;
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue < 3 ? 3.0 : (maxValue + 1.4).toDouble();
    final maxX = points.length <= 1 ? 1.0 : (points.length - 1).toDouble();
    final activeCutoff = (points.length - 1) * revealProgress;
    final visibleSpots = [
      for (var i = 0; i < points.length; i++)
        if (i <= activeCutoff || revealProgress >= 1)
          FlSpot(i.toDouble(), points[i].value.toDouble()),
    ];
    final spots = visibleSpots.isEmpty ? const [FlSpot(0, 0)] : visibleSpots;

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEvery = _trainingChartLabelEvery(
          points.length,
          constraints.maxWidth,
        );

        return RepaintBoundary(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: true,
                horizontalInterval: 1,
                verticalInterval:
                    points.length <= 7 ? 1 : labelEvery.toDouble(),
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: cs.onSurface.withValues(alpha: 0.07),
                      strokeWidth: 1,
                      dashArray: const [5, 6],
                    ),
                getDrawingVerticalLine:
                    (_) => FlLine(
                      color: cs.onSurface.withValues(alpha: 0.035),
                      strokeWidth: 1,
                    ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(
                    color: cs.onSurface.withValues(alpha: 0.12),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchSpotThreshold: 18,
                getTouchedSpotIndicator:
                    (barData, spotIndexes) => [
                      for (final _ in spotIndexes)
                        TouchedSpotIndicatorData(
                          FlLine(
                            color: glowColor.withValues(alpha: 0.34),
                            strokeWidth: 1.4,
                            dashArray: const [4, 5],
                          ),
                          FlDotData(
                            getDotPainter:
                                (spot, percent, barData, spotIndex) =>
                                    _TrainingParticleDotPainter(
                                      color: cs.secondary,
                                      surfaceColor: cs.surface,
                                      haloColor: glowColor,
                                      radius: 5.6,
                                      haloRadius: 11,
                                      haloAlpha: 0.30,
                                      strokeWidth: 1.8,
                                    ),
                          ),
                        ),
                    ],
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipRoundedRadius: 12,
                  tooltipMargin: 12,
                  maxContentWidth: 156,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  tooltipBorder: BorderSide(
                    color: cs.primary.withValues(alpha: 0.24),
                  ),
                  getTooltipColor:
                      (_) => Color.lerp(
                        cs.inverseSurface,
                        cs.primary,
                        0.08,
                      )!.withValues(alpha: 0.94),
                  getTooltipItems:
                      (spots) => [
                        for (final spot in spots)
                          if (spot.x.toInt() >= 0 &&
                              spot.x.toInt() < points.length)
                            LineTooltipItem(
                              '${points[spot.x.toInt()].tooltipTitle}\n',
                              TextStyle(
                                color: cs.onInverseSurface,
                                fontWeight: FontWeight.w900,
                              ),
                              children: [
                                TextSpan(
                                  text: points[spot.x.toInt()].tooltipBody,
                                  style: TextStyle(
                                    color: cs.onInverseSurface.withValues(
                                      alpha: 0.82,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          else
                            null,
                      ],
                ),
              ),
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
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final intValue = value.toInt();
                      if (value != intValue || intValue < 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        intValue.toString(),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.58),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final shouldShow =
                          index == points.length - 1 || index % labelEvery == 0;
                      if (!shouldShow) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          points[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.66),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.28,
                  preventCurveOverShooting: true,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  barWidth: 8,
                  color: glowColor.withValues(alpha: 0.14),
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.28,
                  preventCurveOverShooting: true,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  barWidth: 3.4,
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.88),
                      glowColor,
                      cs.secondary.withValues(alpha: 0.92),
                    ],
                  ),
                  shadow: Shadow(
                    color: glowColor.withValues(alpha: 0.34),
                    blurRadius: 10,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        glowColor.withValues(alpha: 0.16),
                        cs.primary.withValues(alpha: 0.035),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final point =
                          index >= 0 && index < points.length
                              ? points[index]
                              : points.last;
                      final isLast = index == points.length - 1;
                      final isSpecial = point.isHighlighted || isLast;

                      return _TrainingParticleDotPainter(
                        color: isSpecial ? cs.secondary : cs.primary,
                        surfaceColor: cs.surface,
                        haloColor: isSpecial ? cs.secondary : glowColor,
                        radius: isSpecial ? 4.8 : 3.2,
                        haloRadius: isSpecial ? 9.2 : 6.6,
                        haloAlpha: isSpecial ? 0.24 : 0.14,
                        strokeWidth: isSpecial ? 1.7 : 1.3,
                      );
                    },
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        );
      },
    );
  }
}

class _TrainingParticleDotPainter extends FlDotPainter {
  final Color color;
  final Color surfaceColor;
  final Color haloColor;
  final double radius;
  final double haloRadius;
  final double haloAlpha;
  final double strokeWidth;

  const _TrainingParticleDotPainter({
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
      Paint()
        ..color = surfaceColor.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      offsetInCanvas,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      offsetInCanvas.translate(-radius * 0.28, -radius * 0.28),
      math.max(1.1, radius * 0.32),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.62)
        ..style = PaintingStyle.fill,
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

class _TrainingDonutChart extends StatelessWidget {
  static final _motion = TitansMotionSpec.standard();

  final List<TrainingChartPoint> points;

  const _TrainingDonutChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, point) => sum + point.value);
    final activePoints = points.where((point) => point.value > 0).toList();

    if (total == 0 || activePoints.isEmpty) {
      return TitansEmptyState(
        icon: Icons.donut_large_rounded,
        title: 'Sem registros no período',
        message: 'Nenhum treino registrado neste período.',
        compact: true,
      );
    }

    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero) {
      return _buildOrb(context, activePoints, total, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      builder:
          (context, progress, _) => _buildOrb(
            context,
            activePoints,
            total,
            progress.clamp(0.0, 1.0).toDouble(),
          ),
    );
  }

  Widget _buildOrb(
    BuildContext context,
    List<TrainingChartPoint> activePoints,
    int total,
    double revealProgress,
  ) {
    final mostActive = activePoints.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final chartWidget = _TrainingEnergyOrb(
          points: activePoints,
          total: total,
          progress: revealProgress,
          compact: compact,
        );
        final legend = _TrainingDonutLegend(
          points: activePoints,
          mostActive: mostActive,
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chartWidget),
              const SizedBox(height: 8),
              legend,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: chartWidget),
            const SizedBox(width: 14),
            SizedBox(width: 156, child: legend),
          ],
        );
      },
    );
  }
}

class _TrainingEnergyOrb extends StatefulWidget {
  final List<TrainingChartPoint> points;
  final int total;
  final double progress;
  final bool compact;

  const _TrainingEnergyOrb({
    required this.points,
    required this.total,
    required this.progress,
    required this.compact,
  });

  @override
  State<_TrainingEnergyOrb> createState() => _TrainingEnergyOrbState();
}

class _TrainingEnergyOrbState extends State<_TrainingEnergyOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TrainingEnergyOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = widget.points.isEmpty ? null : widget.points.length - 1;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectNextSegment() {
    if (widget.points.isEmpty) return;
    setState(() {
      final selected = _selectedIndex;
      _selectedIndex =
          selected == null ? 0 : (selected + 1) % widget.points.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orbSize = widget.compact ? 92.0 : 112.0;
    final selectedPoint =
        _selectedIndex == null ? null : widget.points[_selectedIndex!];

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _selectNextSegment,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse =
                MediaQuery.disableAnimationsOf(context)
                    ? 0.0
                    : _pulseController.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(widget.compact ? 188 : 220),
                  painter: _TrainingEnergyOrbPainter(
                    points: widget.points,
                    progress: widget.progress,
                    selectedIndex: _selectedIndex,
                    pulse: pulse,
                    colorScheme: cs,
                  ),
                ),
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.34, -0.42),
                      radius: 0.94,
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        cs.primary.withValues(alpha: 0.56),
                        cs.secondary.withValues(alpha: 0.18),
                        cs.surface.withValues(alpha: 0.96),
                      ],
                      stops: const [0.0, 0.28, 0.58, 1.0],
                    ),
                    border: Border.all(
                      color: cs.secondary.withValues(alpha: 0.32),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(
                          alpha: 0.22 + pulse * 0.08,
                        ),
                        blurRadius: 24 + pulse * 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: orbSize * 0.15,
                        left: orbSize * 0.20,
                        child: Container(
                          width: orbSize * 0.28,
                          height: orbSize * 0.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.34),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (selectedPoint?.value ?? widget.total).toString(),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: widget.compact ? 22 : 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              selectedPoint?.label ?? 'Total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.66),
                                fontSize: widget.compact ? 10 : 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedPoint != null)
                  Positioned(
                    bottom: widget.compact ? 8 : 12,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: widget.compact ? 142 : 172,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(
                          TitansUI.radiusPill,
                        ),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '${selectedPoint.label}: ${selectedPoint.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.82),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrainingEnergyOrbPainter extends CustomPainter {
  final List<TrainingChartPoint> points;
  final double progress;
  final int? selectedIndex;
  final double pulse;
  final ColorScheme colorScheme;

  const _TrainingEnergyOrbPainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
    required this.pulse,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = math.min(size.width, size.height);
    final total = points.fold<int>(0, (sum, point) => sum + point.value);
    if (total <= 0) return;

    final visibleProgress = progress.clamp(0.0, 1.0).toDouble();
    final dominantIndex = points.indexWhere(
      (point) => point.value == points.map((p) => p.value).reduce(math.max),
    );
    final activeIndex = selectedIndex ?? dominantIndex;
    final outerRadius = shortest * 0.455;
    final ringRadius = shortest * 0.342;
    final innerRingRadius = shortest * 0.262;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    final innerRingRect = Rect.fromCircle(
      center: center,
      radius: innerRingRadius,
    );

    final haloPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.18 + pulse * 0.04),
              colorScheme.secondary.withValues(alpha: 0.095),
              colorScheme.surface.withValues(alpha: 0.02),
              Colors.transparent,
            ],
            stops: const [0.0, 0.38, 0.66, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, haloPaint);

    final outerGuidePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = colorScheme.primary.withValues(alpha: 0.16 + pulse * 0.04);
    final innerGuidePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colorScheme.onSurface.withValues(alpha: 0.055);
    canvas.drawCircle(center, shortest * 0.425, outerGuidePaint);
    canvas.drawCircle(center, shortest * 0.245, innerGuidePaint);

    final ghostPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.onSurface.withValues(alpha: 0.052);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, ghostPaint);

    final innerGhostPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.primary.withValues(alpha: 0.10);
    canvas.drawArc(
      innerRingRect,
      -math.pi * 0.72,
      math.pi * 1.44 * visibleProgress,
      false,
      innerGhostPaint,
    );

    var start = -math.pi / 2;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final fullSweep = (point.value / total) * math.pi * 2;
      final sweep = fullSweep * visibleProgress;
      if (sweep <= 0) {
        start += fullSweep;
        continue;
      }

      final selected = selectedIndex == i;
      final dominant = i == dominantIndex;
      final isActive = i == activeIndex;
      final baseColor = _trainingChartSliceColor(colorScheme, i);
      final stroke =
          selected
              ? 19.5
              : dominant
              ? 17.5
              : 13.5;
      final dimAlpha = selectedIndex != null && !selected ? 0.36 : 1.0;

      if (isActive) {
        final glowPaint =
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke + 9
              ..strokeCap = StrokeCap.round
              ..color = baseColor.withValues(alpha: 0.13 + pulse * 0.04)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawArc(
          ringRect,
          start + 0.034,
          math.max(0.0, sweep - 0.068),
          false,
          glowPaint,
        );
      }

      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + fullSweep,
              colors: [
                baseColor.withValues(alpha: 0.70 * dimAlpha),
                colorScheme.secondary.withValues(alpha: 0.88 * dimAlpha),
                colorScheme.primary.withValues(alpha: 0.96 * dimAlpha),
                Colors.white.withValues(
                  alpha: (isActive ? 0.62 : 0.24) * dimAlpha,
                ),
              ],
              stops: const [0.0, 0.54, 0.88, 1.0],
            ).createShader(ringRect);

      canvas.drawArc(
        ringRect,
        start + 0.034,
        math.max(0.0, sweep - 0.068),
        false,
        paint,
      );

      final markerAngle = start + sweep;
      if (isActive && visibleProgress > 0.72) {
        final markerOffset = Offset(
          center.dx + math.cos(markerAngle) * ringRadius,
          center.dy + math.sin(markerAngle) * ringRadius,
        );
        final nodePaint =
            Paint()
              ..color = colorScheme.primary.withValues(alpha: 0.88)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(markerOffset, 5.4 + pulse * 1.1, nodePaint);
        canvas.drawCircle(
          markerOffset,
          2.3,
          Paint()..color = Colors.white.withValues(alpha: 0.78),
        );
      }

      start += fullSweep;
    }

    final sweepPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.secondary.withValues(
            alpha: 0.20 + pulse * 0.08,
          );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: shortest * 0.414),
      -math.pi / 2 + pulse * math.pi * 0.18,
      math.pi * 0.46,
      false,
      sweepPaint,
    );

    for (var i = 0; i < math.min(3, points.length); i++) {
      final angle =
          -math.pi / 2 + (math.pi * 2 / math.max(1, points.length)) * i;
      final radius = shortest * (0.405 + i * 0.014);
      final particleOffset = Offset(
        center.dx + math.cos(angle + pulse * 0.08) * radius,
        center.dy + math.sin(angle + pulse * 0.08) * radius,
      );
      canvas.drawCircle(
        particleOffset,
        1.4 + (i == 0 ? pulse * 0.4 : 0),
        Paint()..color = colorScheme.secondary.withValues(alpha: 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrainingEnergyOrbPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.pulse != pulse ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _TrainingDonutLegend extends StatelessWidget {
  final List<TrainingChartPoint> points;
  final TrainingChartPoint mostActive;

  const _TrainingDonutLegend({required this.points, required this.mostActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visiblePoints = points.take(6).toList(growable: false);
    final remaining = points.length - visiblePoints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Composição do período',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${mostActive.label} - ${mostActive.value} treinos',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < visiblePoints.length; i++)
              _TrainingDonutLegendPill(point: visiblePoints[i], index: i),
            if (remaining > 0) _TrainingDonutMorePill(count: remaining),
          ],
        ),
      ],
    );
  }
}

class _TrainingDonutLegendPill extends StatelessWidget {
  final TrainingChartPoint point;
  final int index;

  const _TrainingDonutLegendPill({required this.point, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 146),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _trainingChartSliceColor(cs, index),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _trainingChartSliceColor(
                    cs,
                    index,
                  ).withValues(alpha: 0.22),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${point.label} - ${point.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.76),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingDonutMorePill extends StatelessWidget {
  final int count;

  const _TrainingDonutMorePill({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.62),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

int _trainingChartLabelEvery(int count, double width) {
  if (count <= 7) return 1;
  if (width >= 460) return 2;
  if (width >= 390) return 3;
  return 4;
}

Color _trainingChartSliceColor(ColorScheme cs, int index) {
  final colors = [cs.primary, cs.secondary, cs.tertiary, cs.error];
  return colors[index % colors.length].withValues(alpha: 0.88);
}

class _TrainingBarChart extends StatefulWidget {
  final List<TrainingChartPoint> points;

  const _TrainingBarChart({required this.points});

  @override
  State<_TrainingBarChart> createState() => _TrainingBarChartState();
}

class _TrainingBarChartState extends State<_TrainingBarChart> {
  static final _motion = TitansMotionSpec.standard();

  bool _entrancePlayed = false;
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _TrainingBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = widget.points.isEmpty ? null : widget.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero || _entrancePlayed) {
      return _buildChart(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () => _entrancePlayed = true,
      builder: (context, progress, _) => _buildChart(context, progress),
    );
  }

  Widget _buildChart(BuildContext context, double revealProgress) {
    final points = widget.points;
    final cs = Theme.of(context).colorScheme;
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue < 3 ? 3.0 : (maxValue + 1.25).toDouble();
    final progress = revealProgress.clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEvery = _labelEvery(points.length, constraints.maxWidth);
        final barWidth = _barWidth(points.length, constraints.maxWidth);

        return Semantics(
          label: 'Volume de treinos por periodo',
          child: RepaintBoundary(
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine:
                      (_) => FlLine(
                        color: cs.onSurface.withValues(alpha: 0.065),
                        strokeWidth: 1,
                        dashArray: const [5, 6],
                      ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                barTouchData: _barTouchData(cs, points),
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
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final intValue = value.toInt();
                        if (value != intValue || intValue < 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          intValue.toString(),
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.58),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final shouldShow =
                            index == points.length - 1 ||
                            index % labelEvery == 0;
                        if (!shouldShow) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            points[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.66),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      showingTooltipIndicators:
                          _selectedIndex == i ? const [0] : const [],
                      barRods: [
                        BarChartRodData(
                          toY: points[i].value.toDouble() * progress,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(9),
                            bottom: Radius.circular(2),
                          ),
                          gradient: _barGradient(cs, points[i], i),
                          borderSide: BorderSide(
                            color: _barBorderColor(cs, points[i], i),
                            width: 1.1,
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                cs.onSurface.withValues(alpha: 0.030),
                                cs.onSurface.withValues(alpha: 0.070),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        );
      },
    );
  }

  BarTouchData _barTouchData(ColorScheme cs, List<TrainingChartPoint> points) {
    return BarTouchData(
      enabled: true,
      touchCallback: (event, response) {
        if (!event.isInterestedForInteractions) return;
        final index = response?.spot?.touchedBarGroupIndex;
        if (index == null || index < 0 || index >= points.length) return;
        if (_selectedIndex == index) return;
        setState(() => _selectedIndex = index);
      },
      touchTooltipData: BarTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        tooltipRoundedRadius: 12,
        tooltipMargin: 12,
        maxContentWidth: 150,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        tooltipBorder: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        getTooltipColor:
            (_) => Color.lerp(
              cs.inverseSurface,
              cs.primary,
              0.08,
            )!.withValues(alpha: 0.94),
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          if (groupIndex < 0 || groupIndex >= points.length) {
            return null;
          }
          final point = points[groupIndex];
          return BarTooltipItem(
            '${point.tooltipTitle}\n',
            TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: point.tooltipBody,
                style: TextStyle(
                  color: cs.onInverseSurface.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  LinearGradient _barGradient(
    ColorScheme cs,
    TrainingChartPoint point,
    int index,
  ) {
    final selectedIndex = _selectedIndex;
    final isSelected = selectedIndex == index;
    final isDimmed = selectedIndex != null && !isSelected;
    final isSpecial = isSelected || point.isHighlighted;
    final topColor =
        isSelected
            ? cs.tertiary
            : isSpecial
            ? cs.secondary
            : cs.primary;
    final bottomColor = Color.lerp(cs.surface, cs.primary, 0.32)!;
    final alpha = isDimmed ? 0.42 : 1.0;

    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        bottomColor.withValues(alpha: 0.58 * alpha),
        cs.primary.withValues(alpha: 0.78 * alpha),
        topColor.withValues(alpha: 0.96 * alpha),
        Colors.white.withValues(alpha: isSpecial ? 0.72 * alpha : 0.34 * alpha),
      ],
      stops: const [0.0, 0.62, 0.90, 1.0],
    );
  }

  Color _barBorderColor(ColorScheme cs, TrainingChartPoint point, int index) {
    final selectedIndex = _selectedIndex;
    final isSelected = selectedIndex == index;
    final isDimmed = selectedIndex != null && !isSelected;
    if (isSelected) return cs.tertiary.withValues(alpha: 0.78);
    if (point.isHighlighted) {
      return cs.secondary.withValues(alpha: isDimmed ? 0.28 : 0.58);
    }
    return cs.primary.withValues(alpha: isDimmed ? 0.18 : 0.38);
  }

  int _labelEvery(int count, double width) {
    if (count <= 7) return 1;
    if (width >= 460) return 2;
    if (width >= 390) return 3;
    return 4;
  }

  double _barWidth(int count, double width) {
    if (count <= 7) return 18;
    if (count <= 10) return 14;
    if (width >= 420) return 10;
    return 8;
  }
}

class TrainingFrequencyHeroCard extends StatelessWidget {
  final TrainingChartSummary chart;
  final TrainingChartMode chartMode;
  final ValueChanged<TrainingChartPeriod> onPeriodChanged;
  final ValueChanged<TrainingChartMode> onChartModeChanged;

  const TrainingFrequencyHeroCard({
    super.key,
    required this.chart,
    required this.chartMode,
    required this.onPeriodChanged,
    required this.onChartModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 430;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequência de treino',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chart.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrainingPeriodInlineSelector(
                    selectedPeriod: chart.selectedPeriod,
                    onChanged: onPeriodChanged,
                  ),
                  const SizedBox(width: 8),
                  _TrainingChartModeSwitcher(
                    selectedMode: chartMode,
                    onChanged: onChartModeChanged,
                  ),
                ],
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 10),
                        controls,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: Text(
              chart.totalLabel,
              key: ValueKey(chart.totalLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (chart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TitansEmptyState(
                icon: chartMode.icon,
                title: 'Sem registros no período',
                message: chart.emptyStateLabel,
                compact: true,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: SizedBox(
                key: ValueKey('${chart.selectedPeriod}-$chartMode'),
                height: 280,
                child: _TrainingChartView(
                  mode: chartMode,
                  points: chart.points,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
