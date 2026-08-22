import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/training_session.dart';
import '../repository/training_repository.dart';
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
  State<AddTrainingSessionScreen> createState() => _AddTrainingSessionScreenState();
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
  bool _saving = false;

  late final TrainingRepository repo = TrainingRepository.instance;

  bool get _editing => widget.session != null;

  @override
  void initState() {
    super.initState();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar treino' : 'Novo treino'),
      ),
      body: SingleChildScrollView(
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
                  subtitle: const Text('Criar varios treinos em um intervalo'),
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
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Observacoes (opcional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Debrief pos-treino',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _position,
                decoration: const InputDecoration(
                  labelText: 'Posicao trabalhada',
                  prefixIcon: Icon(Icons.sports_mma_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _technique,
                decoration: const InputDecoration(
                  labelText: 'Tecnica trabalhada',
                  prefixIcon: Icon(Icons.psychology_alt_outlined),
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
                    child: Text('Nao informado'),
                  ),
                  DropdownMenuItem<int?>(value: 1, child: Text('1 - Leve')),
                  DropdownMenuItem<int?>(value: 2, child: Text('2')),
                  DropdownMenuItem<int?>(value: 3, child: Text('3 - Moderada')),
                  DropdownMenuItem<int?>(value: 4, child: Text('4')),
                  DropdownMenuItem<int?>(value: 5, child: Text('5 - Muito intensa')),
                ],
                onChanged: (value) => setState(() => _intensity = value),
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
      ),
    );
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
        );

        final actor = UserScope.maybeOf(context);
        debugPrint(
          "[TRAINING_DEBRIEF_SAVE] mode=${_editing ? 'edit' : 'create'} "
          'session.id=${s.id} target.uid=${widget.uid} '
          'position=$position technique=$technique intensity=$_intensity',
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
            content: Text('Serao criados ${dates.length} treinos. Deseja continuar?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
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
              ),
            )
            .toList();

        final actor = UserScope.maybeOf(context);
        debugPrint(
          '[TRAINING_DEBRIEF_SAVE] mode=create '
          'session.id=multiple(${sessions.length}) target.uid=${widget.uid} '
          'position=$position technique=$technique intensity=$_intensity',
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