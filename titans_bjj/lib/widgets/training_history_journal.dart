import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/training/application/training_use_cases.dart';
import '../features/training/domain/training_models.dart';
import '../model/training_session.dart';
import 'glass_card.dart';
import 'titans_feedback.dart';

part 'training_history_calendar.dart';
part 'training_history_detail.dart';
part 'training_history_list.dart';

enum TrainingJournalMode { calendar, allHistory }

class TrainingHistoryJournal extends StatelessWidget {
  final List<TrainingSessionHistoryItem> allItems;
  final List<TrainingSessionHistoryItem> filteredItems;
  final TextEditingController searchController;
  final Widget activeFilters;
  final TrainingJournalMode mode;
  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final String? selectedSessionId;
  final int visibleCount;
  final int chartPeriodCount;
  final String chartPeriodLabel;
  final bool canEdit;
  final Set<String> lifecycleSavingIds;
  final ValueChanged<TrainingJournalMode> onModeChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<TrainingSessionHistoryItem> onSessionSelected;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onLoadMore;
  final Future<void> Function(TrainingSessionHistoryItem item)? onEdit;
  final Future<void> Function(TrainingSessionHistoryItem item)? onConfirm;
  final Future<void> Function(TrainingSessionHistoryItem item)? onMarkMissed;
  final Future<void> Function(TrainingSessionHistoryItem item)? onCancel;
  final Future<void> Function()? onAddTraining;

  const TrainingHistoryJournal({
    super.key,
    required this.allItems,
    required this.filteredItems,
    required this.searchController,
    required this.activeFilters,
    required this.mode,
    required this.displayedMonth,
    required this.selectedDay,
    required this.selectedSessionId,
    required this.visibleCount,
    required this.chartPeriodCount,
    required this.chartPeriodLabel,
    required this.canEdit,
    required this.lifecycleSavingIds,
    required this.onModeChanged,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onSessionSelected,
    required this.onOpenFilters,
    required this.onClearSearch,
    required this.onLoadMore,
    required this.onEdit,
    required this.onConfirm,
    required this.onMarkMissed,
    required this.onCancel,
    required this.onAddTraining,
  });

