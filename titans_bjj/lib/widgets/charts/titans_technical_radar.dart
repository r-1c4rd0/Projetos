import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class TitansTechnicalRadar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String stateLabel;
  final List<TitansTechnicalRadarEvidence> evidences;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;

  const TitansTechnicalRadar({
    super.key,
    this.title = 'Radar T\u00e9cnico',
    this.subtitle = 'Evid\u00eancias t\u00e9cnicas registradas por eixo.',
    this.stateLabel = 'Perfil t\u00e9cnico em forma\u00e7\u00e3o',
    this.evidences = const [],
    this.axisEvidence = const {},
    this.classifiedEvidenceCount = 0,
    this.awaitingClassificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansPressableCard(
      accent: cs.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth < 360 ? 216.0 : 238.0;
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _TechnicalRadarEvidencePainter(
                      cs,
                      axisEvidence: axisEvidence,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _RadarStatusLabel(label: stateLabel),
          const SizedBox(height: 8),
          Text(
            'N\u00e3o representa nota ou desempenho.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _RadarEvidenceDistribution(
            axisEvidence: axisEvidence,
            classifiedEvidenceCount: classifiedEvidenceCount,
            awaitingClassificationCount: awaitingClassificationCount,
          ),
        ],
      ),
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
          'DISTRIBUI\u00c7\u00c3O DAS EVID\u00caNCIAS',
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
          '$classifiedEvidenceCount classificadas \u00b7 $awaitingClassificationCount aguardando classifica\u00e7\u00e3o',
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
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                if (active)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillFactor,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: color.withValues(alpha: 0.74),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '\u2014',
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

  const _TechnicalRadarEvidencePainter(
    this.colorScheme, {
    required this.axisEvidence,
  });

  static const _labels = <String>[
    'Reten\u00e7\u00e3o',
    'Transi\u00e7\u00e3o',
    'Controle',
    'Ataque',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final gridPaint =
        Paint()
          ..color = colorScheme.onSurface.withValues(alpha: 0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final centerPaint =
        Paint()
          ..color = colorScheme.onSurface.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;

    for (final factor in const [0.34, 0.67, 1.0]) {
      canvas.drawPath(_polygonPath(center, radius * factor), gridPaint);
    }

    canvas.drawCircle(center, 2.5, centerPaint);
    _paintEvidencePolygon(canvas, center, radius);

    for (var i = 0; i < 4; i++) {
      final axisColor = _axisColors[i];
      final point = _point(center, radius, i);
      final axisGlowPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.07)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5;
      final axisPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25;
      final nodeHaloPaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.13)
            ..style = PaintingStyle.fill;
      final nodePaint =
          Paint()
            ..color = axisColor.withValues(alpha: 0.70)
            ..style = PaintingStyle.fill;

      canvas.drawLine(center, point, axisGlowPaint);
      canvas.drawLine(center, point, axisPaint);
      canvas.drawCircle(point, 7, nodeHaloPaint);
      canvas.drawCircle(point, 3.6, nodePaint);
      _paintLabel(canvas, size, point, _labels[i], i, axisColor);
    }
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
          values[i] == 0 ? 0.0 : 0.18 + (values[i] / maxValue) * 0.72;
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
          ..color = colorScheme.tertiary.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final factor = 0.18 + (values[i] / maxValue) * 0.72;
      final point = _point(center, radius * factor, i);
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
    for (var i = 0; i < 4; i++) {
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
    final angle = -math.pi / 2 + index * math.pi / 2;
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
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 92);

    final rawOffset = switch (i) {
      0 => Offset(point.dx - textPainter.width / 2, point.dy - 24),
      1 => Offset(point.dx + 9, point.dy - textPainter.height / 2),
      2 => Offset(point.dx - textPainter.width / 2, point.dy + 10),
      _ => Offset(
        point.dx - textPainter.width - 9,
        point.dy - textPainter.height / 2,
      ),
    };
    final offset = Offset(
      rawOffset.dx.clamp(0.0, size.width - textPainter.width).toDouble(),
      rawOffset.dy.clamp(0.0, size.height - textPainter.height).toDouble(),
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TechnicalRadarEvidencePainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.axisEvidence != axisEvidence;
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
