// event_screen.dart
import 'package:flutter/material.dart';
import '../model/event_models.dart';
import '../main.dart';
import 'package:uuid/uuid.dart';

import '../repository/event_repository.dart';
import '../service/user_session.dart';
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
    await repo.create(EventModel(
      id: const Uuid().v4(),
      title: 'Graduação Faixas',
      type: EventType.graduation,
      start: now.add(const Duration(days: 20)),
      end: now.add(const Duration(days: 20, hours: 2)),
      location: 'Matriz',
      description: 'Cerimônia de graduação e rola comemorativo.',
    ));
    await repo.create(EventModel(
      id: const Uuid().v4(),
      title: 'Aula Especial com Professor X',
      type: EventType.specialClass,
      start: now.add(const Duration(days: 7, hours: 19)),
      end: now.add(const Duration(days: 7, hours: 21)),
      location: 'Filial Centro',
      description: 'Guarda laço e variações.',
    ));
    await repo.create(EventModel(
      id: const Uuid().v4(),
      title: 'Campeonato Estadual',
      type: EventType.tournament,
      start: now.subtract(const Duration(days: 10)),
      end: now.subtract(const Duration(days: 10, hours: -8)),
      location: 'Ginásio Municipal',
      description: 'Equipe completa, categorias adulto e master.',
    ));
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

    return DefaultTabController(
      length: 2,
      child: TitansScaffold(
        scroll: false,
        appBar: AppBar(
          leading: const AppLogoLeading(),
          title: const Text('Eventos'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Próximos'),
            Tab(text: 'Passados'),
          ]),
          actions: [
            PopupMenuButton<EventType?>(
              initialValue: filterType,
              onSelected: (v) => setState(() => filterType = v),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: null, child: Text('Todos os tipos')),
                const PopupMenuItem(value: EventType.graduation, child: Text('Graduação')),
                const PopupMenuItem(value: EventType.specialClass, child: Text('Aula especial')),
                const PopupMenuItem(value: EventType.tournament, child: Text('Campeonato')),
                const PopupMenuItem(value: EventType.other, child: Text('Outros')),
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
        body: TabBarView(children: [
          _buildList(upcoming: true),
          _buildList(upcoming: false),
        ]),
      ),
    );
  }

  Widget _buildList({required bool upcoming}) {
    return FutureBuilder<List<EventModel>>(
      future: _eventsFuture,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final now = DateTime.now();
        var items = snap.data!;
        items = upcoming ? items.where((e) => e.start.isAfter(now)).toList()
            : items.where((e) => e.end.isBefore(now)).toList();
        if (filterType != null) items = items.where((e) => e.type == filterType).toList();

        if (items.isEmpty) {
          return Center(
            child: Text(upcoming ? 'Sem eventos futuros.' : 'Sem eventos passados.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = items[i];
            return Card(
              child: ListTile(
                title: Text(e.title),
                subtitle: Text('${_fmtDate(e.start)} • ${e.location}'),
                trailing: Icon(_iconForType(e.type), color: Theme.of(context).colorScheme.primary),
                onTap: () => _openDetails(e),
              ),
            );
          },
        );
      },
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
      case EventType.graduation: return Icons.military_tech_outlined;
      case EventType.specialClass: return Icons.school_outlined;
      case EventType.tournament: return Icons.emoji_events_outlined;
      case EventType.other: return Icons.event_outlined;
    }
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
    // Para i18n, depois trocamos por intl.
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
              Text(widget.existing == null ? 'Novo evento' : 'Editar evento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EventType>(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(value: EventType.graduation, child: Text('Graduação')),
                  DropdownMenuItem(value: EventType.specialClass, child: Text('Aula especial')),
                  DropdownMenuItem(value: EventType.tournament, child: Text('Campeonato')),
                  DropdownMenuItem(value: EventType.other, child: Text('Outro')),
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
              Row(children: [
                Expanded(child: _DateTimeField(label: 'Início', value: _start, onPick: (d) => setState(() => _start = d))),
                const SizedBox(width: 8),
                Expanded(child: _DateTimeField(label: 'Fim', value: _end, onPick: (d) => setState(() => _end = d))),
              ]),
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
                    end: _end.isAfter(_start) ? _end : _start.add(const Duration(hours: 1)),
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
  const _DateTimeField({required this.label, required this.value, required this.onPick});

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
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
        final picked = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
        onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_fmt(value)),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
