// event_screen.dart
import 'package:flutter/material.dart';
import '../core/titans_ui.dart';
import '../features/events/application/event_use_cases.dart';
import '../features/events/domain/event_models.dart' as events_domain;
import '../model/app_user.dart';
import '../model/event_models.dart';
import 'package:titans_bjj/main.dart';
import 'package:uuid/uuid.dart';

import '../repository/event_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late final IEventRepository repo;
  late Future<List<EventModel>> _eventsFuture;
  final GetEventsDashboardSummary _getEventsDashboardSummary =
      const GetEventsDashboardSummary();
  EventType? filterType;
  _EventTimelineFilter timelineFilter = _EventTimelineFilter.scheduled;
  bool _repoReady = false;
  bool _seeded = false;
  bool _canManageEvents = false;
  DateTime? _selectedDateFilter;
  DateTime _weekAnchor = DateTime.now();
  DateTime _monthAnchor = DateTime.now();
  bool _showMonthCalendar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repoReady) return;

    final user = UserScope.of(context);
    repo = EventRepository.build(academyId: user.academyId);
    _canManageEvents =
        user.role == UserRole.admin || user.role == UserRole.professor;
    _eventsFuture = _seedAndLoad();
    _repoReady = true;
  }

  Future<List<EventModel>> _seedAndLoad() async {
    if (repo is InMemoryEventRepository) {
      await _seedDemo();
    }
    return repo.list();
  }

  Future<void> _seedDemo() async {
    if (_seeded) return;
    _seeded = true;

    final now = DateTime.now();
    await repo.create(
      EventModel(
        id: const Uuid().v4(),
        title: 'Graduação Faixas',
        type: EventType.graduation,
        start: now.add(const Duration(days: 20)),
        end: now.add(const Duration(days: 20, hours: 2)),
        location: 'Matriz',
        description: 'Cerimônia de graduação e rola comemorativo.',
      ),
    );
    await repo.create(
      EventModel(
        id: const Uuid().v4(),
        title: 'Aula Especial com Professor X',
        type: EventType.specialClass,
        start: now.add(const Duration(days: 7, hours: 19)),
        end: now.add(const Duration(days: 7, hours: 21)),
        location: 'Filial Centro',
        description: 'Guarda laço e variações.',
      ),
    );
    await repo.create(
      EventModel(
        id: const Uuid().v4(),
        title: 'Campeonato Estadual',
        type: EventType.tournament,
        start: now.subtract(const Duration(days: 10)),
        end: now.subtract(const Duration(days: 10, hours: -8)),
        location: 'Ginásio Municipal',
        description: 'Equipe completa, categorias adulto e master.',
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _reloadEvents() {
    setState(() {
      _eventsFuture = repo.list();
    });
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _weekStart(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _selectAgendaDate(DateTime date) {
    setState(() {
      _selectedDateFilter = _dateOnly(date);
      _weekAnchor = _weekStart(date);
      _monthAnchor = DateTime(date.year, date.month);
    });
  }

  void _clearAgendaDate() {
    setState(() => _selectedDateFilter = null);
  }

  void _showUpcomingEvents() {
    setState(() {
      _selectedDateFilter = null;
      timelineFilter = _EventTimelineFilter.scheduled;
    });
  }

  void _shiftAgendaWeek(int weeks) {
    setState(() {
      final offset = Duration(days: weeks * 7);
      final selected = _selectedDateFilter;
      if (selected != null) {
        final nextSelected = _dateOnly(selected.add(offset));
        _selectedDateFilter = nextSelected;
        _weekAnchor = _weekStart(nextSelected);
        _monthAnchor = DateTime(nextSelected.year, nextSelected.month);
        return;
      }
      final nextWeek = _weekStart(_weekAnchor.add(offset));
      _weekAnchor = nextWeek;
      _monthAnchor = DateTime(nextWeek.year, nextWeek.month);
    });
  }

  void _shiftAgendaMonth(int months) {
    setState(() {
      final current = DateTime(_monthAnchor.year, _monthAnchor.month);
      final nextMonth = DateTime(current.year, current.month + months);
      _monthAnchor = nextMonth;

      final selected = _selectedDateFilter;
      if (selected == null) {
        _weekAnchor = _weekStart(nextMonth);
        return;
      }

      final maxDay = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
      final nextSelected = DateTime(
        nextMonth.year,
        nextMonth.month,
        selected.day.clamp(1, maxDay),
      );
      _selectedDateFilter = nextSelected;
      _weekAnchor = _weekStart(nextSelected);
    });
  }

  void _goToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _weekAnchor = _weekStart(today);
      _monthAnchor = DateTime(today.year, today.month);
      _selectedDateFilter = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_repoReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return TitansScaffold(
      scroll: false,
      appBar: AppBar(
        leading: const AppLogoLeading(),
        title: const Text('Eventos'),
        actions: [
          PopupMenuButton<EventType?>(
            initialValue: filterType,
            tooltip: 'Filtrar eventos',
            onSelected: (v) => setState(() => filterType = v),
            itemBuilder:
                (ctx) => const [
                  PopupMenuItem(value: null, child: Text('Todos os tipos')),
                  PopupMenuItem(
                    value: EventType.graduation,
                    child: Text('Graduação'),
                  ),
                  PopupMenuItem(
                    value: EventType.specialClass,
                    child: Text('Aula especial'),
                  ),
                  PopupMenuItem(
                    value: EventType.tournament,
                    child: Text('Campeonato'),
                  ),
                  PopupMenuItem(value: EventType.other, child: Text('Outros')),
                ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton:
          _canManageEvents
              ? FloatingActionButton(
                heroTag: 'events_fab',
                onPressed: _openCreate,
                child: const Icon(Icons.add),
              )
              : null,
      body: FutureBuilder<List<EventModel>>(
        future: _eventsFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return _EventsErrorState(
              message:
                  'Não foi possível carregar os eventos. Verifique sua permissão ou conexão.',
              onRetry: _reloadEvents,
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(snap.data ?? const <EventModel>[]);
        },
      ),
    );
  }

  Widget _buildContent(List<EventModel> events) {
    final now = DateTime.now();
    final summary = _getEventsDashboardSummary(
      events: events,
      typeFilter: filterType,
      timelineFilter: timelineFilter.domainFilter,
      now: now,
    );
    final typeFiltered = summary.typeFilteredEvents;
    final visibleEvents = summary.visibleEvents;
    final selectedDate = _selectedDateFilter;
    final dateFilteredEvents =
        selectedDate == null
            ? visibleEvents
            : visibleEvents
                .where((event) => _sameDay(event.start, selectedDate))
                .toList(growable: false);
    final padding = TitansUI.listPadding(context, extra: 80);

    if (typeFiltered.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          TitansEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Agenda em construção',
            description:
                filterType == null
                    ? 'Crie o primeiro evento para organizar a agenda da academia.'
                    : 'Não há eventos para este tipo selecionado.',
            actionLabel:
                _canManageEvents && filterType == null ? 'Criar evento' : null,
            onAction:
                _canManageEvents && filterType == null ? _openCreate : null,
            variant: TitansEmptyStateVariant.action,
          ),
        ],
      );
    }

    return ListView(
      padding: padding,
      children: [
        _EventsAgendaLite(
          events: typeFiltered,
          now: now,
          selectedDate: selectedDate,
          weekStart: _weekStart(_weekAnchor),
          monthAnchor: _monthAnchor,
          monthExpanded: _showMonthCalendar,
          onSelectDate: _selectAgendaDate,
          onPreviousWeek: () => _shiftAgendaWeek(-1),
          onNextWeek: () => _shiftAgendaWeek(1),
          onPreviousMonth: () => _shiftAgendaMonth(-1),
          onNextMonth: () => _shiftAgendaMonth(1),
          onToday: _goToToday,
          onToggleMonth:
              () => setState(() => _showMonthCalendar = !_showMonthCalendar),
        ),
        const SizedBox(height: TitansUI.spaceMd),
        _EventSegmentedFilter(
          value: timelineFilter,
          onChanged: (value) => setState(() => timelineFilter = value),
        ),
        const SizedBox(height: TitansUI.spaceSm),
        _EventsUnifiedList(
          events: dateFilteredEvents,
          totalMatchingFilter: visibleEvents.length,
          selectedDate: selectedDate,
          hasAnyEvents: typeFiltered.isNotEmpty,
          filter: timelineFilter,
          typeFilterLabel: _filterLabel(filterType),
          canManageEvents: _canManageEvents,
          onCreate: _openCreate,
          onClearDate: _clearAgendaDate,
          onShowUpcomingEvents: _showUpcomingEvents,
          fmtDate: _fmtDate,
          iconForType: _iconForType,
          statusForEvent: (event) => _eventStatusLabel(event, now),
          onTap: _openDetails,
        ),
      ],
    );
  }

  _EventStatusPresentation _eventStatusLabel(EventModel event, DateTime now) {
    final status = eventTimelineStatus(event, now);
    if (status == events_domain.EventTimelineStatus.cancelled) {
      return const _EventStatusPresentation(
        label: 'Cancelado',
        variant: TitansStatusChipVariant.alert,
      );
    }
    if (status == events_domain.EventTimelineStatus.active) {
      return const _EventStatusPresentation(
        label: 'Ativo',
        variant: TitansStatusChipVariant.success,
      );
    }
    if (status == events_domain.EventTimelineStatus.scheduled) {
      return const _EventStatusPresentation(
        label: 'Agendado',
        variant: TitansStatusChipVariant.action,
      );
    }
    return const _EventStatusPresentation(
      label: 'Histórico',
      variant: TitansStatusChipVariant.muted,
    );
  }

  Future<void> _openCreate() async {
    if (!_canManageEvents) {
      _showAccessDenied();
      return;
    }

    final created = await showModalBottomSheet<EventModel?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventForm(),
    );
    if (created != null) {
      await repo.create(created);
      if (mounted) _reloadEvents();
    }
  }

  Future<void> _openDetails(EventModel e) async {
    if (!_canManageEvents) {
      _showAccessDenied();
      return;
    }

    final updated = await showModalBottomSheet<EventModel?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventForm(existing: e),
    );
    if (updated == null) return;
    await repo.update(updated);
    if (mounted) _reloadEvents();
  }

  void _showAccessDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apenas professores e administradores editam eventos.'),
      ),
    );
  }

  IconData _iconForType(EventType t) {
    switch (t) {
      case EventType.graduation:
        return Icons.military_tech_outlined;
      case EventType.specialClass:
        return Icons.school_outlined;
      case EventType.tournament:
        return Icons.emoji_events_outlined;
      case EventType.other:
        return Icons.event_outlined;
    }
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
    // Para i18n, depois trocamos por intl.
  }
}

