import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
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

  const TitansTechnicalRadar({
    super.key,
    this.title = 'Radar T\u00e9cnico',
    this.subtitle =
        'Preview visual criado apenas com evid\u00eancias dispon\u00edveis.',
    this.stateLabel = 'Perfil t\u00e9cnico em forma\u00e7\u00e3o',
    this.evidences = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansPressableCard(
      accent: cs.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW DO RADAR',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.66),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth < 360 ? 216.0 : 238.0;
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _TechnicalRadarPreviewPainter(cs),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _RadarStatusLabel(label: stateLabel),
          const SizedBox(height: 6),
          Text(
            'Sem nota, percentual ou avalia\u00e7\u00e3o; cores apenas distinguem eixos.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (evidences.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RadarEvidenceRail(evidences: evidences),
          ],
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

class _RadarEvidenceRail extends StatelessWidget {
  final List<TitansTechnicalRadarEvidence> evidences;

  const _RadarEvidenceRail({required this.evidences});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 380 ? 136.0 : 154.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < evidences.length; i++) ...[
                SizedBox(
                  width: cardWidth,
                  child: _RadarEvidenceChip(evidence: evidences[i]),
                ),
                if (i != evidences.length - 1)
                  const SizedBox(width: TitansUI.spaceSm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RadarEvidenceChip extends StatelessWidget {
  final TitansTechnicalRadarEvidence evidence;

  const _RadarEvidenceChip({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: evidence.helper,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.22)),
          color: cs.tertiary.withValues(alpha: 0.07),
        ),
        child: Row(
          children: [
            Icon(evidence.icon, size: 16, color: cs.tertiary),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    evidence.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    evidence.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.64),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalRadarPreviewPainter extends CustomPainter {
  final ColorScheme colorScheme;

  const _TechnicalRadarPreviewPainter(this.colorScheme);

  static const _labels = <String>[
    'Reten\u00e7\u00e3o',
    'Transi\u00e7\u00e3o',
    'Controle',
    'Ataque',
  ];

  static const _axisColors = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFFE9C46A),
    Color(0xFFB026FF),
    Color(0xFF2D6BFF),
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
  bool shouldRepaint(covariant _TechnicalRadarPreviewPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
