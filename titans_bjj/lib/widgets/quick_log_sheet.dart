import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';

Future<bool?> showQuickLogSheet({
  required BuildContext context,
  required String academyId,
  required String uid,
  required List<TrainingSession> recentSessions,
  required bool canSave,
  VoidCallback? onOpenFullForm,
}) {
  final sessions = List<TrainingSession>.from(recentSessions)
    ..sort((a, b) => b.date.compareTo(a.date));

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => QuickLogSheet(
          academyId: academyId,
          uid: uid,
          recentSessions: sessions,
          canSave: canSave,
          onOpenFullForm: onOpenFullForm,
        ),
  );
}

class QuickLogSheet extends StatefulWidget {
  final String academyId;
  final String uid;
  final List<TrainingSession> recentSessions;
  final bool canSave;
  final VoidCallback? onOpenFullForm;

  const QuickLogSheet({
    super.key,
    required this.academyId,
    required this.uid,
    required this.recentSessions,
    required this.canSave,
    this.onOpenFullForm,
  });

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  final _notesController = TextEditingController();
  final _customTechniqueController = TextEditingController();
  final _customPositionController = TextEditingController();
  final _repository = TrainingRepository.instance;

  late TrainingPlace _place;
  late int _intensity;
  late String _outcome;
  late String? _technique;
  late String? _position;
  bool _saving = false;

  TrainingSession? get _lastSession =>
      widget.recentSessions.isEmpty ? null : widget.recentSessions.first;

