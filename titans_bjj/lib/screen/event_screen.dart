// event_screen.dart
import 'package:flutter/material.dart';
import '../core/titans_ui.dart';
import '../model/event_models.dart';
import '../main.dart';
import 'package:uuid/uuid.dart';

import '../repository/event_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_expandable_section.dart';
import '../widgets/titans_scaffold.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late final IEventRepository repo;
  late Future<List<EventModel>> _eventsFuture;
  EventType? filterType;
  bool _repoReady = false;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repoReady) return;

    final user = UserScope.of(context);
    repo = EventRepository.build(academyId: user.academyId);
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'events_fab',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<EventModel>>(
        future: _eventsFuture,
        builder: (context, snap) {
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
    final filtered =
        filterType == null
            ? List<EventModel>.from(events)
            : events.where((e) => e.type == filterType).toList();

    final upcoming =
        filtered.where((e) => e.start.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final active =
        filtered
            .where((e) => !e.start.isAfter(now) && !e.end.isBefore(now))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final past =
        filtered.where((e) => e.end.isBefore(now)).toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final nextEvent = upcoming.isEmpty ? null : upcoming.first;
    final scheduled = nextEvent == null ? upcoming : upcoming.skip(1).toList();

    final padding = TitansUI.listPadding(context, extra: 80);
    return ListView(
      padding: padding,
      children: [
        _EventsOverviewCard(
          upcomingCount: upcoming.length,
          activeCount: active.length,
          pastCount: past.length,
          filterLabel: _filterLabel(filterType),
        ),
        const SizedBox(height: TitansUI.spaceMd),
        if (nextEvent != null)
          _NextEventCard(
            event: nextEvent,
            fmtDate: _fmtDate,
            iconForType: _iconForType,
          )
        else
          _EmptyNextEventCard(filterLabel: _filterLabel(filterType)),
        const SizedBox(height: TitansUI.spaceMd),
        TitansExpandableSection(
          title: 'Eventos ativos',
          subtitle: _sectionSummary(active, 'evento em andamento'),
          initiallyExpanded: active.isNotEmpty,
          child: _EventsList(
            events: active,
            emptyMessage: 'Nenhum evento ativo agora.',
            fmtDate: _fmtDate,
            iconForType: _iconForType,
            onTap: _openDetails,
          ),
        ),
        const SizedBox(height: TitansUI.spaceSm),
        TitansExpandableSection(
          title: 'Eventos agendados',
          subtitle: _sectionSummary(scheduled, 'evento agendado'),
          initiallyExpanded: scheduled.isNotEmpty && scheduled.length <= 2,
          child: _EventsList(
            events: scheduled,
            emptyMessage: 'Sem outros eventos agendados para este filtro.',
            fmtDate: _fmtDate,
            iconForType: _iconForType,
            onTap: _openDetails,
          ),
        ),
        const SizedBox(height: TitansUI.spaceSm),
        TitansExpandableSection(
          title: 'Histórico',
          subtitle: _sectionSummary(past, 'evento passado'),
          child: _EventsList(
            events: past,
            emptyMessage: 'Sem eventos passados para este filtro.',
            fmtDate: _fmtDate,
            iconForType: _iconForType,
            onTap: _openDetails,
          ),
        ),
      ],
    );
  }

  Future<void> _openCreate() async {
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
    final updated = await showModalBottomSheet<EventModel?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventForm(existing: e),
    );
    if (updated == null) return;
    await repo.update(updated);
    if (mounted) _reloadEvents();
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

class _EventsOverviewCard extends StatelessWidget {
  final int upcomingCount;
  final int activeCount;
  final int pastCount;
  final String filterLabel;

  const _EventsOverviewCard({
    required this.upcomingCount,
    required this.activeCount,
    required this.pastCount,
    required this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TitansCard(
      radius: TitansUI.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agenda da academia',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Filtro: $filterLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TitansUI.spaceSm),
          Wrap(
            spacing: TitansUI.spaceSm,
            runSpacing: TitansUI.spaceSm,
            children: [
              _EventMetric(
                label: 'Próximos',
                value: upcomingCount.toString(),
                color: cs.primary,
              ),
              _EventMetric(
                label: 'Ativos',
                value: activeCount.toString(),
                color: TitansUI.success,
              ),
              _EventMetric(
                label: 'Histórico',
                value: pastCount.toString(),
                color: TitansUI.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EventMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  final EventModel event;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;

  const _NextEventCard({
    required this.event,
    required this.fmtDate,
    required this.iconForType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TitansCard(
      accent: cs.primary,
      radius: TitansUI.radiusSmall,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
            ),
            child: Icon(iconForType(event.type), color: cs.primary),
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próximo compromisso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _EventInfoPill(
                      icon: Icons.schedule_outlined,
                      label: fmtDate(event.start),
                    ),
                    _EventInfoPill(
                      icon: Icons.place_outlined,
                      label: event.location.trim().isEmpty
                          ? 'Local a definir'
                          : event.location,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNextEventCard extends StatelessWidget {
  final String filterLabel;

  const _EmptyNextEventCard({required this.filterLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TitansCard(
      accent: cs.secondary,
      radius: TitansUI.radiusSmall,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_available_outlined, color: cs.secondary),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sem próximo compromisso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filtro atual: $filterLabel.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.66),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
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

class _EventsList extends StatelessWidget {
  final List<EventModel> events;
  final String emptyMessage;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final ValueChanged<EventModel> onTap;

  const _EventsList({
    required this.events,
    required this.emptyMessage,
    required this.fmtDate,
    required this.iconForType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TitansUI.spaceSm),
        child: Text(
          emptyMessage,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.70)),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          _EventListCard(
            event: events[i],
            fmtDate: fmtDate,
            iconForType: iconForType,
            onTap: () => onTap(events[i]),
          ),
          if (i != events.length - 1) const SizedBox(height: TitansUI.spaceSm),
        ],
      ],
    );
  }
}

class _EventListCard extends StatelessWidget {
  final EventModel event;
  final String Function(DateTime) fmtDate;
  final IconData Function(EventType) iconForType;
  final VoidCallback onTap;

  const _EventListCard({
    required this.event,
    required this.fmtDate,
    required this.iconForType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TitansUI.spaceSm),
          child: Row(
            children: [
              Icon(iconForType(event.type), color: cs.primary),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${fmtDate(event.start)} • ${event.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.66),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

String _sectionSummary(List<EventModel> events, String singular) {
  final count = events.length;
  if (count == 0) return 'Nenhum registro neste filtro';
  if (count == 1) return '1 $singular nesta seção';
  return '$count registros nesta seção';
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
