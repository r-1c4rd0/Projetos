import 'package:flutter/material.dart';

class TitansScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;

  /// When true, wraps [body] in a [SingleChildScrollView].
  final bool scroll;

  const TitansScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.padding,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: body,
    );

    if (scroll) {
      content = SingleChildScrollView(child: content);
    }

    return Scaffold(
      extendBody: true,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.85, -0.9),
            radius: 1.4,
            colors: [
              cs.primary.withValues(alpha: 0.14),
              cs.surface.withValues(alpha: 0.02),
              cs.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            // "grid/noise" simples (barato e dá textura)
            IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(
                  painter: _DotGridPainter(color: cs.onSurface.withValues(alpha: 0.9)),
                  size: Size.infinite,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        cs.surface.withValues(alpha: 0.55),
                        cs.surface.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 22.0;
    const r = 1.0;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
