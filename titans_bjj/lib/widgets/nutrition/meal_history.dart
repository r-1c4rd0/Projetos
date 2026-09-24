import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/nutrition/domain/nutrition_models.dart';
import '../../model/nutrition_models.dart' show FoodItem;
import '../titans_feedback.dart';

class NutritionMealsSection extends StatefulWidget {
  final MealLogSummary mealLog;
  final bool canEditNutrition;
  final bool showAddMealAction;
  final VoidCallback onAddMeal;
  final ValueChanged<NutritionMealLogItem> onOpenMeal;

  const NutritionMealsSection({
    super.key,
    required this.mealLog,
    required this.canEditNutrition,
    required this.showAddMealAction,
    required this.onAddMeal,
    required this.onOpenMeal,
  });

  @override
  State<NutritionMealsSection> createState() => _NutritionMealsSectionState();
}

class _NutritionMealsSectionState extends State<NutritionMealsSection> {
  static const _collapsedHistoryCount = 3;
  static const _expandedHistoryCount = 20;

  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final todayMeals = _todayMeals;
    final olderMeals = _olderMeals;
    final latestToday = todayMeals.isEmpty ? null : todayMeals.first.date;
    final weekCount = _weekMealCount(widget.mealLog.items);
    final canAdd = widget.canEditNutrition && widget.showAddMealAction;

    return TitansCard(
      accent:
          widget.mealLog.isEmpty ? TitansUI.actionGold : TitansUI.technicalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            spacing: TitansUI.spaceSm,
            overflowSpacing: TitansUI.spaceSm,
            children: [
              const _MealSectionTitle(
                title: 'Di\u00e1rio de hoje',
                subtitle: 'Registro alimentar descritivo, sem meta.',
              ),
              if (canAdd && !widget.mealLog.isEmpty)
                FilledButton.icon(
                  onPressed: widget.onAddMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar refei\u00e7\u00e3o'),
                ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceSm),
          _MealLogSummaryRail(
            todayCount: todayMeals.length,
            latestTime:
                latestToday == null
                    ? 'Sem registro'
                    : _fmtMealTime(context, latestToday),
            weekCount: weekCount,
          ),
          const SizedBox(height: TitansUI.spaceMd),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                widget.mealLog.isEmpty
                    ? _MealLogEmptyState(
                      canEditNutrition: widget.canEditNutrition,
                      canAdd: canAdd,
                      onAddMeal: widget.onAddMeal,
                    )
                    : _MealLogContent(
                      todayMeals: todayMeals,
                      olderMeals: olderMeals,
                      showHistory: _showHistory,
                      onToggleHistory: _toggleHistory,
                      onOpenMeal: widget.onOpenMeal,
                    ),
          ),
        ],
      ),
    );
  }

  List<NutritionMealLogItem> get _todayMeals {
    final now = DateTime.now();
    return widget.mealLog.items
        .where((item) => _isSameDay(item.date, now))
        .toList(growable: false);
  }

  List<NutritionMealLogItem> get _olderMeals {
    final now = DateTime.now();
    return widget.mealLog.items
        .where((item) => !_isSameDay(item.date, now))
        .toList(growable: false);
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
  }

  int _weekMealCount(List<NutritionMealLogItem> meals) {
    final start = _dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    return meals.where((item) => !_dateOnly(item.date).isBefore(start)).length;
  }
}

class _MealLogSummaryRail extends StatelessWidget {
  final int todayCount;
  final String latestTime;
  final int weekCount;

  const _MealLogSummaryRail({
    required this.todayCount,
    required this.latestTime,
    required this.weekCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TitansUI.spaceSm,
      runSpacing: TitansUI.spaceSm,
      children: [
        _MealLogSummaryPill(
          icon: Icons.today_outlined,
          label: 'Hoje',
          value: '$todayCount',
        ),
        _MealLogSummaryPill(
          icon: Icons.schedule_outlined,
          label: '\u00daltima',
          value: latestTime,
        ),
        _MealLogSummaryPill(
          icon: Icons.calendar_view_week_outlined,
          label: '7 dias',
          value: '$weekCount',
        ),
      ],
    );
  }
}

