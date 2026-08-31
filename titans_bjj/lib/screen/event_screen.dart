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
  _EventTimelineFilter timelineFilter = _EventTimelineFilter.all;
  bool _repoReady = false;
  bool _seeded = false;
  bool _canManageEvents = false;

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
    final nextEvent = summary.featuredEvent;
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
        _NextEventHighlight(
          event: nextEvent,
          canManageEvents: _canManageEvents,
          filterLabel: _filterLabel(filterType),
          onCreate: _openCreate,
          fmtDate: _fmtDate,
          iconForType: _iconForType,
          statusForEvent: (event) => _eventStatusLabel(event, now),
        ),
        const SizedBox(height: TitansUI.spaceMd),
        _EventsAgendaLite(
          events: typeFiltered,
          now: now,
          fmtDate: _fmtDate,
          iconForType: _iconForType,
          statusForEvent: (event) => _eventStatusLabel(event, now),
        ),
        const SizedBox(height: TitansUI.spaceMd),
        _EventSegmentedFilter(
          value: timelineFilter,
          onChanged: (value) => setState(() => timelineFilter = value),
        ),
        const SizedBox(height: TitansUI.spaceSm),
        _EventsUnifiedList(
          events: visibleEvents,
          hasAnyEvents: typeFiltered.isNotEmpty,
          filter: timelineFilter,
          canManageEvents: _canManageEvents,
          onCreate: _openCreate,
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

class _NextEventHighlight extends StatelessWidget {
  final EventModel? event;
  final bool canManageEvents;
  final String filterLabel;
  final VoidCallback onCreate;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation Function(EventModel) statusForEvent;

  const _NextEventHighlight({
    required this.event,
    required this.canManageEvents,
    required this.filterLabel,
    required this.onCreate,
    required this.fmtDate,
    required this.iconForType,
    required this.statusForEvent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final next = event;
    if (next == null) {
      return TitansEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nenhum próximo evento',
        description:
            filterLabel == 'Todos os tipos'
                ? 'A agenda ainda não tem compromissos futuros.'
                : 'Não há compromissos futuros para este filtro.',
        actionLabel: canManageEvents ? 'Criar evento' : null,
        onAction: canManageEvents ? onCreate : null,
        variant: TitansEmptyStateVariant.action,
        compact: true,
      );
    }

    final status = statusForEvent(next);
    return TitansCard(
      accent: TitansUI.actionGold,
      radius: TitansUI.radiusSmall,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TitansUI.actionGold.withValues(alpha: 0.12),
              border: Border.all(
                color: TitansUI.actionGold.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(iconForType(next.type), color: TitansUI.actionGold),
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próximo evento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TitansTypography.sectionEyebrow(context),
                ),
                const SizedBox(height: 6),
                Text(
                  next.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: TitansUI.spaceSm),
                Wrap(
                  spacing: TitansUI.spaceXs,
                  runSpacing: TitansUI.spaceXs,
                  children: [
                    TitansStatusChip(
                      label: status.label,
                      variant: status.variant,
                      compact: true,
                    ),
                    TitansStatusChip(
                      label: fmtDate(next.start),
                      variant: TitansStatusChipVariant.technical,
                      icon: Icons.schedule_outlined,
                      compact: true,
                    ),
                    if (next.location.trim().isNotEmpty)
                      TitansStatusChip(
                        label: next.location.trim(),
                        variant: TitansStatusChipVariant.neutral,
                        icon: Icons.place_outlined,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: TitansUI.spaceXs),
          Icon(Icons.star_rounded, color: cs.primary, size: 20),
        ],
      ),
    );
  }
}

class _EventsAgendaLite extends StatelessWidget {
  final List<EventModel> events;
  final DateTime now;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation Function(EventModel) statusForEvent;

  const _EventsAgendaLite({
    required this.events,
    required this.now,
    required this.fmtDate,
    required this.iconForType,
    required this.statusForEvent,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        events.where((event) {
            final status = eventTimelineStatus(event, now);
            return status == events_domain.EventTimelineStatus.active ||
                status == events_domain.EventTimelineStatus.scheduled;
          }).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final anchor = upcoming.isNotEmpty ? upcoming.first.start : today;
    final daysInMonth = DateUtils.getDaysInMonth(anchor.year, anchor.month);
    final calendarDays = List<DateTime>.generate(
      daysInMonth,
      (index) => DateTime(anchor.year, anchor.month, index + 1),
    );
    final nextItems = upcoming.take(3).toList();

    return TitansCard(
      accent: TitansUI.technicalBlue,
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
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
              ),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agenda', style: TitansTypography.cardTitle(context)),
                    const SizedBox(height: 2),
                    Text(
                      _monthLabel(anchor),
                      style: TitansTypography.caption(context),
                    ),
                  ],
                ),
              ),
              TitansStatusChip(
                label: _futureEventsLabel(upcoming.length),
                variant:
                    upcoming.isEmpty
                        ? TitansStatusChipVariant.muted
                        : TitansStatusChipVariant.technical,
                icon: Icons.event_available_outlined,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceMd),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 380 ? 5 : 7;
              const gap = TitansUI.spaceXs;
              final cellWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final day in calendarDays)
                    SizedBox(
                      width: cellWidth.clamp(42.0, 72.0).toDouble(),
                      child: _AgendaDayCell(
                        day: day,
                        isToday: _sameCalendarDay(day, today),
                        events: _eventsForDay(events, day),
                      ),
                    ),
                ],
              );
            },
          ),
          if (nextItems.isNotEmpty) ...[
            const SizedBox(height: TitansUI.spaceMd),
            Text(
              'Pr\u00f3ximos na agenda',
              style: TitansTypography.sectionEyebrow(context),
            ),
            const SizedBox(height: TitansUI.spaceXs),
            for (var i = 0; i < nextItems.length; i++) ...[
              _AgendaMiniEvent(
                event: nextItems[i],
                fmtDate: fmtDate,
                iconForType: iconForType,
                status: statusForEvent(nextItems[i]),
              ),
              if (i != nextItems.length - 1)
                const SizedBox(height: TitansUI.spaceXs),
            ],
          ],
        ],
      ),
    );
  }

  static List<EventModel> _eventsForDay(List<EventModel> events, DateTime day) {
    return events.where((event) => _sameCalendarDay(event.start, day)).toList();
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Mar\u00e7o',
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

  static String _futureEventsLabel(int count) {
    return count == 1 ? '1 futuro' : '$count futuros';
  }
}

