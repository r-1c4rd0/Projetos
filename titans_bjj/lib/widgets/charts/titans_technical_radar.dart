import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../service/jiu_jitsu_taxonomy.dart';
import '../titans_feedback.dart';

class TitansTechnicalRadarEvidence {
  final String label;
  final String value;
  final String helper;
  final IconData icon;

  const TitansTechnicalRadarEvidence({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
  });
}

/// Radar técnico com vida contínua: varredura (sweep) rotativa, pulso no
/// preenchimento, foco por eixo ao toque e comparação "fantasma" com um
/// período anterior.
///
/// Compatível com o widget original — todos os parâmetros novos têm
/// default e não quebram quem já instancia `TitansTechnicalRadar` sem eles.
///
/// Nota de performance: `enableSweep` mantém uma animação rodando
/// indefinidamente enquanto o widget estiver montado. Em uma lista com
/// vários radares ao mesmo tempo (ex: dashboard com um card por aluno),
/// desligue com `enableSweep: false` e deixe ligado só na tela de detalhe
/// (Game Map / SkillDetail), onde há um radar só na tela.
enum TitansTechnicalRadarVariant { full, compact }

class TitansTechnicalRadar extends StatefulWidget {
  final String title;
  final String subtitle;
  final String stateLabel;
  final List<TitansTechnicalRadarEvidence> evidences;
  final Map<TechnicalRadarAxis, int> axisEvidence;

  /// Evidências do período anterior, para o polígono fantasma tracejado.
  /// Se null, o fantasma não é desenhado.
  final Map<TechnicalRadarAxis, int>? previousAxisEvidence;

  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final TitansTechnicalRadarVariant variant;
  final bool interactive;
  final bool showDistribution;
  final bool showLegend;
  final bool showGhostPolygon;
  final bool showMetrics;
  final bool showSafetyCopy;
  final bool contained;

  /// Liga a varredura rotativa contínua e o pulso de glow. Desligue em
  /// contextos de lista (ver nota de performance acima).
  final bool enableSweep;

  const TitansTechnicalRadar({
    super.key,
    this.title = 'Radar Técnico',
    this.subtitle = 'Evidências técnicas registradas por eixo.',
    this.stateLabel = 'Perfil técnico em formação',
    this.evidences = const [],
    this.axisEvidence = const {},
    this.previousAxisEvidence,
    this.classifiedEvidenceCount = 0,
    this.awaitingClassificationCount = 0,
    this.variant = TitansTechnicalRadarVariant.full,
    this.interactive = true,
    this.showDistribution = true,
    this.showLegend = true,
    this.showGhostPolygon = true,
    this.showMetrics = true,
    this.showSafetyCopy = true,
    this.contained = true,
    this.enableSweep = true,
  });

  @override
  State<TitansTechnicalRadar> createState() => _TitansTechnicalRadarState();
}

