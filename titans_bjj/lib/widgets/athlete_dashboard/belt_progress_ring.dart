import 'package:flutter/material.dart';

import '../../core/titans_live_motion.dart';

class BeltProgressRing extends StatefulWidget {
  final ColorScheme colorScheme;
  final double value;
  final Color color;

  const BeltProgressRing({
    super.key,
    required this.colorScheme,
    required this.value,
    required this.color,
  });

  @override
  State<BeltProgressRing> createState() => _BeltProgressRingState();
}

class _BeltProgressRingState extends State<BeltProgressRing> {
  static const _motion = TitansMotionSpec.emphasis();
  late double _beginValue;
  late double _targetValue;

  @override
  void initState() {
    super.initState();
    _beginValue = 0;
    _targetValue = _safeValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant BeltProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = _safeValue(widget.value);
    if (nextValue == _targetValue) return;
    _beginValue = _targetValue;
    _targetValue = nextValue;
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    final curve = TitansMotion.curve(_motion);
    if (duration == Duration.zero) {
      return _buildRing(_targetValue);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _beginValue, end: _targetValue),
      duration: duration,
      curve: curve,
      onEnd: () {
        _beginValue = _targetValue;
      },
      builder: (context, animatedValue, child) {
        return _buildRing(animatedValue);
      },
    );
  }

  Widget _buildRing(double animatedValue) {
    final cs = widget.colorScheme;
    final safeValue = _safeValue(animatedValue);
    final finalValue = _safeValue(widget.value);

    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: safeValue,
              strokeWidth: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(finalValue * 100).round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'faixa',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _safeValue(double value) => value.clamp(0.0, 1.0).toDouble();
}
