import 'package:flutter/widgets.dart';

/// Foundation minima de motion do Titans.
///
/// Contrato de densidade: em uma mesma viewport, use no maximo 1 Ambient
/// Motion perceptivel. Outros componentes podem usar entrance/feedback motion,
/// mas pulses, sweeps e loops continuos devem ser opt-in e raros.
@immutable
class TitansMotionSpec {
  final Duration duration;
  final Curve curve;
  final bool enabled;
  final bool allowAmbient;
  final bool respectReducedMotion;

  const TitansMotionSpec({
    required this.duration,
    required this.curve,
    this.enabled = true,
    this.allowAmbient = false,
    this.respectReducedMotion = true,
  });

  const TitansMotionSpec.fast({
    bool enabled = true,
    bool respectReducedMotion = true,
  }) : this(
         duration: TitansMotion.fast,
         curve: TitansMotion.standardCurve,
         enabled: enabled,
         respectReducedMotion: respectReducedMotion,
       );

  const TitansMotionSpec.standard({
    bool enabled = true,
    bool respectReducedMotion = true,
  }) : this(
         duration: TitansMotion.standard,
         curve: TitansMotion.standardCurve,
         enabled: enabled,
         respectReducedMotion: respectReducedMotion,
       );

  const TitansMotionSpec.emphasis({
    bool enabled = true,
    bool respectReducedMotion = true,
  }) : this(
         duration: TitansMotion.emphasis,
         curve: TitansMotion.emphasisCurve,
         enabled: enabled,
         respectReducedMotion: respectReducedMotion,
       );

  const TitansMotionSpec.ambient({
    bool enabled = true,
    bool allowAmbient = true,
    bool respectReducedMotion = true,
  }) : this(
         duration: TitansMotion.ambientSlow,
         curve: TitansMotion.ambientCurve,
         enabled: enabled,
         allowAmbient: allowAmbient,
         respectReducedMotion: respectReducedMotion,
       );

  TitansMotionSpec copyWith({
    Duration? duration,
    Curve? curve,
    bool? enabled,
    bool? allowAmbient,
    bool? respectReducedMotion,
  }) {
    return TitansMotionSpec(
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      enabled: enabled ?? this.enabled,
      allowAmbient: allowAmbient ?? this.allowAmbient,
      respectReducedMotion: respectReducedMotion ?? this.respectReducedMotion,
    );
  }
}

abstract final class TitansMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasis = Duration(milliseconds: 600);
  static const Duration ambientSlow = Duration(seconds: 6);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve ambientCurve = Curves.easeInOut;
  static const Curve emphasisCurve = Curves.easeOutCubic;

  static const TitansMotionSpec fastSpec = TitansMotionSpec.fast();
  static const TitansMotionSpec standardSpec = TitansMotionSpec.standard();
  static const TitansMotionSpec emphasisSpec = TitansMotionSpec.emphasis();
  static const TitansMotionSpec ambientSpec = TitansMotionSpec.ambient();

  static bool isReduced(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;
    return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }

  static bool enabled(BuildContext context, TitansMotionSpec spec) {
    if (!spec.enabled) return false;
    if (!spec.respectReducedMotion) return true;
    return !isReduced(context);
  }

  static Duration duration(BuildContext context, TitansMotionSpec spec) {
    return enabled(context, spec) ? spec.duration : Duration.zero;
  }

  static Curve curve(TitansMotionSpec spec) => spec.curve;

  static bool shouldRunAmbient(BuildContext context, TitansMotionSpec spec) {
    return spec.allowAmbient && enabled(context, spec);
  }
}
