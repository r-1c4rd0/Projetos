import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/startup_performance_trace.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _standardDuration = Duration(milliseconds: 2800);
  static const _reducedMotionDuration = Duration(milliseconds: 750);
  static const _fadeOutDuration = Duration(milliseconds: 420);
  static const _reducedFadeOutDuration = Duration(milliseconds: 180);
  static const _asset = 'assets/tela_inicial.png';

  late final AnimationController _controller;
  Timer? _timer;
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
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
      _controller.repeat();
    } else {
      StartupPerformanceTrace.mark('Splash animation skipped reduced motion');
    }

    StartupPerformanceTrace.start('Splash minimum duration');
    _timer = Timer(
      reducedMotion ? _reducedMotionDuration : _standardDuration,
      () {
        StartupPerformanceTrace.end('Splash minimum duration');
        if (!mounted) return;
        StartupPerformanceTrace.start('Splash fade out');
        setState(() => _fadeSplash = true);
      },
    );
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
    _timer?.cancel();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = reducedMotion ? 0.0 : controller.value;
            final pulse = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
            final scale = reducedMotion ? 1.0 : 1.015 + pulse * 0.012;

            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    _SplashScreenState._asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder:
                        (context, error, stackTrace) => _SplashAssetFallback(
                          primary: cs.primary,
                          secondary: cs.secondary,
                        ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.08),
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.56),
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _SplashEnergyPainter(
                    progress: progress,
                    primary: cs.primary,
                    secondary: cs.secondary,
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: const Alignment(0, 0.72),
                    child: Opacity(
                      opacity: reducedMotion ? 0.88 : 0.72 + pulse * 0.20,
                      child: Container(
                        width: 92,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              cs.primary.withValues(alpha: 0.86),
                              cs.secondary.withValues(alpha: 0.62),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.34),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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

class _SplashEnergyPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;

  const _SplashEnergyPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = math.min(size.width, size.height);
    final sweepRect = Rect.fromCircle(center: center, radius: shortest * 0.42);

    final sweep =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..shader = SweepGradient(
            transform: GradientRotation(progress * math.pi * 2),
            colors: [
              Colors.transparent,
              primary.withValues(alpha: 0.08),
              primary.withValues(alpha: 0.30),
              secondary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(sweepRect);

    canvas.drawCircle(center, shortest * 0.36, sweep);
    canvas.drawCircle(center, shortest * 0.48, sweep..strokeWidth = 0.7);

    final verticalGlow =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              primary.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size);

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.48, 0, size.width * 0.04, size.height),
      verticalGlow,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashEnergyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}