class _MealLogSummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MealLogSummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 156),
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceSm,
        vertical: TitansUI.spaceXs,
      ),
      decoration: BoxDecoration(
        color: TitansUI.elevatedSurfaceColor(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: TitansUI.technicalBlue),
          const SizedBox(width: TitansUI.spaceXs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TitansTypography.caption(context)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealLogEmptyState extends StatelessWidget {
  final bool canEditNutrition;
  final bool canAdd;
  final VoidCallback onAddMeal;

  const _MealLogEmptyState({
    required this.canEditNutrition,
    required this.canAdd,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return TitansEmptyState(
      key: const ValueKey('nutrition-empty-meals'),
      icon: Icons.restaurant_outlined,
      title:
          canEditNutrition
              ? 'Seu di\u00e1rio de hoje est\u00e1 vazio.'
              : 'Di\u00e1rio de hoje vazio.',
      message:
          canEditNutrition
              ? 'Use o di\u00e1rio para manter um hist\u00f3rico do que voc\u00ea consumiu.'
              : 'Nenhuma refei\u00e7\u00e3o foi registrada para este usu\u00e1rio hoje.',
      actionLabel: canAdd ? 'Registrar primeira refei\u00e7\u00e3o' : null,
      onAction: canAdd ? onAddMeal : null,
      variant:
          canEditNutrition
              ? TitansEmptyStateVariant.action
              : TitansEmptyStateVariant.neutral,
      compact: true,
      showCard: false,
    );
  }
}

class _MealLogContent extends StatelessWidget {
  final List<NutritionMealLogItem> todayMeals;
  final List<NutritionMealLogItem> olderMeals;
  final bool showHistory;
  final VoidCallback onToggleHistory;
  final ValueChanged<NutritionMealLogItem> onOpenMeal;

  const _MealLogContent({
    required this.todayMeals,
    required this.olderMeals,
    required this.showHistory,
    required this.onToggleHistory,
    required this.onOpenMeal,
  });

  @override
  Widget build(BuildContext context) {
    final historyLimit =
        showHistory
            ? _NutritionMealsSectionState._expandedHistoryCount
            : _NutritionMealsSectionState._collapsedHistoryCount;
    final visibleOlderMeals = olderMeals.take(historyLimit).toList();
    final hiddenHistoryCount = olderMeals.length - visibleOlderMeals.length;

    return Column(
      key: const ValueKey('nutrition-meal-log-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayMeals.isEmpty)
          const TitansEmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Seu di\u00e1rio de hoje est\u00e1 vazio.',
            message: 'Os registros anteriores continuam no hist\u00f3rico.',
            compact: true,
            showCard: false,
          )
        else
          _MealTimelineList(items: todayMeals, onOpenMeal: onOpenMeal),
        if (olderMeals.isNotEmpty) ...[
          const SizedBox(height: TitansUI.spaceMd),
          _MealLogDayHeader(label: 'Refei\u00e7\u00f5es anteriores'),
          const SizedBox(height: TitansUI.spaceXs),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _MealTimelineList(
              items: visibleOlderMeals,
              onOpenMeal: onOpenMeal,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleHistory,
              icon: Icon(
                showHistory
                    ? Icons.expand_less_outlined
                    : Icons.expand_more_outlined,
                size: 18,
              ),
              label: Text(
                showHistory
                    ? 'Ocultar hist\u00f3rico'
                    : hiddenHistoryCount > 0
                    ? 'Ver hist\u00f3rico ($hiddenHistoryCount)'
                    : 'Ver hist\u00f3rico',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MealTimelineList extends StatelessWidget {
  final List<NutritionMealLogItem> items;
  final ValueChanged<NutritionMealLogItem> onOpenMeal;

  const _MealTimelineList({required this.items, required this.onOpenMeal});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          _MealTimelineRow(
            item: items[index],
            onTap: () => onOpenMeal(items[index]),
          ),
        ],
      ],
    );
  }
}

class _MealSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MealSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtMealTime(BuildContext context, DateTime date) =>
    TimeOfDay.fromDateTime(date).format(context);

String _itemsPreview(List<FoodItem> items) {
  if (items.isEmpty) return 'Sem alimentos informados';
  final names = items.take(3).map((food) => food.name).join(', ');
  final remaining = items.length - 3;
  return remaining <= 0 ? names : '$names +$remaining';
}

class _MealLogDayHeader extends StatelessWidget {
  final String label;

  const _MealLogDayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.56),
        ),
        const SizedBox(width: TitansUI.spaceXs),
        Text(
          label,
          style: TitansTypography.caption(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: TitansUI.spaceXs),
        Expanded(
          child: Container(
            height: 1,
            color: cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _MealTimelineRow extends StatelessWidget {
  final NutritionMealLogItem item;
  final VoidCallback onTap;

  const _MealTimelineRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foodCount = item.meal.items.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TitansUI.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  _fmtMealTime(context, item.date),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: TitansUI.technicalBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.mealType,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _itemsPreview(item.meal.items),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (foodCount > 0) ...[
                const SizedBox(width: TitansUI.spaceXs),
                TitansStatusChip(
                  label: '$foodCount',
                  variant: TitansStatusChipVariant.muted,
                  icon: Icons.restaurant_menu_outlined,
                  compact: true,
                ),
              ],
              const SizedBox(width: TitansUI.spaceXs),
              Icon(
                Icons.chevron_right,
                color: cs.onSurface.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
