import 'package:flutter/material.dart';

import '../core/titans_theme.dart';

class TitansScaffold extends StatelessWidget {
  static const double _fabScreenMargin = 16;
  static const double _homeNavigationBarHeight = 72;

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;

  /// When true, wraps [body] in a [SingleChildScrollView].
  final bool scroll;

  /// Bottom margin for FAB to avoid overlapping with bottom navigation or safe area.
  /// Used to position FAB above NavigationBar in HomeShell layout.
  final double floatingActionButtonMarginBottom;

  /// Keeps FABs above HomeShell's NavigationBar when the parent Scaffold uses extendBody.
  final bool avoidBottomNavigationBarOverlap;

  const TitansScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.padding,
    this.scroll = false,
    this.floatingActionButtonMarginBottom = 0,
    this.avoidBottomNavigationBarOverlap = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tc = titansColors(context);
    final media = MediaQuery.of(context);
    final defaultFabBottomOffset =
        media.viewPadding.bottom + _homeNavigationBarHeight;
    final fabBottomOffset =
        floatingActionButtonMarginBottom > 0
            ? floatingActionButtonMarginBottom
            : avoidBottomNavigationBarOverlap && floatingActionButton != null
            ? defaultFabBottomOffset
            : 0.0;

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: body,
    );

    if (scroll) {
      content = SingleChildScrollView(child: content);
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation:
          fabBottomOffset > 0
              ? _TitansFabLocation(bottomOffset: fabBottomOffset)
              : null,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: tc.background,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tc.background,
              Color.lerp(tc.background, cs.secondary, 0.08)!,
              Color.lerp(tc.background, cs.tertiary, 0.05)!,
              tc.background,
            ],
            stops: const [0, 0.38, 0.72, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.9, -0.95),
                      radius: 1.15,
                      colors: [
                        tc.accent.withValues(alpha: 0.10),
                        cs.secondary.withValues(alpha: 0.045),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
            ),
            // "grid/noise" simples (barato e da textura)
            IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(
                  painter: _DotGridPainter(
                    color: tc.textPrimary.withValues(alpha: 0.75),
                  ),
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
                        tc.background.withValues(alpha: 0.74),
                        tc.background.withValues(alpha: 0.96),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(bottom: false, child: content),
          ],
        ),
      ),
    );
  }
}

class _TitansFabLocation extends FloatingActionButtonLocation {
  final double bottomOffset;

  const _TitansFabLocation({required this.bottomOffset});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final scaffoldSize = scaffoldGeometry.scaffoldSize;

    final fabX =
        scaffoldGeometry.textDirection == TextDirection.rtl
            ? TitansScaffold._fabScreenMargin
            : scaffoldSize.width -
                fabSize.width -
                TitansScaffold._fabScreenMargin;

    final fabY =
        scaffoldSize.height -
        fabSize.height -
        TitansScaffold._fabScreenMargin -
        bottomOffset;

    return Offset(
      fabX,
      fabY.clamp(0.0, scaffoldSize.height - fabSize.height).toDouble(),
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
