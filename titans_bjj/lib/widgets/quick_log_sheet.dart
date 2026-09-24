import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/titans_ui.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import 'quick_log_form_controller.dart';
import 'quick_log_form_widgets.dart';

export 'quick_log_form_controller.dart' show QuickLogInputField;

typedef QuickLogSessionSaver =
    Future<void> Function({
      required String academyId,
      required String uid,
      required TrainingSession session,
    });

class QuickLogSaveResult {
  final TrainingSession session;
  final Set<QuickLogInputField> explicitlyProvidedFields;

  QuickLogSaveResult({
    required this.session,
    required Set<QuickLogInputField> explicitlyProvidedFields,
  }) : explicitlyProvidedFields = Set.unmodifiable(explicitlyProvidedFields);
}

Future<QuickLogSaveResult?> showQuickLogSheet({
  required BuildContext context,
  required String academyId,
  required String uid,
  required List<TrainingSession> recentSessions,
  required bool canSave,
  VoidCallback? onOpenFullForm,
}) {
  final sessions = List<TrainingSession>.from(recentSessions)
    ..sort((a, b) => b.date.compareTo(a.date));

  return showModalBottomSheet<QuickLogSaveResult>(
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
  final QuickLogSessionSaver? saveSession;

  const QuickLogSheet({
    super.key,
    required this.academyId,
    required this.uid,
    required this.recentSessions,
    required this.canSave,
    this.onOpenFullForm,
    this.saveSession,
  });

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  late final QuickLogFormController _form;
  TrainingRepository get _repository => TrainingRepository.instance;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _form = QuickLogFormController(widget.recentSessions);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasLast = _form.hasRecentSession;

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
                                ? 'Sugestões recentes só entram no registro quando você seleciona.'
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
                  QuickLogSection(
                    title: 'Técnica (opcional)',
                    child: _OptionWrap(
                      options: _form.recentTechniques,
                      selected: _form.technique,
                      fallbackLabel: 'Sem técnica recente',
                      onSelected:
                          (value) => setState(() {
                            _form.selectTechnique(value);
                          }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  QuickLogSection(
                    title: 'Posição (opcional)',
                    child: _OptionWrap(
                      options: _form.recentPositions,
                      selected: _form.position,
                      fallbackLabel: 'Sem posição recente',
                      onSelected:
                          (value) => setState(() {
                            _form.selectPosition(value);
                          }),
                    ),
                  ),
                  if (!hasLast) ...[
                    const SizedBox(height: 12),
                    QuickTextField(
                      controller: _form.customTechnique,
                      label: 'Técnica opcional',
                      icon: Icons.sports_mma_outlined,
                    ),
                    const SizedBox(height: 10),
                    QuickTextField(
                      controller: _form.customPosition,
                      label: 'Posição opcional',
                      icon: Icons.place_outlined,
                    ),
                  ],
                  const SizedBox(height: 12),
                  QuickLogSection(
                    title: 'Local (obrigatório)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final place in TrainingPlace.values)
                              QuickChoiceChip(
                                label: _placeLabel(place),
                                selected: _form.place == place,
                                onTap:
                                    () => setState(() {
                                      _form.selectPlace(place);
                                    }),
                              ),
                          ],
                        ),
                        if (_form.place == null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Selecione onde o treino aconteceu.',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  QuickLogDetailsSection(controller: _form),
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

  Future<void> _save() async {
    if (_saving) return;
    final validationError = _form.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _saving = true);

    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final session = _form.buildSession(
        id: uuid.v4(),
        academyId: widget.academyId,
        uid: widget.uid,
        now: now,
      );

      final saveSession = widget.saveSession ?? _repository.addSession;
      await saveSession(
        academyId: widget.academyId,
        uid: widget.uid,
        session: session,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        QuickLogSaveResult(
          session: session,
          explicitlyProvidedFields: _form.explicitlyProvidedFields,
        ),
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
    Navigator.of(context).pop();
    widget.onOpenFullForm?.call();
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
          QuickChoiceChip(
            label: option,
            selected: option == selected,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}
