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
        'Preview visual sem score, criado apenas com evid\u00eancias dispon\u00edveis.',
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
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth < 360 ? 220.0 : 244.0;
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _TechnicalRadarPreviewPainter(cs),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: cs.surface.withValues(alpha: 0.72),
                          border: Border.all(
                            color: cs.tertiary.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Text(
                          stateLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final evidence in evidences)
                _RadarEvidenceChip(evidence: evidence),
            ],
          ),
        ],
      ),
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
        constraints: const BoxConstraints(minWidth: 118, maxWidth: 170),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.22)),
          color: cs.tertiary.withValues(alpha: 0.07),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(evidence.icon, size: 17, color: cs.tertiary),
            const SizedBox(width: 8),
            Flexible(
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
                      fontSize: 11,
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.32;
    final gridPaint = Paint()
      ..color = colorScheme.onSurface.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = colorScheme.tertiary.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final nodePaint = Paint()
      ..color = colorScheme.tertiary.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    for (final factor in const [0.34, 0.67, 1.0]) {
      canvas.drawPath(_polygonPath(center, radius * factor), gridPaint);
    }

    for (var i = 0; i < 4; i++) {
      final point = _point(center, radius, i);
      canvas.drawLine(center, point, axisPaint);
      canvas.drawCircle(point, 5, nodePaint);
      _paintLabel(canvas, size, point, _labels[i], i);
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

  void _paintLabel(Canvas canvas, Size size, Offset point, String label, int i) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.76),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 92);

    final offset = switch (i) {
      0 => Offset(point.dx - textPainter.width / 2, point.dy - 28),
      1 => Offset(point.dx + 10, point.dy - textPainter.height / 2),
      2 => Offset(point.dx - textPainter.width / 2, point.dy + 14),
      _ => Offset(
          point.dx - textPainter.width - 10,
          point.dy - textPainter.height / 2,
        ),
    };

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TechnicalRadarPreviewPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}