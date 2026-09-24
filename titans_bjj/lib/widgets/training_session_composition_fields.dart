import 'package:flutter/material.dart';

import '../model/training_session.dart';

class TrainingSessionCompositionInput {
  final int? totalDurationMinutes;
  final bool? totalDurationIsEstimated;
  final List<TrainingStudiedTechnique> studiedTechniques;
  final TrainingRollsBlock? rolls;

  const TrainingSessionCompositionInput({
    required this.totalDurationMinutes,
    required this.totalDurationIsEstimated,
    required this.studiedTechniques,
    required this.rolls,
  });
}

class TrainingSessionCompositionController {
  final TextEditingController totalDuration;
  final TextEditingController rollCount;
  final TextEditingController roundDuration;
  final List<TrainingStudiedTechnique> studiedTechniques;
  bool durationIsEstimated;

  TrainingSessionCompositionController({TrainingSession? session})
    : totalDuration = TextEditingController(
        text: session?.totalDurationMinutes?.toString() ?? '',
      ),
      rollCount = TextEditingController(
        text: session?.rolls?.count.toString() ?? '',
      ),
      roundDuration = TextEditingController(
        text: session?.rolls?.roundDurationMinutes.toString() ?? '',
      ),
      studiedTechniques = List.of(
        session?.studiedTechniques ?? const <TrainingStudiedTechnique>[],
      ),
      durationIsEstimated = session?.totalDurationIsEstimated ?? false;

  bool get hasDuration => totalDuration.text.trim().isNotEmpty;

  String? validate() {
    final durationResult = _positiveInt(
      totalDuration.text,
      fieldLabel: 'duração total',
    );
    if (durationResult.error != null) return durationResult.error;

    final countResult = _positiveInt(
      rollCount.text,
      fieldLabel: 'quantidade de rolas',
    );
    if (countResult.error != null) return countResult.error;
    final roundResult = _positiveInt(
      roundDuration.text,
      fieldLabel: 'duração por round',
    );
    if (roundResult.error != null) return roundResult.error;

    final hasCount = countResult.value != null;
    final hasRoundDuration = roundResult.value != null;
    if (hasCount != hasRoundDuration) {
      return 'Complete quantidade e duração por round ou remova o bloco de rolas.';
    }

    if (hasCount && hasRoundDuration) {
      final combatMinutes = countResult.value! * roundResult.value!;
      final totalMinutes = durationResult.value;
      if (totalMinutes != null && combatMinutes > totalMinutes) {
        return 'O tempo de combate não pode superar a duração total.';
      }
    }
    return null;
  }

  TrainingSessionCompositionInput value() {
    final duration = _optionalPositiveInt(totalDuration.text);
    final count = _optionalPositiveInt(rollCount.text);
    final roundMinutes = _optionalPositiveInt(roundDuration.text);
    return TrainingSessionCompositionInput(
      totalDurationMinutes: duration,
      totalDurationIsEstimated: duration == null ? null : durationIsEstimated,
      studiedTechniques: List.unmodifiable(studiedTechniques),
      rolls:
          count == null || roundMinutes == null
              ? null
              : TrainingRollsBlock(
                count: count,
                roundDurationMinutes: roundMinutes,
              ),
    );
  }

  void addStudiedTechnique(TrainingStudiedTechnique technique) {
    final alreadyAdded = studiedTechniques.any(
      (item) => item.catalogId == technique.catalogId,
    );
    if (!alreadyAdded) studiedTechniques.add(technique);
  }

  void removeStudiedTechnique(String catalogId) {
    studiedTechniques.removeWhere((item) => item.catalogId == catalogId);
  }

  void dispose() {
    totalDuration.dispose();
    rollCount.dispose();
    roundDuration.dispose();
  }

  static _ParsedPositiveInt _positiveInt(
    String raw, {
    required String fieldLabel,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return const _ParsedPositiveInt();
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return _ParsedPositiveInt(
        error: 'Informe $fieldLabel com um número inteiro maior que zero.',
      );
    }
    return _ParsedPositiveInt(value: parsed);
  }

  static int? _optionalPositiveInt(String raw) {
    final parsed = int.tryParse(raw.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

class TrainingSessionCompositionFields extends StatefulWidget {
  final TrainingSessionCompositionController controller;
  final List<TrainingStudiedTechnique> techniqueCatalog;
  final VoidCallback onChanged;
  final bool compact;

  const TrainingSessionCompositionFields({
    super.key,
    required this.controller,
    required this.techniqueCatalog,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<TrainingSessionCompositionFields> createState() =>
      _TrainingSessionCompositionFieldsState();
}

class _TrainingSessionCompositionFieldsState
    extends State<TrainingSessionCompositionFields> {
  String? _selectedCatalogId;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rolls = controller.value().rolls;
    final combatMinutes = rolls?.combatDurationMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller.totalDuration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duração total (minutos)',
            helperText:
                'Inclui todo o treino; o combate não será somado novamente.',
            prefixIcon: Icon(Icons.timer_outlined),
          ),
          onChanged: (_) {
            if (!controller.hasDuration) {
              controller.durationIsEstimated = false;
            }
            _notifyChanged();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: controller.hasDuration && controller.durationIsEstimated,
          onChanged:
              controller.hasDuration
                  ? (value) {
                    controller.durationIsEstimated = value;
                    _notifyChanged();
                  }
                  : null,
          title: const Text('Duração estimada'),
          subtitle: const Text('Marque apenas quando o total for aproximado.'),
        ),
        const SizedBox(height: 8),
        Text(
          'Rolas (opcional)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text('No MVP, todos os rounds deste bloco têm a mesma duração.'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final countField = _NumberField(
              controller: controller.rollCount,
              label: 'Quantidade',
              onChanged: _notifyChanged,
            );
            final durationField = _NumberField(
              controller: controller.roundDuration,
              label: 'Minutos por round',
              onChanged: _notifyChanged,
            );
            if (constraints.maxWidth < 420) {
              return Column(
                children: [
                  countField,
                  const SizedBox(height: 10),
                  durationField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: countField),
                const SizedBox(width: 10),
                Expanded(child: durationField),
              ],
            );
          },
        ),
        if (combatMinutes != null) ...[
          const SizedBox(height: 8),
          Text(
            'Tempo de combate: $combatMinutes min',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'studied-technique-${controller.studiedTechniques.length}',
          ),
          initialValue: _selectedCatalogId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Técnicas estudadas',
            helperText: 'Estudo não comprova aplicação, sucesso ou domínio.',
            prefixIcon: Icon(Icons.school_outlined),
          ),
          items: [
            for (final technique in widget.techniqueCatalog)
              DropdownMenuItem(
                value: technique.catalogId,
                child: Text(technique.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (catalogId) {
            if (catalogId == null) return;
            final technique = widget.techniqueCatalog.firstWhere(
              (item) => item.catalogId == catalogId,
            );
            controller.addStudiedTechnique(technique);
            setState(() => _selectedCatalogId = null);
            widget.onChanged();
          },
        ),
        if (controller.studiedTechniques.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final technique in controller.studiedTechniques)
                InputChip(
                  label: Text(technique.label),
                  onDeleted: () {
                    controller.removeStudiedTechnique(technique.catalogId);
                    _notifyChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _notifyChanged([String? _]) {
    setState(() {});
    widget.onChanged();
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

class _ParsedPositiveInt {
  final int? value;
  final String? error;

  const _ParsedPositiveInt({this.value, this.error});
}
