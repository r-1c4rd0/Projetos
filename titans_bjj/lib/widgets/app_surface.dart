import 'package:flutter/material.dart';
import '../core/titans_ui.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  const AppSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TitansUI.backgroundColor(context),
      child: Stack(
        children: [
          // Radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.9),
                  radius: 1.25,
                  colors: [
                    TitansUI.neonPurple.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Pattern (hex/dots fake, leve)
          Positioned.fill(
            child: CustomPaint(
              painter: _DotPatternPainter(isDark: TitansUI.isDark(context)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final bool isDark;

  const _DotPatternPainter({required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = (isDark ? Colors.white : const Color(0xFF7A6A48))
              .withValues(alpha: isDark ? 0.03 : 0.045);
    const step = 26.0;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
