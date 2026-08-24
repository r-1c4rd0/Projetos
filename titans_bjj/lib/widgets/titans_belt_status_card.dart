import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/grading_rules.dart';

class TitansBeltStatusCard extends StatelessWidget {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final String title;
  final String? subtitle;
  final double? progressPercent;
  final String progressLabel;
  final String? progressValueLabel;
  final bool compact;
  final bool showProgress;
  final bool framed;
  final VoidCallback? onEdit;

  const TitansBeltStatusCard({
    super.key,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    this.title = 'Gradua\u00e7\u00e3o atual',
    this.subtitle,
    this.progressPercent,
    this.progressLabel = 'Progresso da faixa',
    this.progressValueLabel,
    this.compact = false,
    this.showProgress = true,
    this.framed = true,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeMaxDegree = maxDegree.clamp(1, 12).toInt();
    final safeDegree = degree.clamp(0, safeMaxDegree).toInt();
    final beltColor = TitansUI.beltColor(belt.name);
    final progressValue = progressPercent?.clamp(0.0, 1.0).toDouble();
    final resolvedProgressLabel =
        progressValueLabel ?? '${((progressValue ?? 0) * 100).round()}%';

    final content = Padding(
      padding: EdgeInsets.all(framed ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : null,
                  ),
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Editar gradua\u00e7\u00e3o',
                  onPressed: onEdit,
                  icon: const Icon(Icons.military_tech_outlined),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BeltStatusChip(label: beltName(belt), color: beltColor),
              _BeltStatusChip(
                label: 'Grau $safeDegree de $safeMaxDegree',
                color: cs.primary,
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          _DegreeMarkers(
            degree: safeDegree,
            maxDegree: safeMaxDegree,
            color: beltColor,
            compact: compact,
          ),
          if (showProgress && progressValue != null) ...[
            SizedBox(height: compact ? 12 : 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    progressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.72),
                      fontSize: compact ? 12 : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  resolvedProgressLabel,
                  style: TextStyle(
                    color:
                        beltColor.computeLuminance() > 0.8
                            ? cs.onSurface
                            : beltColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TitansProgressIndicator(
              value: progressValue,
              color: beltColor,
              height: compact ? 10 : 14,
            ),
          ],
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            Text(
              subtitle!,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: compact ? 12 : null,
              ),
            ),
          ],
        ],
      ),
    );

    if (!framed) return content;

    return Card(child: content);
  }

  static String beltName(BeltColor belt) {
    return 'Faixa ${TitansUI.beltLabel(belt.name)}';
  }
}

class _BeltStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BeltStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = color.computeLuminance() > 0.8 ? cs.onSurface : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
        color: color.withValues(alpha: 0.10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DegreeMarkers extends StatelessWidget {
  final int degree;
  final int maxDegree;
  final Color color;
  final bool compact;

  const _DegreeMarkers({
    required this.degree,
    required this.maxDegree,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final markerSize = compact ? 8.0 : 10.0;

    return Wrap(
      spacing: compact ? 5 : 6,
      runSpacing: compact ? 5 : 6,
      children: List.generate(maxDegree, (index) {
        final filled = index < degree;
        return Container(
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(
              color:
                  filled
                      ? color
                      : cs.onSurface.withValues(alpha: compact ? 0.30 : 0.38),
              width: 1,
            ),
          ),
        );
      }),
    );
  }
}
