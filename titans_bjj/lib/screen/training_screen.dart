import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/training/application/training_use_cases.dart';
import '../features/training/domain/training_models.dart';
import '../model/app_user.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/glass_card.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import '../widgets/quick_log_sheet.dart';
import 'add_training_session_screen.dart';

class TrainingScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;
  final bool embedded;

  const TrainingScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
    this.embedded = false,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

enum _TrainingChartMode { bar, line, pie }

extension _TrainingChartModeUi on _TrainingChartMode {
  IconData get icon {
    switch (this) {
      case _TrainingChartMode.bar:
        return Icons.bar_chart_rounded;
      case _TrainingChartMode.line:
        return Icons.show_chart_rounded;
      case _TrainingChartMode.pie:
        return Icons.donut_large_rounded;
    }
  }

  String get label {
    switch (this) {
      case _TrainingChartMode.bar:
        return 'Barras';
      case _TrainingChartMode.line:
        return 'Linha';
      case _TrainingChartMode.pie:
        return 'Pizza';
    }
  }
}

class _TrainingScreenState extends State<TrainingScreen> {
  TrainingChartPeriod _period = TrainingChartPeriod.thirtyDays;
  _TrainingChartMode _selectedChartMode = _TrainingChartMode.bar;
  String? _expandedSessionId;
  final _historySearchController = TextEditingController();
  _TrainingHistoryPeriodFilter _historyPeriod =
      _TrainingHistoryPeriodFilter.all;
  _TrainingHistoryResultFilter _historyResult =
      _TrainingHistoryResultFilter.all;
  _TrainingHistoryContextFilter _historyContext =
      _TrainingHistoryContextFilter.all;
  String? _historyPositionFilter;
  String? _historyTechniqueFilter;
  int _visibleHistoryCount = 20;
  String? _trainingDashboardCacheKey;
  TrainingDashboardSummary? _trainingDashboardCache;
  late final GetTrainingDashboardSummary _getTrainingDashboardSummary =
      const GetTrainingDashboardSummary();

  late final TrainingRepository _repo = TrainingRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<List<TrainingSession>>? _sessionsStream;

  @override
  void initState() {
    super.initState();
    _historySearchController.addListener(_onHistorySearchChanged);
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    super.dispose();
  }

  void _onHistorySearchChanged() {
    setState(_resetHistoryWindow);
  }

  void _resetHistoryWindow() {
    _visibleHistoryCount = 20;
    _expandedSessionId = null;
  }

  void _applyHistoryFilters(_TrainingHistoryFilters filters) {
    setState(() {
      _historyPeriod = filters.period;
      _historyResult = filters.result;
      _historyContext = filters.context;
      _historyPositionFilter = filters.position;
      _historyTechniqueFilter = filters.technique;
      _resetHistoryWindow();
    });
  }

  Future<void> _showHistoryFilters(
    List<TrainingSessionHistoryItem> items,
  ) async {
    final filters = await showModalBottomSheet<_TrainingHistoryFilters>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _TrainingHistoryFilterSheet(
            initial: _TrainingHistoryFilters(
              period: _historyPeriod,
              result: _historyResult,
              context: _historyContext,
              position: _historyPositionFilter,
              technique: _historyTechniqueFilter,
            ),
            positions: _historyFilterValues(
              items.expand((item) => item.positions),
            ),
            techniques: _historyFilterValues(
              items.expand((item) => item.techniqueNames),
            ),
          ),
    );

