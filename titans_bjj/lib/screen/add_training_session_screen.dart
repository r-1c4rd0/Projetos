import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/app_user.dart';
import '../model/jiu_jitsu_taxonomy_item.dart';
import '../model/training_session.dart';
import '../repository/jiu_jitsu_taxonomy_repository.dart';
import '../repository/training_repository.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/recurrence_generator.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actor = UserScope.maybeOf(context);
    final canAddToAcademy = actor != null &&
        actor.academyId == widget.academyId &&
        (actor.role == UserRole.admin || actor.role == UserRole.professor);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar treino' : 'Novo treino'),
      ),
      body: StreamBuilder<List<JiuJitsuTaxonomyItem>>(
        stream: _positionItemsStream,
        builder: (context, positionSnap) {
          return StreamBuilder<List<JiuJitsuTaxonomyItem>>(
            stream: _techniqueItemsStream,
            builder: (context, techniqueSnap) {
              final positionOptions = JiuJitsuTaxonomy.mergeStaticAndCustom(
                staticItems: JiuJitsuTaxonomy.positions,
                customItems:
                    (positionSnap.data ?? const <JiuJitsuTaxonomyItem>[])
                        .where((item) => item.isActive)
                        .map((item) => item.label),
              );
              final techniqueOptions = JiuJitsuTaxonomy.mergeStaticAndCustom(
                staticItems: JiuJitsuTaxonomy.techniques,
                customItems:
                    (techniqueSnap.data ?? const <JiuJitsuTaxonomyItem>[])
                        .where((item) => item.isActive)
                        .map((item) => item.label),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_editing)
                        SwitchListTile(
                          value: _recurring,
                          onChanged: (v) => setState(() => _recurring = v),
                          title: const Text('Treino recorrente'),
                          subtitle: const Text(
                            'Criar varios treinos em um intervalo',
                          ),
                        ),
                      if (!_editing) const SizedBox(height: 12),
                      if (!_recurring) ...[
                        _DateField(
                          label: 'Data do treino',
                          value: _singleDate,
                          onPick: (d) => setState(() => _singleDate = d),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Data inicial',
                                value: _start,
                                onPick: (d) => setState(() => _start = d),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateField(
                                label: 'Data final',
                                value: _end,
                                onPick: (d) => setState(() => _end = d),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _WeekdayPicker(
                          selected: _weekdays,
                          onChanged: (s) => setState(() {
                            _weekdays
                              ..clear()
                              ..addAll(s);
                          }),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ex: seg/qua/sab para treinos da equipe',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notes,
                        decoration: const InputDecoration(
                          labelText: 'Observacoes (opcional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Debrief p\u00f3s-treino',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _DebriefSelectCard(
                        label: 'Posi\u00e7\u00e3o trabalhada',
                        placeholder: 'Selecionar posi\u00e7\u00e3o',
                        value: _optionalText(_position),
                        icon: Icons.sports_mma_outlined,
                        loading: positionSnap.connectionState ==
                                ConnectionState.waiting &&
                            !positionSnap.hasData,
                        onTap: () => _selectDebriefValue(
                          title: 'Posi\u00e7\u00e3o trabalhada',
                          placeholder: 'Buscar posi\u00e7\u00e3o',
                          type: JiuJitsuTaxonomyType.position,
                          options: positionOptions,
                          controller: _position,
                          canAddToAcademy: canAddToAcademy,
                          actorUid: actor?.uid,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DebriefSelectCard(
                        label: 'T\u00e9cnica trabalhada',
                        placeholder: 'Selecionar t\u00e9cnica',
                        value: _optionalText(_technique),
                        icon: Icons.psychology_alt_outlined,
                        loading: techniqueSnap.connectionState ==
                                ConnectionState.waiting &&
                            !techniqueSnap.hasData,
                        onTap: () => _selectDebriefValue(
                          title: 'T\u00e9cnica trabalhada',
                          placeholder: 'Buscar t\u00e9cnica',
                          type: JiuJitsuTaxonomyType.technique,
                          options: techniqueOptions,
                          controller: _technique,
                          canAddToAcademy: canAddToAcademy,
                          actorUid: actor?.uid,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _successes,
                        decoration: const InputDecoration(
                          labelText: 'Sucessos do treino',
                          prefixIcon: Icon(Icons.check_circle_outline),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _difficulties,
                        decoration: const InputDecoration(
                          labelText: 'Dificuldades encontradas',
                          prefixIcon: Icon(Icons.report_problem_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _intensity,
                        decoration: const InputDecoration(
                          labelText: 'Intensidade percebida',
                          prefixIcon: Icon(Icons.local_fire_department_outlined),
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
                          DropdownMenuItem<int?>(value: 2, child: Text('2')),
                          DropdownMenuItem<int?>(
                            value: 3,
                            child: Text('3 - Moderada'),
                          ),
                          DropdownMenuItem<int?>(value: 4, child: Text('4')),
                          DropdownMenuItem<int?>(
                            value: 5,
                            child: Text('5 - Muito intensa'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _intensity = value),
                      ),
                      const SizedBox(height: 12),
                      _DebriefChoiceSection(
                        title: 'Aplica\u00e7\u00e3o t\u00e9cnica',
                        subtitle: 'Onde voc\u00ea tentou usar?',
                        options: _applicationContextOptions,
                        selectedValue: _applicationContext,
                        onSelected: (value) => setState(
                          () => _applicationContext =
                              _applicationContext == value ? null : value,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DebriefChoiceSection(
                        title: 'Resultado',
                        subtitle: 'Como foi a tentativa?',
                        options: _techniqueOutcomeOptions,
                        selectedValue: _techniqueOutcome,
                        onSelected: (value) => setState(
                          () => _techniqueOutcome =
                              _techniqueOutcome == value ? null : value,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _debriefNotes,
                        decoration: const InputDecoration(
                          labelText: 'Observacoes do debrief',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Salvando...' : 'Salvar'),
                        ),
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
    required TextEditingController controller,
    required bool canAddToAcademy,
    required String? actorUid,
  }) async {
    final selected = await showModalBottomSheet<_DebriefSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DebriefSelectSheet(
        title: title,
        placeholder: placeholder,
        options: options,
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
      final position = _optionalText(_position);
      final technique = _optionalText(_technique);
      final successes = _optionalText(_successes);
      final difficulties = _optionalText(_difficulties);
      final debriefNotes = _optionalText(_debriefNotes);
      final applicationContext = _applicationContext;
      final techniqueOutcome = _techniqueOutcome;

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
          throw Exception('Nenhuma data gerada. Confira o intervalo e os dias.');
        }

        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmar cadastro'),
            content: Text(
              'Serao criados ${dates.length} treinos. Deseja continuar?',
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

        if (ok != true) {
          setState(() => _saving = false);
          return;
        }

        final sessions = dates
            .map(
              (d) => TrainingSession(
                id: uuid.v4(),
                date: d,
                place: TrainingPlace.academy,
                notes: notesOrNull,
                position: position,
                technique: technique,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}

const _applicationContextOptions = <_DebriefChoiceOption>[
  _DebriefChoiceOption(
    value: TrainingSession.applicationContextDrill,
    label: 'Drill',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.applicationContextPositionalSparring,
    label: 'Treino posicional',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.applicationContextSparring,
    label: 'Rola',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.applicationContextCompetition,
    label: 'Competi\u00e7\u00e3o',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.applicationContextNotApplied,
    label: 'N\u00e3o aplicada',
  ),
];

const _techniqueOutcomeOptions = <_DebriefChoiceOption>[
  _DebriefChoiceOption(
    value: TrainingSession.techniqueOutcomeWorked,
    label: 'Funcionou',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.techniqueOutcomeAlmost,
    label: 'Quase funcionou',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.techniqueOutcomeFailed,
    label: 'Falhou',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.techniqueOutcomeDefended,
    label: 'Parceiro defendeu',
  ),
  _DebriefChoiceOption(
    value: TrainingSession.techniqueOutcomeNotTested,
    label: 'N\u00e3o testada',
  ),
];

class _DebriefChoiceOption {
  final String value;
  final String label;

  const _DebriefChoiceOption({required this.value, required this.label});
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
                  label: Text(option.label),
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
            child: loading
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
            color: hasValue ? cs.onSurface : cs.onSurface.withValues(alpha: 0.55),
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

  const _DebriefSelection({
    required this.label,
    required this.addToAcademy,
  });
}

class _DebriefSelectSheet extends StatefulWidget {
  final String title;
  final String placeholder;
  final List<String> options;
  final String currentValue;
  final bool canAddToAcademy;

  const _DebriefSelectSheet({
    required this.title,
    required this.placeholder,
    required this.options,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim();
    final queryKey = JiuJitsuTaxonomy.normalizedKey(query);
    final filtered = widget.options
        .where((option) => option.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final exactMatch = widget.options.any(
      (option) => JiuJitsuTaxonomy.normalizedKey(option) == queryKey,
    );
    final showCustom = query.isNotEmpty && !exactMatch;
    final valueToConfirm = showCustom ? query : _selected;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.placeholder,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {
                  _addSelectedToAcademy = false;
                }),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (showCustom) ...[
                      _DebriefOptionTile(
                        label: 'Usar "$query"',
                        selected: _selected == query && !_addSelectedToAcademy,
                        accent: true,
                        onTap: () => setState(() {
                          _selected = query;
                          _addSelectedToAcademy = false;
                        }),
                      ),
                      if (widget.canAddToAcademy)
                        _DebriefOptionTile(
                          label: 'Adicionar "$query" a lista da academia',
                          selected: _selected == query && _addSelectedToAcademy,
                          accent: true,
                          onTap: () => setState(() {
                            _selected = query;
                            _addSelectedToAcademy = true;
                          }),
                        ),
                    ],
                    for (final option in filtered)
                      _DebriefOptionTile(
                        label: option,
                        selected: JiuJitsuTaxonomy.normalizedKey(option) ==
                                JiuJitsuTaxonomy.normalizedKey(_selected) &&
                            !_addSelectedToAcademy,
                        onTap: () => setState(() {
                          _selected = option;
                          _addSelectedToAcademy = false;
                        }),
                      ),
                    if (filtered.isEmpty && !showCustom)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Nenhuma opcao encontrada.',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: valueToConfirm.trim().isEmpty
                      ? null
                      : () => Navigator.pop(
                            context,
                            _DebriefSelection(
                              label: valueToConfirm.trim(),
                              addToAcademy:
                                  showCustom && _addSelectedToAcademy,
                            ),
                          ),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar selecao'),
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

    return Card(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.55)
          : accent
              ? cs.secondaryContainer.withValues(alpha: 0.35)
              : null,
      child: ListTile(
        onTap: onTap,
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        trailing: selected ? const Icon(Icons.check) : null,
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

  const _WeekdayPicker({
    required this.selected,
    required this.onChanged,
  });

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