  @override
  Widget build(BuildContext context) {
    final monthItems = allItems
        .where((item) => _isSameMonth(item.date, displayedMonth))
        .toList(growable: false);
    final visibleItems = filteredItems
        .take(visibleCount)
        .toList(growable: false);
    final dayItems =
        selectedDay == null
            ? const <TrainingSessionHistoryItem>[]
            : allItems
                .where((item) => _isSameDay(item.date, selectedDay!))
                .toList(growable: false);
    final selectionSource =
        mode == TrainingJournalMode.calendar ? dayItems : visibleItems;
    final selectedItem = _itemById(selectionSource, selectedSessionId);
    final leftPane =
        mode == TrainingJournalMode.calendar
            ? _TrainingCalendarPane(
              items: monthItems,
              displayedMonth: displayedMonth,
              selectedDay: selectedDay,
              selectedSessionId: selectedSessionId,
              onMonthChanged: onMonthChanged,
              onDaySelected: onDaySelected,
              onSessionSelected: onSessionSelected,
            )
            : _TrainingHistoryListPane(
              allItems: allItems,
              filteredItems: filteredItems,
              visibleItems: visibleItems,
              selectedSessionId: selectedSessionId,
              searchController: searchController,
              activeFilters: activeFilters,
              canEdit: canEdit,
              onOpenFilters: onOpenFilters,
              onClearSearch: onClearSearch,
              onLoadMore: onLoadMore,
              onSessionSelected: onSessionSelected,
              onAddTraining: onAddTraining,
            );
    final detailPane = _TrainingJournalDetail(
      item: selectedItem,
      canEdit: canEdit,
      lifecycleSaving:
          selectedItem != null && lifecycleSavingIds.contains(selectedItem.id),
      onEdit:
          selectedItem == null || onEdit == null
              ? null
              : () => onEdit!(selectedItem),
      onConfirm:
          selectedItem == null || onConfirm == null
              ? null
              : () => onConfirm!(selectedItem),
      onMarkMissed:
          selectedItem == null || onMarkMissed == null
              ? null
              : () => onMarkMissed!(selectedItem),
      onCancel:
          selectedItem == null || onCancel == null
              ? null
              : () => onCancel!(selectedItem),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrainingJournalHeader(
          mode: mode,
          chartPeriodCount: chartPeriodCount,
          chartPeriodLabel: chartPeriodLabel,
          monthCount: monthItems.length,
          resultCount: filteredItems.length,
          onModeChanged: onModeChanged,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [leftPane, const SizedBox(height: 12), detailPane],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: leftPane),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: detailPane),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TrainingJournalHeader extends StatelessWidget {
  final TrainingJournalMode mode;
  final int chartPeriodCount;
  final String chartPeriodLabel;
  final int monthCount;
  final int resultCount;
  final ValueChanged<TrainingJournalMode> onModeChanged;

  const _TrainingJournalHeader({
    required this.mode,
    required this.chartPeriodCount,
    required this.chartPeriodLabel,
    required this.monthCount,
    required this.resultCount,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIÁRIO DE TREINOS',
            style: TextStyle(
              color: cs.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _JournalModeSwitcher(value: mode, onChanged: onModeChanged),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final oneColumn =
                  MediaQuery.textScalerOf(context).scale(1) > 1.35;
              final width =
                  oneColumn
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _JournalCountTile(
                    width: width,
                    label: 'Gráfico · $chartPeriodLabel',
                    value: chartPeriodCount,
                    color: cs.primary,
                  ),
                  _JournalCountTile(
                    width: width,
                    label: 'Mês do calendário',
                    value: monthCount,
                    color: TitansUI.technicalBlue,
                  ),
                  _JournalCountTile(
                    width: width,
                    label: 'Resultados da busca',
                    value: resultCount,
                    color: TitansUI.successGreen,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JournalModeSwitcher extends StatelessWidget {
  final TrainingJournalMode value;
  final ValueChanged<TrainingJournalMode> onChanged;

  const _JournalModeSwitcher({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneColumn = MediaQuery.textScalerOf(context).scale(1) > 1.35;
        final width =
            oneColumn ? constraints.maxWidth : (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModeButton(
              width: width,
              label: 'Calendário',
              icon: Icons.calendar_month_outlined,
              selected: value == TrainingJournalMode.calendar,
              onPressed: () => onChanged(TrainingJournalMode.calendar),
            ),
            _ModeButton(
              width: width,
              label: 'Todo o histórico',
              icon: Icons.view_list_outlined,
              selected: value == TrainingJournalMode.allHistory,
              onPressed: () => onChanged(TrainingJournalMode.allHistory),
            ),
          ],
        );
      },
    );
  }
}

class _JournalCountTile extends StatelessWidget {
  final double width;
  final String label;
  final int value;
  final Color color;

  const _JournalCountTile({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.width,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child:
          selected
              ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              )
              : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              ),
    );
  }
}

TrainingSessionHistoryItem? _itemById(
  List<TrainingSessionHistoryItem> items,
  String? id,
) {
  if (id == null) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

Color _statusColor(BuildContext context, TrainingSession session) {
  if (session.isAwaitingConfirmation()) return TitansUI.actionGold;
  return switch (session.effectiveStatus()) {
    TrainingSessionStatus.completed => TitansUI.successGreen,
    TrainingSessionStatus.planned => Theme.of(context).colorScheme.primary,
    TrainingSessionStatus.missed ||
    TrainingSessionStatus.canceled => Theme.of(context).colorScheme.error,
  };
}

Color _outcomeColor(String outcome) {
  if (outcome == 'Funcionou' || outcome == 'Quase funcionou') {
    return TitansUI.success;
  }
  if (outcome == 'Falhou' || outcome == 'Parceiro defendeu') {
    return TitansUI.danger;
  }
  return TitansUI.info;
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _isSameMonth(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month;

String _monthLabel(DateTime date) => '${_months[date.month - 1]} ${date.year}';

String _fullDateLabel(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';

const _months = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