    if (filters == null || !mounted) return;
    _applyHistoryFilters(filters);
  }

  TrainingDashboardSummary _trainingDashboardFor({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
    required TrainingChartPeriod selectedPeriod,
  }) {
    final cacheKey = _trainingDashboardSignature(
      academyId: academyId,
      uid: uid,
      selectedPeriod: selectedPeriod,
      sessions: sessions,
    );
    final cached = _trainingDashboardCache;
    if (_trainingDashboardCacheKey == cacheKey && cached != null) {
      return cached;
    }

    final next = _getTrainingDashboardSummary(
      sessions,
      selectedPeriod: selectedPeriod,
    );
    _trainingDashboardCacheKey = cacheKey;
    _trainingDashboardCache = next;
    return next;
  }

  String _trainingDashboardSignature({
    required String academyId,
    required String uid,
    required TrainingChartPeriod selectedPeriod,
    required List<TrainingSession> sessions,
  }) {
    final sessionParts = <String>[];

    for (final session in sessions) {
      final scoreKeys = session.scores.keys.toList()..sort();
      final part =
          StringBuffer()
            ..write(session.id)
            ..write('@')
            ..write(session.date.microsecondsSinceEpoch)
            ..write('|place:')
            ..write(session.place.name)
            ..write('|academy:')
            ..write(session.academyId ?? '')
            ..write('|uid:')
            ..write(session.uid ?? '')
            ..write('|source:')
            ..write(session.source ?? '')
            ..write('|attendance:')
            ..write(session.attendanceSessionId ?? '')
            ..write('|checkin:')
            ..write(session.attendanceCheckInUid ?? '')
            ..write('|class:')
            ..write(session.classType ?? '')
            ..write('|instructorUid:')
            ..write(session.instructorUid ?? '')
            ..write('|instructorName:')
            ..write(session.instructorName ?? '')
            ..write('|position:')
            ..write(session.position ?? '')
            ..write('|technique:')
            ..write(session.technique ?? '')
            ..write('|successes:')
            ..write(session.successes ?? '')
            ..write('|difficulties:')
            ..write(session.difficulties ?? '')
            ..write('|intensity:')
            ..write(session.intensity ?? '')
            ..write('|notes:')
            ..write(session.notes ?? '')
            ..write('|debrief:')
            ..write(session.debriefNotes ?? '')
            ..write('|context:')
            ..write(session.applicationContext ?? '')
            ..write('|outcome:')
            ..write(session.techniqueOutcome ?? '');

      for (final key in scoreKeys) {
        part
          ..write('|score:')
          ..write(key)
          ..write('=')
          ..write(session.scores[key]);
      }

      for (final entry in session.effectiveTechniqueEntries) {
        part
          ..write('|entry:')
          ..write(entry.technique)
          ..write(':')
          ..write(entry.position ?? '')
          ..write(':')
          ..write(entry.category ?? '')
          ..write(':')
          ..write(entry.side.name)
          ..write(':')
          ..write(entry.applicationContext ?? '')
          ..write(':')
          ..write(entry.techniqueOutcome ?? '')
          ..write(':')
          ..write(entry.notes ?? '');
      }

      sessionParts.add(part.toString());
    }

    sessionParts.sort();

    final signature =
        StringBuffer()
          ..write(academyId)
          ..write('|')
          ..write(uid)
          ..write('|period:')
          ..write(selectedPeriod.name)
          ..write('|count:')
          ..write(sessions.length);
    for (final part in sessionParts) {
      signature
        ..write('|session:')
        ..write(part);
    }

    return signature.toString();
  }

  void _syncStream({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
    _trainingDashboardCacheKey = null;
    _trainingDashboardCache = null;
    _sessionsStream = _repo.watchSessions(academyId: academyId, uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    final resolverTarget = TargetResolver.maybeOf(
      context,
      mode: widget.targetMode,
    );
    final target = widget.explicitTarget ?? resolverTarget;
    final canEditTarget =
        target != null && _canEditTarget(loggedUser: actor, target: target);
    debugPrint(
      '[TRAINING_TARGET] screen=TrainingScreen '
      'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
      'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
      'explicit.academyId=${widget.explicitTarget?.academyId} '
      'resolver.uid=${resolverTarget?.uid} '
      'resolver.academyId=${resolverTarget?.academyId} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId} '
      'canEditTarget=$canEditTarget',
    );

    final academyId = target?.academyId;
    final uid = target?.uid;

    if (academyId == null || uid == null) {
      debugPrint(
        '[TRAINING_ACTIONS] showAddTraining=false canEditTarget=$canEditTarget '
        'hiddenBy=missing-target-or-academy-or-uid actor.uid=${actor?.uid} '
        'actor.role=${actor?.role} target.uid=${target?.uid} '
        'target.academyId=${target?.academyId}',
      );
      return _wrapModule(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Treinos')),
        body:
            widget.targetMode == TargetMode.selectedStudent
                ? const TitansStateView.noStudent(
                  message:
                      'Selecione um aluno no Painel do Mestre para acessar Treinos.',
                )
                : const TitansStateView.error(
                  title: 'Perfil n\u00e3o carregado',
                  message:
                      'N\u00e3o foi poss\u00edvel identificar seu usu\u00e1rio para carregar Treinos.',
                ),
      );
    }

    _syncStream(academyId: academyId, uid: uid);

    debugPrint(
      '[TRAINING_ACTIONS] showAddTraining=$canEditTarget '
      "canEditTarget=$canEditTarget hiddenBy=${canEditTarget ? 'none' : 'canEditTarget=false'} "
      'actor.uid=${actor?.uid} actor.role=${actor?.role} '
      'target.uid=$uid target.academyId=$academyId',
    );

    return _wrapModule(
      appBar: AppBar(title: Text(widget.titleOverride ?? 'Treinos')),
      floatingActionButton: null,
      body: StreamBuilder<List<TrainingSession>>(
        stream: _sessionsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 4);
          }

          if (snap.hasError) {
            return TitansStateView.error(
              title: 'Erro ao carregar treinos',
              message: snap.error.toString(),
            );
          }

          final rawSessions = snap.data ?? const <TrainingSession>[];
          final dashboard = _trainingDashboardFor(
            academyId: academyId,
            uid: uid,
            sessions: rawSessions,
            selectedPeriod: _period,
          );
          final sessions = dashboard.sortedSessions;
          final historyItems = dashboard.historyItems;
          final chart = dashboard.chart;
          final summary = dashboard.overview;
          final lastTrainingLabel = dashboard.lastTrainingLabel;

          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 48);

          return ListView(
            padding: listPadding,
            children: [
              _TrainingFrequencyHeroCard(
                chart: chart,
                chartMode: _selectedChartMode,
                onPeriodChanged: (period) => setState(() => _period = period),
                onChartModeChanged:
                    (mode) => setState(() => _selectedChartMode = mode),
              ),
              const SizedBox(height: 10),
              _TrainingCompactMetricsAndActions(
                summary: summary,
                lastTrainingLabel: lastTrainingLabel,
                canAddTraining: canEditTarget,
                onQuickLog:
                    canEditTarget
                        ? () => _openQuickLog(
                          academyId: academyId,
                          uid: uid,
                          sessions: sessions,
                        )
                        : null,
                onAddTraining:
                    canEditTarget
                        ? () =>
                            _openTrainingForm(academyId: academyId, uid: uid)
                        : null,
              ),
              const SizedBox(height: 10),
              _TrainingHistorySection(
                items: historyItems,
                searchController: _historySearchController,
                period: _historyPeriod,
                result: _historyResult,
                contextFilter: _historyContext,
                positionFilter: _historyPositionFilter,
                techniqueFilter: _historyTechniqueFilter,
                visibleCount: _visibleHistoryCount,
                expandedSessionId: _expandedSessionId,
                canEdit: canEditTarget,
                onOpenFilters: () => _showHistoryFilters(historyItems),
                onClearSearch: _historySearchController.clear,
                onClearPeriod: () {
                  setState(() {
                    _historyPeriod = _TrainingHistoryPeriodFilter.all;
                    _resetHistoryWindow();
                  });
                },
                onClearResult: () {
                  setState(() {
                    _historyResult = _TrainingHistoryResultFilter.all;
                    _resetHistoryWindow();
                  });
                },
                onClearContext: () {
                  setState(() {
                    _historyContext = _TrainingHistoryContextFilter.all;
                    _resetHistoryWindow();
                  });
                },
                onClearPosition: () {
                  setState(() {
                    _historyPositionFilter = null;
                    _resetHistoryWindow();
                  });
                },
                onClearTechnique: () {
                  setState(() {
                    _historyTechniqueFilter = null;
                    _resetHistoryWindow();
                  });
                },
                onLoadMore: () {
                  setState(() => _visibleHistoryCount += 20);
                },
                onToggle: (item) {
                  setState(() {
                    _expandedSessionId =
                        _expandedSessionId == item.id ? null : item.id;
                  });
                },
                onEdit:
                    canEditTarget
                        ? (item) {
                          final session = item.session;
                          debugPrint(
                            '[TRAINING_EDIT_OPEN] actor.uid=${actor?.uid} '
                            'target.uid=$uid canEditTarget=$canEditTarget '
                            'academyId=$academyId session.id=${session.id}',
                          );
                          return _openTrainingForm(
                            academyId: academyId,
                            uid: uid,
                            session: session,
                          );
                        }
                        : null,
                onAddTraining:
                    canEditTarget
                        ? () =>
                            _openTrainingForm(academyId: academyId, uid: uid)
                        : null,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _wrapModule({
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    required Widget body,
  }) {
    if (widget.embedded) return body;
    return TitansScaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }

  bool _canEditTarget({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    if (loggedUser == null) return false;
    final canManage =
        loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return loggedUser.academyId == target.academyId &&
        (loggedUser.uid == target.uid || canManage);
  }

  Future<bool?> _openQuickLog({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
  }) {
    return showQuickLogSheet(
      context: context,
      academyId: academyId,
      uid: uid,
      recentSessions: sessions,
      canSave: true,
      onOpenFullForm: () => _openTrainingForm(academyId: academyId, uid: uid),
    );
  }

  Future<void> _openTrainingForm({
    required String academyId,
    required String uid,
    TrainingSession? session,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AddTrainingSessionScreen(
              academyId: academyId,
              uid: uid,
              session: session,
            ),
      ),
    );
  }
}

class _TrainingMetricRailItemData {
  final String label;
  final String value;
  final Color color;

  const _TrainingMetricRailItemData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _TrainingMetricRail extends StatelessWidget {
  final List<_TrainingMetricRailItemData> items;

  const _TrainingMetricRail({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        color: TitansUI.subtleFillColor(context, alpha: 0.48),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.34)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
          final columns = maxWidth >= 520 ? 4 : 2;
          const gap = 8.0;
          final itemWidth = (maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth.clamp(112.0, maxWidth).toDouble(),
                  child: _TrainingMetricRailItem(
                    item: item,
                    baseColor: cs.onSurface,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrainingMetricRailItem extends StatelessWidget {
  final _TrainingMetricRailItemData item;
  final Color baseColor;

  const _TrainingMetricRailItem({required this.item, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: baseColor.withValues(alpha: 0.54),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TitansAnimatedMetricValue(
            value: item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainingHistoryActiveFilters extends StatelessWidget {
  final String query;
  final _TrainingHistoryPeriodFilter period;
  final _TrainingHistoryResultFilter result;
  final _TrainingHistoryContextFilter contextFilter;
  final String? positionFilter;
  final String? techniqueFilter;
  final VoidCallback onClearSearch;
  final VoidCallback onClearPeriod;
  final VoidCallback onClearResult;
  final VoidCallback onClearContext;
  final VoidCallback onClearPosition;
  final VoidCallback onClearTechnique;

  const _TrainingHistoryActiveFilters({
    required this.query,
    required this.period,
    required this.result,
    required this.contextFilter,
    required this.positionFilter,
    required this.techniqueFilter,
    required this.onClearSearch,
    required this.onClearPeriod,
    required this.onClearResult,
    required this.onClearContext,
    required this.onClearPosition,
    required this.onClearTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (query.isNotEmpty)
        _ActiveHistoryChip(label: 'Busca: $query', onDeleted: onClearSearch),
      if (period != _TrainingHistoryPeriodFilter.all)
        _ActiveHistoryChip(label: period.label, onDeleted: onClearPeriod),
      if (result != _TrainingHistoryResultFilter.all)
        _ActiveHistoryChip(label: result.label, onDeleted: onClearResult),
      if (contextFilter != _TrainingHistoryContextFilter.all)
        _ActiveHistoryChip(
          label: contextFilter.label,
          onDeleted: onClearContext,
        ),
      if (positionFilter != null)
        _ActiveHistoryChip(label: positionFilter!, onDeleted: onClearPosition),
      if (techniqueFilter != null)
        _ActiveHistoryChip(
          label: techniqueFilter!,
          onDeleted: onClearTechnique,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _ActiveHistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveHistoryChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      visualDensity: VisualDensity.compact,
      backgroundColor: cs.primary.withValues(alpha: 0.10),
      side: BorderSide(color: cs.primary.withValues(alpha: 0.22)),
      labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
    );
  }
}

class _TrainingHistoryFilterSheet extends StatefulWidget {
  final _TrainingHistoryFilters initial;
  final List<String> positions;
  final List<String> techniques;

  const _TrainingHistoryFilterSheet({
    required this.initial,
    required this.positions,
    required this.techniques,
  });

  @override
  State<_TrainingHistoryFilterSheet> createState() =>
      _TrainingHistoryFilterSheetState();
}

class _TrainingHistoryFilterSheetState
    extends State<_TrainingHistoryFilterSheet> {
  late _TrainingHistoryPeriodFilter _period = widget.initial.period;
  late _TrainingHistoryResultFilter _result = widget.initial.result;
  late _TrainingHistoryContextFilter _contextFilter = widget.initial.context;
  late String? _positionFilter = widget.initial.position;
  late String? _techniqueFilter = widget.initial.technique;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterGroup(
                title: 'Periodo',
                children: [
                  for (final option in _TrainingHistoryPeriodFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _period == option,
                      onSelected: () => setState(() => _period = option),
                    ),
                ],
              ),
              _FilterGroup(
                title: 'Resultado',
                children: [
                  for (final option in _TrainingHistoryResultFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _result == option,
                      onSelected: () => setState(() => _result = option),
                    ),
                ],
              ),
              _FilterGroup(
                title: 'Tipo/contexto',
                children: [
                  for (final option in _TrainingHistoryContextFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _contextFilter == option,
                      onSelected: () => setState(() => _contextFilter = option),
                    ),
                ],
              ),
              _filterDropdown(
                label: 'Posicao',
                value: _positionFilter,
                values: widget.positions,
                onChanged: (value) => setState(() => _positionFilter = value),
              ),
              const SizedBox(height: 10),
              _filterDropdown(
                label: 'Tecnica',
                value: _techniqueFilter,
                values: widget.techniques,
                onChanged: (value) => setState(() => _techniqueFilter = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _period = _TrainingHistoryPeriodFilter.all;
                        _result = _TrainingHistoryResultFilter.all;
                        _contextFilter = _TrainingHistoryContextFilter.all;
                        _positionFilter = null;
                        _techniqueFilter = null;
                      });
                    },
                    child: const Text('Limpar filtros'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _TrainingHistoryFilters(
                          period: _period,
                          result: _result,
                          context: _contextFilter,
                          position: _positionFilter,
                          technique: _techniqueFilter,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChoice({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        for (final item in values)
          DropdownMenuItem<String?>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FilterGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
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
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _TrainingHistoryFilters {
  final _TrainingHistoryPeriodFilter period;
  final _TrainingHistoryResultFilter result;
  final _TrainingHistoryContextFilter context;
  final String? position;
  final String? technique;

  const _TrainingHistoryFilters({
    required this.period,
    required this.result,
    required this.context,
    required this.position,
    required this.technique,
  });
}

enum _TrainingHistoryPeriodFilter { sevenDays, thirtyDays, threeMonths, all }

enum _TrainingHistoryResultFilter { all, worked, partial, review, none }

enum _TrainingHistoryContextFilter {
  all,
  academy,
  home,
  sparring,
  drill,
  competition,
}

extension _TrainingHistoryPeriodFilterLabel on _TrainingHistoryPeriodFilter {
  String get label {
    switch (this) {
      case _TrainingHistoryPeriodFilter.sevenDays:
        return '7 dias';
      case _TrainingHistoryPeriodFilter.thirtyDays:
        return '30 dias';
      case _TrainingHistoryPeriodFilter.threeMonths:
        return '3 meses';
      case _TrainingHistoryPeriodFilter.all:
        return 'Todos';
    }
  }
}

extension _TrainingHistoryResultFilterLabel on _TrainingHistoryResultFilter {
  String get label {
    switch (this) {
      case _TrainingHistoryResultFilter.all:
        return 'Todos';
      case _TrainingHistoryResultFilter.worked:
        return 'Funcionou';
      case _TrainingHistoryResultFilter.partial:
        return 'Parcial';
      case _TrainingHistoryResultFilter.review:
        return 'Revisar';
      case _TrainingHistoryResultFilter.none:
        return 'Sem resultado';
    }
  }

  TrainingHistoryResultBucket get domainBucket {
    switch (this) {
      case _TrainingHistoryResultFilter.all:
        return TrainingHistoryResultBucket.none;
      case _TrainingHistoryResultFilter.worked:
        return TrainingHistoryResultBucket.worked;
      case _TrainingHistoryResultFilter.partial:
        return TrainingHistoryResultBucket.partial;
      case _TrainingHistoryResultFilter.review:
        return TrainingHistoryResultBucket.review;
      case _TrainingHistoryResultFilter.none:
        return TrainingHistoryResultBucket.none;
    }
  }
}

extension _TrainingHistoryContextFilterLabel on _TrainingHistoryContextFilter {
  String get label {
    switch (this) {
      case _TrainingHistoryContextFilter.all:
        return 'Todos';
      case _TrainingHistoryContextFilter.academy:
        return 'Academia';
      case _TrainingHistoryContextFilter.home:
        return 'Casa';
      case _TrainingHistoryContextFilter.sparring:
        return 'Rola';
      case _TrainingHistoryContextFilter.drill:
        return 'Drill';
      case _TrainingHistoryContextFilter.competition:
        return 'Competicao';
    }
  }

  TrainingHistoryContextBucket get domainBucket {
    switch (this) {
      case _TrainingHistoryContextFilter.all:
        return TrainingHistoryContextBucket.academy;
      case _TrainingHistoryContextFilter.academy:
        return TrainingHistoryContextBucket.academy;
      case _TrainingHistoryContextFilter.home:
        return TrainingHistoryContextBucket.home;
      case _TrainingHistoryContextFilter.sparring:
        return TrainingHistoryContextBucket.sparring;
      case _TrainingHistoryContextFilter.drill:
        return TrainingHistoryContextBucket.drill;
      case _TrainingHistoryContextFilter.competition:
        return TrainingHistoryContextBucket.competition;
    }
  }
}

extension _TrainingHistoryPeriodFilterDomain on _TrainingHistoryPeriodFilter {
  TrainingHistoryPeriod get domainPeriod {
    switch (this) {
      case _TrainingHistoryPeriodFilter.sevenDays:
        return TrainingHistoryPeriod.sevenDays;
      case _TrainingHistoryPeriodFilter.thirtyDays:
        return TrainingHistoryPeriod.thirtyDays;
      case _TrainingHistoryPeriodFilter.threeMonths:
        return TrainingHistoryPeriod.threeMonths;
      case _TrainingHistoryPeriodFilter.all:
        return TrainingHistoryPeriod.all;
    }
  }
}

class _TrainingSessionCard extends StatelessWidget {
  final TrainingSessionHistoryItem item;
  final bool expanded;
  final bool canEdit;
  final VoidCallback onToggle;
  final Future<void> Function()? onEdit;

  const _TrainingSessionCard({
    required this.item,
    required this.expanded,
    required this.canEdit,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = item.session;

    return glassCard(
      context,
      InkWell(
        borderRadius: BorderRadius.circular(TitansUI.radius),
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.dateLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.62),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: expanded ? 'Ocultar detalhes' : 'Ver detalhes',
                    onPressed: onToggle,
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: 'Opcoes do treino',
                      padding: EdgeInsets.zero,
                      onSelected: (_) => onEdit?.call(),
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar treino'),
                            ),
                          ],
                      icon: const Icon(Icons.more_vert, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: TitansUI.spaceXs,
                runSpacing: TitansUI.spaceXs,
                children: [
                  _TrainingActionChip(
                    label: item.techniqueCountLabel,
                    color: cs.secondary,
                  ),
                  if (session.intensity != null)
                    _TrainingActionChip(
                      label: 'Intensidade ${session.intensity}/5',
                      color: TitansUI.actionGold,
                    ),
                  if (session.scores.isNotEmpty)
                    _TrainingActionChip(
                      label: 'Notas: ${session.scores.length}',
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                ],
              ),
              if (item.techniques.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: TitansUI.spaceXs,
                  runSpacing: TitansUI.spaceXs,
                  children: [
                    for (final entry in item.techniques.take(3))
                      _TrainingActionChip(
                        label: entry.technique,
                        color: cs.primary,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                item.summary,
                maxLines: expanded ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.article_outlined,
                    size: 18,
                  ),
                  label: Text(expanded ? 'Ocultar detalhes' : 'Ver detalhes'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              if (expanded)
                _TrainingSessionDetails(
                  session: session,
                  techniques: item.techniques,
                  canEdit: canEdit,
                  onEdit: onEdit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingSessionDetails extends StatelessWidget {
  final TrainingSession session;
  final List<TrainingTechniqueDisplayEntry> techniques;
  final bool canEdit;
  final Future<void> Function()? onEdit;

  const _TrainingSessionDetails({
    required this.session,
    required this.techniques,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryNote = primarySessionNote(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.onSurface.withValues(alpha: 0.10)),
        if (techniques.isEmpty)
          Text(
            'Nenhuma tecnica informada.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
          )
        else
          for (var i = 0; i < techniques.length; i++) ...[
            _TrainingTechniqueDetail(entry: techniques[i]),
            if (i != techniques.length - 1) const SizedBox(height: 10),
          ],
        if (primaryNote != null) ...[
          const SizedBox(height: 12),
          Text(
            primaryNote.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            primaryNote.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.82)),
          ),
        ],
        if (canEdit) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEdit == null ? null : () => onEdit!.call(),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar treino'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrainingTechniqueDetail extends StatelessWidget {
  final TrainingTechniqueDisplayEntry entry;

  const _TrainingTechniqueDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contextLabel = applicationContextLabel(entry.applicationContext);
    final outcomeLabel = techniqueOutcomeLabel(entry.techniqueOutcome);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.technique,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: TitansUI.spaceXs,
            runSpacing: TitansUI.spaceXs,
            children: [
              _TrainingActionChip(
                label: entry.position ?? 'Posicao nao informada',
                color: cs.primary,
              ),
              if (contextLabel != null)
                _TrainingActionChip(
                  label: contextLabel,
                  color: TitansUI.technicalBlue,
                ),
              if (outcomeLabel != null)
                _TrainingActionChip(
                  label: outcomeLabel,
                  color: _outcomeColor(outcomeLabel),
                ),
            ],
          ),
          if (entry.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.notes!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.78)),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _historyFilterValues(Iterable<String> values) {
  final deduped = dedupeTrainingDisplayValues(values);
  return List<String>.from(deduped)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

Color _outcomeColor(String outcome) {
  if (outcome == 'Funcionou' || outcome == 'Quase funcionou') {
    return TitansUI.success;
  }
  if (outcome == 'Falhou' || outcome == 'Parceiro defendeu') {
    return TitansUI.danger;
  }
  return TitansUI.info;
}

class _TrainingActionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TrainingActionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return TitansStatusChip(label: label, color: color, compact: true);
  }
}

class _TrainingPeriodInlineSelector extends StatelessWidget {
  final TrainingChartPeriod selectedPeriod;
  final ValueChanged<TrainingChartPeriod> onChanged;

  const _TrainingPeriodInlineSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = TitansUI.navSelectedForeground(context);

    return Tooltip(
      message: 'Alterar período',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(_nextPeriod(selectedPeriod)),
          borderRadius: BorderRadius.circular(TitansUI.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitansUI.radiusPill),
              color: TitansUI.navSelectedBackground(
                context,
              ).withValues(alpha: 0.86),
              border: Border.all(
                color: TitansUI.navBorder(context, selected: true),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.secondary.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: Text(
                _compactPeriodLabel(selectedPeriod),
                key: ValueKey(selectedPeriod),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TrainingChartPeriod _nextPeriod(TrainingChartPeriod period) {
    switch (period) {
      case TrainingChartPeriod.sevenDays:
        return TrainingChartPeriod.thirtyDays;
      case TrainingChartPeriod.thirtyDays:
        return TrainingChartPeriod.threeMonths;
      case TrainingChartPeriod.threeMonths:
        return TrainingChartPeriod.twelveMonths;
      case TrainingChartPeriod.twelveMonths:
        return TrainingChartPeriod.sevenDays;
    }
  }

  String _compactPeriodLabel(TrainingChartPeriod period) {
    switch (period) {
      case TrainingChartPeriod.sevenDays:
        return '7d';
      case TrainingChartPeriod.thirtyDays:
        return '30d';
      case TrainingChartPeriod.threeMonths:
        return '3m';
      case TrainingChartPeriod.twelveMonths:
        return '12m';
    }
  }
}

class _TrainingChartModeSwitcher extends StatelessWidget {
  final _TrainingChartMode selectedMode;
  final ValueChanged<_TrainingChartMode> onChanged;

  const _TrainingChartModeSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = TitansUI.navSelectedForeground(context);

    return Tooltip(
      message: 'Alterar gráfico: ${selectedMode.label}',
      child: Semantics(
        label: 'Alterar gráfico',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(_nextMode(selectedMode)),
            borderRadius: BorderRadius.circular(TitansUI.radiusPill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 32,
              decoration: BoxDecoration(
                color: TitansUI.navUnselectedBackground(
                  context,
                ).withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(TitansUI.radiusPill),
                border: Border.all(
                  color: TitansUI.navBorder(context, selected: false),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: Icon(
                  selectedMode.icon,
                  key: ValueKey(selectedMode),
                  size: 18,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TrainingChartMode _nextMode(_TrainingChartMode mode) {
    switch (mode) {
      case _TrainingChartMode.bar:
        return _TrainingChartMode.line;
      case _TrainingChartMode.line:
        return _TrainingChartMode.pie;
      case _TrainingChartMode.pie:
        return _TrainingChartMode.bar;
    }
  }
}

class _TrainingChartView extends StatelessWidget {
  final _TrainingChartMode mode;
  final List<TrainingChartPoint> points;

  const _TrainingChartView({required this.mode, required this.points});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case _TrainingChartMode.bar:
        return _TrainingBarChart(points: points);
      case _TrainingChartMode.line:
        return _TrainingLineChart(points: points);
      case _TrainingChartMode.pie:
        return _TrainingDonutChart(points: points);
    }
  }
}

class _TrainingLineChart extends StatelessWidget {
  final List<TrainingChartPoint> points;

  const _TrainingLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue < 3 ? 3.0 : (maxValue + 1).toDouble();
    final maxX = points.length <= 1 ? 1.0 : (points.length - 1).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEvery = _trainingChartLabelEvery(
          points.length,
          constraints.maxWidth,
        );

        return RepaintBoundary(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      strokeWidth: 1,
                    ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipRoundedRadius: 10,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  getTooltipItems:
                      (spots) => [
                        for (final spot in spots)
                          if (spot.x.toInt() >= 0 &&
                              spot.x.toInt() < points.length)
                            LineTooltipItem(
                              '${points[spot.x.toInt()].tooltipTitle}\n',
                              TextStyle(
                                color: cs.onInverseSurface,
                                fontWeight: FontWeight.w900,
                              ),
                              children: [
                                TextSpan(
                                  text: points[spot.x.toInt()].tooltipBody,
                                  style: TextStyle(
                                    color: cs.onInverseSurface.withValues(
                                      alpha: 0.82,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          else
                            null,
                      ],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final intValue = value.toInt();
                      if (value != intValue || intValue < 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        intValue.toString(),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final shouldShow =
                          index == points.length - 1 || index % labelEvery == 0;
                      if (!shouldShow) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          points[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.66),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].value.toDouble()),
                  ],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  barWidth: 3,
                  color: cs.primary,
                  belowBarData: BarAreaData(
                    show: true,
                    color: cs.primary.withValues(alpha: 0.10),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter:
                        (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: points[index].isHighlighted ? 4 : 2.8,
                          color:
                              points[index].isHighlighted
                                  ? cs.secondary
                                  : cs.primary,
                          strokeColor: Theme.of(context).colorScheme.surface,
                          strokeWidth: 1.5,
                        ),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        );
      },
    );
  }
}

class _TrainingDonutChart extends StatelessWidget {
  static final _motion = TitansMotionSpec.standard();

  final List<TrainingChartPoint> points;

  const _TrainingDonutChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final total = points.fold<int>(0, (sum, point) => sum + point.value);
    final activePoints = points.where((point) => point.value > 0).toList();

    if (total == 0 || activePoints.isEmpty) {
      return TitansEmptyState(
        icon: Icons.donut_large_rounded,
        title: 'Sem registros no período',
        message: 'Nenhum treino registrado neste período.',
        compact: true,
      );
    }

    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero) {
      return _buildOrb(context, activePoints, total, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      builder:
          (context, progress, _) => _buildOrb(
            context,
            activePoints,
            total,
            progress.clamp(0.0, 1.0).toDouble(),
          ),
    );
  }

  Widget _buildOrb(
    BuildContext context,
    List<TrainingChartPoint> activePoints,
    int total,
    double revealProgress,
  ) {
    final mostActive = activePoints.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final chartWidget = _TrainingEnergyOrb(
          points: activePoints,
          total: total,
          progress: revealProgress,
          compact: compact,
        );
        final legend = _TrainingDonutLegend(
          points: activePoints,
          mostActive: mostActive,
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chartWidget),
              const SizedBox(height: 8),
              legend,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: chartWidget),
            const SizedBox(width: 14),
            SizedBox(width: 156, child: legend),
          ],
        );
      },
    );
  }
}

class _TrainingEnergyOrb extends StatefulWidget {
  final List<TrainingChartPoint> points;
  final int total;
  final double progress;
  final bool compact;

  const _TrainingEnergyOrb({
    required this.points,
    required this.total,
    required this.progress,
    required this.compact,
  });

  @override
  State<_TrainingEnergyOrb> createState() => _TrainingEnergyOrbState();
}

class _TrainingEnergyOrbState extends State<_TrainingEnergyOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TrainingEnergyOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = widget.points.isEmpty ? null : widget.points.length - 1;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectNextSegment() {
    if (widget.points.isEmpty) return;
    setState(() {
      final selected = _selectedIndex;
      _selectedIndex =
          selected == null ? 0 : (selected + 1) % widget.points.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orbSize = widget.compact ? 92.0 : 112.0;
    final selectedPoint =
        _selectedIndex == null ? null : widget.points[_selectedIndex!];

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _selectNextSegment,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse =
                MediaQuery.disableAnimationsOf(context)
                    ? 0.0
                    : _pulseController.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(widget.compact ? 188 : 220),
                  painter: _TrainingEnergyOrbPainter(
                    points: widget.points,
                    progress: widget.progress,
                    selectedIndex: _selectedIndex,
                    pulse: pulse,
                    colorScheme: cs,
                  ),
                ),
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.34, -0.42),
                      radius: 0.94,
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        cs.primary.withValues(alpha: 0.56),
                        cs.secondary.withValues(alpha: 0.18),
                        cs.surface.withValues(alpha: 0.96),
                      ],
                      stops: const [0.0, 0.28, 0.58, 1.0],
                    ),
                    border: Border.all(
                      color: cs.secondary.withValues(alpha: 0.32),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(
                          alpha: 0.22 + pulse * 0.08,
                        ),
                        blurRadius: 24 + pulse * 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: orbSize * 0.15,
                        left: orbSize * 0.20,
                        child: Container(
                          width: orbSize * 0.28,
                          height: orbSize * 0.18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.34),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.total.toString(),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: widget.compact ? 22 : 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              selectedPoint?.label ?? 'treinos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.66),
                                fontSize: widget.compact ? 10 : 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedPoint != null)
                  Positioned(
                    bottom: widget.compact ? 8 : 12,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: widget.compact ? 142 : 172,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(
                          TitansUI.radiusPill,
                        ),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '${selectedPoint.label}: ${selectedPoint.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.82),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrainingEnergyOrbPainter extends CustomPainter {
  final List<TrainingChartPoint> points;
  final double progress;
  final int? selectedIndex;
  final double pulse;
  final ColorScheme colorScheme;

  const _TrainingEnergyOrbPainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
    required this.pulse,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortest = math.min(size.width, size.height);
    final total = points.fold<int>(0, (sum, point) => sum + point.value);
    if (total <= 0) return;

    final haloPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.20 + pulse * 0.06),
              colorScheme.secondary.withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: shortest * 0.48),
          );
    canvas.drawCircle(center, shortest * 0.48, haloPaint);

    final ghostPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.onSurface.withValues(alpha: 0.055);
    final ringRect = Rect.fromCircle(center: center, radius: shortest * 0.34);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, ghostPaint);

    var start = -math.pi / 2;
    final visibleProgress = progress.clamp(0.0, 1.0).toDouble();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final sweep = (point.value / total) * math.pi * 2 * visibleProgress;
      if (sweep <= 0) continue;
      final selected =
          selectedIndex == i || (selectedIndex == null && point.isHighlighted);
      final baseColor = _trainingChartSliceColor(colorScheme, i);
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 18 : 13
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + sweep,
              colors: [
                baseColor.withValues(alpha: selected ? 0.96 : 0.70),
                colorScheme.secondary.withValues(alpha: selected ? 0.92 : 0.58),
                colorScheme.primary.withValues(alpha: selected ? 0.98 : 0.76),
              ],
            ).createShader(ringRect);

      canvas.drawArc(
        ringRect,
        start + 0.025,
        math.max(0.0, sweep - 0.05),
        false,
        paint,
      );

      if (selected) {
        final endAngle = start + sweep;
        final pointOffset = Offset(
          center.dx + math.cos(endAngle) * shortest * 0.34,
          center.dy + math.sin(endAngle) * shortest * 0.34,
        );
        final nodePaint =
            Paint()
              ..color = colorScheme.primary.withValues(alpha: 0.95)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(pointOffset, 5.5 + pulse * 1.5, nodePaint);
      }

      start += sweep;
    }

    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = colorScheme.secondary.withValues(
            alpha: 0.22 + pulse * 0.07,
          );
    canvas.drawCircle(center, shortest * 0.42, orbitPaint);

    final diagonalPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colorScheme.primary.withValues(alpha: 0.16);
    canvas.drawArc(
      Rect.fromCenter(
        center: center,
        width: shortest * 0.74,
        height: shortest * 0.30,
      ),
      math.pi * 0.08,
      math.pi * 1.36,
      false,
      diagonalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrainingEnergyOrbPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.pulse != pulse ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _TrainingDonutLegend extends StatelessWidget {
  final List<TrainingChartPoint> points;
  final TrainingChartPoint mostActive;

  const _TrainingDonutLegend({required this.points, required this.mostActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visiblePoints = points.take(6).toList(growable: false);
    final remaining = points.length - visiblePoints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Composição do período',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${mostActive.label} - ${mostActive.value} treinos',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < visiblePoints.length; i++)
              _TrainingDonutLegendPill(point: visiblePoints[i], index: i),
            if (remaining > 0) _TrainingDonutMorePill(count: remaining),
          ],
        ),
      ],
    );
  }
}

class _TrainingDonutLegendPill extends StatelessWidget {
  final TrainingChartPoint point;
  final int index;

  const _TrainingDonutLegendPill({required this.point, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 146),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _trainingChartSliceColor(cs, index),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _trainingChartSliceColor(
                    cs,
                    index,
                  ).withValues(alpha: 0.22),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${point.label} - ${point.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.76),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingDonutMorePill extends StatelessWidget {
  final int count;

  const _TrainingDonutMorePill({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.62),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

int _trainingChartLabelEvery(int count, double width) {
  if (count <= 7) return 1;
  if (width >= 460) return 2;
  if (width >= 390) return 3;
  return 4;
}

Color _trainingChartSliceColor(ColorScheme cs, int index) {
  final colors = [cs.primary, cs.secondary, cs.tertiary, cs.error];
  return colors[index % colors.length].withValues(alpha: 0.88);
}

class _TrainingBarChart extends StatefulWidget {
  final List<TrainingChartPoint> points;

  const _TrainingBarChart({required this.points});

  @override
  State<_TrainingBarChart> createState() => _TrainingBarChartState();
}

class _TrainingBarChartState extends State<_TrainingBarChart> {
  static final _motion = TitansMotionSpec.standard();

  bool _entrancePlayed = false;
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _TrainingBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = widget.points.isEmpty ? null : widget.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero || _entrancePlayed) {
      return _buildChart(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () => _entrancePlayed = true,
      builder: (context, progress, _) => _buildChart(context, progress),
    );
  }

  Widget _buildChart(BuildContext context, double revealProgress) {
    final points = widget.points;
    final cs = Theme.of(context).colorScheme;
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue < 3 ? 3.0 : (maxValue + 1).toDouble();
    final progress = revealProgress.clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEvery = _labelEvery(points.length, constraints.maxWidth);

        return RepaintBoundary(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      strokeWidth: 1,
                    ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: _barTouchData(cs, points),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final intValue = value.toInt();
                      if (value != intValue || intValue < 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        intValue.toString(),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final shouldShow =
                          index == points.length - 1 || index % labelEvery == 0;
                      if (!shouldShow) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          points[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.66),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    showingTooltipIndicators:
                        _selectedIndex == i ? const [0] : const [],
                    barRods: [
                      BarChartRodData(
                        toY: points[i].value.toDouble() * progress,
                        width: _barWidth(points.length, constraints.maxWidth),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                        color: _barColor(cs, points[i], i),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: cs.onSurface.withValues(alpha: 0.045),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            duration: Duration.zero,
          ),
        );
      },
    );
  }

  BarTouchData _barTouchData(ColorScheme cs, List<TrainingChartPoint> points) {
    return BarTouchData(
      enabled: true,
      touchCallback: (event, response) {
        if (!event.isInterestedForInteractions) return;
        final index = response?.spot?.touchedBarGroupIndex;
        if (index == null || index < 0 || index >= points.length) return;
        if (_selectedIndex == index) return;
        setState(() => _selectedIndex = index);
      },
      touchTooltipData: BarTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        tooltipRoundedRadius: 10,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          if (groupIndex < 0 || groupIndex >= points.length) {
            return null;
          }
          final point = points[groupIndex];
          return BarTooltipItem(
            '${point.tooltipTitle}\n',
            TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: point.tooltipBody,
                style: TextStyle(
                  color: cs.onInverseSurface.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _barColor(ColorScheme cs, TrainingChartPoint point, int index) {
    final selectedIndex = _selectedIndex;
    final isSelected = selectedIndex == index;
    final isDimmed = selectedIndex != null && !isSelected;
    if (isSelected) return cs.tertiary;
    if (point.isHighlighted) {
      return cs.secondary.withValues(alpha: isDimmed ? 0.48 : 1);
    }
    return cs.primary.withValues(alpha: isDimmed ? 0.34 : 0.78);
  }

  int _labelEvery(int count, double width) {
    if (count <= 7) return 1;
    if (width >= 460) return 2;
    if (width >= 390) return 3;
    return 4;
  }

  double _barWidth(int count, double width) {
    if (count <= 7) return 18;
    if (count <= 10) return 14;
    if (width >= 420) return 10;
    return 8;
  }
}

class _TrainingFrequencyHeroCard extends StatelessWidget {
  final TrainingChartSummary chart;
  final _TrainingChartMode chartMode;
  final ValueChanged<TrainingChartPeriod> onPeriodChanged;
  final ValueChanged<_TrainingChartMode> onChartModeChanged;

  const _TrainingFrequencyHeroCard({
    required this.chart,
    required this.chartMode,
    required this.onPeriodChanged,
    required this.onChartModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 430;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequência de treino',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chart.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrainingPeriodInlineSelector(
                    selectedPeriod: chart.selectedPeriod,
                    onChanged: onPeriodChanged,
                  ),
                  const SizedBox(width: 8),
                  _TrainingChartModeSwitcher(
                    selectedMode: chartMode,
                    onChanged: onChartModeChanged,
                  ),
                ],
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 10),
                        controls,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: Text(
              chart.totalLabel,
              key: ValueKey(chart.totalLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (chart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TitansEmptyState(
                icon: chartMode.icon,
                title: 'Sem registros no período',
                message: chart.emptyStateLabel,
                compact: true,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: SizedBox(
                key: ValueKey('${chart.selectedPeriod}-$chartMode'),
                height: 280,
                child: _TrainingChartView(
                  mode: chartMode,
                  points: chart.points,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainingCompactMetricsAndActions extends StatelessWidget {
  final TrainingOverviewSummary summary;
  final String lastTrainingLabel;
  final bool canAddTraining;
  final VoidCallback? onQuickLog;
  final VoidCallback? onAddTraining;

  const _TrainingCompactMetricsAndActions({
    required this.summary,
    required this.lastTrainingLabel,
    required this.canAddTraining,
    this.onQuickLog,
    this.onAddTraining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = summary.averageIntensity;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Histórico de treinos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastTrainingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TrainingMetricRail(
            items: [
              _TrainingMetricRailItemData(
                label: 'Treinos',
                value: summary.total.toString(),
                color: cs.onSurface,
              ),
              _TrainingMetricRailItemData(
                label: 'Técnicas',
                value: summary.techniques.toString(),
                color: cs.onSurface,
              ),
              _TrainingMetricRailItemData(
                label: 'Intensidade',
                value:
                    intensity == null
                        ? 'Sem dados'
                        : '${intensity.toStringAsFixed(1)}/5',
                color: TitansUI.actionGold,
              ),
              _TrainingMetricRailItemData(
                label: 'Aplicação',
                value: summary.applicationCount.toString(),
                color: TitansUI.successGreen,
              ),
            ],
          ),
          if (canAddTraining &&
              (onQuickLog != null || onAddTraining != null)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onQuickLog != null)
                  FilledButton.icon(
                    onPressed: onQuickLog,
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Registro rápido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TitansUI.actionGold,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
                if (onAddTraining != null)
                  OutlinedButton.icon(
                    onPressed: onAddTraining,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Treino'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 38),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrainingHistorySection extends StatelessWidget {
  final List<TrainingSessionHistoryItem> items;
  final TextEditingController searchController;
  final _TrainingHistoryPeriodFilter period;
  final _TrainingHistoryResultFilter result;
  final _TrainingHistoryContextFilter contextFilter;
  final String? positionFilter;
  final String? techniqueFilter;
  final int visibleCount;
  final String? expandedSessionId;
  final bool canEdit;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onClearPeriod;
  final VoidCallback onClearResult;
  final VoidCallback onClearContext;
  final VoidCallback onClearPosition;
  final VoidCallback onClearTechnique;
  final VoidCallback onLoadMore;
  final ValueChanged<TrainingSessionHistoryItem> onToggle;
  final Future<void> Function(TrainingSessionHistoryItem item)? onEdit;
  final Future<void> Function()? onAddTraining;

  const _TrainingHistorySection({
    required this.items,
    required this.searchController,
    required this.period,
    required this.result,
    required this.contextFilter,
    required this.positionFilter,
    required this.techniqueFilter,
    required this.visibleCount,
    required this.expandedSessionId,
    required this.canEdit,
    required this.onOpenFilters,
    required this.onClearSearch,
    required this.onClearPeriod,
    required this.onClearResult,
    required this.onClearContext,
    required this.onClearPosition,
    required this.onClearTechnique,
    required this.onLoadMore,
    required this.onToggle,
    required this.onEdit,
    required this.onAddTraining,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredItems();
    final visible = filtered.take(visibleCount).toList(growable: false);
    final query = searchController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar treino',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon:
                      query.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  isDense: true,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filtros',
              onPressed: onOpenFilters,
              icon: const Icon(Icons.tune, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TrainingHistoryActiveFilters(
          query: query,
          period: period,
          result: result,
          contextFilter: contextFilter,
          positionFilter: positionFilter,
          techniqueFilter: techniqueFilter,
          onClearSearch: onClearSearch,
          onClearPeriod: onClearPeriod,
          onClearResult: onClearResult,
          onClearContext: onClearContext,
          onClearPosition: onClearPosition,
          onClearTechnique: onClearTechnique,
        ),
        const SizedBox(height: 8),
        Text(
          '${filtered.length} treinos encontrados',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.60),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          TitansEmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'Sem treinos registrados',
            message: 'Adicione uma sessao para iniciar o historico.',
            compact: true,
            action:
                canEdit
                    ? FilledButton.icon(
                      onPressed: onAddTraining,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar treino'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 38),
                      ),
                    )
                    : null,
          )
        else if (filtered.isEmpty)
          const TitansEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'Nenhum treino encontrado com esses filtros.',
            message: 'Ajuste a busca ou remova algum filtro ativo.',
            compact: true,
          )
        else ...[
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TrainingSessionCard(
                item: item,
                expanded: expandedSessionId == item.id,
                canEdit: canEdit,
                onToggle: () => onToggle(item),
                onEdit: onEdit == null ? null : () => onEdit!(item),
              ),
            ),
          if (filtered.length > visible.length)
            Center(
              child: OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(
                  'Carregar mais (${filtered.length - visible.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 38),
                ),
              ),
            ),
        ],
      ],
    );
  }

  List<TrainingSessionHistoryItem> _filteredItems() {
    final query = trainingHistoryKey(searchController.text);
    final now = DateTime.now();
    return items
        .where((item) {
          if (query.isNotEmpty && !item.searchText.contains(query)) {
            return false;
          }
          if (!matchesTrainingHistoryPeriod(
            item.date,
            period.domainPeriod,
            now,
          )) {
            return false;
          }
          if (result != _TrainingHistoryResultFilter.all &&
              item.resultBucket != result.domainBucket) {
            return false;
          }
          if (contextFilter != _TrainingHistoryContextFilter.all &&
              !item.contextBuckets.contains(contextFilter.domainBucket)) {
            return false;
          }
          final position = positionFilter;
          if (position != null &&
              !item.positionKeys.contains(trainingHistoryKey(position))) {
            return false;
          }
          final technique = techniqueFilter;
          if (technique != null &&
              !item.techniqueKeys.contains(trainingHistoryKey(technique))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}