class _TitansTechnicalRadarState extends State<TitansTechnicalRadar>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop; // sweep + pulse contínuos
  int? _focusedAxisIndex;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.enableSweep) _loop.repeat();
  }

  @override
  void didUpdateWidget(covariant TitansTechnicalRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableSweep != oldWidget.enableSweep) {
      widget.enableSweep ? _loop.repeat() : _loop.stop();
    }
    if (!widget.interactive && _focusedAxisIndex != null) {
      _focusedAxisIndex = null;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, double size, double radius) {
    if (!widget.interactive) return;
    final center = Offset(size / 2, size / 2);
    final local = details.localPosition - center;
    if (local.distance > radius * 1.35) {
      if (_focusedAxisIndex != null) setState(() => _focusedAxisIndex = null);
      return;
    }
    var angle = math.atan2(local.dy, local.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final step = 2 * math.pi / _axisOrder.length;
    final index = (angle / step).round() % _axisOrder.length;
    HapticFeedback.selectionClick();
    setState(() {
      _focusedAxisIndex = _focusedAxisIndex == index ? null : index;
    });
  }

  static double _radarSizeFor(
    double maxWidth,
    TitansTechnicalRadarVariant variant,
  ) {
    if (variant == TitansTechnicalRadarVariant.compact) {
      if (maxWidth < 360) return 188.0;
      if (maxWidth < 430) return 204.0;
      return 216.0;
    }
    if (maxWidth < 360) return 214.0;
    if (maxWidth < 430) return 232.0;
    return 252.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasEvidence = widget.axisEvidence.values.any((value) => value > 0);
    final effectiveFocusedAxisIndex =
        widget.interactive ? _focusedAxisIndex : null;
    final effectivePreviousAxisEvidence =
        widget.showGhostPolygon ? widget.previousAxisEvidence : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = _radarSizeFor(constraints.maxWidth, widget.variant);
            final radius = size * 0.31;
            return Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entrance, _loop]),
                builder: (context, _) {
                  final progress = Curves.easeOutCubic.transform(
                    _entrance.value,
                  );
                  final loopValue = widget.enableSweep ? _loop.value : 0.0;
                  final pulse =
                      widget.enableSweep
                          ? 0.85 + 0.15 * math.sin(loopValue * 2 * math.pi * 3)
                          : 1.0;
                  return GestureDetector(
                    onTapUp:
                        widget.interactive
                            ? (d) => _handleTapUp(d, size, radius)
                            : null,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: CustomPaint(
                        painter: _TechnicalRadarEvidencePainter(
                          cs,
                          axisEvidence: widget.axisEvidence,
                          previousAxisEvidence: effectivePreviousAxisEvidence,
                          progress: progress,
                          sweepAngle: loopValue * 2 * math.pi,
                          pulse: pulse,
                          showSweep: widget.enableSweep,
                          focusedAxisIndex: effectiveFocusedAxisIndex,
                        ),
                        child:
                            hasEvidence ? null : const _RadarEmptyCenterLabel(),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (widget.interactive && _focusedAxisIndex != null) ...[
          const SizedBox(height: 8),
          _RadarFocusDetail(
            axis: _axisOrder[_focusedAxisIndex!],
            value: widget.axisEvidence[_axisOrder[_focusedAxisIndex!]] ?? 0,
            color: _axisColors[_focusedAxisIndex!],
          ),
        ],
        if (widget.showLegend) ...[
          const SizedBox(height: 10),
          _RadarLegend(
            items: [
              _RadarLegendItem(color: cs.tertiary, label: 'Evidências'),
              if (effectivePreviousAxisEvidence != null)
                _RadarLegendItem(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  label: 'Período anterior',
                ),
              if (widget.evidences.any(
                (item) => item.label.toLowerCase().contains('avalia'),
              ))
                _RadarLegendItem(
                  color: cs.secondary,
                  label: 'Avaliações registradas',
                ),
            ],
          ),
        ],
        if (widget.showMetrics && widget.evidences.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RadarEvidenceMetrics(items: widget.evidences),
        ],
        const SizedBox(height: 12),
        _RadarStatusLabel(label: widget.stateLabel),
        if (widget.showSafetyCopy) ...[
          const SizedBox(height: 8),
          Text(
            'Não representa nota ou desempenho.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (widget.showDistribution) ...[
          const SizedBox(height: 12),
          _RadarEvidenceDistribution(
            axisEvidence: widget.axisEvidence,
            classifiedEvidenceCount: widget.classifiedEvidenceCount,
            awaitingClassificationCount: widget.awaitingClassificationCount,
          ),
        ],
      ],
    );

    if (!widget.contained) return content;

    return TitansPressableCard(accent: cs.tertiary, child: content);
  }
}