class _AgendaDayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final List<EventModel> events;

  const _AgendaDayCell({
    required this.day,
    required this.isToday,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasEvent = events.isNotEmpty;
    final accent =
        isToday
            ? TitansUI.actionGold
            : hasEvent
            ? TitansUI.technicalBlue
            : cs.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: hasEvent || isToday ? 0.12 : 0.04),
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        border: Border.all(
          color: accent.withValues(alpha: hasEvent || isToday ? 0.30 : 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TitansUI.spaceXs,
          vertical: TitansUI.spaceXs,
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
                color: cs.onSurface.withValues(alpha: hasEvent ? 0.94 : 0.72),
                fontSize: 14,
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
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return labels[date.weekday - 1];
  }
}

class _AgendaMiniEvent extends StatelessWidget {
  final EventModel event;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation status;

  const _AgendaMiniEvent({
    required this.event,
    required this.fmtDate,
    required this.iconForType,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TitansUI.spaceXs),
        child: Row(
          children: [
            Icon(
              iconForType(event.type),
              color: TitansUI.technicalBlue,
              size: 18,
            ),
            const SizedBox(width: TitansUI.spaceXs),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: TitansUI.spaceXs),
            TitansStatusChip(
              label: fmtDate(event.start),
              variant: status.variant,
              compact: true,
            ),
          ],
        ),
      ),
    );
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
    final cs = Theme.of(context).colorScheme;
    final accent = selected ? TitansUI.actionGold : cs.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansRadius.chip),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitansRadius.chip),
            color: accent.withValues(alpha: selected ? 0.14 : 0.06),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.34 : 0.14),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: selected ? 0.92 : 0.70),
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

class _EventsUnifiedList extends StatelessWidget {
  final List<EventModel> events;
  final bool hasAnyEvents;
  final _EventTimelineFilter filter;
  final bool canManageEvents;
  final VoidCallback onCreate;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final _EventStatusPresentation Function(EventModel) statusForEvent;
  final ValueChanged<EventModel> onTap;

  const _EventsUnifiedList({
    required this.events,
    required this.hasAnyEvents,
    required this.filter,
    required this.canManageEvents,
    required this.onCreate,
    required this.fmtDate,
    required this.iconForType,
    required this.statusForEvent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      final isAllEmpty = !hasAnyEvents && filter == _EventTimelineFilter.all;
      return TitansEmptyState(
        icon: Icons.event_note_outlined,
        title: isAllEmpty ? 'Agenda em construção' : _emptyTitle(filter),
        description:
            isAllEmpty
                ? 'Crie o primeiro evento para organizar a agenda da academia.'
                : 'Não há eventos para o filtro selecionado.',
        actionLabel: isAllEmpty && canManageEvents ? 'Criar evento' : null,
        onAction: isAllEmpty && canManageEvents ? onCreate : null,
        variant:
            isAllEmpty
                ? TitansEmptyStateVariant.action
                : TitansEmptyStateVariant.neutral,
        compact: true,
      );
    }

    return TitansCard(
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Eventos', style: TitansTypography.cardTitle(context)),
          const SizedBox(height: TitansUI.spaceSm),
          for (var i = 0; i < events.length; i++) ...[
            _EventListCard(
              event: events[i],
              fmtDate: fmtDate,
              iconForType: iconForType,
              status: statusForEvent(events[i]),
              onTap: () => onTap(events[i]),
            ),
            if (i != events.length - 1)
              const SizedBox(height: TitansUI.spaceSm),
          ],
        ],
      ),
    );
  }

  String _emptyTitle(_EventTimelineFilter filter) {
    switch (filter) {
      case _EventTimelineFilter.all:
        return 'Nenhum evento encontrado';
      case _EventTimelineFilter.active:
        return 'Nenhum evento ativo';
      case _EventTimelineFilter.scheduled:
        return 'Nenhum evento agendado';
      case _EventTimelineFilter.history:
        return 'Histórico vazio';
    }
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
          child: Row(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: TitansUI.spaceXs),
                        TitansStatusChip(
                          label: status.label,
                          variant: status.variant,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: TitansUI.spaceXs),
                    Wrap(
                      spacing: TitansUI.spaceXs,
                      runSpacing: TitansUI.spaceXs,
                      children: [
                        TitansStatusChip(
                          label: fmtDate(event.start),
                          variant: TitansStatusChipVariant.technical,
                          icon: Icons.schedule_outlined,
                          compact: true,
                        ),
                        if (location.isNotEmpty)
                          TitansStatusChip(
                            label: location,
                            variant: TitansStatusChipVariant.neutral,
                            icon: Icons.place_outlined,
                            compact: true,
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
          ),
        ),
      ),
    );
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
