import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import 'quick_log_form_controller.dart';
import 'training_session_composition_fields.dart';

class QuickLogDetailsSection extends StatefulWidget {
  final QuickLogFormController controller;

  const QuickLogDetailsSection({super.key, required this.controller});

  @override
  State<QuickLogDetailsSection> createState() => _QuickLogDetailsSectionState();
}

class _QuickLogDetailsSectionState extends State<QuickLogDetailsSection> {
  static const _applicationContexts = <String>[
    TrainingSession.applicationContextDrill,
    TrainingSession.applicationContextPositionalSparring,
    TrainingSession.applicationContextSparring,
    TrainingSession.applicationContextCompetition,
    TrainingSession.applicationContextNotApplied,
  ];

  QuickLogFormController get _form => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: const Icon(Icons.tune_rounded),
        title: const Text(
          'Adicionar detalhes (opcional)',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: [
          TrainingSessionCompositionFields(
            controller: _form.composition,
            techniqueCatalog: _form.studiedTechniqueCatalog,
            compact: true,
            onChanged: _form.markCompositionChanged,
          ),
          const SizedBox(height: 12),
          QuickLogSection(
            title: 'Intensidade',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var value = 1; value <= 5; value++)
                  QuickChoiceChip(
                    label: value.toString(),
                    selected: _form.intensity == value,
                    onTap: () => setState(() => _form.selectIntensity(value)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          QuickLogSection(
            title: 'Contexto de aplicação',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final applicationContext in _applicationContexts)
                  QuickChoiceChip(
                    label: _applicationContextLabel(applicationContext),
                    selected: _form.applicationContext == applicationContext,
                    onTap:
                        () => setState(
                          () => _form.selectApplicationContext(
                            applicationContext,
                          ),
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          QuickLogSection(
            title: 'Resultado',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                QuickChoiceChip(
                  label: 'Funcionou',
                  selected:
                      _form.outcome == TrainingSession.techniqueOutcomeWorked,
                  onTap:
                      () => setState(
                        () => _form.selectOutcome(
                          TrainingSession.techniqueOutcomeWorked,
                        ),
                      ),
                ),
                QuickChoiceChip(
                  label: 'Precisa ajuste',
                  selected:
                      _form.outcome == TrainingSession.techniqueOutcomeFailed,
                  onTap:
                      () => setState(
                        () => _form.selectOutcome(
                          TrainingSession.techniqueOutcomeFailed,
                        ),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          QuickTextField(
            controller: _form.notes,
            label: 'Observação opcional',
            icon: Icons.notes_outlined,
            maxLines: 2,
            maxLength: 140,
          ),
        ],
      ),
    );
  }

  String _applicationContextLabel(String value) {
    return switch (value) {
      TrainingSession.applicationContextDrill => 'Drill',
      TrainingSession.applicationContextPositionalSparring =>
        'Treino posicional',
      TrainingSession.applicationContextSparring => 'Rola',
      TrainingSession.applicationContextCompetition => 'Competição',
      TrainingSession.applicationContextNotApplied => 'Não aplicada',
      _ => value,
    };
  }
}

class QuickLogSection extends StatelessWidget {
  final String title;
  final Widget child;

  const QuickLogSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.68),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class QuickChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const QuickChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: TextStyle(
        color:
            selected
                ? TitansUI.navSelectedForeground(context)
                : TitansUI.navUnselectedForeground(context),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
      backgroundColor:
          selected
              ? TitansUI.navSelectedBackground(context)
              : TitansUI.navUnselectedBackground(context),
      side: BorderSide(color: TitansUI.navBorder(context, selected: selected)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class QuickTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final int? maxLength;

  const QuickTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterText: '',
        filled: true,
        fillColor: TitansUI.elevatedSurfaceColor(
          context,
        ).withValues(alpha: 0.78),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          borderSide: BorderSide(color: TitansUI.borderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          borderSide: BorderSide(color: TitansUI.borderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.72)),
        ),
      ),
    );
  }
}
