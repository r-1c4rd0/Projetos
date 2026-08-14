import 'package:flutter/material.dart';

import '../core/titans_ui.dart';

Widget glassCard(BuildContext context, Widget child, {Color? accent}) {
  final cs = Theme.of(context).colorScheme;
  final glow = accent ?? cs.primary;

  return Container(
    padding: TitansUI.cardPadding,
    decoration: TitansUI.cardDecoration(context, accent: glow),
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TitansUI.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    glow.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}
