import 'package:flutter/material.dart';

import '../model/training_session.dart';

class TrainingFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const TrainingFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
        ),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
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

class TrainingSessionScheduleSection extends StatelessWidget {
  final bool editing;
  final TrainingSessionStatus intent;
  final ValueChanged<TrainingSessionStatus> onIntentChanged;
  final bool recurring;
  final ValueChanged<bool> onRecurringChanged;
  final bool isRegisteringCompleted;
  final DateTime singleDate;
  final bool singleDateIsFuture;
  final ValueChanged<DateTime> onSingleDateChanged;
  final DateTime startDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final DateTime endDate;
  final ValueChanged<DateTime> onEndDateChanged;
  final Set<int> weekdays;
  final ValueChanged<Set<int>> onWeekdaysChanged;
  final String recurrenceSummary;
  final TextEditingController notesController;

  const TrainingSessionScheduleSection({
    super.key,
    required this.editing,
    required this.intent,
    required this.onIntentChanged,
    required this.recurring,
    required this.onRecurringChanged,
    required this.isRegisteringCompleted,
    required this.singleDate,
    required this.singleDateIsFuture,
    required this.onSingleDateChanged,
    required this.startDate,
    required this.onStartDateChanged,
    required this.endDate,
    required this.onEndDateChanged,
    required this.weekdays,
    required this.onWeekdaysChanged,
    required this.recurrenceSummary,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    final futureDateMessage =
        singleDateIsFuture && isRegisteringCompleted
            ? 'Data futura nao pode ser registrada como treino realizado.'
            : null;

    return TrainingFormSection(
      title: 'Dados do treino',
      icon: Icons.event_available_outlined,
      children: [
        SegmentedButton<TrainingSessionStatus>(
          segments: const [
            ButtonSegment(
              value: TrainingSessionStatus.completed,
              icon: Icon(Icons.check_circle_outline),
              label: Text('Ja treinei'),
            ),
            ButtonSegment(
              value: TrainingSessionStatus.planned,
              icon: Icon(Icons.event_outlined),
              label: Text('Planejar treino'),
            ),
          ],
          selected: {intent},
          onSelectionChanged: (selection) => onIntentChanged(selection.single),
        ),
        const SizedBox(height: 12),
        if (!editing) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: recurring,
            onChanged: onRecurringChanged,
            title: const Text('Treino recorrente'),
            subtitle: const Text(
              'Repetir como planejamento; cada ocorrencia futura precisara de confirmacao.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!recurring)
          _TrainingDateField(
            label: 'Data do treino',
            value: singleDate,
            onPick: onSingleDateChanged,
            errorText: futureDateMessage,
            trailingAction:
                futureDateMessage == null
                    ? null
                    : TextButton(
                      onPressed:
                          () => onIntentChanged(TrainingSessionStatus.planned),
                      child: const Text('Mudar para planejamento'),
                    ),
          )
        else ...[
          if (isRegisteringCompleted) ...[
            _TrainingDateField(
              label: 'Data realizada',
              value: singleDate,
              onPick: onSingleDateChanged,
              errorText: futureDateMessage,
              trailingAction:
                  futureDateMessage == null
                      ? null
                      : TextButton(
                        onPressed:
                            () =>
                                onIntentChanged(TrainingSessionStatus.planned),
                        child: const Text('Mudar para planejamento'),
                      ),
            ),
            const SizedBox(height: 12),
          ],
          _ResponsiveTrainingDateFields(
            start: startDate,
            end: endDate,
            onStartPick: onStartDateChanged,
            onEndPick: onEndDateChanged,
          ),
          const SizedBox(height: 12),
          _TrainingWeekdayPicker(
            selected: weekdays,
            onChanged: onWeekdaysChanged,
          ),
        ],
        const SizedBox(height: 12),
        _TrainingSaveSummary(text: recurrenceSummary),
        const SizedBox(height: 12),
        TextFormField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notas gerais',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}

class _ResponsiveTrainingDateFields extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final ValueChanged<DateTime> onStartPick;
  final ValueChanged<DateTime> onEndPick;

  const _ResponsiveTrainingDateFields({
    required this.start,
    required this.end,
    required this.onStartPick,
    required this.onEndPick,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final startField = _TrainingDateField(
          label: 'Data inicial',
          value: start,
          onPick: onStartPick,
        );
        final endField = _TrainingDateField(
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

class _TrainingDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  final String? errorText;
  final Widget? trailingAction;

  const _TrainingDateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.errorText,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final field = InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(DateTime.now().year + 5),
        );
        if (date != null) onPick(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: errorText),
        child: Text(text),
      ),
    );

    final action = trailingAction;
    if (action == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [field, Align(alignment: Alignment.centerLeft, child: action)],
    );
  }
}

class _TrainingWeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _TrainingWeekdayPicker({
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
        for (final (weekday, label) in days)
          FilterChip(
            label: Text(label),
            selected: selected.contains(weekday),
            onSelected: (value) {
              final updated = {...selected};
              if (value) {
                updated.add(weekday);
              } else {
                updated.remove(weekday);
              }
              onChanged(updated);
            },
          ),
      ],
    );
  }
}

class _TrainingSaveSummary extends StatelessWidget {
  final String text;

  const _TrainingSaveSummary({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
        color: colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.78),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class TrainingSessionDebriefSections extends StatelessWidget {
  final int? intensity;
  final ValueChanged<int?> onIntensityChanged;
  final TextEditingController successesController;
  final TextEditingController difficultiesController;
  final TextEditingController notesController;

  const TrainingSessionDebriefSections({
    super.key,
    required this.intensity,
    required this.onIntensityChanged,
    required this.successesController,
    required this.difficultiesController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TrainingFormSection(
          title: 'Debrief rápido',
          icon: Icons.bolt_outlined,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: intensity,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Intensidade percebida',
                prefixIcon: Icon(Icons.local_fire_department_outlined),
              ),
              items: const [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Não informado'),
                ),
                DropdownMenuItem<int?>(value: 1, child: Text('1 - Leve')),
                DropdownMenuItem<int?>(value: 2, child: Text('2')),
                DropdownMenuItem<int?>(value: 3, child: Text('3 - Moderada')),
                DropdownMenuItem<int?>(value: 4, child: Text('4')),
                DropdownMenuItem<int?>(
                  value: 5,
                  child: Text('5 - Muito intensa'),
                ),
              ],
              onChanged: onIntensityChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: successesController,
              decoration: const InputDecoration(
                labelText: 'Sucesso principal',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: difficultiesController,
              decoration: const InputDecoration(
                labelText: 'Dificuldade principal',
                prefixIcon: Icon(Icons.report_problem_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TrainingFormSection(
          title: 'Observações',
          icon: Icons.edit_note_outlined,
          children: [
            TextFormField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Observações do debrief',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ],
    );
  }
}

class TrainingSessionFormActions extends StatelessWidget {
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const TrainingSessionFormActions({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: 8,
      overflowSpacing: 8,
      children: [
        TextButton(
          onPressed: saving ? null : onCancel,
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: saving ? null : onSubmit,
          icon:
              saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.save),
          label: Text(submitLabel),
        ),
      ],
    );
  }
}
