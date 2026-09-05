import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../service/jiu_jitsu_taxonomy.dart';
import '../titans_feedback.dart';

class TitansTechnicalRadarEvidence {
  final String label;
  final String value;
  final String helper;
  final IconData icon;

  const TitansTechnicalRadarEvidence({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
  });
}

/// Radar técnico com vida contínua: varredura (sweep) rotativa, pulso no
/// preenchimento, foco por eixo ao toque e comparação "fantasma" com um
/// período anterior.
///
/// Compatível com o widget original — todos os parâmetros novos têm
/// default e não quebram quem já instancia `TitansTechnicalRadar` sem eles.
///
/// Nota de performance: `enableSweep` mantém uma animação rodando
/// indefinidamente enquanto o widget estiver montado. Em uma lista com
/// vários radares ao mesmo tempo (ex: dashboard com um card por aluno),
/// desligue com `enableSweep: false` e deixe ligado só na tela de detalhe
/// (Game Map / SkillDetail), onde há um radar só na tela.
enum TitansTechnicalRadarVariant { full, compact, homePreview }

enum TitansRadarPerspective {
  top,
  isometric,
  holographic,
  live,
  axisFocus,
  free,
}

class TitansRadarCamera {
  final double pitch;
  final double yaw;
  final double roll;
  final double perspective;
  final double scale;

  const TitansRadarCamera({
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.perspective,
    required this.scale,
  });

  static const top = TitansRadarCamera(
    pitch: 0,
    yaw: 0,
    roll: 0,
    perspective: 0,
    scale: 1,
  );

  static const isometric = TitansRadarCamera(
    pitch: -0.58,
    yaw: 0.14,
    roll: -0.10,
    perspective: 0.0012,
    scale: 1.02,
  );

  static const holographic = TitansRadarCamera(
    pitch: -0.34,
    yaw: 0.06,
    roll: 0,
    perspective: 0.0012,
    scale: 1.08,
  );

  static const live = TitansRadarCamera(
    pitch: -0.38,
    yaw: 0.08,
    roll: -0.025,
    perspective: 0.00135,
    scale: 1.10,
  );

  TitansRadarCamera copyWith({
    double? pitch,
    double? yaw,
    double? roll,
    double? perspective,
    double? scale,
  }) {
    return TitansRadarCamera(
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
      perspective: perspective ?? this.perspective,
      scale: scale ?? this.scale,
    );
  }

  TitansRadarCamera clamped() {
    return TitansRadarCamera(
      pitch: pitch.clamp(-0.80, 0.10).toDouble(),
      yaw: yaw.clamp(-0.50, 0.50).toDouble(),
      roll: roll.clamp(-0.18, 0.18).toDouble(),
      perspective: perspective.clamp(0.0, 0.0018).toDouble(),
      scale: scale.clamp(0.94, 1.12).toDouble(),
    );
  }

  static TitansRadarCamera forPerspective(TitansRadarPerspective perspective) {
    return switch (perspective) {
      TitansRadarPerspective.top => top,
      TitansRadarPerspective.isometric => isometric,
      TitansRadarPerspective.holographic => holographic,
      TitansRadarPerspective.live => live,
      TitansRadarPerspective.axisFocus => live,
      TitansRadarPerspective.free => holographic,
    };
  }

