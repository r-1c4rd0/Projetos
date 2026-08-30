import 'package:flutter/material.dart';

import '../core/titans_ui.dart';

class TitansPressableCard extends StatefulWidget {
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const TitansPressableCard({
    super.key,
    required this.child,
    this.accent,
    this.onTap,
    this.padding = TitansUI.cardPadding,
  });

  @override
  State<TitansPressableCard> createState() => _TitansPressableCardState();
}

class _TitansPressableCardState extends State<TitansPressableCard> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.accent ?? cs.primary;
    final interactive = widget.onTap != null;
    final scale =
        !interactive ? 1.0 : (_pressed ? 0.985 : (_hovered ? 1.006 : 1.0));
    return MouseRegion(
      onEnter: interactive ? (_) => _setHovered(true) : null,
      onExit: interactive ? (_) => _setHovered(false) : null,
      child: GestureDetector(
        behavior:
            interactive ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: TitansUI.cardDecoration(context, accent: accent),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: interactive && _pressed ? 0.92 : 1,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class TitansSkeletonCard extends StatelessWidget {
  final int lines;
  final bool showHeader;

  const TitansSkeletonCard({super.key, this.lines = 4, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: TitansUI.pagePadding,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: TitansUI.cardPadding,
          decoration: TitansUI.cardDecoration(context, accent: cs.primary),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Row(
                  children: [
                    _SkeletonBlock(width: 46, height: 46, radius: 999),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBlock(width: double.infinity, height: 14),
                          SizedBox(height: 8),
                          _SkeletonBlock(width: 160, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              for (var i = 0; i < lines; i++) ...[
                _SkeletonBlock(
                  width: i.isEven ? double.infinity : 220,
                  height: 12,
                ),
                if (i != lines - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.85),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: cs.onSurface.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

enum TitansEmptyStateVariant { neutral, action, success, alert }

class TitansEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final TitansEmptyStateVariant variant;
  final bool compact;
  final bool showCard;

  const TitansEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.description,
    this.actionLabel,
    this.onAction,
    this.action,
    this.variant = TitansEmptyStateVariant.neutral,
    this.compact = false,
    this.showCard = true,
  });

  Color _accentFor(BuildContext context) {
    switch (variant) {
      case TitansEmptyStateVariant.neutral:
        return TitansUI.technicalBlue;
      case TitansEmptyStateVariant.action:
        return TitansUI.actionGold;
      case TitansEmptyStateVariant.success:
        return TitansUI.successGreen;
      case TitansEmptyStateVariant.alert:
        return TitansUI.alertRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(context);
    final resolvedIcon = icon ?? Icons.inbox_outlined;
    final resolvedMessage = message ?? description;
    final resolvedAction =
        action ??
        (actionLabel == null || onAction == null
            ? null
            : FilledButton(onPressed: onAction, child: Text(actionLabel!)));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 42 : 52,
          height: compact ? 42 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(resolvedIcon, color: accent),
        ),
        SizedBox(height: compact ? TitansUI.spaceSm : TitansUI.spaceMd),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TitansTypography.cardTitle(context),
        ),
        if (resolvedMessage != null && resolvedMessage.trim().isNotEmpty) ...[
          const SizedBox(height: TitansUI.spaceXs),
          Text(
            resolvedMessage,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TitansTypography.body(context),
          ),
        ],
        if (resolvedAction != null) ...[
          SizedBox(height: compact ? TitansUI.spaceSm : TitansUI.spaceMd),
          resolvedAction,
        ],
      ],
    );

    if (!showCard) return content;

    return TitansPressableCard(
      accent: accent,
      padding: EdgeInsets.all(compact ? TitansUI.spaceMd : TitansUI.spaceLg),
      child: content,
    );
  }
}

class TitansAnimatedSection extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const TitansAnimatedSection({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final visible = value.clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: visible,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - visible)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
