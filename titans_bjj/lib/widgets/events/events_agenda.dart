import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../model/event_models.dart';

class EventsAgenda extends StatelessWidget {
  final List<EventModel> events;
  final DateTime now;
  final DateTime? selectedDate;
  final DateTime weekStart;
  final DateTime monthAnchor;
  final bool monthExpanded;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final VoidCallback onToggleMonth;

  const EventsAgenda({
    super.key,
    required this.events,
    required this.now,
    required this.selectedDate,
    required this.weekStart,
    required this.monthAnchor,
    required this.monthExpanded,
    required this.onSelectDate,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onToggleMonth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _dateOnly(now);
    final weekDays = List<DateTime>.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final selectedDay = selectedDate;
    final focusedDay = selectedDay ?? today;
    final selectedDayEvents = _eventsForDay(events, focusedDay);
    final weekEvents = _eventsForWeek(events, weekStart);
    final countLabel =
        selectedDay == null
            ? _eventsLabel(weekEvents.length, suffix: 'na semana')
            : _eventsLabel(selectedDayEvents.length, suffix: 'no dia');

    return TitansCard(
      accent: TitansUI.technicalBlue,
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final icon = Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TitansUI.technicalBlue.withValues(alpha: 0.12),
                  border: Border.all(
                    color: TitansUI.technicalBlue.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: TitansUI.technicalBlue,
                ),
              );
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agenda', style: TitansTypography.cardTitle(context)),
                  const SizedBox(height: 2),
                  Text(
                    selectedDate == null
                        ? 'Semana ${_weekRangeLabel(weekStart)}'
                        : 'Dia selecionado: ${_shortDate(focusedDay)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TitansTypography.caption(context),
                  ),
                ],
              );
              final chip = _AgendaCountChip(
                label: countLabel,
                muted: selectedDayEvents.isEmpty,
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: TitansUI.spaceSm),
                        Expanded(child: title),
                      ],
                    ),
                    const SizedBox(height: TitansUI.spaceXs),
                    chip,
                  ],
                );
              }

              return Row(
                children: [
                  icon,
                  const SizedBox(width: TitansUI.spaceSm),
                  Expanded(child: title),
                  const SizedBox(width: TitansUI.spaceXs),
                  chip,
                ],
              );
            },
          ),
          const SizedBox(height: TitansUI.spaceSm),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Semana anterior',
                onPressed: onPreviousWeek,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: TitansUI.spaceXs),
              IconButton.filledTonal(
                tooltip: 'Próxima semana',
                onPressed: onNextWeek,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onToday,
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('Hoje'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                tooltip:
                    monthExpanded
                        ? 'Recolher calendário mensal'
                        : 'Abrir calendário mensal',
                onPressed: onToggleMonth,
                icon: AnimatedRotation(
                  turns: monthExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceXs),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = TitansUI.spaceXs;
              return Row(
                children: [
                  for (var index = 0; index < weekDays.length; index++) ...[
                    Expanded(
                      child: _AgendaDayCell(
                        day: weekDays[index],
                        isToday: _sameCalendarDay(weekDays[index], today),
                        selected:
                            selectedDay != null &&
                            _sameCalendarDay(weekDays[index], selectedDay),
                        eventCount:
                            _eventsForDay(events, weekDays[index]).length,
                        onTap: () => onSelectDate(weekDays[index]),
                      ),
                    ),
                    if (index != weekDays.length - 1)
                      const SizedBox(width: gap),
                  ],
                ],
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child:
                monthExpanded
                    ? Padding(
                      padding: const EdgeInsets.only(top: TitansUI.spaceSm),
                      child: _MonthlyCalendarGrid(
                        anchor: monthAnchor,
                        today: today,
                        selectedDate: selectedDay,
                        events: events,
                        onSelectDate: onSelectDate,
                        onPreviousMonth: onPreviousMonth,
                        onNextMonth: onNextMonth,
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: TitansUI.spaceSm),
          Text(
            selectedDate == null
                ? 'Selecione um dia para filtrar a lista, ou use os filtros de status abaixo.'
                : 'A lista abaixo combina este dia com o filtro de status selecionado.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<EventModel> _eventsForDay(List<EventModel> events, DateTime day) {
    return events.where((event) => _sameCalendarDay(event.start, day)).toList();
  }

  static List<EventModel> _eventsForWeek(
    List<EventModel> events,
    DateTime weekStart,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return events
        .where(
          (event) =>
              !event.start.isBefore(weekStart) && event.start.isBefore(weekEnd),
        )
        .toList(growable: false);
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _shortDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}';
  }

  static String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.year == end.year && start.month == end.month) {
      return '${_shortDate(start)}-${_shortDate(end)}';
    }
    return '${_shortDate(start)}/${start.year}-${_shortDate(end)}/${end.year}';
  }

  static String _eventsLabel(int count, {required String suffix}) {
    return count == 1 ? '1 evento $suffix' : '$count eventos $suffix';
  }
}

