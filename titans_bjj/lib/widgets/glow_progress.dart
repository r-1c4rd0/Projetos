import 'package:flutter/material.dart';

class GlowProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;

  const GlowProgressBar({
    super.key,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 10, color: Colors.white.withValues(alpha: 0.08)),
          FractionallySizedBox(
            widthFactor: v,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
