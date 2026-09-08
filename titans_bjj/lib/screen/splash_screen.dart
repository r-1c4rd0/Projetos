import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/startup_performance_trace.dart';
import '../core/titans_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _entryDuration = Duration(milliseconds: 520);
  static const _fadeOutDuration = Duration(milliseconds: 260);
  static const _reducedFadeOutDuration = Duration(milliseconds: 120);
  static const _asset = 'assets/logo_icon.png';

  late final AnimationController _controller;
  bool _showSplash = true;
  bool _fadeSplash = false;
  bool _completed = false;
  bool _scheduled = false;
  bool _precacheStarted = false;
  bool _childVisibleMarked = false;

  @override
  void initState() {
    super.initState();
    StartupPerformanceTrace.mark('Splash initState');
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: _entryDuration)
      ..addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _fadeSplash || !mounted) {
      return;
    }
    StartupPerformanceTrace.start('Splash fade out');
    setState(() => _fadeSplash = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted) {
      _precacheStarted = true;
      StartupPerformanceTrace.start('Splash image precache');
      unawaited(
        precacheImage(const AssetImage(_asset), context)
            .then((_) {
              StartupPerformanceTrace.end('Splash image precache');
            })
            .catchError((Object error, StackTrace stackTrace) {
              StartupPerformanceTrace.end(
                'Splash image precache',
                detail: 'error=${error.runtimeType}',
              );
            }),
      );
    }
    if (_scheduled) return;
    _scheduled = true;

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!reducedMotion) {
      StartupPerformanceTrace.mark('Splash animation start');
      _controller.forward(from: 0);
    } else {
      StartupPerformanceTrace.mark('Splash animation skipped reduced motion');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _fadeSplash) return;
        StartupPerformanceTrace.start('Splash fade out');
        setState(() => _fadeSplash = true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    StartupPerformanceTrace.mark(
      'Splash lifecycle ${state.name} show=$_showSplash scheduled=$_scheduled',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!_childVisibleMarked) {
      _childVisibleMarked = true;
      StartupPerformanceTrace.mark('Splash child visible');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_showSplash)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _fadeSplash ? 0 : 1,
              duration:
                  reducedMotion ? _reducedFadeOutDuration : _fadeOutDuration,
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (!_fadeSplash || _completed || !mounted) return;
                _completed = true;
                _controller.stop();
                StartupPerformanceTrace.end('Splash fade out');
                StartupPerformanceTrace.mark('Splash completed');
                setState(() => _showSplash = false);
              },
              child: _SplashStage(controller: _controller),
            ),
          ),
      ],
    );
  }
}

class _SplashStage extends StatelessWidget {
  final Animation<double> controller;

  const _SplashStage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final cs = Theme.of(context).colorScheme;
    final tc = titansColors(context);

    return Scaffold(
      backgroundColor: tc.background,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = reducedMotion ? 1.0 : controller.value;
            final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
            final scale = reducedMotion ? 1.0 : 0.985 + eased * 0.015;
            final opacity = reducedMotion ? 1.0 : eased.clamp(0.0, 1.0);

            return DecoratedBox(
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
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
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
                  Opacity(
                    opacity: 0.045,
                    child: CustomPaint(
                      painter: _SplashDotGridPainter(
                        color: tc.textPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final shortest = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final logoSize = (shortest * 0.32).clamp(120.0, 190.0);
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final decodePx =
                          (logoSize * dpr).round().clamp(1, 512).toInt();

                      return Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _SplashGoldGlow(
                              progress: eased,
                              color: tc.accent,
                              size: logoSize * 1.82,
                              reducedMotion: reducedMotion,
                            ),
                            Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: Semantics(
                                  label: 'Titans BJJ',
                                  image: true,
                                  child: Image.asset(
                                    _SplashScreenState._asset,
                                    width: logoSize,
                                    height: logoSize,
                                    cacheWidth: decodePx,
                                    cacheHeight: decodePx,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _SplashAssetFallback(
                                              primary: cs.primary,
                                              secondary: cs.secondary,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashGoldGlow extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final bool reducedMotion;

  const _SplashGoldGlow({
    required this.progress,
    required this.color,
    required this.size,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = reducedMotion ? 0.52 : 0.30 + progress * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: intensity),
            color.withValues(alpha: intensity * 0.28),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}

class _SplashAssetFallback extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _SplashAssetFallback({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [
            primary.withValues(alpha: 0.26),
            secondary.withValues(alpha: 0.12),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sports_martial_arts_rounded,
          color: primary,
          size: 72,
        ),
      ),
    );
  }
}

class _SplashDotGridPainter extends CustomPainter {
  final Color color;

  const _SplashDotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 22.0;
    const radius = 1.0;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashDotGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
