import 'package:flutter/material.dart';
import '../core/titans_ui.dart';

class NeoCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsets padding;
  final Widget? topRight;

  const NeoCard({
    super.key,
    required this.child,
    this.glowColor,
    this.padding = const EdgeInsets.all(18),
    this.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? Theme.of(context).colorScheme.primary;
    final dark = TitansUI.isDark(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radius),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: dark ? 0.14 : 0.07),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: TitansUI.softShadowColor(context),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: TitansUI.surfaceColor(context),
          borderRadius: BorderRadius.circular(TitansUI.radius),
          border: Border.all(color: TitansUI.borderColor(context), width: 1),
        ),
        child: Stack(
          children: [
            // highlight diagonal
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TitansUI.radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      glow.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (topRight != null)
              Positioned(right: 12, top: 12, child: topRight!),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class NeoPill extends StatelessWidget {
  final String text;
  final Color color;

  const NeoPill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TitansUI.subtleFillColor(context, alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TitansUI.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: TitansUI.textSecondaryColor(
                context,
              ).withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
