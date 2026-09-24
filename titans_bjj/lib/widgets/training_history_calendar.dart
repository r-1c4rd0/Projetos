part of 'training_history_journal.dart';

class _TrainingCalendarPane extends StatelessWidget {
  final List<TrainingSessionHistoryItem> items;
  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final String? selectedSessionId;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<TrainingSessionHistoryItem> onSessionSelected;

  const _TrainingCalendarPane({
    required this.items,
    required this.displayedMonth,
    required this.selectedDay,
    required this.selectedSessionId,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final itemsByDay = <int, List<TrainingSessionHistoryItem>>{};
    for (final item in items) {
      itemsByDay.putIfAbsent(item.date.day, () => []).add(item);
    }
    final selectedItems =
        selectedDay == null || !_isSameMonth(selectedDay!, displayedMonth)
            ? const <TrainingSessionHistoryItem>[]
            : itemsByDay[selectedDay!.day] ??
                const <TrainingSessionHistoryItem>[];

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarMonthHeader(
            month: displayedMonth,
            onPrevious:
                () => onMonthChanged(
                  DateTime(displayedMonth.year, displayedMonth.month - 1),
                ),
            onNext:
                () => onMonthChanged(
                  DateTime(displayedMonth.year, displayedMonth.month + 1),
                ),
          ),
          const SizedBox(height: 10),
          _CompactTrainingCalendar(
            month: displayedMonth,
            itemsByDay: itemsByDay,
            selectedDay: selectedDay,
            onDaySelected: onDaySelected,
          ),
          const SizedBox(height: 10),
          const _CalendarLegend(),
          if (selectedDay != null) ...[
            const SizedBox(height: 12),
            Text(
              _fullDateLabel(selectedDay!),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (selectedItems.isEmpty)
              Text(
                'Nenhuma sessão registrada neste dia.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              )
            else
              _SessionChoiceList(
                items: selectedItems,
                selectedSessionId: selectedSessionId,
                onSelected: onSessionSelected,
              ),
          ],
        ],
      ),
    );
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _monthLabel(month),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _CompactTrainingCalendar extends StatelessWidget {
  final DateTime month;
  final Map<int, List<TrainingSessionHistoryItem>> itemsByDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _CompactTrainingCalendar({
    required this.month,
    required this.itemsByDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 1; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _CalendarDayCell(
          day: DateTime(month.year, month.month, day),
          items: itemsByDay[day] ?? const <TrainingSessionHistoryItem>[],
          selected:
              selectedDay != null &&
              _isSameDay(selectedDay!, DateTime(month.year, month.month, day)),
          onPressed:
              () => onDaySelected(DateTime(month.year, month.month, day)),
        ),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio:
              MediaQuery.textScalerOf(context).scale(1) > 1.35 ? 0.44 : 0.72,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final List<TrainingSessionHistoryItem> items;
  final bool selected;
  final VoidCallback onPressed;

  const _CalendarDayCell({
    required this.day,
    required this.items,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final markers = items.take(3).toList(growable: false);
    return Semantics(
      label: '${day.day}, ${items.length} sessões',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                selected
                    ? cs.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
            border: Border.all(
              color:
                  selected ? cs.primary : cs.onSurface.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            children: [
              Text(
                day.day.toString(),
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final item in markers) _StatusDot(item: item),
                  if (items.length > markers.length)
                    Text(
                      '+${items.length - markers.length}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final TrainingSessionHistoryItem item;

  const _StatusDot({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: _statusColor(context, item.session),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        _LegendItem(label: 'Realizado', color: TitansUI.successGreen),
        _LegendItem(
          label: 'Planejado',
          color: Theme.of(context).colorScheme.primary,
        ),
        _LegendItem(label: 'Pendente', color: TitansUI.actionGold),
        _LegendItem(
          label: 'Não realizado/cancelado',
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionChoiceList extends StatelessWidget {
  final List<TrainingSessionHistoryItem> items;
  final String? selectedSessionId;
  final ValueChanged<TrainingSessionHistoryItem> onSelected;

  const _SessionChoiceList({
    required this.items,
    required this.selectedSessionId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.length > 1) ...[
          Text(
            'Escolha uma sessão para consultar',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
        ],
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _CompactSessionRow(
              item: item,
              selected: selectedSessionId == item.id,
              onPressed: () => onSelected(item),
            ),
          ),
      ],
    );
  }
}