class _AgendaCountChip extends StatelessWidget {
  final String label;
  final bool muted;

  const _AgendaCountChip({required this.label, required this.muted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent =
        muted ? cs.onSurface.withValues(alpha: 0.58) : TitansUI.technicalBlue;

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.chip),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 13, color: accent),
          const SizedBox(width: TitansUI.spaceXs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.86),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyCalendarGrid extends StatelessWidget {
  final DateTime anchor;
  final DateTime today;
  final DateTime? selectedDate;
  final List<EventModel> events;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _MonthlyCalendarGrid({
    required this.anchor,
    required this.today,
    required this.selectedDate,
    required this.events,
    required this.onSelectDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(anchor.year, anchor.month, 1);
    final leadingBlanks = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateUtils.getDaysInMonth(anchor.year, anchor.month);
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'M\u00eas anterior',
              onPressed: onPreviousMonth,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 20),
            ),
            Expanded(
              child: Text(
                _monthLabel(anchor),
                textAlign: TextAlign.center,
                style: TitansTypography.sectionEyebrow(context),
              ),
            ),
            IconButton(
              tooltip: 'Pr\u00f3ximo m\u00eas',
              onPressed: onNextMonth,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
        const SizedBox(height: TitansUI.spaceXs),
        Row(
          children: const [
            _MonthWeekdayLabel('Seg'),
            _MonthWeekdayLabel('Ter'),
            _MonthWeekdayLabel('Qua'),
            _MonthWeekdayLabel('Qui'),
            _MonthWeekdayLabel('Sex'),
            _MonthWeekdayLabel('Sab'),
            _MonthWeekdayLabel('Dom'),
          ],
        ),
        const SizedBox(height: TitansUI.spaceXs),
        for (var row = 0; row < rows; row++) ...[
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: column == 6 ? 0 : TitansUI.spaceXs,
                      bottom: TitansUI.spaceXs,
                    ),
                    child: _monthCell(row, column, leadingBlanks, daysInMonth),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _monthCell(int row, int column, int leadingBlanks, int daysInMonth) {
    final cellIndex = row * 7 + column;
    final dayNumber = cellIndex - leadingBlanks + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 42);
    }
    final day = DateTime(anchor.year, anchor.month, dayNumber);
    return _AgendaDayCell(
      day: day,
      isToday: EventsAgenda._sameCalendarDay(day, today),
      selected:
          selectedDate != null &&
          EventsAgenda._sameCalendarDay(day, selectedDate!),
      eventCount: EventsAgenda._eventsForDay(events, day).length,
      onTap: () => onSelectDate(day),
      compact: true,
    );
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MonthWeekdayLabel extends StatelessWidget {
  final String label;

  const _MonthWeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TitansTypography.caption(
          context,
        ).copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AgendaDayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool selected;
  final int eventCount;
  final VoidCallback onTap;
  final bool compact;

  const _AgendaDayCell({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.eventCount,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasEvent = eventCount > 0;
    final accent =
        selected
            ? cs.primary
            : isToday
            ? TitansUI.actionGold
            : hasEvent
            ? TitansUI.technicalBlue
            : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha:
                  selected
                      ? 0.18
                      : hasEvent || isToday
                      ? 0.12
                      : 0.04,
            ),
            borderRadius: BorderRadius.circular(TitansRadius.sm),
            border: Border.all(
              color: accent.withValues(
                alpha:
                    selected
                        ? 0.46
                        : hasEvent || isToday
                        ? 0.30
                        : 0.08,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 2 : TitansUI.spaceXs,
              vertical: compact ? 5 : TitansUI.spaceXs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _weekdayLabel(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: cs.onSurface.withValues(
                      alpha: hasEvent || selected ? 0.94 : 0.72,
                    ),
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: hasEvent ? 16 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: hasEvent ? 0.90 : 0.22),
                    borderRadius: BorderRadius.circular(TitansRadius.pill),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return labels[date.weekday - 1];
  }
}
