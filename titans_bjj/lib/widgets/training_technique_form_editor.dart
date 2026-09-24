import 'package:flutter/material.dart';

import '../model/training_session.dart';
import '../service/training_aggregator.dart';
import 'training_session_form_sections.dart';
import 'training_technique_form_controller.dart';

class TrainingTechniqueFormEditor extends StatelessWidget {
  final TrainingTechniqueFormController controller;
  final bool positionLoading;
  final bool techniqueLoading;
  final ValueChanged<TrainingTechniqueFormEntry> onPickPosition;
  final ValueChanged<TrainingTechniqueFormEntry> onPickTechnique;
  final VoidCallback onChanged;

  const TrainingTechniqueFormEditor({
    super.key,
    required this.controller,
    required this.positionLoading,
    required this.techniqueLoading,
    required this.onPickPosition,
    required this.onPickTechnique,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = controller.entries;
    return TrainingFormSection(
      title: 'Técnicas do treino',
      icon: Icons.psychology_alt_outlined,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          _TrainingTechniqueEntryCard(
            key: ObjectKey(entries[index]),
            index: index,
            entry: entries[index],
            canRemove: entries.length > 1,
            positionLoading: positionLoading,
            techniqueLoading: techniqueLoading,
            onToggle: () {
              controller.toggleEntry(entries[index]);
              onChanged();
            },
            onRemove: () {
              controller.removeEntry(entries[index]);
              onChanged();
            },
            onPickPosition: () => onPickPosition(entries[index]),
            onPickTechnique: () => onPickTechnique(entries[index]),
            onChanged: onChanged,
          ),
          if (index != entries.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              controller.addEntry();
              onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Adicionar técnica'),
          ),
        ),
      ],
    );
  }
}

class _TrainingTechniqueEntryCard extends StatelessWidget {
  final int index;
  final TrainingTechniqueFormEntry entry;
  final bool canRemove;
  final bool positionLoading;
  final bool techniqueLoading;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onPickPosition;
  final VoidCallback onPickTechnique;
  final VoidCallback onChanged;

  const _TrainingTechniqueEntryCard({
    super.key,
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
    final colorScheme = Theme.of(context).colorScheme;
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
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.10),
        ),
        color: colorScheme.surface.withValues(alpha: 0.34),
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
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.16,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.primary,
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.64,
                              ),
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
                    value: technique,
                    icon: Icons.psychology_alt_outlined,
                    loading: techniqueLoading,
                    onTap: onPickTechnique,
                  ),
                  const SizedBox(height: 12),
                  _DebriefSelectCard(
                    label: 'Posição/contexto',
                    placeholder: 'Selecionar posição',
                    value: position,
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
  return switch (side) {
    TrainingTechniqueSide.left => 'Esquerda',
    TrainingTechniqueSide.right => 'Direita',
    TrainingTechniqueSide.both => 'Ambos',
    TrainingTechniqueSide.notApplicable => 'Não se aplica',
    TrainingTechniqueSide.unknown => 'Desconhecido',
  };
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
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
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
                hasValue
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
