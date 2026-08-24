import 'package:flutter/material.dart';

class TitansUI {
  static const radius = 18.0;
  static const radiusSmall = 12.0;

  static const spaceXs = 6.0;
  static const spaceSm = 10.0;
  static const spaceMd = 16.0;
  static const spaceLg = 24.0;
  static const spaceXl = 32.0;

  static const pagePadding = EdgeInsets.all(spaceMd);
  static const cardPadding = EdgeInsets.all(spaceMd);
  static const sectionGap = SizedBox(height: 12);
  static const cardGap = SizedBox(height: 12);

  static const bg = Color(0xFF070A0F);
  static const card = Color(0xFF0B111A);
  static const card2 = Color(0xFF080D14);

  static const stroke = Color(0x24FFFFFF);

  static const neonRed = Color(0xFFFF2D2D);
  static const neonPurple = Color(0xFFB026FF);
  static const neonBlue = Color(0xFF2D6BFF);
  static const neonGold = Color(0xFFE9C46A);

  static const success = Color(0xFF70E000);
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF5C5C);
  static const info = Color(0xFF4CC9F0);

  static Color beltColor(String belt) {
    switch (belt) {
      case 'white':
        return Colors.white.withValues(alpha: 0.9);
      case 'blue':
        return neonBlue;
      case 'purple':
        return neonPurple;
      case 'brown':
        return const Color(0xFF8D6E63);
      case 'black':
        return const Color(0xFFE6E6E6);
      default:
        return Colors.white.withValues(alpha: 0.9);
    }
  }

  static String beltLabel(String? belt) {
    switch (belt?.trim().toLowerCase().replaceFirst('beltcolor.', '')) {
      case 'white':
      case 'branca':
        return 'branca';
      case 'blue':
      case 'azul':
        return 'azul';
      case 'purple':
      case 'roxa':
        return 'roxa';
      case 'brown':
      case 'marrom':
        return 'marrom';
      case 'black':
      case 'preta':
        return 'preta';
      default:
        return 'n\u00e3o informada';
    }
  }

  static EdgeInsets listPadding(BuildContext context, {double extra = 32}) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return EdgeInsets.fromLTRB(spaceMd, spaceMd, spaceMd, 80 + bottom + extra);
  }

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? accent,
    double radius = TitansUI.radius,
  }) {
    final cs = Theme.of(context).colorScheme;
    final glow = accent ?? cs.primary;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: card,
      border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
      boxShadow: [
        BoxShadow(
          color: glow.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 22,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }
}


class TitansSpacing {
  static const xs = TitansUI.spaceXs;
  static const sm = TitansUI.spaceSm;
  static const md = TitansUI.spaceMd;
  static const lg = TitansUI.spaceLg;
  static const xl = TitansUI.spaceXl;
}

class TitansRadius {
  static const sm = TitansUI.radiusSmall;
  static const md = 14.0;
  static const lg = TitansUI.radius;
  static const pill = 999.0;
}

class TitansTypography {
  static TextStyle? title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          );

  static TextStyle? label(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          );

  static TextStyle muted(BuildContext context, {double alpha = 0.68}) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha),
    );
  }
}

class TitansBreakpoint {
  static const mobile = 600.0;
  static const desktop = 900.0;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}
class TitansStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  const TitansStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  const TitansStateView.loading({
    super.key,
    this.title = 'Carregando',
    this.message,
    this.action,
    this.compact = false,
  }) : icon = Icons.hourglass_empty_outlined;

  const TitansStateView.empty({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  }) : icon = Icons.inbox_outlined;

  const TitansStateView.error({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  }) : icon = Icons.error_outline;

  const TitansStateView.noStudent({
    super.key,
    this.title = 'Nenhum aluno selecionado',
    this.message = 'Selecione um aluno no Painel do Mestre para abrir esta area.',
    this.action,
    this.compact = false,
  }) : icon = Icons.person_search_outlined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isError = icon == Icons.error_outline;
    final accent = isError ? cs.error : cs.primary;

    final content = Container(
      constraints: BoxConstraints(maxWidth: compact ? 420 : 520),
      padding: EdgeInsets.all(compact ? TitansUI.spaceMd : TitansUI.spaceLg),
      decoration: TitansUI.cardDecoration(context, accent: accent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.13),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: TitansUI.spaceMd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: TitansUI.spaceSm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: TitansUI.spaceMd),
            action!,
          ],
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? TitansUI.spaceMd : TitansUI.spaceLg),
        child: content,
      ),
    );
  }
}

class TitansSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const TitansSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.64)),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: TitansUI.spaceMd),
          trailing!,
        ],
      ],
    );
  }
}
class TitansCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const TitansCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = TitansUI.cardPadding,
    this.radius = TitansUI.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: TitansUI.cardDecoration(
        context,
        accent: accent,
        radius: radius,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class TitansMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const TitansMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: TitansUI.spaceXs),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: accent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TitansStatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const TitansStatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceSm,
        vertical: TitansUI.spaceXs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.pill),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: TitansUI.spaceXs),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 64,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.86),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TitansProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const TitansProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(TitansRadius.pill),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0.0, 1.0).toDouble(),
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.60),
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }
}

class TitansResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  const TitansResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = TitansUI.spaceSm,
    this.runSpacing = TitansUI.spaceSm,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();

        final width = constraints.maxWidth;
        final columns = (width / minItemWidth)
            .floor()
            .clamp(1, children.length)
            .toInt();
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth.isFinite ? itemWidth : minItemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class TitansBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: TitansCard(
              radius: TitansUI.radius,
              child: builder(context),
            ),
          ),
        );
      },
    );
  }
}
