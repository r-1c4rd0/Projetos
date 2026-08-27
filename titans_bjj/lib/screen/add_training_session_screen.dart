import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/app_user.dart';
import '../model/jiu_jitsu_taxonomy_item.dart';
import '../model/training_session.dart';
import '../repository/jiu_jitsu_taxonomy_repository.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/recurrence_generator.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';

class AddTrainingSessionScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final TrainingSession? session;

  const AddTrainingSessionScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.session,
  });

  @override
  State<AddTrainingSessionScreen> createState() =>
      _AddTrainingSessionScreenState();
}

class _AddTrainingSessionScreenState extends State<AddTrainingSessionScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _position = TextEditingController();
  final _technique = TextEditingController();
  final _successes = TextEditingController();
  final _difficulties = TextEditingController();
  final _debriefNotes = TextEditingController();
  final List<_TechniqueFormEntry> _techniqueEntries = [];

  bool _recurring = false;

  DateTime _singleDate = DateTime.now();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));

  final Set<int> _weekdays = {DateTime.monday, DateTime.wednesday};

  int? _intensity;
  String? _applicationContext;
  String? _techniqueOutcome;
  bool _saving = false;

  late final TrainingRepository repo = TrainingRepository.instance;
  late final JiuJitsuTaxonomyRepository _taxonomyRepo =
      JiuJitsuTaxonomyRepository.instance;
  late final Stream<List<JiuJitsuTaxonomyItem>> _positionItemsStream;
  late final Stream<List<JiuJitsuTaxonomyItem>> _techniqueItemsStream;

  bool get _editing => widget.session != null;

  @override
  void initState() {
    super.initState();

    _positionItemsStream = _taxonomyRepo.watchItems(
      academyId: widget.academyId,
      type: JiuJitsuTaxonomyType.position,
    );
    _techniqueItemsStream = _taxonomyRepo.watchItems(
      academyId: widget.academyId,
      type: JiuJitsuTaxonomyType.technique,
    );

    final session = widget.session;
    _initTechniqueEntries(session);
    debugPrint(
      "[TRAINING_DEBRIEF_FORM] mode=${session == null ? 'create' : 'edit'} "
      'session.id=${session?.id} target.uid=${widget.uid} '
      'position=${session?.position} technique=${session?.technique} '
      'intensity=${session?.intensity}',
    );
    if (session == null) return;

    _singleDate = session.date;
    _notes.text = session.notes ?? '';
    _position.text = session.position ?? '';
    _technique.text = session.technique ?? '';
    _successes.text = session.successes ?? '';
    _difficulties.text = session.difficulties ?? '';
    _debriefNotes.text = session.debriefNotes ?? '';
    _intensity = session.intensity;
    _applicationContext = session.applicationContext;
    _techniqueOutcome = session.techniqueOutcome;
  }

  @override
  void dispose() {
    _notes.dispose();
    _position.dispose();
    _technique.dispose();
    _successes.dispose();
    _difficulties.dispose();
    _debriefNotes.dispose();
    for (final entry in _techniqueEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _initTechniqueEntries(TrainingSession? session) {
    final entries =
        session?.effectiveTechniqueEntries ?? const <TrainingTechniqueEntry>[];
    if (entries.isEmpty) {
      _techniqueEntries.add(_TechniqueFormEntry(expanded: true));
      return;
    }

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      _techniqueEntries.add(
        _TechniqueFormEntry.fromEntry(entry, expanded: i == 0),
      );
    }
  }

  void _addTechniqueEntry() {
    setState(() {
      for (final entry in _techniqueEntries) {
        entry.expanded = false;
      }
      _techniqueEntries.add(_TechniqueFormEntry(expanded: true));
    });
  }

  void _removeTechniqueEntry(int index) {
    if (_techniqueEntries.length == 1) {
      final entry = _techniqueEntries.single;
      setState(() {
        entry.position.clear();
        entry.technique.clear();
        entry.notes.clear();
        entry.side = TrainingTechniqueSide.unknown;
        entry.applicationContext = null;
        entry.techniqueOutcome = null;
        entry.expanded = true;
      });
      return;
    }

    final removed = _techniqueEntries.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _toggleTechniqueEntry(int index) {
    setState(
      () =>
          _techniqueEntries[index].expanded =
              !_techniqueEntries[index].expanded,
    );
  }

  List<String> _recentTechniqueOptions({String? excluding}) {
    return _recentValues(
      _techniqueEntries.map((entry) => entry.technique.text),
      excluding: excluding,
    );
  }

  List<String> _recentPositionOptions({String? excluding}) {
    return _recentValues(
      _techniqueEntries.map((entry) => entry.position.text),
      excluding: excluding,
    );
  }

  List<String> _recentValues(Iterable<String> values, {String? excluding}) {
    final recent = <String>[];
    final seen = <String>{};
    final excludingKey = JiuJitsuTaxonomy.normalizedKey(excluding ?? '');

    for (final value in values) {
      final label = value.trim();
      if (label.isEmpty) continue;

      final key = JiuJitsuTaxonomy.normalizedKey(label);
      if (key.isEmpty || key == excludingKey || !seen.add(key)) continue;

      recent.add(label);
      if (recent.length == 6) break;
    }

    return recent;
  }

  List<TrainingTechniqueEntry> _buildTechniqueEntries() {
    final entries = <TrainingTechniqueEntry>[];
    final seen = <String>{};

    for (final formEntry in _techniqueEntries) {
      final technique = _optionalText(formEntry.technique);
      if (technique == null) continue;

      final position = _optionalText(formEntry.position);
      final key =
          '${JiuJitsuTaxonomy.normalizedKey(position ?? '')}:${JiuJitsuTaxonomy.normalizedKey(technique)}';
      if (!seen.add(key)) continue;

      entries.add(
        TrainingTechniqueEntry(
          technique: technique,
          position: position,
          side: formEntry.side,
          applicationContext: formEntry.applicationContext,
          techniqueOutcome: formEntry.techniqueOutcome,
          notes: _optionalText(formEntry.notes),
        ),
      );
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final actor = UserScope.maybeOf(context);
    final canAddToAcademy =
        actor != null &&
        actor.academyId == widget.academyId &&
        (actor.role == UserRole.admin || actor.role == UserRole.professor);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar treino' : 'Novo treino')),
      body: StreamBuilder<List<JiuJitsuTaxonomyItem>>(
        stream: _positionItemsStream,
        builder: (context, positionSnap) {
          return StreamBuilder<List<JiuJitsuTaxonomyItem>>(
            stream: _techniqueItemsStream,
            builder: (context, techniqueSnap) {
              final positionOptions = JiuJitsuTaxonomy.mergeStaticAndCustom(
                staticItems: JiuJitsuTaxonomy.positions,
                customItems: (positionSnap.data ??
                        const <JiuJitsuTaxonomyItem>[])
                    .where((item) => item.isActive)
                    .map((item) => item.label),
              );
              final techniqueOptions = JiuJitsuTaxonomy.mergeStaticAndCustom(
                staticItems: JiuJitsuTaxonomy.techniques,
                customItems: (techniqueSnap.data ??
                        const <JiuJitsuTaxonomyItem>[])
                    .where((item) => item.isActive)
                    .map((item) => item.label),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrainingFormSection(
                        title: 'Dados do treino',
                        icon: Icons.event_available_outlined,
                        children: [
                          if (!_editing) ...[
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _recurring,
                              onChanged: (v) => setState(() => _recurring = v),
                              title: const Text('Treino recorrente'),
                              subtitle: const Text(
                                'Criar treinos em intervalo',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_recurring)
                            _DateField(
                              label: 'Data do treino',
                              value: _singleDate,
                              onPick: (d) => setState(() => _singleDate = d),
                            )
                          else ...[
                            _ResponsiveDateFields(
                              start: _start,
                              end: _end,
                              onStartPick: (d) => setState(() => _start = d),
                              onEndPick: (d) => setState(() => _end = d),
                            ),
                            const SizedBox(height: 12),
                            _WeekdayPicker(
                              selected: _weekdays,
                              onChanged:
                                  (s) => setState(() {
                                    _weekdays
                                      ..clear()
                                      ..addAll(s);
                                  }),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            decoration: const InputDecoration(
                              labelText: 'Notas gerais',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TrainingFormSection(
                        title: 'Técnicas do treino',
                        icon: Icons.psychology_alt_outlined,
                        children: [
                          for (
                            var i = 0;
                            i < _techniqueEntries.length;
                            i++
                          ) ...[
                            _TechniqueEntryCard(
                              index: i,
                              entry: _techniqueEntries[i],
                              canRemove: _techniqueEntries.length > 1,
                              positionLoading:
                                  positionSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !positionSnap.hasData,
                              techniqueLoading:
                                  techniqueSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !techniqueSnap.hasData,
                              onToggle: () => _toggleTechniqueEntry(i),
                              onRemove: () => _removeTechniqueEntry(i),
                              onPickPosition:
                                  () => _selectDebriefValue(
                                    title: 'Posi\u00e7\u00e3o trabalhada',
                                    placeholder: 'Buscar posição',
                                    type: JiuJitsuTaxonomyType.position,
                                    options: positionOptions,
                                    recentOptions: _recentPositionOptions(
                                      excluding: _techniqueEntries[i].position.text,
                                    ),
                                    controller: _techniqueEntries[i].position,
                                    canAddToAcademy: canAddToAcademy,
                                    actorUid: actor?.uid,
                                  ),
                              onPickTechnique:
                                  () => _selectDebriefValue(
                                    title: 'Técnica trabalhada',
                                    placeholder: 'Buscar técnica',
                                    type: JiuJitsuTaxonomyType.technique,
                                    options: techniqueOptions,
                                    recentOptions: _recentTechniqueOptions(
                                      excluding: _techniqueEntries[i].technique.text,
                                    ),
                                    controller: _techniqueEntries[i].technique,
                                    canAddToAcademy: canAddToAcademy,
                                    actorUid: actor?.uid,
                                  ),
                              onChanged: () => setState(() {}),
                            ),
                            if (i != _techniqueEntries.length - 1)
                              const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addTechniqueEntry,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar técnica'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TrainingFormSection(
                        title: 'Debrief r\u00e1pido',
                        icon: Icons.bolt_outlined,
                        children: [
                          DropdownButtonFormField<int?>(
                            initialValue: _intensity,
                            decoration: const InputDecoration(
                              labelText: 'Intensidade percebida',
                              prefixIcon: Icon(
                                Icons.local_fire_department_outlined,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('N\u00e3o informado'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 1,
                                child: Text('1 - Leve'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 2,
                                child: Text('2'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 3,
                                child: Text('3 - Moderada'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 4,
                                child: Text('4'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 5,
                                child: Text('5 - Muito intensa'),
                              ),
                            ],
                            onChanged:
                                (value) => setState(() => _intensity = value),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _successes,
                            decoration: const InputDecoration(
                              labelText: 'Sucesso principal',
                              prefixIcon: Icon(Icons.check_circle_outline),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _difficulties,
                            decoration: const InputDecoration(
                              labelText: 'Dificuldade principal',
                              prefixIcon: Icon(Icons.report_problem_outlined),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TrainingFormSection(
                        title: 'Observa\u00e7\u00f5es',
                        icon: Icons.edit_note_outlined,
                        children: [
                          TextFormField(
                            controller: _debriefNotes,
                            decoration: const InputDecoration(
                              labelText: 'Observa\u00e7\u00f5es do debrief',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 8,
                        overflowSpacing: 8,
                        children: [
                          TextButton(
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon:
                                _saving
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.save),
                            label: Text(_saving ? 'Salvando...' : 'Salvar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _selectDebriefValue({
    required String title,
    required String placeholder,
    required JiuJitsuTaxonomyType type,
    required List<String> options,
    required List<String> recentOptions,
    required TextEditingController controller,
    required bool canAddToAcademy,
    required String? actorUid,
  }) async {
    final selected = await showModalBottomSheet<_DebriefSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => _DebriefSelectSheet(
            title: title,
            placeholder: placeholder,
            options: options,
            recentOptions: recentOptions,
            currentValue: controller.text,
            canAddToAcademy: canAddToAcademy,
          ),
    );

    if (selected == null) return;

    var label = selected.label;
    if (selected.addToAcademy && canAddToAcademy && actorUid != null) {
      try {
        final item = await _taxonomyRepo.addCustomItem(
          academyId: widget.academyId,
          type: type,
          label: selected.label,
          createdByUid: actorUid,
        );
        label = item.label;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar termo: $error')),
        );
      }
    }

    if (!mounted) return;
    setState(() => controller.text = label);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      const uuid = Uuid();
      final notesOrNull = _optionalText(_notes);
      final techniqueEntries = _buildTechniqueEntries();
      final primaryTechnique =
          techniqueEntries.isEmpty ? null : techniqueEntries.first;
      final position = primaryTechnique?.position ?? _optionalText(_position);
      final technique =
          primaryTechnique?.technique ?? _optionalText(_technique);
      final successes = _optionalText(_successes);
      final difficulties = _optionalText(_difficulties);
      final debriefNotes = _optionalText(_debriefNotes);
      final applicationContext =
          primaryTechnique?.applicationContext ?? _applicationContext;
      final techniqueOutcome =
          primaryTechnique?.techniqueOutcome ?? _techniqueOutcome;

      if (!_recurring) {
        final existing = widget.session;
        final s = TrainingSession(
          id: existing?.id ?? uuid.v4(),
          date: DateTime(_singleDate.year, _singleDate.month, _singleDate.day),
          place: existing?.place ?? TrainingPlace.academy,
          notes: notesOrNull,
          scores: existing?.scores,
          academyId: existing?.academyId,
          uid: existing?.uid,
          source: existing?.source,
          attendanceSessionId: existing?.attendanceSessionId,
          attendanceCheckInUid: existing?.attendanceCheckInUid,
          classType: existing?.classType,
          instructorUid: existing?.instructorUid,
          instructorName: existing?.instructorName,
          position: position,
          technique: technique,
          techniques: techniqueEntries,
          successes: successes,
          difficulties: difficulties,
          intensity: _intensity,
          debriefNotes: debriefNotes,
          applicationContext: applicationContext,
          techniqueOutcome: techniqueOutcome,
        );

        final actor = UserScope.maybeOf(context);
        debugPrint(
          "[TRAINING_DEBRIEF_SAVE] mode=${_editing ? 'edit' : 'create'} "
          'session.id=${s.id} target.uid=${widget.uid} '
          'position=$position technique=$technique intensity=$_intensity '
          'applicationContext=$applicationContext techniqueOutcome=$techniqueOutcome',
        );
        debugPrint(
          "[TRAINING_SAVE] mode=${_editing ? 'edit' : 'create'} "
          'actor.uid=${actor?.uid} target.uid=${widget.uid} '
          'academyId=${widget.academyId} uid=${widget.uid} '
          'session.id=${s.id}',
        );
        await repo.addSession(
          academyId: widget.academyId,
          uid: widget.uid,
          session: s,
        );
      } else {
        if (_weekdays.isEmpty) {
          throw Exception('Selecione pelo menos um dia da semana.');
        }

        final dates = RecurrenceGenerator.generateDates(
          start: _start,
          end: _end,
          weekdays: _weekdays,
        );

        if (dates.isEmpty) {
          throw Exception(
            'Nenhuma data gerada. Confira o intervalo e os dias.',
          );
        }

        final ok = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Confirmar cadastro'),
                content: Text(
                  'Ser\u00e3o criados ${dates.length} treinos. Deseja continuar?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
        );

        if (!mounted) return;

        if (ok != true) {
          setState(() => _saving = false);
          return;
        }

        final sessions =
            dates
                .map(
                  (d) => TrainingSession(
                    id: uuid.v4(),
                    date: d,
                    place: TrainingPlace.academy,
                    notes: notesOrNull,
                    position: position,
                    technique: technique,
                    techniques: techniqueEntries,
                    successes: successes,
                    difficulties: difficulties,
                    intensity: _intensity,
                    debriefNotes: debriefNotes,
                    applicationContext: applicationContext,
                    techniqueOutcome: techniqueOutcome,
                  ),
                )
                .toList();

        final actor = UserScope.maybeOf(context);
        debugPrint(
          '[TRAINING_DEBRIEF_SAVE] mode=create '
          'session.id=multiple(${sessions.length}) target.uid=${widget.uid} '
          'position=$position technique=$technique intensity=$_intensity '
          'applicationContext=$applicationContext techniqueOutcome=$techniqueOutcome',
        );
        debugPrint(
          '[TRAINING_SAVE] mode=create actor.uid=${actor?.uid} '
          'target.uid=${widget.uid} academyId=${widget.academyId} '
          'uid=${widget.uid} session.id=multiple(${sessions.length})',
        );
        await repo.addSessionsBatch(
          academyId: widget.academyId,
          uid: widget.uid,
          sessions: sessions,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}

class _TechniqueFormEntry {
  final TextEditingController position;
  final TextEditingController technique;
  final TextEditingController notes;
  TrainingTechniqueSide side;
  String? applicationContext;
  String? techniqueOutcome;
  bool expanded;

  _TechniqueFormEntry({
    String? position,
    String? technique,
    String? notes,
    this.side = TrainingTechniqueSide.unknown,
    this.applicationContext,
    this.techniqueOutcome,
    this.expanded = false,
  }) : position = TextEditingController(text: position ?? ''),
       technique = TextEditingController(text: technique ?? ''),
       notes = TextEditingController(text: notes ?? '');

  factory _TechniqueFormEntry.fromEntry(
    TrainingTechniqueEntry entry, {
    required bool expanded,
  }) {
    return _TechniqueFormEntry(
      position: entry.position,
      technique: entry.technique,
      notes: entry.notes,
      side: entry.side,
      applicationContext: entry.applicationContext,
      techniqueOutcome: entry.techniqueOutcome,
      expanded: expanded,
    );
  }

  void dispose() {
    position.dispose();
    technique.dispose();
    notes.dispose();
  }
}

class _TechniqueEntryCard extends StatelessWidget {
  final int index;
  final _TechniqueFormEntry entry;
  final bool canRemove;
  final bool positionLoading;
  final bool techniqueLoading;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onPickPosition;
  final VoidCallback onPickTechnique;
  final VoidCallback onChanged;

  const _TechniqueEntryCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.positionLoading,
    required this.techniqueLoading,
    required this.onToggle,
    required this.onRemove,
    required this.onPickPosition,
    required this.onPickTechnique,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final technique = _clean(entry.technique.text);
    final position = _clean(entry.position.text);
    final title = technique ?? 'Técnica ${index + 1}';
    final subtitle = [
      if (position != null) position,
      _sideLabel(entry.side),
      if (entry.applicationContext != null)
        TrainingAggregator.applicationContextLabel(entry.applicationContext),
      if (entry.techniqueOutcome != null)
        TrainingAggregator.techniqueOutcomeLabel(entry.techniqueOutcome),
    ].whereType<String>().join(' • ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        color: cs.surface.withValues(alpha: 0.34),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: cs.primary.withValues(alpha: 0.16),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.64),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      tooltip: 'Remover técnica',
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  AnimatedRotation(
                    turns: entry.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                entry.expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _DebriefSelectCard(
                    label: 'Técnica',
                    placeholder: 'Selecionar técnica',
                    value: _clean(entry.technique.text),
                    icon: Icons.psychology_alt_outlined,
                    loading: techniqueLoading,
                    onTap: onPickTechnique,
                  ),
                  const SizedBox(height: 12),
                  _DebriefSelectCard(
                    label: 'Posição/contexto',
                    placeholder: 'Selecionar posição',
                    value: _clean(entry.position.text),
                    icon: Icons.sports_mma_outlined,
                    loading: positionLoading,
                    onTap: onPickPosition,
                  ),
                  const SizedBox(height: 12),
                  _TechniqueSideChoiceSection(
                    selected: entry.side,
                    onSelected: (side) {
                      entry.side = side;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  _DebriefChoiceSection(
                    title: 'Contexto',
                    subtitle: 'Onde essa técnica foi aplicada?',
                    options: _applicationContextOptions,
                    selectedValue: entry.applicationContext,
                    onSelected: (value) {
                      entry.applicationContext =
                          entry.applicationContext == value ? null : value;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  _DebriefChoiceSection(
                    title: 'Resultado',
                    subtitle: 'Como foi a tentativa dessa técnica?',
                    options: _techniqueOutcomeOptions,
                    selectedValue: entry.techniqueOutcome,
                    onSelected: (value) {
                      entry.techniqueOutcome =
                          entry.techniqueOutcome == value ? null : value;
                      onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: entry.notes,
                    decoration: const InputDecoration(
                      labelText: 'Observação da técnica',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static String? _clean(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _TechniqueSideChoiceSection extends StatelessWidget {
  final TrainingTechniqueSide selected;
  final ValueChanged<TrainingTechniqueSide> onSelected;

  const _TechniqueSideChoiceSection({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Lado',
        prefixIcon: Icon(Icons.compare_arrows_outlined),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final side in TrainingTechniqueSide.values)
            FilterChip(
              label: Text(_sideLabel(side)),
              selected: selected == side,
              onSelected: (_) => onSelected(side),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

String _sideLabel(TrainingTechniqueSide side) {
  switch (side) {
    case TrainingTechniqueSide.left:
      return 'Esquerda';
    case TrainingTechniqueSide.right:
      return 'Direita';
    case TrainingTechniqueSide.both:
      return 'Ambos';
    case TrainingTechniqueSide.notApplicable:
      return 'Não se aplica';
    case TrainingTechniqueSide.unknown:
      return 'Desconhecido';
  }
}

class _TrainingFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _TrainingFormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ResponsiveDateFields extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final ValueChanged<DateTime> onStartPick;
  final ValueChanged<DateTime> onEndPick;

  const _ResponsiveDateFields({
    required this.start,
    required this.end,
    required this.onStartPick,
    required this.onEndPick,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final startField = _DateField(
          label: 'Data inicial',
          value: start,
          onPick: onStartPick,
        );
        final endField = _DateField(
          label: 'Data final',
          value: end,
          onPick: onEndPick,
        );

        if (constraints.maxWidth < 420) {
          return Column(
            children: [startField, const SizedBox(height: 12), endField],
          );
        }

        return Row(
          children: [
            Expanded(child: startField),
            const SizedBox(width: 8),
            Expanded(child: endField),
          ],
        );
      },
    );
  }
}

const _applicationContextOptions = <_DebriefChoiceOption>[
  _DebriefChoiceOption(TrainingSession.applicationContextDrill),
  _DebriefChoiceOption(TrainingSession.applicationContextPositionalSparring),
  _DebriefChoiceOption(TrainingSession.applicationContextSparring),
  _DebriefChoiceOption(TrainingSession.applicationContextCompetition),
  _DebriefChoiceOption(TrainingSession.applicationContextNotApplied),
];

const _techniqueOutcomeOptions = <_DebriefChoiceOption>[
  _DebriefChoiceOption(TrainingSession.techniqueOutcomeWorked),
  _DebriefChoiceOption(TrainingSession.techniqueOutcomeAlmost),
  _DebriefChoiceOption(TrainingSession.techniqueOutcomeFailed),
  _DebriefChoiceOption(TrainingSession.techniqueOutcomeDefended),
  _DebriefChoiceOption(TrainingSession.techniqueOutcomeNotTested),
];

class _DebriefChoiceOption {
  final String value;

  const _DebriefChoiceOption(this.value);

  String get label =>
      TrainingAggregator.applicationContextLabel(value) ??
      TrainingAggregator.techniqueOutcomeLabel(value) ??
      value;
}

class _DebriefChoiceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_DebriefChoiceOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const _DebriefChoiceSection({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        prefixIcon: const Icon(Icons.sports_score_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: selectedValue == option.value,
                  onSelected: (_) => onSelected(option.value),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebriefSelectCard extends StatelessWidget {
  final String label;
  final String placeholder;
  final String? value;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _DebriefSelectCard({
    required this.label,
    required this.placeholder,
    required this.value,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                loading
                    ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : const Icon(
                      Icons.keyboard_arrow_down,
                      key: ValueKey('arrow'),
                    ),
          ),
        ),
        child: Text(
          hasValue ? value!.trim() : placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                hasValue ? cs.onSurface : cs.onSurface.withValues(alpha: 0.55),
            fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DebriefSelection {
  final String label;
  final bool addToAcademy;

  const _DebriefSelection({required this.label, required this.addToAcademy});
}

class _DebriefSelectSheet extends StatefulWidget {
  final String title;
  final String placeholder;
  final List<String> options;
  final List<String> recentOptions;
  final String currentValue;
  final bool canAddToAcademy;

  const _DebriefSelectSheet({
    required this.title,
    required this.placeholder,
    required this.options,
    required this.recentOptions,
    required this.currentValue,
    required this.canAddToAcademy,
  });

  @override
  State<_DebriefSelectSheet> createState() => _DebriefSelectSheetState();
}

class _DebriefSelectSheetState extends State<_DebriefSelectSheet> {
  late final TextEditingController _search;
  late String _selected;
  bool _addSelectedToAcademy = false;

  bool get _isTechniqueSheet => widget.title.toLowerCase().contains('técnica');

  bool get _isPositionSheet => widget.title.toLowerCase().contains('posição');

  String get _subtitle {
    if (_isTechniqueSheet) return 'Escolha uma técnica usada neste treino';
    if (_isPositionSheet) return 'Onde essa técnica foi trabalhada?';
    return 'Escolha uma opção para continuar';
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue.trim();
    _search = TextEditingController(text: _selected);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _filteredRecentOptions(String query) {
    final filtered = <String>[];
    final seen = <String>{};
    final normalizedQuery = query.toLowerCase();

    for (final option in widget.recentOptions) {
      final label = option.trim();
      if (label.isEmpty) continue;
      if (normalizedQuery.isNotEmpty &&
          !label.toLowerCase().contains(normalizedQuery)) {
        continue;
      }

      final key = JiuJitsuTaxonomy.normalizedKey(label);
      if (key.isEmpty || !seen.add(key)) continue;

      filtered.add(label);
      if (filtered.length == 6) break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _search.text.trim();
    final queryKey = JiuJitsuTaxonomy.normalizedKey(query);
    final recentOptions = _filteredRecentOptions(query);
    final recentKeys = recentOptions.map(JiuJitsuTaxonomy.normalizedKey).toSet();
    final filtered =
        widget.options
            .where(
              (option) => option.toLowerCase().contains(query.toLowerCase()),
            )
            .where(
              (option) => !recentKeys.contains(
                JiuJitsuTaxonomy.normalizedKey(option),
              ),
            )
            .toList();
    final exactMatch = widget.options.any(
      (option) => JiuJitsuTaxonomy.normalizedKey(option) == queryKey,
    );
    final showCustom = query.isNotEmpty && !exactMatch;
    final valueToConfirm = _selected;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.84,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.34),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                onChanged:
                    (_) => setState(() {
                      _addSelectedToAcademy = false;
                    }),
              ),
              const SizedBox(height: 10),
              if (recentOptions.isNotEmpty) ...[
                Text(
                  'Recentes',
                  style: textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final option = recentOptions[index];
                      final selected =
                          JiuJitsuTaxonomy.normalizedKey(option) ==
                              JiuJitsuTaxonomy.normalizedKey(_selected) &&
                          !_addSelectedToAcademy;

                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected:
                            (_) => setState(() {
                              _selected = option;
                              _addSelectedToAcademy = false;
                            }),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                    color: cs.surface.withValues(alpha: 0.22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView(
                      shrinkWrap: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        if (showCustom) ...[
                          _DebriefOptionTile(
                            label: 'Usar "$query"',
                            selected:
                                _selected == query && !_addSelectedToAcademy,
                            accent: true,
                            onTap:
                                () => setState(() {
                                  _selected = query;
                                  _addSelectedToAcademy = false;
                                }),
                          ),
                          if (widget.canAddToAcademy)
                            _DebriefOptionTile(
                              label: 'Adicionar "$query" à lista da academia',
                              selected:
                                  _selected == query && _addSelectedToAcademy,
                              accent: true,
                              onTap:
                                  () => setState(() {
                                    _selected = query;
                                    _addSelectedToAcademy = true;
                                  }),
                            ),
                        ],
                        for (final option in filtered)
                          _DebriefOptionTile(
                            label: option,
                            selected:
                                JiuJitsuTaxonomy.normalizedKey(option) ==
                                    JiuJitsuTaxonomy.normalizedKey(_selected) &&
                                !_addSelectedToAcademy,
                            onTap:
                                () => setState(() {
                                  _selected = option;
                                  _addSelectedToAcademy = false;
                                }),
                          ),
                        if (filtered.isEmpty && !showCustom)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 28,
                            ),
                            child: Text(
                              'Nenhum resultado encontrado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      valueToConfirm.trim().isEmpty
                          ? null
                          : () => Navigator.pop(
                            context,
                            _DebriefSelection(
                              label: valueToConfirm.trim(),
                              addToAcademy: _addSelectedToAcademy,
                            ),
                          ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    valueToConfirm.trim().isEmpty
                        ? 'Selecione uma opção'
                        : 'Confirmar seleção',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebriefOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _DebriefOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color:
          selected
              ? cs.primary.withValues(alpha: 0.16)
              : accent
              ? cs.secondary.withValues(alpha: 0.12)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : accent
                      ? Icons.add_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color:
                      selected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      color:
                          selected
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.84),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(DateTime.now().year + 5),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(text),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = const [
      (DateTime.monday, 'Seg'),
      (DateTime.tuesday, 'Ter'),
      (DateTime.wednesday, 'Qua'),
      (DateTime.thursday, 'Qui'),
      (DateTime.friday, 'Sex'),
      (DateTime.saturday, 'Sab'),
      (DateTime.sunday, 'Dom'),
    ];

    return Wrap(
      spacing: 8,
      children: [
        for (final (wd, label) in days)
          FilterChip(
            label: Text(label),
            selected: selected.contains(wd),
            onSelected: (v) {
              final copy = {...selected};
              if (v) {
                copy.add(wd);
              } else {
                copy.remove(wd);
              }
              onChanged(copy);
            },
          ),
      ],
    );
  }
}
