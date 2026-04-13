import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/recurrence_generator.dart';

class AddTrainingSessionScreen extends StatefulWidget {
  final String academyId;
  final String uid;

  const AddTrainingSessionScreen({
    super.key,
    required this.academyId,
    required this.uid,
  });

  @override
  State<AddTrainingSessionScreen> createState() => _AddTrainingSessionScreenState();
}

class _AddTrainingSessionScreenState extends State<AddTrainingSessionScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();

  bool _recurring = false;

  DateTime _singleDate = DateTime.now();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));

  final Set<int> _weekdays = {DateTime.monday, DateTime.wednesday};

  bool _saving = false;

  late final TrainingRepository repo = TrainingRepository(FirebaseFirestore.instance);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar treino')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              SwitchListTile(
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
                title: const Text('Treino recorrente'),
                subtitle: const Text('Criar vários treinos em um intervalo'),
              ),
              const SizedBox(height: 12),
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
                    'Ex: seg/qua/sáb para treinos da equipe',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Observações (opcional)'),
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
      final notes = _notes.text.trim();
      final notesOrNull = notes.isEmpty ? null : notes;

      if (!_recurring) {
        final s = TrainingSession(
          id: uuid.v4(),
          date: DateTime(_singleDate.year, _singleDate.month, _singleDate.day),
          place: TrainingPlace.academy,
          notes: notesOrNull,
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
            content: Text('Serão criados ${dates.length} treinos. Deseja continuar?'),
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
          ),
        )
            .toList();

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
      (DateTime.saturday, 'Sáb'),
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