  @override
  void initState() {
    super.initState();
    final last = _lastSession;
    final primaryEntry = last?.effectiveTechniqueEntries.firstOrNull;
    _place = last?.place ?? TrainingPlace.academy;
    _intensity = last?.intensity?.clamp(1, 5) ?? 3;
    _outcome = _quickOutcomeFrom(last?.techniqueOutcome);
    _technique = _clean(primaryEntry?.technique ?? last?.technique);
    _position = _clean(primaryEntry?.position ?? last?.position);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customTechniqueController.dispose();
    _customPositionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final recentTechniques = _recentTechniqueOptions();
    final recentPositions = _recentPositionOptions();
    final hasLast = _lastSession != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TitansUI.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: TitansUI.borderColor(context, alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: TitansUI.softShadowColor(context),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TitansUI.actionGold.withValues(alpha: 0.16),
                        border: Border.all(
                          color: TitansUI.actionGold.withValues(alpha: 0.34),
                        ),
                      ),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: TitansUI.actionGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro rápido',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasLast
                                ? 'Use o último treino como base e ajuste só o necessário.'
                                : 'Registre o essencial agora e detalhe depois, se quiser.',
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
                if (!widget.canSave) ...[
                  const SizedBox(height: 12),
                  TitansStateView.empty(
                    title: 'Somente leitura',
                    message:
                        'Este contexto não permite registrar treino para este aluno.',
                    compact: true,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _QuickLogSection(
                    title: 'Técnica',
                    child: _OptionWrap(
                      options: recentTechniques,
                      selected: _technique,
                      fallbackLabel: 'Sem técnica recente',
                      onSelected: (value) => setState(() => _technique = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickLogSection(
                    title: 'Posição',
                    child: _OptionWrap(
                      options: recentPositions,
                      selected: _position,
                      fallbackLabel: 'Sem posição recente',
                      onSelected: (value) => setState(() => _position = value),
                    ),
                  ),
                  if (!hasLast) ...[
                    const SizedBox(height: 12),
                    _QuickTextField(
                      controller: _customTechniqueController,
                      label: 'Técnica opcional',
                      icon: Icons.sports_mma_outlined,
                    ),
                    const SizedBox(height: 10),
                    _QuickTextField(
                      controller: _customPositionController,
                      label: 'Posição opcional',
                      icon: Icons.place_outlined,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _QuickLogSection(
                    title: 'Local',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final place in TrainingPlace.values)
                          _QuickChoiceChip(
                            label: _placeLabel(place),
                            selected: _place == place,
                            onTap: () => setState(() => _place = place),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickLogSection(
                    title: 'Intensidade',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var value = 1; value <= 5; value++)
                          _QuickChoiceChip(
                            label: value.toString(),
                            selected: _intensity == value,
                            onTap: () => setState(() => _intensity = value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickLogSection(
                    title: 'Resultado',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickChoiceChip(
                          label: 'Funcionou',
                          selected:
                              _outcome ==
                              TrainingSession.techniqueOutcomeWorked,
                          onTap:
                              () => setState(
                                () =>
                                    _outcome =
                                        TrainingSession.techniqueOutcomeWorked,
                              ),
                        ),
                        _QuickChoiceChip(
                          label: 'Precisa ajuste',
                          selected:
                              _outcome ==
                              TrainingSession.techniqueOutcomeFailed,
                          onTap:
                              () => setState(
                                () =>
                                    _outcome =
                                        TrainingSession.techniqueOutcomeFailed,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickTextField(
                    controller: _notesController,
                    label: 'Observação opcional',
                    icon: Icons.notes_outlined,
                    maxLines: 2,
                    maxLength: 140,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon:
                              _saving
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.check_rounded),
                          label: const Text('Salvar treino'),
                          style: FilledButton.styleFrom(
                            backgroundColor: TitansUI.actionGold,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.onOpenFullForm != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _openFullForm,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Abrir formulário completo'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _recentTechniqueOptions() {
    final options = <String>[];
    final seen = <String>{};
    for (final session in widget.recentSessions) {
      for (final entry in session.effectiveTechniqueEntries) {
        final value = _clean(entry.technique);
        if (value == null) continue;
        final key = value.toLowerCase();
        if (seen.add(key)) options.add(value);
        if (options.length >= 4) return options;
      }
    }
    return options;
  }

  List<String> _recentPositionOptions() {
    final options = <String>[];
    final seen = <String>{};
    for (final session in widget.recentSessions) {
      final values = [
        _clean(session.position),
        for (final entry in session.effectiveTechniqueEntries)
          _clean(entry.position),
      ];
      for (final value in values.whereType<String>()) {
        final key = value.toLowerCase();
        if (seen.add(key)) options.add(value);
        if (options.length >= 4) return options;
      }
    }
    return options;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      const uuid = Uuid();
      final technique =
          _clean(_technique) ?? _clean(_customTechniqueController.text);
      final position =
          _clean(_position) ?? _clean(_customPositionController.text);
      final notes = _clean(_notesController.text);
      if (technique == null && position == null && notes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Informe uma técnica, posição ou observação antes de salvar.',
            ),
          ),
        );
        return;
      }
      final techniqueEntries =
          technique == null
              ? const <TrainingTechniqueEntry>[]
              : [
                TrainingTechniqueEntry(
                  technique: technique,
                  position: position,
                  applicationContext:
                      TrainingSession.applicationContextSparring,
                  techniqueOutcome: _outcome,
                ),
              ];
      final now = DateTime.now();
      final session = TrainingSession(
        id: uuid.v4(),
        date: DateTime(now.year, now.month, now.day),
        place: _place,
        notes: notes,
        academyId: widget.academyId,
        uid: widget.uid,
        position: position,
        technique: technique,
        techniques: techniqueEntries,
        intensity: _intensity,
        debriefNotes: notes,
        applicationContext: TrainingSession.applicationContextSparring,
        techniqueOutcome: _outcome,
      );

      await _repository.addSession(
        academyId: widget.academyId,
        uid: widget.uid,
        session: session,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Treino registrado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar treino: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openFullForm() {
    Navigator.of(context).pop(false);
    widget.onOpenFullForm?.call();
  }

  String _quickOutcomeFrom(String? value) {
    return TrainingSession.isTechniqueOutcomeNeedsWork(value)
        ? TrainingSession.techniqueOutcomeFailed
        : TrainingSession.techniqueOutcomeWorked;
  }

  String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _placeLabel(TrainingPlace place) {
    switch (place) {
      case TrainingPlace.academy:
        return 'Academia';
      case TrainingPlace.home:
        return 'Casa';
      case TrainingPlace.other:
        return 'Outro';
    }
  }
}

class _QuickLogSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _QuickLogSection({required this.title, required this.child});

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

class _OptionWrap extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final String fallbackLabel;
  final ValueChanged<String> onSelected;

  const _OptionWrap({
    required this.options,
    required this.selected,
    required this.fallbackLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        fallbackLabel,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.52),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _QuickChoiceChip(
            label: option,
            selected: option == selected,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

class _QuickChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChoiceChip({
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

class _QuickTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final int? maxLength;

  const _QuickTextField({
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
