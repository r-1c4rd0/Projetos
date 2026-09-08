import 'package:flutter/material.dart';

import '../core/theme_controller.dart';
import '../core/titans_ui.dart';

Future<void> showTitansThemePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => const SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: TitansThemePreferenceSection(),
          ),
        ),
  );
}

class TitansThemePreferenceSection extends StatelessWidget {
  const TitansThemePreferenceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(TitansRadius.md),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(TitansUI.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferência visual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: TitansUI.spaceXs),
                Text(
                  'A escolha vale para a conta ativa neste dispositivo.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TitansTypography.caption(context),
                ),
                const SizedBox(height: TitansUI.spaceSm),
                for (final choice in TitansThemeChoice.values) ...[
                  _ThemeChoiceTile(
                    choice: choice,
                    selected: themeController.choice == choice,
                    onSelected: () => themeController.setChoice(choice),
                  ),
                  if (choice != TitansThemeChoice.values.last)
                    const SizedBox(height: TitansUI.spaceXs),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  final TitansThemeChoice choice;
  final bool selected;
  final VoidCallback onSelected;

  const _ThemeChoiceTile({
    required this.choice,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = _previewFor(choice);
    final borderColor =
        selected ? cs.primary : cs.onSurface.withValues(alpha: 0.10);

    return Material(
      color:
          selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(TitansRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.all(TitansUI.spaceSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansRadius.sm),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _ThemePreviewSwatch(colors: preview),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TitansTypography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TitansUI.spaceXs),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color:
                    selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _previewFor(TitansThemeChoice choice) {
    switch (choice) {
      case TitansThemeChoice.black:
        return const [Color(0xFF020304), Color(0xFF121416), Color(0xFFE7C15C)];
      case TitansThemeChoice.midnight:
        return const [Color(0xFF070A0F), Color(0xFF101826), Color(0xFF2D6BFF)];
      case TitansThemeChoice.light:
        return const [Color(0xFFE6DFCC), Color(0xFFFFFCF6), Color(0xFFB8860B)];
    }
  }
}

class _ThemePreviewSwatch extends StatelessWidget {
  final List<Color> colors;

  const _ThemePreviewSwatch({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 34,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors[0],
                borderRadius: BorderRadius.circular(TitansRadius.sm),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            bottom: 8,
            width: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors[1],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors[2],
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 16),
            ),
          ),
        ],
      ),
    );
  }
}
