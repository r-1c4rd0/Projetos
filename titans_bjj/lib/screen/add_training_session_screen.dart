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
import '../widgets/training_debrief_select_sheet.dart';
import '../widgets/training_session_form_data.dart';
import '../widgets/training_session_composition_fields.dart';
import '../widgets/training_session_form_sections.dart';
import '../widgets/training_technique_form_controller.dart';
import '../widgets/training_technique_form_editor.dart';

class AddTrainingSessionScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final TrainingSession? session;
  final TrainingSessionStatus initialStatus;

  const AddTrainingSessionScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.session,
    this.initialStatus = TrainingSessionStatus.completed,
  });

  @override
  State<AddTrainingSessionScreen> createState() =>
      _AddTrainingSessionScreenState();
}

class _AddTrainingSessionScreenState extends State<AddTrainingSessionScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _successes = TextEditingController();
  final _difficulties = TextEditingController();
  final _debriefNotes = TextEditingController();
  late final TrainingSessionCompositionController _composition;
  late final TrainingTechniqueFormController _techniqueForm;

  bool _recurring = false;
  late TrainingSessionStatus _intent;

  DateTime _singleDate = DateTime.now();

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));

  final Set<int> _weekdays = {};

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
  bool get _isRegisteringCompleted =>
      _intent == TrainingSessionStatus.completed;

  bool get _singleDateIsFuture =>
      TrainingSession.isFutureDay(_singleDate, now: DateTime.now());

  String get _submitLabel {
    if (_saving) return 'Salvando...';
    return _isRegisteringCompleted ? 'Registrar treino' : 'Agendar treino';
  }

  String get _recurrenceSummary {
    if (!_recurring) {
      return _isRegisteringCompleted
          ? '1 treino realizado'
          : '1 treino planejado';
    }

    return _sessionCountSummary(
      count: _recurringOccurrenceDates(now: DateTime.now()).length,
      status: _intent,
    );
  }

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
    _composition = TrainingSessionCompositionController(session: session);
    _techniqueForm = TrainingTechniqueFormController(session: session);
    _intent = session?.effectiveStatus() ?? widget.initialStatus;
    debugPrint(
      "[TRAINING_DEBRIEF_FORM] mode=${session == null ? 'create' : 'edit'} "
      'session.id=${session?.id} target.uid=${widget.uid} '
      'position=${session?.position} technique=${session?.technique} '
      'intensity=${session?.intensity}',
    );
    if (session == null) return;

    _singleDate = session.date;
    _notes.text = session.notes ?? '';
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
    _successes.dispose();
    _difficulties.dispose();
    _debriefNotes.dispose();
    _composition.dispose();
    _techniqueForm.dispose();
    super.dispose();
  }

  bool _validateTechniquePositions() {
    final invalidEntry = _techniqueForm.firstTechniqueMissingPosition;
    if (invalidEntry == null) return true;

    setState(() => _techniqueForm.expandOnly(invalidEntry));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Informe a posição/contexto desta técnica.'),
      ),
    );
    return false;
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
              final studiedTechniqueCatalog = _studiedTechniqueCatalog(
                techniqueSnap.data ?? const <JiuJitsuTaxonomyItem>[],
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
                      TrainingSessionScheduleSection(
                        editing: _editing,
                        intent: _intent,
                        onIntentChanged:
                            (value) => setState(() => _intent = value),
                        recurring: _recurring,
                        onRecurringChanged:
                            (value) => setState(() => _recurring = value),
                        isRegisteringCompleted: _isRegisteringCompleted,
                        singleDate: _singleDate,
                        singleDateIsFuture: _singleDateIsFuture,
                        onSingleDateChanged:
                            (value) => setState(() => _singleDate = value),
                        startDate: _start,
                        onStartDateChanged:
                            (value) => setState(() => _start = value),
                        endDate: _end,
                        onEndDateChanged:
                            (value) => setState(() => _end = value),
                        weekdays: _weekdays,
                        onWeekdaysChanged:
                            (values) => setState(() {
                              _weekdays
                                ..clear()
                                ..addAll(values);
                            }),
                        recurrenceSummary: _recurrenceSummary,
                        notesController: _notes,
                      ),
                      const SizedBox(height: 12),
                      TrainingFormSection(
                        title: 'Composição do treino',
                        icon: Icons.format_list_bulleted_outlined,
                        children: [
                          TrainingSessionCompositionFields(
                            controller: _composition,
                            techniqueCatalog: studiedTechniqueCatalog,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TrainingTechniqueFormEditor(
                        controller: _techniqueForm,
                        positionLoading:
                            positionSnap.connectionState ==
                                ConnectionState.waiting &&
                            !positionSnap.hasData,
                        techniqueLoading:
                            techniqueSnap.connectionState ==
                                ConnectionState.waiting &&
                            !techniqueSnap.hasData,
                        onPickPosition:
                            (entry) => _selectDebriefValue(
                              title: 'Posi\u00e7\u00e3o trabalhada',
                              placeholder: 'Buscar posição',
                              type: JiuJitsuTaxonomyType.position,
                              options: positionOptions,
                              recentOptions: _techniqueForm.recentPositions(
                                excluding: entry.position.text,
                              ),
                              controller: entry.position,
                              canAddToAcademy: canAddToAcademy,
                              actorUid: actor?.uid,
                            ),
                        onPickTechnique:
                            (entry) => _selectDebriefValue(
                              title: 'Técnica trabalhada',
                              placeholder: 'Buscar técnica',
                              type: JiuJitsuTaxonomyType.technique,
                              options: techniqueOptions,
                              recentOptions: _techniqueForm.recentTechniques(
                                excluding: entry.technique.text,
                              ),
                              controller: entry.technique,
                              canAddToAcademy: canAddToAcademy,
                              actorUid: actor?.uid,
                            ),
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TrainingSessionDebriefSections(
                        intensity: _intensity,
                        onIntensityChanged:
                            (value) => setState(() => _intensity = value),
                        successesController: _successes,
                        difficultiesController: _difficulties,
                        notesController: _debriefNotes,
                      ),
                      const SizedBox(height: 16),
                      TrainingSessionFormActions(
                        saving: _saving,
                        submitLabel: _submitLabel,
                        onCancel: () => Navigator.pop(context),
                        onSubmit: _save,
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
    final sheet = TrainingDebriefSelectSheet(
      title: title,
      placeholder: placeholder,
      options: options,
      recentOptions: recentOptions,
      currentValue: controller.text,
      canAddToAcademy: canAddToAcademy,
    );
    final useDialog = MediaQuery.sizeOf(context).width >= 700;
    TrainingDebriefSelection? selected;
    if (useDialog) {
      selected = await showDialog<TrainingDebriefSelection>(
        context: context,
        builder:
            (context) => Dialog(
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.all(24),
              child: sheet,
            ),
      );
    } else {
      selected = await showModalBottomSheet<TrainingDebriefSelection>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => sheet,
      );
    }

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
    if (!_validateTechniquePositions()) return;
    final compositionError = _composition.validate();
    if (compositionError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(compositionError)));
      return;
    }
    setState(() => _saving = true);

    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final formData = _buildFormData();

      if (!_recurring) {
        if (_isRegisteringCompleted && _singleDateIsFuture) {
          throw Exception(
            'Data futura nao pode ser registrada como treino realizado.',
          );
        }

        final existing = widget.session;
        final normalizedDate = DateTime(
          _singleDate.year,
          _singleDate.month,
          _singleDate.day,
        );
        final s = formData.buildSingleSession(
          id: existing?.id ?? uuid.v4(),
          date: normalizedDate,
          status: _intent,
          academyId: widget.academyId,
          uid: widget.uid,
          now: now,
          existing: existing,
        );

        final actor = UserScope.maybeOf(context);
        debugPrint(
          "[TRAINING_DEBRIEF_SAVE] mode=${_editing ? 'edit' : 'create'} "
          'session.id=${s.id} target.uid=${widget.uid} '
          'position=${formData.position} technique=${formData.technique} '
          'intensity=${formData.intensity} '
          'applicationContext=${formData.applicationContext} '
          'techniqueOutcome=${formData.techniqueOutcome}',
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
        if (TrainingSession.dateOnly(
          _start,
        ).isAfter(TrainingSession.dateOnly(_end))) {
          throw Exception(
            'Data inicial deve ser anterior ou igual a data final.',
          );
        }

        final occurrenceDates = _recurringOccurrenceDates(now: now);
        if (occurrenceDates.isEmpty) {
          throw Exception(
            'Nenhuma ocorrência encontrada para o intervalo e dias selecionados.',
          );
        }

        final status = _intent;
        final timeSource = _recurringTimeSource;
        final sessions = <TrainingSession>[
          for (final occurrenceDate in occurrenceDates)
            formData.buildRecurringSession(
              id: formData.recurringSessionId(
                academyId: widget.academyId,
                uid: widget.uid,
                occurrenceDate: _withTimeFrom(occurrenceDate, timeSource),
                status: status,
              ),
              date: _withTimeFrom(occurrenceDate, timeSource),
              status: status,
              academyId: widget.academyId,
              uid: widget.uid,
              now: now,
            ),
        ];
        final confirmationSummary = _sessionCountSummary(
          count: sessions.length,
          status: status,
        );

        final ok = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Confirmar cadastro'),
                content: Text(confirmationSummary),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      _isRegisteringCompleted ? 'Registrar' : 'Agendar',
                    ),
                  ),
                ],
              ),
        );

        if (!mounted) return;

        if (ok != true) {
          setState(() => _saving = false);
          return;
        }

        final actor = UserScope.maybeOf(context);
        debugPrint(
          '[TRAINING_DEBRIEF_SAVE] mode=create '
          'session.id=multiple(${sessions.length}) target.uid=${widget.uid} '
          'position=${formData.position} technique=${formData.technique} '
          'intensity=${formData.intensity} '
          'applicationContext=${formData.applicationContext} '
          'techniqueOutcome=${formData.techniqueOutcome}',
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

  TrainingSessionFormData _buildFormData() {
    final techniqueEntries = _techniqueForm.buildEntries();
    final primaryTechnique =
        techniqueEntries.isEmpty ? null : techniqueEntries.first;
    final compositionFingerprint = <String>[
      _composition.totalDuration.text.trim(),
      _composition.durationIsEstimated.toString(),
      _composition.rollCount.text.trim(),
      _composition.roundDuration.text.trim(),
      for (final technique in _composition.studiedTechniques) ...[
        technique.catalogId,
        technique.label,
      ],
    ].join('|');

    return TrainingSessionFormData(
      notes: _optionalText(_notes),
      position: primaryTechnique?.position ?? _techniqueForm.fallbackPosition,
      technique:
          primaryTechnique?.technique ?? _techniqueForm.fallbackTechnique,
      techniqueEntries: techniqueEntries,
      successes: _optionalText(_successes),
      difficulties: _optionalText(_difficulties),
      intensity: _intensity,
      debriefNotes: _optionalText(_debriefNotes),
      applicationContext:
          primaryTechnique?.applicationContext ?? _applicationContext,
      techniqueOutcome: primaryTechnique?.techniqueOutcome ?? _techniqueOutcome,
      composition: _composition.value(),
      compositionFingerprint: compositionFingerprint,
    );
  }

  List<DateTime> _recurringOccurrenceDates({required DateTime now}) {
    final today = TrainingSession.dateOnly(now);
    return generateRecurringDates(
      startDate: _start,
      endDate: _end,
      selectedWeekdays: _weekdays,
      earliestDate: _isRegisteringCompleted ? null : today,
      latestDate: _isRegisteringCompleted ? today : null,
    );
  }

  DateTime get _recurringTimeSource {
    return _isRegisteringCompleted ? _singleDate : _start;
  }

  DateTime _withTimeFrom(DateTime date, DateTime timeSource) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
      timeSource.millisecond,
      timeSource.microsecond,
    );
  }

  String _sessionCountSummary({
    required int count,
    required TrainingSessionStatus status,
  }) {
    final label =
        status == TrainingSessionStatus.completed ? 'realizado' : 'planejado';
    final plural = count == 1 ? label : '${label}s';
    return '$count ${count == 1 ? 'treino' : 'treinos'} $plural';
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  List<TrainingStudiedTechnique> _studiedTechniqueCatalog(
    List<JiuJitsuTaxonomyItem> customItems,
  ) {
    final byNormalizedKey = <String, TrainingStudiedTechnique>{};
    for (final label in JiuJitsuTaxonomy.techniques) {
      final catalogId = JiuJitsuTaxonomy.normalizedKey(label);
      byNormalizedKey[catalogId] = TrainingStudiedTechnique(
        catalogId: catalogId,
        label: label,
      );
    }
    for (final item in customItems) {
      if (!item.isActive) continue;
      if (item.normalizedKey.trim().isEmpty || item.id.trim().isEmpty) continue;
      byNormalizedKey.putIfAbsent(
        item.normalizedKey,
        () => TrainingStudiedTechnique(catalogId: item.id, label: item.label),
      );
    }
    return byNormalizedKey.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }
}