class _EventsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventsErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, color: cs.error, size: 36),
            const SizedBox(height: TitansUI.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: TitansUI.spaceMd),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EventTimelineFilter { all, active, scheduled, history }

extension _EventTimelineFilterDomain on _EventTimelineFilter {
  events_domain.EventTimelineFilter get domainFilter {
    switch (this) {
      case _EventTimelineFilter.all:
        return events_domain.EventTimelineFilter.all;
      case _EventTimelineFilter.active:
        return events_domain.EventTimelineFilter.active;
      case _EventTimelineFilter.scheduled:
        return events_domain.EventTimelineFilter.scheduled;
      case _EventTimelineFilter.history:
        return events_domain.EventTimelineFilter.history;
    }
  }
}

class _EventStatusPresentation {
  final String label;
  final TitansStatusChipVariant variant;

  const _EventStatusPresentation({required this.label, required this.variant});
}

class _EventsAgendaLite extends StatelessWidget {
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

  const _EventsAgendaLite({
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
      isToday: _EventsAgendaLite._sameCalendarDay(day, today),
      selected:
          selectedDate != null &&
          _EventsAgendaLite._sameCalendarDay(day, selectedDate!),
      eventCount: _EventsAgendaLite._eventsForDay(events, day).length,
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

class _EventSegmentedFilter extends StatelessWidget {
  final _EventTimelineFilter value;
  final ValueChanged<_EventTimelineFilter> onChanged;

  const _EventSegmentedFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth <= 390;
        if (isNarrow) {
          return Wrap(
            spacing: TitansUI.spaceXs,
            runSpacing: TitansUI.spaceXs,
            children: [
              for (final option in _EventTimelineFilter.values)
                _EventFilterChip(
                  label: _timelineFilterLabel(option),
                  selected: value == option,
                  onTap: () => onChanged(option),
                ),
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_EventTimelineFilter>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: _EventTimelineFilter.all,
                label: Text('Todos'),
              ),
              ButtonSegment(
                value: _EventTimelineFilter.active,
                label: Text('Ativos'),
              ),
              ButtonSegment(
                value: _EventTimelineFilter.scheduled,
                label: Text('Agendados'),
              ),
              ButtonSegment(
                value: _EventTimelineFilter.history,
                label: Text('Histórico'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (selected) => onChanged(selected.first),
          ),
        );
      },
    );
  }
}

class _EventFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EventFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansRadius.chip),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansRadius.chip),
            color:
                selected
                    ? TitansUI.navSelectedBackground(context)
                    : TitansUI.navUnselectedBackground(context),
            border: Border.all(
              color: TitansUI.navBorder(context, selected: selected),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  selected
                      ? TitansUI.navSelectedForeground(context)
                      : TitansUI.navUnselectedForeground(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

String _timelineFilterLabel(_EventTimelineFilter filter) {
  switch (filter) {
    case _EventTimelineFilter.all:
      return 'Todos';
    case _EventTimelineFilter.active:
      return 'Ativos';
    case _EventTimelineFilter.scheduled:
      return 'Agendados';
    case _EventTimelineFilter.history:
      return 'Histórico';
  }
}

class _EventsUnifiedList extends StatefulWidget {
  final List<EventModel> events;
  final int totalMatchingFilter;
  final DateTime? selectedDate;
  final bool hasAnyEvents;
  final _EventTimelineFilter filter;
  final String typeFilterLabel;
  final bool canManageEvents;
  final VoidCallback onCreate;
  final VoidCallback onClearDate;
  final VoidCallback onShowUpcomingEvents;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation Function(EventModel) statusForEvent;
  final ValueChanged<EventModel> onTap;

  const _EventsUnifiedList({
    required this.events,
    required this.totalMatchingFilter,
    required this.selectedDate,
    required this.hasAnyEvents,
    required this.filter,
    required this.typeFilterLabel,
    required this.canManageEvents,
    required this.onCreate,
    required this.onClearDate,
    required this.onShowUpcomingEvents,
    required this.fmtDate,
    required this.iconForType,
    required this.statusForEvent,
    required this.onTap,
  });

  @override
  State<_EventsUnifiedList> createState() => _EventsUnifiedListState();
}

class _EventsUnifiedListState extends State<_EventsUnifiedList> {
  static const int _initialVisibleEvents = 12;
  static const int _eventsIncrement = 12;
  int _visibleEventCount = _initialVisibleEvents;

  @override
  void didUpdateWidget(covariant _EventsUnifiedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.length != widget.events.length ||
        oldWidget.totalMatchingFilter != widget.totalMatchingFilter ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.filter != widget.filter ||
        oldWidget.typeFilterLabel != widget.typeFilterLabel) {
      _visibleEventCount = _initialVisibleEvents;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedDate;
    if (widget.events.isEmpty) {
      final isAllEmpty =
          !widget.hasAnyEvents && widget.filter == _EventTimelineFilter.all;
      return TitansEmptyState(
        icon: Icons.event_note_outlined,
        title:
            selected != null
                ? 'Nenhum evento neste dia'
                : isAllEmpty
                ? 'Agenda em construção'
                : _emptyTitle(widget.filter),
        description:
            selected == null
                ? _emptyDescription(widget.filter)
                : 'O dia selecionado não tem eventos para o status e tipo atuais.',
        actionLabel:
            isAllEmpty && widget.canManageEvents
                ? 'Criar evento'
                : selected != null
                ? 'Mostrar próximos eventos'
                : null,
        onAction:
            isAllEmpty && widget.canManageEvents
                ? widget.onCreate
                : selected != null
                ? widget.onShowUpcomingEvents
                : null,
        variant:
            isAllEmpty
                ? TitansEmptyStateVariant.action
                : TitansEmptyStateVariant.neutral,
        compact: true,
      );
    }

    final orderedEvents = _orderedEvents(widget.events, widget.filter);
    final visibleEvents = orderedEvents
        .take(_visibleEventCount)
        .toList(growable: false);
    final remaining = orderedEvents.length - visibleEvents.length;
    final rows = _rowsFor(visibleEvents);

    return TitansCard(
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _listTitle,
                      style: TitansTypography.cardTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summaryLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TitansTypography.caption(context),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                TextButton.icon(
                  onPressed: widget.onClearDate,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Data'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceSm),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is DateTime) {
                return Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : TitansUI.spaceSm,
                    bottom: TitansUI.spaceXs,
                  ),
                  child: _EventDateHeader(label: _dateHeader(row)),
                );
              }
              final event = row as EventModel;
              return Padding(
                padding: const EdgeInsets.only(bottom: TitansUI.spaceSm),
                child: _EventListCard(
                  event: event,
                  fmtDate: widget.fmtDate,
                  iconForType: widget.iconForType,
                  status: widget.statusForEvent(event),
                  onTap: () => widget.onTap(event),
                ),
              );
            },
          ),
          if (remaining > 0) ...[
            const SizedBox(height: TitansUI.spaceXs),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _visibleEventCount += _eventsIncrement;
                  });
                },
                icon: const Icon(Icons.expand_more_outlined, size: 18),
                label: Text('Mostrar mais ($remaining)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<EventModel> _orderedEvents(
    List<EventModel> events,
    _EventTimelineFilter filter,
  ) {
    final ordered = List<EventModel>.from(events);
    ordered.sort((a, b) {
      if (filter == _EventTimelineFilter.history) {
        return b.start.compareTo(a.start);
      }
      return a.start.compareTo(b.start);
    });
    return ordered;
  }

  List<Object> _rowsFor(List<EventModel> events) {
    final rows = <Object>[];
    DateTime? currentDay;
    for (final event in events) {
      final eventDay = _dateOnly(event.start);
      if (currentDay == null || !_sameDate(currentDay, eventDay)) {
        currentDay = eventDay;
        rows.add(eventDay);
      }
      rows.add(event);
    }
    return rows;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get _listTitle {
    switch (widget.filter) {
      case _EventTimelineFilter.all:
        return 'Agenda';
      case _EventTimelineFilter.active:
        return 'Eventos ativos';
      case _EventTimelineFilter.scheduled:
        return 'Próximos eventos';
      case _EventTimelineFilter.history:
        return 'Histórico';
    }
  }

  String get _summaryLabel {
    final statusLabel = _timelineFilterLabel(widget.filter).toLowerCase();
    final base =
        'Exibindo ${widget.events.length} de ${widget.totalMatchingFilter} eventos; status: $statusLabel; tipo: ${widget.typeFilterLabel}.';
    final selected = widget.selectedDate;
    if (selected == null) return base;
    String two(int value) => value.toString().padLeft(2, '0');
    return '$base Dia ${two(selected.day)}/${two(selected.month)} aplicado.';
  }

  String _dateHeader(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    if (_sameDate(date, today)) return 'Hoje';
    if (_sameDate(date, tomorrow)) return 'Amanhã';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _emptyDescription(_EventTimelineFilter filter) {
    switch (filter) {
      case _EventTimelineFilter.scheduled:
        return 'Nenhum próximo evento para os filtros selecionados.';
      case _EventTimelineFilter.history:
        return 'Nenhum evento no histórico para os filtros selecionados.';
      default:
        return 'Não há eventos para os filtros selecionados.';
    }
  }

  String _emptyTitle(_EventTimelineFilter filter) {
    switch (filter) {
      case _EventTimelineFilter.all:
        return 'Nenhum evento encontrado';
      case _EventTimelineFilter.active:
        return 'Nenhum evento ativo';
      case _EventTimelineFilter.scheduled:
        return 'Nenhum próximo evento';
      case _EventTimelineFilter.history:
        return 'Histórico vazio';
    }
  }
}

class _EventDateHeader extends StatelessWidget {
  final String label;

  const _EventDateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: TitansUI.technicalBlue.withValues(alpha: 0.82),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: TitansUI.spaceXs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventListCard extends StatelessWidget {
  final EventModel event;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation status;
  final VoidCallback onTap;

  const _EventListCard({
    required this.event,
    required this.fmtDate,
    required this.iconForType,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final location = event.location.trim();
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TitansUI.spaceSm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 300;
              final metaMaxWidth = (constraints.maxWidth * 0.72).clamp(
                120.0,
                210.0,
              );
              final statusChip = _EventMetaChip(
                label: status.label,
                variant: status.variant,
                maxWidth: isCompact ? metaMaxWidth : 128,
              );

              final title = Text(
                event.title,
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(iconForType(event.type), color: cs.primary),
                  ),
                  const SizedBox(width: TitansUI.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCompact) ...[
                          title,
                          const SizedBox(height: TitansUI.spaceXs),
                          statusChip,
                        ] else
                          Row(
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: TitansUI.spaceXs),
                              statusChip,
                            ],
                          ),
                        const SizedBox(height: TitansUI.spaceXs),
                        Wrap(
                          spacing: TitansUI.spaceXs,
                          runSpacing: TitansUI.spaceXs,
                          children: [
                            _EventMetaChip(
                              label: fmtDate(event.start),
                              variant: TitansStatusChipVariant.technical,
                              icon: Icons.schedule_outlined,
                              maxWidth: metaMaxWidth,
                            ),
                            if (location.isNotEmpty)
                              _EventMetaChip(
                                label: location,
                                variant: TitansStatusChipVariant.neutral,
                                icon: Icons.place_outlined,
                                maxWidth: metaMaxWidth,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TitansUI.spaceXs),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.54),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EventMetaChip extends StatelessWidget {
  final String label;
  final TitansStatusChipVariant variant;
  final IconData? icon;
  final double maxWidth;

  const _EventMetaChip({
    required this.label,
    required this.variant,
    required this.maxWidth,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accentFor(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
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
            if (icon != null) ...[
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: TitansUI.spaceXs),
            ],
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
      ),
    );
  }

  Color _accentFor(BuildContext context) {
    final tokens = TitansUI.colors(context);
    switch (variant) {
      case TitansStatusChipVariant.technical:
      case TitansStatusChipVariant.neutral:
        return tokens.technical;
      case TitansStatusChipVariant.action:
      case TitansStatusChipVariant.attention:
        return tokens.accent;
      case TitansStatusChipVariant.success:
        return tokens.success;
      case TitansStatusChipVariant.alert:
      case TitansStatusChipVariant.error:
        return tokens.alert;
      case TitansStatusChipVariant.muted:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
    }
  }
}

String _filterLabel(EventType? type) {
  switch (type) {
    case null:
      return 'Todos os tipos';
    case EventType.graduation:
      return 'Graduação';
    case EventType.specialClass:
      return 'Aula especial';
    case EventType.tournament:
      return 'Campeonato';
    case EventType.other:
      return 'Outros';
  }
}

class _EventForm extends StatefulWidget {
  final EventModel? existing;
  const _EventForm({this.existing});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  EventType _type = EventType.other;
  DateTime _start = DateTime.now().add(const Duration(hours: 2));
  DateTime _end = DateTime.now().add(const Duration(hours: 4));

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _location.text = e.location;
      _description.text = e.description;
      _type = e.type;
      _start = e.start;
      _end = e.end;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null ? 'Novo evento' : 'Editar evento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe o título'
                            : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EventType>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                    value: EventType.graduation,
                    child: Text('Graduação'),
                  ),
                  DropdownMenuItem(
                    value: EventType.specialClass,
                    child: Text('Aula especial'),
                  ),
                  DropdownMenuItem(
                    value: EventType.tournament,
                    child: Text('Campeonato'),
                  ),
                  DropdownMenuItem(
                    value: EventType.other,
                    child: Text('Outro'),
                  ),
                ],
                onChanged: (v) => setState(() => _type = v ?? EventType.other),
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeField(
                      label: 'Início',
                      value: _start,
                      onPick: (d) => setState(() => _start = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateTimeField(
                      label: 'Fim',
                      value: _end,
                      onPick: (d) => setState(() => _end = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  final id = widget.existing?.id ?? const Uuid().v4();
                  final model = EventModel(
                    id: id,
                    title: _title.text.trim(),
                    type: _type,
                    start: _start,
                    end:
                        _end.isAfter(_start)
                            ? _end
                            : _start.add(const Duration(hours: 1)),
                    location: _location.text.trim(),
                    description: _description.text.trim(),
                    status: widget.existing?.status ?? EventStatus.scheduled,
                    attendees: widget.existing?.attendees,
                  );
                  Navigator.pop(context, model);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (d == null) return;
        if (!context.mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        final picked = DateTime(
          d.year,
          d.month,
          d.day,
          t?.hour ?? 0,
          t?.minute ?? 0,
        );
        onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_fmt(value)),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
