import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/training/application/training_use_cases.dart';
import '../features/training/domain/training_history_focus.dart';
import '../features/training/domain/training_models.dart';
import '../features/training/domain/training_operation_context.dart';
import '../main.dart';
import '../model/app_user.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';
import '../widgets/quick_log_sheet.dart';
import '../widgets/training_dashboard_header.dart';
import '../widgets/training_frequency_chart.dart';
import '../widgets/training_history_filters.dart';
import '../widgets/training_history_journal.dart';
import '../widgets/training_save_confirmation.dart';
import '../widgets/training_screen_states.dart';
import 'add_training_session_screen.dart';

class TrainingScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;
  final bool embedded;
  final String? focusSessionId;

  const TrainingScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
    this.embedded = false,
    this.focusSessionId,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  TrainingChartPeriod _period = TrainingChartPeriod.thirtyDays;
  TrainingChartMode _selectedChartMode = TrainingChartMode.bar;
  TrainingJournalMode _historyMode = TrainingJournalMode.calendar;
  DateTime _displayedHistoryMonth = _monthStart(DateTime.now());
  DateTime? _selectedHistoryDay;
  String? _selectedSessionId;
  String? _requestedFocusSessionId;
  String? _appliedFocusSessionId;
  final Set<String> _lifecycleUpdatingIds = <String>{};
  final _historySearchController = TextEditingController();
  TrainingHistoryPeriodFilter _historyPeriod = TrainingHistoryPeriodFilter.all;
  TrainingHistoryResultFilter _historyResult = TrainingHistoryResultFilter.all;
  TrainingHistoryContextFilter _historyContext =
      TrainingHistoryContextFilter.all;
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
  String? _streamActorUid;
  Stream<List<TrainingSession>>? _sessionsStream;

  @override
  void initState() {
    super.initState();
    _requestedFocusSessionId = widget.focusSessionId;
    _historySearchController.addListener(_onHistorySearchChanged);
  }

  @override
  void didUpdateWidget(covariant TrainingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusSessionId != oldWidget.focusSessionId) {
      _requestedFocusSessionId = widget.focusSessionId;
      _appliedFocusSessionId = null;
    }
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
  }

  List<TrainingSessionHistoryItem> _filteredHistoryItems(
    List<TrainingSessionHistoryItem> items,
  ) {
    final query = trainingHistoryKey(_historySearchController.text);
    final now = DateTime.now();
    return items
        .where((item) {
          if (query.isNotEmpty && !item.searchText.contains(query)) {
            return false;
          }
          if (!matchesTrainingHistoryPeriod(
            item.date,
            _historyPeriod.domainPeriod,
            now,
          )) {
            return false;
          }
          if (_historyResult != TrainingHistoryResultFilter.all &&
              item.resultBucket != _historyResult.domainBucket) {
            return false;
          }
          if (_historyContext != TrainingHistoryContextFilter.all &&
              !item.contextBuckets.contains(_historyContext.domainBucket)) {
            return false;
          }
          final position = _historyPositionFilter;
          if (position != null &&
              !item.positionKeys.contains(trainingHistoryKey(position))) {
            return false;
          }
          final technique = _historyTechniqueFilter;
          if (technique != null &&
              !item.techniqueKeys.contains(trainingHistoryKey(technique))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _scheduleFocusedSession(TrainingSessionHistoryItem item) {
    if (_appliedFocusSessionId == item.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedFocusSessionId != item.id) return;
      setState(() {
        _historyMode = TrainingJournalMode.calendar;
        _displayedHistoryMonth = _monthStart(item.date);
        _selectedHistoryDay = _dayStart(item.date);
        _selectedSessionId = item.id;
        _appliedFocusSessionId = item.id;
      });
    });
  }

  TrainingSessionHistoryItem? _requestedFocusItem(
    List<TrainingSessionHistoryItem> items,
  ) {
    final requestedId = _requestedFocusSessionId;
    if (requestedId == null || requestedId == _appliedFocusSessionId) {
      return null;
    }
    final selection = resolveTrainingHistoryFocus(
      items: items,
      focusedSessionId: requestedId,
    );
    if (selection == null) return null;
    return items.firstWhere((item) => item.id == selection.sessionId);
  }

  void _applyHistoryFilters(TrainingHistoryFilters filters) {
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
    final filters = await showModalBottomSheet<TrainingHistoryFilters>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => TrainingHistoryFilterSheet(
            initial: TrainingHistoryFilters(
              period: _historyPeriod,
              result: _historyResult,
              context: _historyContext,
              position: _historyPositionFilter,
              technique: _historyTechniqueFilter,
            ),
            positions: trainingHistoryFilterValues(
              items.expand((item) => item.positions),
            ),
            techniques: trainingHistoryFilterValues(
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
            ..write('|status:')
            ..write(session.status?.name ?? '')
            ..write('|plannedFor:')
            ..write(session.plannedFor?.microsecondsSinceEpoch ?? '')
            ..write('|effectiveDate:')
            ..write(session.effectiveDate?.microsecondsSinceEpoch ?? '')
            ..write('|confirmedAt:')
            ..write(session.confirmedAt?.microsecondsSinceEpoch ?? '')
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

  void _syncStream({
    required String academyId,
    required String uid,
    required String actorUid,
  }) {
    if (_streamAcademyId == academyId &&
        _streamUid == uid &&
        _streamActorUid == actorUid) {
      return;
    }

    _streamAcademyId = academyId;
    _streamUid = uid;
    _streamActorUid = actorUid;
    _resetHistoryForContextChange();
    _trainingDashboardCacheKey = null;
    _trainingDashboardCache = null;
    _sessionsStream = _repo.watchSessions(academyId: academyId, uid: uid);
  }

  void _clearStreamContext() {
    if (_streamAcademyId == null &&
        _streamUid == null &&
        _streamActorUid == null) {
      return;
    }
    _streamAcademyId = null;
    _streamUid = null;
    _streamActorUid = null;
    _sessionsStream = null;
    _trainingDashboardCacheKey = null;
    _trainingDashboardCache = null;
    _resetHistoryForContextChange();
  }

  void _resetHistoryForContextChange() {
    _historySearchController.removeListener(_onHistorySearchChanged);
    _historySearchController.clear();
    _historySearchController.addListener(_onHistorySearchChanged);
    _historyMode = TrainingJournalMode.calendar;
    _displayedHistoryMonth = _monthStart(DateTime.now());
    _selectedHistoryDay = null;
    _selectedSessionId = null;
    _requestedFocusSessionId = widget.focusSessionId;
    _appliedFocusSessionId = null;
    _historyPeriod = TrainingHistoryPeriodFilter.all;
    _historyResult = TrainingHistoryResultFilter.all;
    _historyContext = TrainingHistoryContextFilter.all;
    _historyPositionFilter = null;
    _historyTechniqueFilter = null;
    _visibleHistoryCount = 20;
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

    final academyId = target?.academyId;
    final uid = target?.uid;

    if (academyId == null || uid == null || actor == null) {
      _clearStreamContext();
      return _wrapModule(
        appBar: AppBar(
          leading: _mainScreenLeading(context),
          title: Text(widget.titleOverride ?? 'Treinos'),
        ),
        body: TrainingScreenUnavailableState(
          requiresSelectedStudent:
              widget.targetMode == TargetMode.selectedStudent,
        ),
      );
    }

    _syncStream(academyId: academyId, uid: uid, actorUid: actor.uid);

    return _wrapModule(
      appBar: AppBar(
        leading: _mainScreenLeading(context),
        title: Text(widget.titleOverride ?? 'Treinos'),
      ),
      floatingActionButton: null,
      body: StreamBuilder<List<TrainingSession>>(
        stream: _sessionsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const TrainingScreenLoadingState();
          }

          if (snap.hasError) {
            return TrainingScreenErrorState(error: snap.error!);
          }

          final rawSessions = snap.data ?? const <TrainingSession>[];
          final dashboard = _trainingDashboardFor(
            academyId: academyId,
            uid: uid,
            sessions: rawSessions,
            selectedPeriod: _period,
          );
          final completedSessions = dashboard.completedSessions;
          final historyItems = dashboard.historyItems;
          final filteredHistoryItems = _filteredHistoryItems(historyItems);
          final requestedFocusItem = _requestedFocusItem(historyItems);
          if (requestedFocusItem != null) {
            _scheduleFocusedSession(requestedFocusItem);
          }
          final displayedHistoryMonth =
              requestedFocusItem == null
                  ? _displayedHistoryMonth
                  : _monthStart(requestedFocusItem.date);
          final selectedHistoryDay =
              requestedFocusItem == null
                  ? _selectedHistoryDay
                  : _dayStart(requestedFocusItem.date);
          final selectedSessionId =
              requestedFocusItem?.id ?? _selectedSessionId;
          final lifecyclePrefix = '$academyId|$uid|';
          final currentLifecycleSavingIds = <String>{
            for (final key in _lifecycleUpdatingIds)
              if (key.startsWith(lifecyclePrefix))
                key.substring(lifecyclePrefix.length),
          };
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
              TrainingFrequencyHeroCard(
                chart: chart,
                chartMode: _selectedChartMode,
                onPeriodChanged: (period) => setState(() => _period = period),
                onChartModeChanged:
                    (mode) => setState(() => _selectedChartMode = mode),
              ),
              const SizedBox(height: 10),
              TrainingCompactMetricsAndActions(
                summary: summary,
                lastTrainingLabel: lastTrainingLabel,
                canAddTraining: canEditTarget,
                onQuickLog:
                    canEditTarget
                        ? () => _openQuickLog(
                          academyId: academyId,
                          uid: uid,
                          sessions: completedSessions,
                          actorUid: actor.uid,
                        )
                        : null,
                onAddTraining:
                    canEditTarget
                        ? () => _openTrainingForm(
                          academyId: academyId,
                          uid: uid,
                          initialStatus: TrainingSessionStatus.completed,
                        )
                        : null,
                onScheduleTraining:
                    canEditTarget
                        ? () => _openTrainingForm(
                          academyId: academyId,
                          uid: uid,
                          initialStatus: TrainingSessionStatus.planned,
                        )
                        : null,
              ),
              const SizedBox(height: 10),
              TrainingHistoryJournal(
                allItems: historyItems,
                filteredItems: filteredHistoryItems,
                searchController: _historySearchController,
                activeFilters: TrainingHistoryActiveFilters(
                  query: _historySearchController.text.trim(),
                  period: _historyPeriod,
                  result: _historyResult,
                  contextFilter: _historyContext,
                  positionFilter: _historyPositionFilter,
                  techniqueFilter: _historyTechniqueFilter,
                  onClearSearch: _historySearchController.clear,
                  onClearPeriod: () {
                    setState(() {
                      _historyPeriod = TrainingHistoryPeriodFilter.all;
                      _resetHistoryWindow();
                    });
                  },
                  onClearResult: () {
                    setState(() {
                      _historyResult = TrainingHistoryResultFilter.all;
                      _resetHistoryWindow();
                    });
                  },
                  onClearContext: () {
                    setState(() {
                      _historyContext = TrainingHistoryContextFilter.all;
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
                ),
                mode:
                    requestedFocusItem == null
                        ? _historyMode
                        : TrainingJournalMode.calendar,
                displayedMonth: displayedHistoryMonth,
                selectedDay: selectedHistoryDay,
                selectedSessionId: selectedSessionId,
                visibleCount: _visibleHistoryCount,
                chartPeriodCount: dashboard.periodSessions.length,
                chartPeriodLabel: TrainingChartPeriodOption.byId(_period).label,
                canEdit: canEditTarget,
                lifecycleSavingIds: currentLifecycleSavingIds,
                onModeChanged: (mode) {
                  setState(() {
                    _historyMode = mode;
                    _requestedFocusSessionId = null;
                  });
                },
                onMonthChanged: (month) {
                  setState(() {
                    _displayedHistoryMonth = _monthStart(month);
                    _selectedHistoryDay = null;
                    _selectedSessionId = null;
                    _requestedFocusSessionId = null;
                  });
                },
                onDaySelected: (day) {
                  final dayItems = historyItems
                      .where((item) => _sameHistoryDay(item.date, day))
                      .toList(growable: false);
                  setState(() {
                    _selectedHistoryDay = _dayStart(day);
                    _selectedSessionId =
                        dayItems.length == 1 ? dayItems.first.id : null;
                    _requestedFocusSessionId = null;
                  });
                },
                onSessionSelected: (item) {
                  setState(() {
                    _displayedHistoryMonth = _monthStart(item.date);
                    _selectedHistoryDay = _dayStart(item.date);
                    _selectedSessionId = item.id;
                    _requestedFocusSessionId = null;
                  });
                },
                onOpenFilters: () => _showHistoryFilters(historyItems),
                onClearSearch: _historySearchController.clear,
                onLoadMore: () {
                  setState(() => _visibleHistoryCount += 20);
                },
                onEdit:
                    canEditTarget
                        ? (item) {
                          final session = item.session;
                          debugPrint(
                            '[TRAINING_EDIT_OPEN] actor.uid=${actor.uid} '
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
                onConfirm:
                    canEditTarget
                        ? (item) => _updateLifecycle(
                          academyId: academyId,
                          uid: uid,
                          session: item.session,
                          status: TrainingSessionStatus.completed,
                          successMessage: 'Treino confirmado como realizado.',
                        )
                        : null,
                onMarkMissed:
                    canEditTarget
                        ? (item) => _updateLifecycle(
                          academyId: academyId,
                          uid: uid,
                          session: item.session,
                          status: TrainingSessionStatus.missed,
                          successMessage: 'Treino marcado como não realizado.',
                        )
                        : null,
                onCancel:
                    canEditTarget
                        ? (item) => _updateLifecycle(
                          academyId: academyId,
                          uid: uid,
                          session: item.session,
                          status: TrainingSessionStatus.canceled,
                          successMessage: 'Treino cancelado.',
                        )
                        : null,
                onAddTraining:
                    canEditTarget
                        ? () => _openTrainingForm(
                          academyId: academyId,
                          uid: uid,
                          initialStatus: TrainingSessionStatus.completed,
                        )
                        : null,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget? _mainScreenLeading(BuildContext context) {
    if (widget.embedded || Navigator.of(context).canPop()) return null;
    return const AppLogoLeading();
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

  Future<void> _openQuickLog({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
    required String actorUid,
  }) async {
    final operationContext = TrainingOperationContext(
      actorUid: actorUid,
      academyId: academyId,
      targetUid: uid,
    );
    final savedResult = await showQuickLogSheet(
      context: context,
      academyId: academyId,
      uid: uid,
      recentSessions: sessions,
      canSave: true,
      onOpenFullForm: () => _openTrainingForm(academyId: academyId, uid: uid),
    );
    if (!mounted ||
        savedResult == null ||
        !_isTrainingContextCurrent(operationContext)) {
      return;
    }

    final savedSession = savedResult.session;
    _focusTraining(savedSession.id);
    showTrainingSaveConfirmation(
      context: context,
      session: savedSession,
      kind: TrainingSaveConfirmationKind.created,
      visibleDetails: quickLogConfirmationDetails(savedResult),
      onViewTraining: () {
        if (_isTrainingContextCurrent(operationContext)) {
          _focusTraining(savedSession.id);
        }
      },
    );
  }

  Future<void> _openTrainingForm({
    required String academyId,
    required String uid,
    TrainingSession? session,
    TrainingSessionStatus initialStatus = TrainingSessionStatus.completed,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AddTrainingSessionScreen(
              academyId: academyId,
              uid: uid,
              session: session,
              initialStatus: initialStatus,
            ),
      ),
    );
  }

  Future<void> _updateLifecycle({
    required String academyId,
    required String uid,
    required TrainingSession session,
    required TrainingSessionStatus status,
    required String successMessage,
  }) async {
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    if (actor == null) return;
    final operationContext = TrainingOperationContext(
      actorUid: actor.uid,
      academyId: academyId,
      targetUid: uid,
    );
    final operationKey = operationContext.sessionKey(session.id);
    if (_lifecycleUpdatingIds.contains(operationKey)) return;
    if (status == TrainingSessionStatus.completed &&
        session.effectiveStatus() == TrainingSessionStatus.completed) {
      return;
    }
    if (status == TrainingSessionStatus.completed &&
        !session.isAwaitingConfirmation()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este treino ainda nao pode ser confirmado.'),
        ),
      );
      return;
    }

    setState(() => _lifecycleUpdatingIds.add(operationKey));
    try {
      final effectiveDate =
          status == TrainingSessionStatus.completed
              ? DateTime(
                session.date.year,
                session.date.month,
                session.date.day,
              )
              : null;
      await _repo.updateSessionLifecycle(
        academyId: academyId,
        uid: uid,
        sessionId: session.id,
        status: status,
        effectiveDate: effectiveDate,
      );
      if (!mounted || !_isTrainingContextCurrent(operationContext)) return;
      if (status == TrainingSessionStatus.completed) {
        final confirmedSession = session.copyWith(
          status: TrainingSessionStatus.completed,
          effectiveDate: effectiveDate,
        );
        _focusTraining(session.id);
        showTrainingSaveConfirmation(
          context: context,
          session: confirmedSession,
          kind: TrainingSaveConfirmationKind.plannedSessionConfirmed,
          onViewTraining: () {
            if (_isTrainingContextCurrent(operationContext)) {
              _focusTraining(session.id);
            }
          },
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted || !_isTrainingContextCurrent(operationContext)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar treino: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _lifecycleUpdatingIds.remove(operationKey));
      }
    }
  }

  void _focusTraining(String sessionId) {
    setState(() {
      _historyMode = TrainingJournalMode.calendar;
      _requestedFocusSessionId = sessionId;
      _appliedFocusSessionId = null;
    });
  }

  bool _isTrainingContextCurrent(TrainingOperationContext operationContext) {
    if (!mounted) return false;
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    final target = TargetResolver.maybeOf(
      context,
      mode: widget.targetMode,
      explicitTarget: widget.explicitTarget,
    );
    return operationContext.matches(
      actorUid: actor?.uid,
      academyId: target?.academyId,
      targetUid: target?.uid,
    );
  }
}

DateTime _dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

bool _sameHistoryDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