/// Detalhe compacto mostrado abaixo do radar quando um eixo está focado.
class _RadarFocusDetail extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int value;
  final Color color;

  const _RadarFocusDetail({
    required this.axis,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              axis.displayLabel,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$value evidências',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarEmptyCenterLabel extends StatelessWidget {
  const _RadarEmptyCenterLabel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: cs.surface.withValues(alpha: 0.72),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        ),
        child: Text(
          'Sem evidências classificadas',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.66),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RadarLegendItem {
  final Color color;
  final String label;

  const _RadarLegendItem({required this.color, required this.label});
}

class _RadarLegend extends StatelessWidget {
  final List<_RadarLegendItem> items;

  const _RadarLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: item.color.withValues(alpha: 0.08),
              border: Border.all(color: item.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.82),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RadarEvidenceMetrics extends StatelessWidget {
  final List<TitansTechnicalRadarEvidence> items;

  const _RadarEvidenceMetrics({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 320;
        final width =
            twoColumns ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 70),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: cs.tertiary.withValues(alpha: 0.1),
                        ),
                        child: Icon(item.icon, size: 17, color: cs.tertiary),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.helper,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RadarStatusLabel extends StatelessWidget {
  final String label;

  const _RadarStatusLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: cs.tertiary.withValues(alpha: 0.08),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.tertiary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RadarEvidenceDistribution extends StatelessWidget {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;

  const _RadarEvidenceDistribution({
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = _axisOrder.fold<int>(0, (max, axis) {
      final value = axisEvidence[axis] ?? 0;
      return value > max ? value : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISTRIBUIÇÃO DAS EVIDÊNCIAS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        for (var i = 0; i < _distributionAxisOrder.length; i++) ...[
          _RadarEvidenceDistributionRow(
            axis: _distributionAxisOrder[i],
            value: axisEvidence[_distributionAxisOrder[i]] ?? 0,
            maxValue: maxValue,
            color: _distributionAxisColors[i],
          ),
          if (i != _distributionAxisOrder.length - 1) const SizedBox(height: 7),
        ],
        const SizedBox(height: 10),
        Text(
          '$classifiedEvidenceCount classificadas · $awaitingClassificationCount aguardando classificação',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RadarEvidenceDistributionRow extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int value;
  final int maxValue;
  final Color color;

  const _RadarEvidenceDistributionRow({
    required this.axis,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = value > 0 && maxValue > 0;
    final fillFactor =
        active ? (value / maxValue).clamp(0.08, 1.0).toDouble() : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            axis.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  active
                      ? cs.onSurface.withValues(alpha: 0.88)
                      : cs.onSurface.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? color : cs.onSurface.withValues(alpha: 0.42),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.07),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                if (active)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillFactor,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.45),
                            color.withValues(alpha: 0.9),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnicalRadarEvidencePainter extends CustomPainter {
  final ColorScheme colorScheme;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final Map<TechnicalRadarAxis, int>? previousAxisEvidence;
  final double progress;
  final double sweepAngle;
  final double pulse;
  final bool showSweep;
  final int? focusedAxisIndex;

  const _TechnicalRadarEvidencePainter(
    this.colorScheme, {
    required this.axisEvidence,
    this.previousAxisEvidence,
    required this.progress,
    this.sweepAngle = 0,
    this.pulse = 1.0,
    this.showSweep = true,
    this.focusedAxisIndex,
  });

  static const _labels = <String>[
    'Retenção',
    'Transição',
    'Controle',
    'Ataque',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.31;

    final gridPaint =
        Paint()
          ..color = colorScheme.onSurface.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final softGridPaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
    final centerPaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.32)
          ..style = PaintingStyle.fill;

    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              colorScheme.tertiary.withValues(alpha: 0.16 * pulse),
              colorScheme.tertiary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.1));
    canvas.drawCircle(center, radius * 1.08, glowPaint);

    // Varredura contínua — o "beam" clássico de radar, atrás da grade.
    _paintSweep(canvas, center, radius);

    for (final factor in const [0.2, 0.4, 0.6, 0.8, 1.0]) {
      final path = _polygonPath(center, radius * factor);
      if (factor == 1.0) canvas.drawPath(path, softGridPaint);
      canvas.drawPath(path, gridPaint);
    }

    canvas.drawCircle(center, 3, centerPaint);

    // Fantasma do período anterior, atrás do polígono atual.
    _paintGhostPolygon(canvas, center, radius);

    _paintEvidencePolygon(canvas, center, radius);

    for (var i = 0; i < _axisOrder.length; i++) {
      final isFocused = focusedAxisIndex == null || focusedAxisIndex == i;
      final dim = focusedAxisIndex != null && focusedAxisIndex != i;
      final axisColor = _axisColors[i];
      final point = _point(center, radius, i);
      final alphaMul = dim ? 0.35 : 1.0;

      final axisGlowPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.07 * alphaMul * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5;
      final axisPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.4 * alphaMul)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25;
      final nodeHaloPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.13 * alphaMul)
            ..style = PaintingStyle.fill;
      final nodePaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.7 * alphaMul)
            ..style = PaintingStyle.fill;

      canvas.drawLine(center, point, axisGlowPaint);
      canvas.drawLine(center, point, axisPaint);
      canvas.drawCircle(point, isFocused ? 7 : 6, nodeHaloPaint);
      canvas.drawCircle(point, isFocused ? 3.6 : 3.0, nodePaint);
      _paintLabel(canvas, size, point, _labels[i], i, axisColor, alphaMul);
    }
  }

  /// Feixe rotativo translúcido — o motivo visual mais reconhecível de
  /// "radar". `sweepAngle` vem de um AnimationController em loop (0 a 2π).
  void _paintSweep(Canvas canvas, Offset center, double radius) {
    if (!showSweep) return;
    if (sweepAngle == 0 && !_hasAnyEvidence()) return;
    final rect = Rect.fromCircle(center: center, radius: radius * 1.15);
    final sweepPaint =
        Paint()
          ..shader = SweepGradient(
            colors: [
              colorScheme.tertiary.withValues(alpha: 0.0),
              colorScheme.tertiary.withValues(alpha: 0.20),
              colorScheme.tertiary.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.035, 0.16],
            transform: GradientRotation(sweepAngle - math.pi / 2),
          ).createShader(rect);
    canvas.drawCircle(center, radius * 1.15, sweepPaint);
  }

  bool _hasAnyEvidence() => axisEvidence.values.any((v) => v > 0);

  /// Polígono tracejado do período anterior — mostra evolução técnica de
  /// forma visual, não só em número.
  void _paintGhostPolygon(Canvas canvas, Offset center, double radius) {
    final previous = previousAxisEvidence;
    if (previous == null) return;
    final values = _axisOrder.map((a) => previous[a] ?? 0).toList();
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxValue <= 0) return;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final factor =
          values[i] == 0
              ? 0.0
              : (0.16 + (values[i] / maxValue) * 0.78) * progress;
      final point = _point(center, radius * factor, i);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();

    final dashPaint =
        Paint()
          ..color = colorScheme.onSurface.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
    canvas.drawPath(_dashed(path, dash: 4, gap: 3), dashPaint);
  }

  Path _dashed(Path source, {required double dash, required double gap}) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dash : gap;
        final next = math.min(distance + len, metric.length);
        if (draw) out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next;
        draw = !draw;
      }
    }
    return out;
  }

  void _paintEvidencePolygon(Canvas canvas, Offset center, double radius) {
    final values = _axisValues();
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (maxValue <= 0) return;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final factor =
          values[i] == 0
              ? 0.0
              : (0.16 + (values[i] / maxValue) * 0.78) * progress;
      final point = _point(center, radius * factor, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final fillPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              colorScheme.tertiary.withValues(alpha: 0.28 * pulse),
              colorScheme.secondary.withValues(alpha: 0.1),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final haloPaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.16 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;

    canvas.drawPath(path, haloPaint);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final factor = (0.16 + (values[i] / maxValue) * 0.78) * progress;
      final point = _point(center, radius * factor, i);
      canvas.drawCircle(
        point,
        8,
        Paint()..color = _axisColors[i].withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        point,
        4.8,
        Paint()..color = _axisColors[i].withValues(alpha: 0.86),
      );
    }
  }

  List<int> _axisValues() {
    return _axisOrder.map((axis) => axisEvidence[axis] ?? 0).toList();
  }

  Path _polygonPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < _axisOrder.length; i++) {
      final point = _point(center, radius, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Offset _point(Offset center, double radius, int index) {
    final angle = -math.pi / 2 + index * math.pi * 2 / _axisOrder.length;
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Offset point,
    String label,
    int i,
    Color color,
    double alphaMul,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9 * alphaMul),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 92);

    final rawOffset = switch (i) {
      0 => Offset(point.dx - textPainter.width / 2, point.dy - 30),
      1 => Offset(point.dx + 16, point.dy - textPainter.height / 2),
      2 => Offset(point.dx - textPainter.width / 2, point.dy + 16),
      _ => Offset(
        point.dx - textPainter.width - 16,
        point.dy - textPainter.height / 2,
      ),
    };
    final offset = Offset(
      rawOffset.dx.clamp(0.0, size.width - textPainter.width).toDouble(),
      rawOffset.dy.clamp(0.0, size.height - textPainter.height).toDouble(),
    );

    final labelRect = Rect.fromLTWH(
      offset.dx - 7,
      offset.dy - 4,
      textPainter.width + 14,
      textPainter.height + 8,
    );
    final labelRRect = RRect.fromRectAndRadius(
      labelRect,
      const Radius.circular(999),
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = colorScheme.surface.withValues(alpha: 0.76 * alphaMul)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = color.withValues(alpha: 0.18 * alphaMul)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TechnicalRadarEvidencePainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.axisEvidence != axisEvidence ||
        oldDelegate.previousAxisEvidence != previousAxisEvidence ||
        oldDelegate.progress != progress ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.showSweep != showSweep ||
        oldDelegate.focusedAxisIndex != focusedAxisIndex;
  }
}

const _axisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
];

const _axisColors = <Color>[
  Color(0xFF4CC9F0),
  Color(0xFFE9C46A),
  Color(0xFFB026FF),
  Color(0xFF2D6BFF),
];

const _distributionAxisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.attack,
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
];

const _distributionAxisColors = <Color>[
  Color(0xFF2D6BFF),
  Color(0xFF4CC9F0),
  Color(0xFFE9C46A),
  Color(0xFFB026FF),
];
