import 'package:flutter/material.dart';

import '../core/titans_ui.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? accent;

  const AppCard({
    super.key,
    required this.child,
    this.padding = TitansUI.cardPadding,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: TitansUI.cardDecoration(context, accent: accent),
      child: child,
    );
  }
}
