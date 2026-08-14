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