  static TitansRadarCamera lerp(
    TitansRadarCamera a,
    TitansRadarCamera b,
    double t,
  ) {
    return TitansRadarCamera(
      pitch: _lerpDouble(a.pitch, b.pitch, t),
      yaw: _lerpDouble(a.yaw, b.yaw, t),
      roll: _lerpDouble(a.roll, b.roll, t),
      perspective: _lerpDouble(a.perspective, b.perspective, t),
      scale: _lerpDouble(a.scale, b.scale, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

class _RadarCameraTween extends Tween<TitansRadarCamera> {
  _RadarCameraTween({required TitansRadarCamera end}) : super(end: end);

  @override
  TitansRadarCamera lerp(double t) {
    return TitansRadarCamera.lerp(begin ?? end!, end!, t);
  }
}

class TitansTechnicalRadar extends StatefulWidget {
  final String title;
  final String subtitle;
  final String stateLabel;
  final List<TitansTechnicalRadarEvidence> evidences;
  final Map<TechnicalRadarAxis, int> axisEvidence;

  /// Evidências do período anterior, para o polígono fantasma tracejado.
  /// Se null, o fantasma não é desenhado.
  final Map<TechnicalRadarAxis, int>? previousAxisEvidence;

  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final TitansTechnicalRadarVariant variant;
  final bool interactive;
  final bool showDistribution;
  final bool showLegend;
  final bool showGhostPolygon;
  final bool showMetrics;
  final bool showSafetyCopy;
  final bool contained;

  final bool enableHolographicMode;
  final bool enablePerspectiveControls;
  final TitansRadarPerspective initialPerspective;

  /// Liga a varredura rotativa contínua e o pulso de glow. Desligue em
  /// contextos de lista (ver nota de performance acima).
  final bool enableSweep;

  /// Liga detalhes extras de HUD: scanlines sutis, reticles nos cantos,
  /// trilha "cometa" no eixo dominante e um ping de radar ao focar um
  /// eixo. 100% opt-in — desligado por padrão para não alterar a
  /// aparência de quem já usa o widget. Recomendado junto de
  /// `enableHolographicMode: true`, mas funciona sem ele também
  /// (nesse caso fica mais sutil, sem a trilha 3D).
  final bool enableHudDetails;

  const TitansTechnicalRadar({
    super.key,
    this.title = 'Radar Técnico',
    this.subtitle = 'Evidências técnicas registradas por eixo.',
    this.stateLabel = 'Perfil técnico em formação',
    this.evidences = const [],
    this.axisEvidence = const {},
    this.previousAxisEvidence,
    this.classifiedEvidenceCount = 0,
    this.awaitingClassificationCount = 0,
    this.variant = TitansTechnicalRadarVariant.full,
    this.interactive = true,
    this.showDistribution = true,
    this.showLegend = true,
    this.showGhostPolygon = true,
    this.showMetrics = true,
    this.showSafetyCopy = true,
    this.contained = true,
    this.enableHolographicMode = false,
    this.enablePerspectiveControls = false,
    this.initialPerspective = TitansRadarPerspective.holographic,
    this.enableSweep = true,
    this.enableHudDetails = false,
  });

  @override
  State<TitansTechnicalRadar> createState() => _TitansTechnicalRadarState();
}

class _TitansTechnicalRadarState extends State<TitansTechnicalRadar>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop; // sweep + pulse contínuos
  late final AnimationController _focusPing; // anel de radar ao focar eixo
  int? _focusedAxisIndex;
  late TitansRadarPerspective _perspective;
  TitansRadarCamera _freeCamera = TitansRadarCamera.live;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _focusPing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _perspective = widget.initialPerspective;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopWithMotionPreference();
  }

  void _syncLoopWithMotionPreference() {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final shouldRun = widget.enableSweep && !disableAnimations;
    if (disableAnimations && !_entrance.isCompleted) {
      _entrance.value = 1.0;
    }
    if (shouldRun) {
      if (!_loop.isAnimating) _loop.repeat();
    } else if (_loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void didUpdateWidget(covariant TitansTechnicalRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableSweep != oldWidget.enableSweep) {
      _syncLoopWithMotionPreference();
    }
    if (widget.initialPerspective != oldWidget.initialPerspective &&
        !widget.enablePerspectiveControls) {
      _perspective = widget.initialPerspective;
    }
    if (!widget.interactive && _focusedAxisIndex != null) {
      _focusedAxisIndex = null;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    _focusPing.dispose();
    super.dispose();
  }

  void _setPerspective(TitansRadarPerspective perspective) {
    if (_perspective == perspective) return;
    setState(() {
      _perspective = perspective;
      if (perspective == TitansRadarPerspective.free) {
        _freeCamera = _targetCamera(_loop.value, false);
      }
    });
  }

  void _focusAxis(int index) {
    if (!widget.interactive) return;
    HapticFeedback.selectionClick();
    setState(() {
      _focusedAxisIndex = index;
      if (widget.enablePerspectiveControls && widget.enableHolographicMode) {
        _perspective = TitansRadarPerspective.axisFocus;
      }
    });
    if (widget.enableHudDetails) {
      _focusPing
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  void _resetToHolographic() {
    setState(() {
      _freeCamera = TitansRadarCamera.live;
      _perspective = TitansRadarPerspective.live;
    });
  }

  void _handleFreePanUpdate(DragUpdateDetails details) {
    if (!widget.enablePerspectiveControls ||
        _perspective != TitansRadarPerspective.free) {
      return;
    }
    setState(() {
      _freeCamera =
          _freeCamera
              .copyWith(
                yaw: _freeCamera.yaw + details.delta.dx * 0.006,
                pitch: _freeCamera.pitch - details.delta.dy * 0.006,
                perspective: 0.0014,
                scale: 0.98,
              )
              .clamped();
    });
  }

  TitansRadarCamera _targetCamera(double loopValue, bool effectiveSweep) {
    final base = switch (_perspective) {
      TitansRadarPerspective.free => _freeCamera,
      TitansRadarPerspective.axisFocus => _axisCamera(_focusedAxisIndex),
      _ => TitansRadarCamera.forPerspective(_perspective),
    };
    if (!effectiveSweep ||
        (_perspective != TitansRadarPerspective.holographic &&
            _perspective != TitansRadarPerspective.live &&
            _perspective != TitansRadarPerspective.axisFocus &&
            _perspective != TitansRadarPerspective.free)) {
      return base;
    }
    final orbit = loopValue * math.pi * 2;
    return base
        .copyWith(
          pitch: base.pitch + math.sin(orbit) * 0.024,
          yaw: base.yaw + math.cos(orbit) * 0.020,
          roll: base.roll + math.sin(orbit) * 0.006,
        )
        .clamped();
  }

  TitansRadarCamera _axisCamera(int? index) {
    final safeIndex = index ?? 0;
    final angle = -math.pi / 2 + safeIndex * math.pi * 2 / _axisOrder.length;
    return TitansRadarCamera(
      pitch: -0.42,
      yaw: (math.cos(angle) * 0.28).clamp(-0.50, 0.50).toDouble(),
      roll: (math.sin(angle) * 0.10).clamp(-0.18, 0.18).toDouble(),
      perspective: 0.0013,
      scale: 1.07,
    ).clamped();
  }

  void _handleTapUp(TapUpDetails details, double size, double radius) {
    if (!widget.interactive) return;
    final center = Offset(size / 2, size / 2);
    final local = details.localPosition - center;
    if (local.distance > radius * 1.35) {
      if (_focusedAxisIndex != null) setState(() => _focusedAxisIndex = null);
      return;
    }
    var angle = math.atan2(local.dy, local.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final step = 2 * math.pi / _axisOrder.length;
    final index = (angle / step).round() % _axisOrder.length;
    if (_focusedAxisIndex == index) {
      setState(() => _focusedAxisIndex = null);
      return;
    }
    _focusAxis(index);
  }

  static double _radarSizeFor(
    double maxWidth,
    TitansTechnicalRadarVariant variant,
    bool holographicMode,
  ) {
    if (holographicMode && variant == TitansTechnicalRadarVariant.full) {
      if (maxWidth < 360) return 262.0;
      if (maxWidth < 430) return 292.0;
      if (maxWidth < 620) return 324.0;
      return 360.0;
    }
    if (variant == TitansTechnicalRadarVariant.compact) {
      if (maxWidth < 360) return 188.0;
      if (maxWidth < 430) return 204.0;
      return 216.0;
    }
    if (variant == TitansTechnicalRadarVariant.homePreview) {
      if (maxWidth < 360) return 226.0;
      if (maxWidth < 430) return 244.0;
      if (maxWidth < 620) return 268.0;
      return 292.0;
    }
    if (maxWidth < 360) return 214.0;
    if (maxWidth < 430) return 232.0;
    return 252.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasEvidence = widget.axisEvidence.values.any((value) => value > 0);
    final effectiveFocusedAxisIndex =
        widget.interactive ? _focusedAxisIndex : null;
    final effectivePreviousAxisEvidence =
        widget.showGhostPolygon ? widget.previousAxisEvidence : null;

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final effectiveSweep = widget.enableSweep && !disableAnimations;
    final showPerspectiveControls =
        widget.enablePerspectiveControls && widget.enableHolographicMode;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPerspectiveControls) ...[
          _RadarPerspectiveSelector(
            selected: _perspective,
            onChanged: _setPerspective,
            onReset: _resetToHolographic,
            selectedAxisIndex: _focusedAxisIndex,
            onAxisSelected: _focusAxis,
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final size = _radarSizeFor(
              constraints.maxWidth,
              widget.variant,
              widget.enableHolographicMode,
            );
            final radius = size * (widget.enableHolographicMode ? 0.37 : 0.31);
            return Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entrance, _loop, _focusPing]),
                builder: (context, _) {
                  final progress =
                      disableAnimations
                          ? 1.0
                          : Curves.easeOutCubic.transform(_entrance.value);
                  final loopValue = effectiveSweep ? _loop.value : 0.0;
                  final pulse =
                      effectiveSweep
                          ? 0.88 + 0.12 * math.sin(loopValue * 2 * math.pi * 2)
                          : 1.0;
                  final camera = _targetCamera(loopValue, effectiveSweep);
                  final radar = RepaintBoundary(
                    child: CustomPaint(
                      painter: _TechnicalRadarEvidencePainter(
                        cs,
                        axisEvidence: widget.axisEvidence,
                        previousAxisEvidence: effectivePreviousAxisEvidence,
                        progress: progress,
                        sweepAngle: loopValue * 2 * math.pi,
                        pulse: pulse,
                        showSweep: effectiveSweep,
                        focusedAxisIndex: effectiveFocusedAxisIndex,
                        holographicMode: widget.enableHolographicMode,
                        enableHudDetails: widget.enableHudDetails,
                        focusPingValue:
                            effectiveFocusedAxisIndex == null
                                ? 0
                                : _focusPing.value,
                      ),
                      child:
                          hasEvidence ? null : const _RadarEmptyCenterLabel(),
                    ),
                  );
                  final transformedRadar =
                      widget.enableHolographicMode
                          ? TweenAnimationBuilder<TitansRadarCamera>(
                            tween: _RadarCameraTween(end: camera),
                            duration:
                                disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            builder:
                                (context, animatedCamera, _) => RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _TechnicalRadarEvidencePainter(
                                      cs,
                                      axisEvidence: widget.axisEvidence,
                                      previousAxisEvidence:
                                          effectivePreviousAxisEvidence,
                                      progress: progress,
                                      sweepAngle: loopValue * 2 * math.pi,
                                      pulse: pulse,
                                      showSweep: effectiveSweep,
                                      focusedAxisIndex:
                                          effectiveFocusedAxisIndex,
                                      holographicMode:
                                          widget.enableHolographicMode,
                                      camera: animatedCamera,
                                      enableHudDetails: widget.enableHudDetails,
                                      focusPingValue:
                                          effectiveFocusedAxisIndex == null
                                              ? 0
                                              : _focusPing.value,
                                    ),
                                    child:
                                        hasEvidence
                                            ? null
                                            : const _RadarEmptyCenterLabel(),
                                  ),
                                ),
                          )
                          : radar;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate:
                        _perspective == TitansRadarPerspective.free
                            ? _handleFreePanUpdate
                            : null,
                    onDoubleTap:
                        _perspective == TitansRadarPerspective.free
                            ? _resetToHolographic
                            : null,
                    onTapUp:
                        widget.interactive
                            ? (d) => _handleTapUp(d, size, radius)
                            : null,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: transformedRadar,
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (widget.interactive && _focusedAxisIndex != null) ...[
          const SizedBox(height: 8),
          _RadarFocusDetail(
            axis: _axisOrder[_focusedAxisIndex!],
            value: widget.axisEvidence[_axisOrder[_focusedAxisIndex!]] ?? 0,
            color: _axisColors[_focusedAxisIndex!],
          ),
        ],
        if (widget.showLegend) ...[
          const SizedBox(height: 10),
          _RadarLegend(
            items: [
              _RadarLegendItem(color: cs.tertiary, label: 'Evidências'),
              if (effectivePreviousAxisEvidence != null)
                _RadarLegendItem(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  label: 'Período anterior',
                ),
              if (widget.evidences.any(
                (item) => item.label.toLowerCase().contains('avalia'),
              ))
                _RadarLegendItem(
                  color: cs.secondary,
                  label: 'Avaliações registradas',
                ),
            ],
          ),
        ],
        if (widget.showMetrics && widget.evidences.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RadarEvidenceMetrics(items: widget.evidences),
        ],
        const SizedBox(height: 12),
        _RadarStatusLabel(label: widget.stateLabel),
        if (widget.showSafetyCopy) ...[
          const SizedBox(height: 8),
          Text(
            'Não representa nota ou desempenho.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (widget.showDistribution) ...[
          const SizedBox(height: 12),
          _RadarEvidenceDistribution(
            axisEvidence: widget.axisEvidence,
            classifiedEvidenceCount: widget.classifiedEvidenceCount,
            awaitingClassificationCount: widget.awaitingClassificationCount,
          ),
        ],
      ],
    );

    if (!widget.contained) return content;

    return TitansPressableCard(accent: cs.tertiary, child: content);
  }
}

/// Detalhe compacto mostrado abaixo do radar quando um eixo está focado.
class _RadarPerspectiveSelector extends StatelessWidget {
  final TitansRadarPerspective selected;
  final ValueChanged<TitansRadarPerspective> onChanged;
  final VoidCallback onReset;
  final int? selectedAxisIndex;
  final ValueChanged<int> onAxisSelected;

  const _RadarPerspectiveSelector({
    required this.selected,
    required this.onChanged,
    required this.onReset,
    required this.selectedAxisIndex,
    required this.onAxisSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <_RadarPerspectiveItem>[
      const _RadarPerspectiveItem(
        perspective: TitansRadarPerspective.top,
        label: 'Topo',
        icon: Icons.trip_origin_rounded,
      ),
      const _RadarPerspectiveItem(
        perspective: TitansRadarPerspective.isometric,
        label: '3D',
        icon: Icons.view_in_ar_outlined,
      ),
      const _RadarPerspectiveItem(
        perspective: TitansRadarPerspective.live,
        label: 'Live',
        icon: Icons.radar_outlined,
      ),
      const _RadarPerspectiveItem(
        perspective: TitansRadarPerspective.axisFocus,
        label: 'Eixo',
        icon: Icons.center_focus_strong_outlined,
      ),
      const _RadarPerspectiveItem(
        perspective: TitansRadarPerspective.free,
        label: 'Livre',
        icon: Icons.open_with_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perspectiva do mapa',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in items)
              _RadarPerspectiveChip(
                item: item,
                selected: selected == item.perspective,
                onTap: () => onChanged(item.perspective),
              ),
            if (selected == TitansRadarPerspective.axisFocus)
              _RadarAxisFocusSelector(
                selectedAxisIndex: selectedAxisIndex,
                onAxisSelected: onAxisSelected,
              ),
            if (selected == TitansRadarPerspective.free)
              _RadarPerspectiveResetChip(onTap: onReset),
          ],
        ),
      ],
    );
  }
}

class _RadarAxisFocusSelector extends StatelessWidget {
  final int? selectedAxisIndex;
  final ValueChanged<int> onAxisSelected;

  const _RadarAxisFocusSelector({
    required this.selectedAxisIndex,
    required this.onAxisSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _axisOrder.length; i++)
          _RadarAxisFocusChip(
            label: _axisOrder[i].displayLabel,
            color: _axisColors[i],
            selected: selectedAxisIndex == i,
            onTap: () => onAxisSelected(i),
          ),
      ],
    );
  }
}

class _RadarAxisFocusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RadarAxisFocusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color:
                selected
                    ? color.withValues(alpha: 0.14)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.24),
            border: Border.all(
              color:
                  selected
                      ? color.withValues(alpha: 0.38)
                      : cs.outline.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? color : cs.onSurface.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPerspectiveItem {
  final TitansRadarPerspective perspective;
  final String label;
  final IconData icon;

  const _RadarPerspectiveItem({
    required this.perspective,
    required this.label,
    required this.icon,
  });
}

class _RadarPerspectiveChip extends StatelessWidget {
  final _RadarPerspectiveItem item;
  final bool selected;
  final VoidCallback onTap;

  const _RadarPerspectiveChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.tertiary : cs.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color:
                selected
                    ? cs.tertiary.withValues(alpha: 0.14)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.32),
            border: Border.all(
              color:
                  selected
                      ? cs.tertiary.withValues(alpha: 0.34)
                      : cs.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: color.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withValues(alpha: selected ? 0.96 : 0.68),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPerspectiveResetChip extends StatelessWidget {
  final VoidCallback onTap;

  const _RadarPerspectiveResetChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: cs.primary.withValues(alpha: 0.08),
            border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 5),
              Text(
                'Resetar',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarFocusDetail extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int value;
  final Color color;

  const _RadarFocusDetail({
    required this.axis,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              axis.displayLabel,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$value evidências',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarEmptyCenterLabel extends StatelessWidget {
  const _RadarEmptyCenterLabel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: cs.surface.withValues(alpha: 0.72),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        ),
        child: Text(
          'Sem evidências classificadas',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.66),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RadarLegendItem {
  final Color color;
  final String label;

  const _RadarLegendItem({required this.color, required this.label});
}

class _RadarLegend extends StatelessWidget {
  final List<_RadarLegendItem> items;

  const _RadarLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: item.color.withValues(alpha: 0.08),
              border: Border.all(color: item.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.82),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RadarEvidenceMetrics extends StatelessWidget {
  final List<TitansTechnicalRadarEvidence> items;

  const _RadarEvidenceMetrics({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 320;
        final width =
            twoColumns ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 70),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: cs.tertiary.withValues(alpha: 0.1),
                        ),
                        child: Icon(item.icon, size: 17, color: cs.tertiary),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.helper,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RadarStatusLabel extends StatelessWidget {
  final String label;

  const _RadarStatusLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: cs.tertiary.withValues(alpha: 0.08),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.tertiary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RadarEvidenceDistribution extends StatelessWidget {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;

  const _RadarEvidenceDistribution({
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = _axisOrder.fold<int>(0, (max, axis) {
      final value = axisEvidence[axis] ?? 0;
      return value > max ? value : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISTRIBUIÇÃO DAS EVIDÊNCIAS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        for (var i = 0; i < _distributionAxisOrder.length; i++) ...[
          _RadarEvidenceDistributionRow(
            axis: _distributionAxisOrder[i],
            value: axisEvidence[_distributionAxisOrder[i]] ?? 0,
            maxValue: maxValue,
            color: _distributionAxisColors[i],
          ),
          if (i != _distributionAxisOrder.length - 1) const SizedBox(height: 7),
        ],
        const SizedBox(height: 10),
        Text(
          '$classifiedEvidenceCount classificadas · $awaitingClassificationCount aguardando classificação',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RadarEvidenceDistributionRow extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int value;
  final int maxValue;
  final Color color;

  const _RadarEvidenceDistributionRow({
    required this.axis,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = value > 0 && maxValue > 0;
    final fillFactor =
        active ? (value / maxValue).clamp(0.08, 1.0).toDouble() : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            axis.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  active
                      ? cs.onSurface.withValues(alpha: 0.88)
                      : cs.onSurface.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? color : cs.onSurface.withValues(alpha: 0.42),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.onSurface.withValues(alpha: 0.07),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                if (active)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillFactor,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.45),
                            color.withValues(alpha: 0.9),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarPoint3D {
  final double x;
  final double y;
  final double z;

  const _RadarPoint3D(this.x, this.y, this.z);
}

class _ProjectedRadarPoint {
  final Offset offset;
  final double depth;

  const _ProjectedRadarPoint(this.offset, this.depth);
}

class _TechnicalRadarEvidencePainter extends CustomPainter {
  final ColorScheme colorScheme;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final Map<TechnicalRadarAxis, int>? previousAxisEvidence;
  final double progress;
  final double sweepAngle;
  final double pulse;
  final bool showSweep;
  final int? focusedAxisIndex;
  final bool holographicMode;
  final TitansRadarCamera camera;
  final bool enableHudDetails;

  /// 0..1 — progresso do anel de "ping" desde que um eixo foi focado.
  final double focusPingValue;

  const _TechnicalRadarEvidencePainter(
    this.colorScheme, {
    required this.axisEvidence,
    this.previousAxisEvidence,
    required this.progress,
    this.sweepAngle = 0,
    this.pulse = 1.0,
    this.showSweep = true,
    this.focusedAxisIndex,
    this.holographicMode = false,
    this.camera = TitansRadarCamera.top,
    this.enableHudDetails = false,
    this.focusPingValue = 0,
  });

  static const _ringSegments = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width, size.height) * (holographicMode ? 0.37 : 0.31);
    final effectiveCamera =
        holographicMode ? camera.clamped() : TitansRadarCamera.top;

    _paintDepthBase(canvas, center, radius, effectiveCamera);
    if (enableHudDetails) _paintCornerReticles(canvas, size);

    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: holographicMode ? 0.05 * pulse : 0,
              ),
              colorScheme.tertiary.withValues(
                alpha: (holographicMode ? 0.34 : 0.16) * pulse,
              ),
              colorScheme.secondary.withValues(
                alpha: holographicMode ? 0.16 * pulse : 0,
              ),
              colorScheme.tertiary.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.22, 0.58, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius * 1.42),
          );
    canvas.drawCircle(center, radius * 1.24, glowPaint);
    if (enableHudDetails) _paintScanlines(canvas, center, radius);

    _paintSweep(canvas, center, radius, effectiveCamera);
    _paintRings(canvas, center, radius, effectiveCamera);
    _paintGhostPolygon(canvas, center, radius, effectiveCamera);
    _paintEvidencePolygon(canvas, center, radius, effectiveCamera);
    if (enableHudDetails) {
      _paintDominantTrail(canvas, center, radius, effectiveCamera);
    }
    if (holographicMode) {
      _paintParticles(canvas, center, radius, effectiveCamera);
    }
    _paintAxesAndLabels(canvas, size, center, radius, effectiveCamera);
    if (enableHudDetails && focusedAxisIndex != null && focusPingValue > 0) {
      _paintFocusPing(canvas, center, radius, effectiveCamera);
    }

    canvas.drawCircle(
      _projectPoint(
        const _RadarPoint3D(0, 0, 0.02),
        center,
        radius,
        effectiveCamera,
      ).offset,
      3,
      Paint()..color = colorScheme.tertiary.withValues(alpha: 0.32),
    );
  }

  void _paintDepthBase(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    if (!holographicMode) return;
    final shadowTilt = (1.0 + camera.pitch.abs() * 0.55).clamp(1.0, 1.42);
    final baseRect = Rect.fromCircle(center: center, radius: radius * 1.46);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(camera.yaw * radius * 0.22, radius * 0.10),
        width: radius * (2.42 + camera.yaw.abs() * 0.32),
        height: radius * (2.02 / shadowTilt),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
            colorScheme.tertiary.withValues(alpha: 0.18),
            colorScheme.primary.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.34, 0.66, 1.0],
        ).createShader(baseRect),
    );

    final rimRect = Rect.fromCenter(
      center: center.translate(camera.yaw * radius * 0.18, radius * 0.08),
      width: radius * 2.34,
      height: radius * (1.92 / shadowTilt),
    );
    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            colorScheme.tertiary.withValues(alpha: 0.20),
            colorScheme.primary.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(rimRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final glint =
        Path()
          ..moveTo(center.dx - radius * 0.68, center.dy - radius * 0.52)
          ..quadraticBezierTo(
            center.dx,
            center.dy - radius * 0.72,
            center.dx + radius * 0.58,
            center.dy - radius * 0.46,
          );
    canvas.drawPath(
      glint,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
  }

  /// Brackets de mira nos 4 cantos da área do widget — reforça a leitura
  /// de "interface tática" sem competir com os dados. Estático e barato.
  void _paintCornerReticles(Canvas canvas, Size size) {
    const inset = 6.0;
    const arm = 12.0;
    final paint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;

    void bracket(Offset corner, double dx, double dy) {
      canvas.drawLine(corner, corner.translate(dx * arm, 0), paint);
      canvas.drawLine(corner, corner.translate(0, dy * arm), paint);
    }

    bracket(const Offset(inset, inset), 1, 1);
    bracket(Offset(size.width - inset, inset), -1, 1);
    bracket(Offset(inset, size.height - inset), 1, -1);
    bracket(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  /// Linhas horizontais finas sobre o disco do radar — textura de tela
  /// holográfica. Alpha bem baixo para não brigar com o conteúdo.
  void _paintScanlines(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 1.2)),
    );
    final paint =
        Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.028)
          ..strokeWidth = 1;
    const step = 5.0;
    final top = center.dy - radius * 1.2;
    final bottom = center.dy + radius * 1.2;
    for (var y = top; y <= bottom; y += step) {
      canvas.drawLine(
        Offset(center.dx - radius * 1.2, y),
        Offset(center.dx + radius * 1.2, y),
        paint,
      );
    }
    canvas.restore();
  }

  /// Trilha "cometa" atrás do vértice de maior evidência: 3 ecos
  /// decrescentes ao longo da direção do eixo, dando sensação de
  /// varredura contínua naquele ponto.
  void _paintDominantTrail(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final values = _axisValues();
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxValue <= 0) return;
    final dominantIndex = values.indexOf(maxValue);
    final baseFactor = (0.16 + 1.0 * 0.78) * progress;
    final color = _axisColors[dominantIndex];

    for (var echo = 1; echo <= 3; echo++) {
      final trailFactor = (baseFactor - echo * 0.05).clamp(0.0, 1.0);
      final z = holographicMode ? trailFactor * 0.18 : 0.0;
      final point = _projectPoint(
        _axisPoint3D(dominantIndex, trailFactor, z),
        center,
        radius,
        camera,
      );
      canvas.drawCircle(
        point.offset,
        3.2 - echo * 0.5,
        Paint()
          ..color = color.withValues(
            alpha: (0.16 - echo * 0.04).clamp(0.0, 1.0),
          ),
      );
    }
  }

  /// Anel de radar que nasce no vértice focado e se expande com fade —
  /// disparado uma vez por foco via `focusPingValue` (0 a 1).
  void _paintFocusPing(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final index = focusedAxisIndex!;
    final endpoint =
        _projectPoint(
          _axisPoint3D(index, 1.0, 0.01),
          center,
          radius,
          camera,
        ).offset;
    final t = Curves.easeOut.transform(focusPingValue.clamp(0.0, 1.0));
    final ringRadius = 6 + t * 26;
    final alpha = (1 - t) * 0.5;
    canvas.drawCircle(
      endpoint,
      ringRadius,
      Paint()
        ..color = _axisColors[index].withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _paintRings(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final gridPaint =
        Paint()
          ..color = colorScheme.onSurface.withValues(
            alpha: holographicMode ? 0.16 : 0.12,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = holographicMode ? 1.15 : 1;
    final softGridPaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(
            alpha: holographicMode ? 0.10 : 0.065,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = holographicMode ? 5.4 : 5;

    for (final factor in const [0.2, 0.4, 0.6, 0.8, 1.0]) {
      final path = _projectedCirclePath(center, radius, factor, camera);
      if (factor == 1.0) canvas.drawPath(path, softGridPaint);
      canvas.drawPath(path, gridPaint);
      if (holographicMode && factor == 0.6) {
        canvas.drawPath(
          path,
          Paint()
            ..color = colorScheme.secondary.withValues(alpha: 0.08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
      }
    }
  }

  void _paintAxesAndLabels(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final projectedCenter =
        _projectPoint(
          const _RadarPoint3D(0, 0, 0),
          center,
          radius,
          camera,
        ).offset;

    for (var i = 0; i < _axisOrder.length; i++) {
      final isFocused = focusedAxisIndex == null || focusedAxisIndex == i;
      final dim = focusedAxisIndex != null && focusedAxisIndex != i;
      final axisColor = _axisColors[i];
      final endpoint = _projectPoint(
        _axisPoint3D(i, 1.0, 0.01),
        center,
        radius,
        camera,
      );
      final alphaMul = dim ? 0.35 : 1.0;

      canvas.drawLine(
        projectedCenter,
        endpoint.offset,
        Paint()
          ..color = axisColor.withValues(alpha: 0.07 * alphaMul * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = holographicMode ? 5.2 : 4.2,
      );
      canvas.drawLine(
        projectedCenter,
        endpoint.offset,
        Paint()
          ..color = axisColor.withValues(
            alpha: (holographicMode ? 0.52 : 0.42) * alphaMul,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25,
      );

      canvas.drawCircle(
        endpoint.offset,
        (isFocused ? 8.5 : 7.2) + (holographicMode ? pulse : 0),
        Paint()
          ..color = axisColor.withValues(
            alpha: (holographicMode ? 0.24 : 0.13) * alphaMul * pulse,
          ),
      );
      canvas.drawCircle(
        endpoint.offset,
        isFocused ? 4.4 : 3.4,
        Paint()..color = axisColor.withValues(alpha: 0.72 * alphaMul),
      );
      if (holographicMode) {
        canvas.drawCircle(
          endpoint.offset.translate(-1.2, -1.4),
          1.1,
          Paint()..color = Colors.white.withValues(alpha: 0.56 * alphaMul),
        );
      }
      _paintLabel(
        canvas,
        size,
        endpoint.offset,
        _axisOrder[i].displayLabel,
        i,
        axisColor,
        alphaMul,
      );
    }
  }

  void _paintParticles(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    const seeds = <double>[0.08, 0.19, 0.31, 0.47, 0.63, 0.78, 0.91];
    for (var i = 0; i < seeds.length; i++) {
      final angle = seeds[i] * math.pi * 2 + sweepAngle * 0.18;
      final orbit = 0.68 + (i % 3) * 0.19;
      final point =
          _projectPoint(
            _polarPoint3D(angle, orbit, 0.025 + (i % 2) * 0.025),
            center,
            radius,
            camera,
          ).offset;
      final color = _axisColors[i % _axisColors.length];
      final alpha = 0.16 + 0.08 * math.sin(sweepAngle + i);
      canvas.drawCircle(
        point,
        1.4 + (i % 2) * 0.6,
        Paint()..color = color.withValues(alpha: alpha.clamp(0.08, 0.24)),
      );
      canvas.drawCircle(
        point,
        4.2,
        Paint()..color = color.withValues(alpha: 0.035),
      );
    }
  }

  void _paintSweep(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    if (!showSweep) return;
    if (sweepAngle == 0 && !_hasAnyEvidence()) return;
    final outer = <Offset>[];
    final inner = <Offset>[];
    const width = 0.72;
    for (var step = 0; step <= 18; step++) {
      final t = step / 18;
      final angle = sweepAngle - width + width * t;
      outer.add(
        _projectPoint(
          _polarPoint3D(angle, 1.12, 0.006),
          center,
          radius,
          camera,
        ).offset,
      );
      inner.add(
        _projectPoint(
          _polarPoint3D(angle, 0.08, 0.006),
          center,
          radius,
          camera,
        ).offset,
      );
    }
    final path = Path()..moveTo(inner.first.dx, inner.first.dy);
    for (final point in outer) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in inner.reversed) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = colorScheme.tertiary.withValues(
          alpha: holographicMode ? 0.11 : 0.08,
        )
        ..style = PaintingStyle.fill,
    );
  }

  bool _hasAnyEvidence() => axisEvidence.values.any((v) => v > 0);

  void _paintGhostPolygon(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final previous = previousAxisEvidence;
    if (previous == null) return;
    final values = _axisOrder.map((a) => previous[a] ?? 0).toList();
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxValue <= 0) return;

    final path = _dataPolygonPath(values, maxValue, center, radius, camera);
    canvas.drawPath(
      _dashed(path, dash: 4, gap: 3),
      Paint()
        ..color = colorScheme.onSurface.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  Path _dashed(Path source, {required double dash, required double gap}) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dash : gap;
        final next = math.min(distance + len, metric.length);
        if (draw) out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next;
        draw = !draw;
      }
    }
    return out;
  }

  void _paintEvidencePolygon(
    Canvas canvas,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final values = _axisValues();
    final maxValue = values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (maxValue <= 0) return;

    final path = _dataPolygonPath(values, maxValue, center, radius, camera);
    final polygonBounds = Rect.fromCircle(center: center, radius: radius);
    final fillPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: holographicMode ? 0.035 : 0),
              colorScheme.secondary.withValues(alpha: 0.18),
              colorScheme.tertiary.withValues(alpha: 0.40 * pulse),
              colorScheme.primary.withValues(alpha: 0.16),
            ],
            stops: const [0.0, 0.28, 0.70, 1.0],
          ).createShader(polygonBounds)
          ..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(
            alpha: holographicMode ? 1.0 : 0.72,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = holographicMode ? 3.2 : 2;
    final haloPaint =
        Paint()
          ..color = colorScheme.tertiary.withValues(
            alpha: (holographicMode ? 0.34 : 0.16) * pulse,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = holographicMode ? 12 : 6;

    if (holographicMode) {
      canvas.drawShadow(
        path,
        colorScheme.tertiary.withValues(alpha: 0.38),
        10,
        false,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.secondary.withValues(alpha: 0.18 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(path, haloPaint);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final factor = (0.16 + (values[i] / maxValue) * 0.78) * progress;
      final z = holographicMode ? factor * 0.18 : 0.0;
      final point = _projectPoint(
        _axisPoint3D(i, factor, z),
        center,
        radius,
        camera,
      );
      final dominant = values[i] == maxValue;
      canvas.drawCircle(
        point.offset,
        dominant && holographicMode ? 14.5 : 8,
        Paint()
          ..color = _axisColors[i].withValues(
            alpha: dominant && holographicMode ? 0.32 * pulse : 0.16,
          )
          ..maskFilter =
              holographicMode
                  ? const MaskFilter.blur(BlurStyle.normal, 1.8)
                  : null,
      );
      canvas.drawCircle(
        point.offset,
        dominant && holographicMode ? 6.6 : 4.8,
        Paint()..color = _axisColors[i].withValues(alpha: 0.88),
      );
      if (holographicMode) {
        canvas.drawCircle(
          point.offset.translate(-1.4, -1.6),
          dominant ? 1.7 : 1.2,
          Paint()..color = Colors.white.withValues(alpha: 0.62),
        );
      }
    }
  }

  List<int> _axisValues() {
    return _axisOrder.map((axis) => axisEvidence[axis] ?? 0).toList();
  }

  Path _projectedCirclePath(
    Offset center,
    double radius,
    double factor,
    TitansRadarCamera camera,
  ) {
    final path = Path();
    for (var i = 0; i <= _ringSegments; i++) {
      final angle = i / _ringSegments * math.pi * 2;
      final point =
          _projectPoint(
            _polarPoint3D(angle, factor, 0),
            center,
            radius,
            camera,
          ).offset;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _dataPolygonPath(
    List<int> values,
    int maxValue,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final factor =
          values[i] == 0
              ? 0.0
              : (0.16 + (values[i] / maxValue) * 0.78) * progress;
      final z = holographicMode ? factor * 0.18 : 0.0;
      final point =
          _projectPoint(
            _axisPoint3D(i, factor, z),
            center,
            radius,
            camera,
          ).offset;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  _RadarPoint3D _axisPoint3D(int index, double factor, double z) {
    final angle = -math.pi / 2 + index * math.pi * 2 / _axisOrder.length;
    return _polarPoint3D(angle, factor, z);
  }

  _RadarPoint3D _polarPoint3D(double angle, double factor, double z) {
    return _RadarPoint3D(math.cos(angle) * factor, math.sin(angle) * factor, z);
  }

  _ProjectedRadarPoint _projectPoint(
    _RadarPoint3D point,
    Offset center,
    double radius,
    TitansRadarCamera camera,
  ) {
    var x = point.x;
    var y = point.y;
    var z = point.z;

    final cosX = math.cos(camera.pitch);
    final sinX = math.sin(camera.pitch);
    final y1 = y * cosX - z * sinX;
    final z1 = y * sinX + z * cosX;
    y = y1;
    z = z1;

    final cosY = math.cos(camera.yaw);
    final sinY = math.sin(camera.yaw);
    final x1 = x * cosY + z * sinY;
    final z2 = -x * sinY + z * cosY;
    x = x1;
    z = z2;

    final cosZ = math.cos(camera.roll);
    final sinZ = math.sin(camera.roll);
    final x2 = x * cosZ - y * sinZ;
    final y2 = x * sinZ + y * cosZ;
    x = x2;
    y = y2;

    final zPx = z * radius;
    final depth =
        (1 / (1 + zPx * camera.perspective)).clamp(0.86, 1.16).toDouble();
    return _ProjectedRadarPoint(
      Offset(
        center.dx + x * radius * camera.scale * depth,
        center.dy + y * radius * camera.scale * depth,
      ),
      depth,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Size size,
    Offset point,
    String label,
    int i,
    Color color,
    double alphaMul,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9 * alphaMul),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 104);

    final rawOffset = switch (i) {
      0 => Offset(point.dx - textPainter.width / 2, point.dy - 30),
      1 => Offset(point.dx + 16, point.dy - textPainter.height / 2),
      2 => Offset(point.dx - textPainter.width / 2, point.dy + 16),
      _ => Offset(
        point.dx - textPainter.width - 16,
        point.dy - textPainter.height / 2,
      ),
    };
    final offset = Offset(
      rawOffset.dx.clamp(0.0, size.width - textPainter.width).toDouble(),
      rawOffset.dy.clamp(0.0, size.height - textPainter.height).toDouble(),
    );

    final labelRect = Rect.fromLTWH(
      offset.dx - 7,
      offset.dy - 4,
      textPainter.width + 14,
      textPainter.height + 8,
    );
    final labelRRect = RRect.fromRectAndRadius(
      labelRect,
      const Radius.circular(999),
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = colorScheme.surface.withValues(alpha: 0.84 * alphaMul)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      labelRRect,
      Paint()
        ..color = color.withValues(alpha: 0.28 * alphaMul)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TechnicalRadarEvidencePainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.axisEvidence != axisEvidence ||
        oldDelegate.previousAxisEvidence != previousAxisEvidence ||
        oldDelegate.progress != progress ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.showSweep != showSweep ||
        oldDelegate.focusedAxisIndex != focusedAxisIndex ||
        oldDelegate.holographicMode != holographicMode ||
        oldDelegate.camera != camera ||
        oldDelegate.enableHudDetails != enableHudDetails ||
        oldDelegate.focusPingValue != focusPingValue;
  }
}

const _axisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
];

const _axisColors = <Color>[
  Color(0xFF4CC9F0),
  Color(0xFFE9C46A),
  Color(0xFFB026FF),
  Color(0xFF2D6BFF),
];

const _distributionAxisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.attack,
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
];

const _distributionAxisColors = <Color>[
  Color(0xFF2D6BFF),
  Color(0xFF4CC9F0),
  Color(0xFFE9C46A),
  Color(0xFFB026FF),
];
