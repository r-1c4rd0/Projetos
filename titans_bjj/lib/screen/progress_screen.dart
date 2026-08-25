import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/grading_rules.dart';
import '../model/app_user.dart';
import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/training_repository.dart';
import '../repository/user_repository.dart';
import '../repository/user_progress_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../service/training_aggregator.dart';
import '../widgets/titans_belt_status_card.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

class ProgressScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;
  final bool embedded;

  const ProgressScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
    this.embedded = false,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressPeriod _period = ProgressPeriod.month;

  late final TrainingRepository _trainingRepo = TrainingRepository.instance;

  late final GradingRulesRepository _rulesRepo =
      GradingRulesRepository.instance;

  late final UserProgressRepository _progressRepo =
      UserProgressRepository.instance;

  late final UserRepository _userRepo = UserRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<GradingRules?>? _rulesStream;
  Stream<AppUser?>? _athleteStream;
  Stream<UserProgressProfile?>? _profileStream;
  Stream<List<TrainingSession>>? _sessionsStream;

  bool _ensuringRules = false;
  Object? _ensureError;

  TargetProfile? _resolveTarget(BuildContext context) {
    return widget.explicitTarget ??
        TargetResolver.maybeOf(context, mode: widget.targetMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ensuringRules) return;

    final target = _resolveTarget(context);
    final academyId = target?.academyId;

    if (academyId == null) return;

    _ensuringRules = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _rulesRepo.ensureDefault(academyId);
        _ensureError = null;
      } catch (e) {
        _ensureError = e;
      } finally {
        if (mounted) setState(() => _ensuringRules = false);
      }
    });
  }

  void _syncStreams({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
    _rulesStream = _rulesRepo.watch(academyId);
    _athleteStream = _userRepo.watchUser(academyId: academyId, uid: uid);
    _profileStream = _progressRepo.watchProfile(academyId: academyId, uid: uid);
    _sessionsStream = _trainingRepo.watchSessions(
      academyId: academyId,
      uid: uid,
    );
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
      '[PROGRESS_TARGET] screen=ProgressScreen '
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
        '[PROGRESS_ACTIONS] showEditGraduation=false canEditTarget=$canEditTarget '
        'hiddenBy=missing-target-or-academy-or-uid actor.uid=${actor?.uid} '
        'actor.role=${actor?.role} target.uid=${target?.uid} '
        'target.academyId=${target?.academyId}',
      );

      return _wrapModule(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Progresso')),
        body:
            widget.targetMode == TargetMode.selectedStudent
                ? const TitansStateView.noStudent(
                  message:
                      'Selecione um aluno no Painel do Mestre para acessar Progresso.',
                )
                : const TitansStateView.error(
                  title: 'Perfil n\u00e3o carregado',
                  message:
                      'N\u00e3o foi poss\u00edvel identificar seu usu\u00e1rio para carregar Progresso.',
                ),
      );
    }

    _syncStreams(academyId: academyId, uid: uid);

    debugPrint(
      '[PROGRESS_ACTIONS] showEditGraduation=$canEditTarget '
      "canEditTarget=$canEditTarget hiddenBy=${canEditTarget ? 'none' : 'canEditTarget=false'} "
      'actor.uid=${actor?.uid} actor.role=${actor?.role} '
      'target.uid=$uid target.academyId=$academyId',
    );

    return _wrapModule(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Progresso'),
        actions: [
          PopupMenuButton<ProgressPeriod>(
            initialValue: _period,
            onSelected: (p) => setState(() => _period = p),
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: ProgressPeriod.day, child: Text('Dia')),
                  PopupMenuItem(
                    value: ProgressPeriod.month,
                    child: Text('M\u00eas'),
                  ),
                  PopupMenuItem(value: ProgressPeriod.year, child: Text('Ano')),
                ],
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body:
          _ensureError != null
              ? _ErrorState(
                title: 'Erro ao configurar regras',
                message: _ensureError.toString(),
              )
              : StreamBuilder<GradingRules?>(
                stream: _rulesStream,
                builder: (context, rulesSnap) {
                  if (_ensuringRules &&
                      rulesSnap.connectionState == ConnectionState.waiting) {
                    return const TitansSkeletonCard(lines: 4);
                  }

                  if (rulesSnap.hasError) {
                    return _ErrorState(
                      title: 'Erro ao carregar regras',
                      message: rulesSnap.error.toString(),
                    );
                  }

                  final rules = rulesSnap.data;
                  if (rules == null) {
                    return const _EmptyState(
                      title: 'Regras da academia n\u00e3o configuradas.',
                      subtitle:
                          'N\u00e3o foi poss\u00edvel ler academies/{academyId}/grading_rules/default.',
                    );
                  }

                  return StreamBuilder<AppUser?>(
                    stream: _athleteStream,
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const TitansSkeletonCard(lines: 4);
                      }

                      if (userSnap.hasError) {
                        return _ErrorState(
                          title: 'Erro ao carregar atleta',
                          message: userSnap.error.toString(),
                        );
                      }

                      final athlete = userSnap.data;
                      if (athlete == null) {
                        return const _EmptyState(
                          title: 'Atleta n\u00e3o encontrado.',
                          subtitle:
                              'Crie academies/{academyId}/users/{uid} com faixa e grau.',
                        );
                      }

                      return StreamBuilder<UserProgressProfile?>(
                        stream: _profileStream,
                        builder: (context, profileSnap) {
                          if (profileSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: TitansSkeletonCard(
                                lines: 3,
                                showHeader: false,
                              ),
                            );
                          }

                          if (profileSnap.hasError) {
                            return _ErrorState(
                              title: 'Erro ao carregar perfil de progresso',
                              message: profileSnap.error.toString(),
                            );
                          }

                          final profile = profileSnap.data;
                          if (profile == null) {
                            return const _EmptyState(
                              title: 'Perfil de progresso n\u00e3o encontrado.',
                              subtitle:
                                  'Crie o perfil de progresso com data de in\u00edcio da faixa e estimativa de sess\u00f5es.',
                            );
                          }

                          return StreamBuilder<List<TrainingSession>>(
                            stream: _sessionsStream,
                            builder: (context, trainSnap) {
                              if (trainSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: TitansSkeletonCard(
                                    lines: 3,
                                    showHeader: false,
                                  ),
                                );
                              }

                              if (trainSnap.hasError) {
                                return _ErrorState(
                                  title: 'Erro ao carregar treinos',
                                  message: trainSnap.error.toString(),
                                );
                              }

                              final sessions =
                                  TrainingAggregator.uniqueSessions(
                                    List<TrainingSession>.from(
                                      trainSnap.data ??
                                          const <TrainingSession>[],
                                    ),
                                  );

                              final filtered =
                                  rules.onlyAcademyPlace
                                      ? sessions
                                          .where(
                                            (s) =>
                                                s.place ==
                                                TrainingPlace.academy,
                                          )
                                          .toList()
                                      : List<TrainingSession>.from(sessions);

                              filtered.sort((a, b) => a.date.compareTo(b.date));

                              final metrics = TrainingAggregator.metrics(
                                filtered,
                              );

                              final beltProgress = _calcBeltProgress(
                                rules: rules,
                                athlete: athlete,
                                profile: profile,
                                sessions: filtered,
                              );

                              final series = _buildSeries(filtered, _period);
                              final totalInWindow = series.values.fold<int>(
                                0,
                                (a, b) => a + b,
                              );
                              final heatmap = _buildHeatmap(filtered);

                              final listPadding =
                                  widget.embedded
                                      ? TitansUI.listPadding(
                                        context,
                                        extra: TitansUI.spaceMd,
                                      )
                                      : TitansUI.listPadding(context);

                              return ListView(
                                padding: listPadding,
                                children: [
                                  if (widget.embedded)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: PopupMenuButton<ProgressPeriod>(
                                        tooltip: 'Filtrar periodo',
                                        initialValue: _period,
                                        onSelected:
                                            (p) => setState(() => _period = p),
                                        itemBuilder:
                                            (_) => const [
                                              PopupMenuItem(
                                                value: ProgressPeriod.day,
                                                child: Text('Dia'),
                                              ),
                                              PopupMenuItem(
                                                value: ProgressPeriod.month,
                                                child: Text('M\u00eas'),
                                              ),
                                              PopupMenuItem(
                                                value: ProgressPeriod.year,
                                                child: Text('Ano'),
                                              ),
                                            ],
                                        icon: const Icon(
                                          Icons.filter_alt_outlined,
                                        ),
                                      ),
                                    ),
                                  _BeltProgressCard(
                                    progress: beltProgress,
                                    onEditGraduation:
                                        canEditTarget
                                            ? () => _showGraduationDialog(
                                              academyId: academyId,
                                              uid: uid,
                                              athlete: athlete,
                                              rules: rules,
                                            )
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _TrainingMetricsCard(metrics: metrics),
                                  const SizedBox(height: 12),
                                  _ConsistencySummaryCard(
                                    title: _titleForPeriod(_period),
                                    totalInWindow: totalInWindow,
                                  ),
                                  const SizedBox(height: 12),
                                  _ConsistencyChartCard(
                                    title: _titleForPeriod(_period),
                                    totalInWindow: totalInWindow,
                                    labels: series.labels,
                                    values: series.values,
                                    period: _period,
                                  ),
                                  const SizedBox(height: 12),
                                  _ConsistencyHeatmapCard(viewModel: heatmap),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
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
    final isStaff =
        loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return isStaff && loggedUser.academyId == target.academyId;
  }

  Future<void> _showGraduationDialog({
    required String academyId,
    required String uid,
    required AppUser athlete,
    required GradingRules rules,
  }) async {
    var selectedBelt = athlete.belt;
    var selectedDegree =
        athlete.degree.clamp(0, rules.maxDegrees(selectedBelt)).toInt();
    var saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDegree = rules.maxDegrees(selectedBelt);
            final degreeItems = List.generate(
              maxDegree + 1,
              (index) =>
                  DropdownMenuItem(value: index, child: Text(index.toString())),
            );

            return AlertDialog(
              title: const Text('Editar gradua\u00e7\u00e3o'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<BeltColor>(
                      initialValue: selectedBelt,
                      decoration: const InputDecoration(
                        labelText: 'Faixa',
                        prefixIcon: Icon(Icons.horizontal_rule),
                      ),
                      items:
                          BeltColor.values
                              .map(
                                (belt) => DropdownMenuItem(
                                  value: belt,
                                  child: Text(_BeltProgressCard.beltName(belt)),
                                ),
                              )
                              .toList(),
                      onChanged:
                          saving
                              ? null
                              : (belt) {
                                if (belt == null) return;
                                setDialogState(() {
                                  selectedBelt = belt;
                                  selectedDegree =
                                      selectedDegree
                                          .clamp(0, rules.maxDegrees(belt))
                                          .toInt();
                                });
                              },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('${selectedBelt.name}-$selectedDegree'),
                      initialValue: selectedDegree,
                      decoration: const InputDecoration(
                        labelText: 'Grau',
                        prefixIcon: Icon(Icons.star_outline),
                      ),
                      items: degreeItems,
                      onChanged:
                          saving
                              ? null
                              : (degree) {
                                if (degree == null) return;
                                setDialogState(() => selectedDegree = degree);
                              },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            setDialogState(() {
                              saving = true;
                              errorMessage = null;
                            });
                            try {
                              final clampedDegree =
                                  selectedDegree
                                      .clamp(0, rules.maxDegrees(selectedBelt))
                                      .toInt();
                              await _userRepo.updateBeltDegree(
                                academyId: academyId,
                                uid: uid,
                                belt: selectedBelt,
                                degree: clampedDegree,
                              );
                              if (!mounted) return;
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Gradua\u00e7\u00e3o atualizada.',
                                  ),
                                ),
                              );
                            } catch (error) {
                              setDialogState(() {
                                saving = false;
                                errorMessage =
                                    'N\u00e3o foi poss\u00edvel salvar. $error';
                              });
                            }
                          },
                  icon:
                      saving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Salvando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _BeltProgress _calcBeltProgress({
    required GradingRules rules,
    required AppUser athlete,
    required UserProgressProfile profile,
    required List<TrainingSession> sessions,
  }) {
    // TODO migration: currentBelt/currentDegree in progress/profile are legacy
    // cache fields. Graduation is canonical in academies/{academyId}/users/{uid}.
    final belt = athlete.belt;
    final maxDeg = rules.maxDegrees(belt).clamp(1, 12).toInt();

    final beltStart = profile.beltStartAt;
    final sessionsInBelt =
        sessions.where((s) => !s.date.isBefore(beltStart)).length;

    final degree = athlete.degree.clamp(0, maxDeg).toInt();

    final estimated = profile.estimatedSessionsInBelt;
    final requiredByRules = rules.requiredSessions(belt);
    final safeFallback = sessionsInBelt > 0 ? sessionsInBelt : maxDeg;
    final sessionsRequired =
        (estimated != null && estimated > 0)
            ? estimated
            : (requiredByRules > 0 ? requiredByRules : safeFallback)
                .clamp(1, 1 << 30)
                .toInt();

    final percent =
        (sessionsInBelt / sessionsRequired).clamp(0.0, 1.0).toDouble();

    return _BeltProgress(
      belt: belt,
      degree: degree,
      maxDegree: maxDeg,
      percentToNextBelt: percent,
      sessionsInCurrentBelt: sessionsInBelt,
      sessionsRequiredCurrentBelt: sessionsRequired,
    );
  }

  _Series _buildSeries(List<TrainingSession> sessions, ProgressPeriod period) {
    final now = DateTime.now();
    final map = <String, int>{};
    final labels = <String>[];

    if (period == ProgressPeriod.day) {
      for (int i = 13; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final label =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        labels.add(label);
        map[label] = 0;
      }
    } else if (period == ProgressPeriod.month) {
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final label = '${d.month.toString().padLeft(2, '0')}/${d.year}';
        labels.add(label);
        map[label] = 0;
      }
    } else {
      for (int i = 4; i >= 0; i--) {
        final label = (now.year - i).toString();
        labels.add(label);
        map[label] = 0;
      }
    }

    for (final s in sessions) {
      final d = s.date;

      final key = switch (period) {
        ProgressPeriod.day =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
        ProgressPeriod.month =>
          '${d.month.toString().padLeft(2, '0')}/${d.year}',
        ProgressPeriod.year => d.year.toString(),
      };

      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    return _Series(
      labels: labels,
      values: labels.map((l) => map[l] ?? 0).toList(),
    );
  }

  _ConsistencyHeatmapViewModel _buildHeatmap(List<TrainingSession> sessions) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 83));
    final countsByDay = <String, int>{};

    for (final session in sessions) {
      final day = _dateOnly(session.date);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      final key = _heatmapDateKey(day);
      countsByDay[key] = (countsByDay[key] ?? 0) + 1;
    }

    final weeks = <_ConsistencyHeatmapWeek>[];
    for (var weekIndex = 0; weekIndex < 12; weekIndex++) {
      final days = <_ConsistencyHeatmapDay>[];
      final weekStart = start.add(Duration(days: weekIndex * 7));

      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        final date = weekStart.add(Duration(days: dayIndex));
        final count = countsByDay[_heatmapDateKey(date)] ?? 0;
        final level = count >= 3 ? 3 : count;
        final dateLabel = _shortDateLabel(date);
        final countLabel = _heatmapCountLabel(count);

        days.add(
          _ConsistencyHeatmapDay(
            date: date,
            dayLabel: _weekdayLabel(date.weekday),
            count: count,
            intensityLevel: level,
            tooltipTitle: _dateOnly(date) == today ? 'Hoje' : dateLabel,
            tooltipBody: countLabel,
            isToday: _dateOnly(date) == today,
            isOutsideRange: false,
          ),
        );
      }

      weeks.add(
        _ConsistencyHeatmapWeek(label: _shortDateLabel(weekStart), days: days),
      );
    }

    final totalTrainingDays =
        countsByDay.values.where((count) => count > 0).length;

    return _ConsistencyHeatmapViewModel(
      title: 'Consist\u00eancia di\u00e1ria',
      subtitle: 'Treinos registrados nos \u00faltimos 84 dias.',
      weeks: weeks,
      weekdayLabels: weeks.first.days.map((day) => day.dayLabel).toList(),
      legendItems: const [
        _ConsistencyHeatmapLegendItem(label: '0', intensityLevel: 0),
        _ConsistencyHeatmapLegendItem(label: '1', intensityLevel: 1),
        _ConsistencyHeatmapLegendItem(label: '2', intensityLevel: 2),
        _ConsistencyHeatmapLegendItem(label: '3+', intensityLevel: 3),
      ],
      totalTrainingDays: totalTrainingDays,
      emptyStateLabel: 'Sem treino registrado nos \u00faltimos 84 dias.',
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _heatmapDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _shortDateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  static String _weekdayLabel(int weekday) {
    const labels = <int, String>{
      DateTime.monday: 'S',
      DateTime.tuesday: 'T',
      DateTime.wednesday: 'Q',
      DateTime.thursday: 'Q',
      DateTime.friday: 'S',
      DateTime.saturday: 'S',
      DateTime.sunday: 'D',
    };
    return labels[weekday] ?? '';
  }

  static String _heatmapCountLabel(int count) {
    if (count <= 0) return 'Sem treino registrado';
    if (count == 1) return '1 treino registrado';
    if (count == 2) return '2 treinos registrados';
    return '3+ treinos registrados';
  }

  String _titleForPeriod(ProgressPeriod p) {
    switch (p) {
      case ProgressPeriod.day:
        return 'Consist\u00eancia (14 dias)';
      case ProgressPeriod.month:
        return 'Consist\u00eancia (12 meses)';
      case ProgressPeriod.year:
        return 'Consist\u00eancia (5 anos)';
    }
  }
}

class _BeltProgressCard extends StatelessWidget {
  final _BeltProgress progress;
  final VoidCallback? onEditGraduation;

  const _BeltProgressCard({required this.progress, this.onEditGraduation});

  @override
  Widget build(BuildContext context) {
    final pctText = '${(progress.percentToNextBelt * 100).toStringAsFixed(0)}%';
    final sessionLabel =
        '${progress.sessionsInCurrentBelt}/${progress.sessionsRequiredCurrentBelt} sess\u00f5es na faixa atual';

    return TitansBeltStatusCard(
      belt: progress.belt,
      degree: progress.degree,
      maxDegree: progress.maxDegree,
      progressPercent: progress.percentToNextBelt,
      progressValueLabel: pctText,
      subtitle:
          '$sessionLabel\nBaseado em sess\u00f5es registradas nesta faixa.',
      onEdit: onEditGraduation,
    );
  }

  static String beltName(BeltColor belt) => TitansBeltStatusCard.beltName(belt);
}

class _TrainingMetricsCard extends StatelessWidget {
  final TrainingMetrics metrics;

  const _TrainingMetricsCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recentPercent =
        '${(metrics.recentFrequency * 100).toStringAsFixed(0)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volume de treino',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Volume mostra quantidade de treinos registrados.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansResponsiveGrid(
              minItemWidth: 128,
              spacing: 8,
              runSpacing: 8,
              children: [
                TitansMetricCard(
                  label: 'Total',
                  value: metrics.total.toString(),
                  icon: Icons.fitness_center_outlined,
                ),
                TitansMetricCard(
                  label: 'M\u00eas',
                  value: metrics.month.toString(),
                  icon: Icons.calendar_month_outlined,
                ),
                TitansMetricCard(
                  label: 'Ano',
                  value: metrics.year.toString(),
                  icon: Icons.event_available_outlined,
                ),
                TitansMetricCard(
                  label: '\u00daltimos 30 dias',
                  value: metrics.recent.toString(),
                  icon: Icons.history_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Frequ\u00eancia recente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            TitansResponsiveGrid(
              minItemWidth: 180,
              spacing: 8,
              runSpacing: 8,
              children: [
                TitansMetricCard(
                  label: 'Regularidade',
                  value: recentPercent,
                  icon: Icons.timeline_outlined,
                  color: cs.secondary,
                ),
                TitansMetricCard(
                  label: 'Sess\u00f5es',
                  value: metrics.recent.toString(),
                  icon: Icons.check_circle_outline,
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Frequ\u00eancia recente considera os \u00faltimos 30 dias.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsistencySummaryCard extends StatelessWidget {
  final String title;
  final int totalInWindow;

  const _ConsistencySummaryCard({
    required this.title,
    required this.totalInWindow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consist\u00eancia',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Consist\u00eancia mede regularidade, n\u00e3o gradua\u00e7\u00e3o.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansResponsiveGrid(
              minItemWidth: 160,
              spacing: 8,
              runSpacing: 8,
              children: [
                TitansMetricCard(
                  label: 'Treinos',
                  value: totalInWindow.toString(),
                  icon: Icons.insights_outlined,
                  color: cs.primary,
                ),
                TitansMetricCard(
                  label: 'Recorte',
                  value: title,
                  icon: Icons.stacked_line_chart_outlined,
                  color: cs.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsistencyChartCard extends StatelessWidget {
  final String title;
  final int totalInWindow;
  final ProgressPeriod period;
  final List<String> labels;
  final List<int> values;

  const _ConsistencyChartCard({
    required this.title,
    required this.totalInWindow,
    required this.period,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = _buildViewModel();
    final hasData = viewModel.points.any((point) => point.value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    viewModel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Total: $totalInWindow',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.subtitle,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChartChip(label: viewModel.periodLabel, color: cs.primary),
                _ChartChip(label: viewModel.trendLabel, color: cs.secondary),
                if (viewModel.averageLine != null)
                  _ChartChip(
                    label:
                        'M\u00e9dia ${viewModel.averageLine!.toStringAsFixed(1)}',
                    color: cs.tertiary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              _ChartEmptyState(
                colorScheme: cs,
                message: viewModel.emptyStateLabel,
              )
            else
              _ProgressAreaChart(viewModel: viewModel),
          ],
        ),
      ),
    );
  }

  _ProgressChartViewModel _buildViewModel() {
    final points = <_ProgressChartPoint>[
      for (var index = 0; index < labels.length; index++) _buildPoint(index),
    ];

    final maxValue = points.fold<int>(0, (max, point) {
      return point.value > max ? point.value : max;
    });
    final highlightedIndex = points.lastIndexWhere(
      (point) => point.value == maxValue && point.value > 0,
    );
    final highlightedPoints = <_ProgressChartPoint>[
      for (var index = 0; index < points.length; index++)
        points[index].copyWith(isHighlighted: index == highlightedIndex),
    ];
    final hasData = points.any((point) => point.value > 0);
    final average =
        !hasData || points.isEmpty
            ? null
            : points.fold<int>(0, (sum, point) => sum + point.value) /
                points.length;

    return _ProgressChartViewModel(
      title: 'Regularidade de treino',
      subtitle:
          'Sess\u00f5es registradas por per\u00edodo. Use este gr\u00e1fico para acompanhar regularidade, n\u00e3o gradua\u00e7\u00e3o.',
      periodLabel: title,
      points: highlightedPoints,
      averageLine: average,
      trendLabel: _activityLabel(values),
      emptyStateLabel:
          'Registre treinos para visualizar sua regularidade no per\u00edodo selecionado.',
    );
  }

  _ProgressChartPoint _buildPoint(int index) {
    final date = _dateForPoint(index);
    final value = index < values.length ? values[index] : 0;

    return _ProgressChartPoint(
      label: labels[index],
      value: value,
      tooltipTitle: _tooltipTitle(date),
      tooltipBody: _sessionTooltip(value),
      isHighlighted: false,
    );
  }

  DateTime _dateForPoint(int index) {
    final now = DateTime.now();
    switch (period) {
      case ProgressPeriod.day:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: labels.length - 1 - index));
      case ProgressPeriod.month:
        return DateTime(now.year, now.month - (labels.length - 1 - index), 1);
      case ProgressPeriod.year:
        return DateTime(now.year - (labels.length - 1 - index), 1, 1);
    }
  }

  String _tooltipTitle(DateTime date) {
    switch (period) {
      case ProgressPeriod.day:
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      case ProgressPeriod.month:
        return '${date.month.toString().padLeft(2, '0')}/${date.year}';
      case ProgressPeriod.year:
        return date.year.toString();
    }
  }

  static String _sessionTooltip(int count) {
    return count == 1
        ? '1 sess\u00e3o registrada'
        : '$count sess\u00f5es registradas';
  }

  static String _activityLabel(List<int> values) {
    final activePeriods = values.where((value) => value > 0).length;
    if (activePeriods == 0) return 'Sem registros no per\u00edodo';
    if (activePeriods == 1) return '1 per\u00edodo com treino';
    return '$activePeriods per\u00edodos com treino';
  }
}

class _ProgressAreaChart extends StatelessWidget {
  final _ProgressChartViewModel viewModel;

  const _ProgressAreaChart({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final compact = chartWidth < 390;
        final chartHeight = compact ? 200.0 : 232.0;
        final values = viewModel.points.map((point) => point.value).toList();
        final maxY = _maxY(values);
        final leftInterval = _leftInterval(maxY);
        final bottomInterval = _bottomInterval(
          viewModel.points.length,
          chartWidth,
        );
        final spots = _spots(viewModel.points);

        return SizedBox(
          height: chartHeight,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineTouchData: _touchData(context, viewModel),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: leftInterval,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: cs.onSurface.withValues(alpha: 0.08),
                      strokeWidth: 1,
                    ),
              ),
              borderData: FlBorderData(show: false),
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
                    reservedSize: compact ? 24 : 30,
                    interval: leftInterval,
                    getTitlesWidget: (v, _) {
                      if (v < 0 || v > maxY) return const SizedBox.shrink();
                      if (v != v.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.58),
                          fontSize: compact ? 10 : 11,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: compact ? 42 : 38,
                    interval: bottomInterval,
                    getTitlesWidget: (v, _) {
                      final idx = v.round();
                      if (v != idx.toDouble() ||
                          idx < 0 ||
                          idx >= viewModel.points.length ||
                          !_showBottomLabel(
                            idx,
                            viewModel.points.length,
                            bottomInterval,
                          )) {
                        return const SizedBox.shrink();
                      }

                      final text = viewModel.points[idx].label;
                      final rotate = compact || text.length >= 6;

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Transform.rotate(
                          angle: rotate ? -0.68 : 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 54),
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.58),
                                fontSize: compact ? 9 : 10,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  barWidth: compact ? 2.8 : 3.5,
                  color: cs.primary,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) {
                      final index = spot.x.round();
                      if (index < 0 || index >= viewModel.points.length) {
                        return false;
                      }
                      return viewModel.points[index].isHighlighted ||
                          viewModel.points.length <= 7;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      final highlighted =
                          index >= 0 &&
                          index < viewModel.points.length &&
                          viewModel.points[index].isHighlighted;
                      return FlDotCirclePainter(
                        radius: highlighted ? 4.6 : 3.2,
                        color: highlighted ? cs.secondary : cs.primary,
                        strokeWidth: 2,
                        strokeColor: cs.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.primary.withValues(alpha: 0.24),
                        cs.primary.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
              ],
              extraLinesData:
                  viewModel.averageLine == null
                      ? null
                      : ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: viewModel.averageLine!.clamp(0, maxY),
                            color: cs.secondary.withValues(alpha: 0.42),
                            strokeWidth: 1,
                            dashArray: [6, 4],
                          ),
                        ],
                      ),
            ),
          ),
        );
      },
    );
  }

  static LineTouchData _touchData(
    BuildContext context,
    _ProgressChartViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;

    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchSpotThreshold: 18,
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        maxContentWidth: 160,
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tooltipMargin: 10,
        tooltipBorder: BorderSide(color: cs.primary.withValues(alpha: 0.28)),
        getTooltipColor:
            (_) => cs.surfaceContainerHighest.withValues(alpha: 0.96),
        getTooltipItems: (spots) {
          return spots.map((spot) {
            final index = spot.x.round();
            if (index < 0 || index >= viewModel.points.length) return null;
            final point = viewModel.points[index];
            return LineTooltipItem(
              '${point.tooltipTitle}\n',
              TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              textAlign: TextAlign.left,
              children: [
                TextSpan(
                  text: point.tooltipBody,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.76),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  static List<FlSpot> _spots(List<_ProgressChartPoint> points) {
    return points
        .asMap()
        .entries
        .map(
          (entry) => FlSpot(entry.key.toDouble(), entry.value.value.toDouble()),
        )
        .toList();
  }

  static double _maxY(List<int> values) {
    if (values.isEmpty) return 4;
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final padded = maxValue + 1;
    return padded < 4 ? 4 : padded;
  }

  static double _leftInterval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    return 10;
  }

  static double _bottomInterval(int len, double width) {
    if (len <= 5) return 1;
    if (width < 390) return len > 10 ? 4 : 2;
    if (width < 430) return len > 10 ? 3 : 2;
    if (len <= 14) return 2;
    return 3;
  }

  static bool _showBottomLabel(int index, int len, double interval) {
    if (index == 0 || index == len - 1) return true;
    return index % interval.toInt() == 0;
  }
}

class _ConsistencyHeatmapCard extends StatelessWidget {
  final _ConsistencyHeatmapViewModel viewModel;

  const _ConsistencyHeatmapCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = viewModel.totalTrainingDays > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    viewModel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                if (hasData)
                  Text(
                    '${viewModel.totalTrainingDays} dias',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _ConsistencyHeatmapGrid(viewModel: viewModel),
            const SizedBox(height: 12),
            _ConsistencyHeatmapLegend(items: viewModel.legendItems),
            if (!hasData) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.emptyStateLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsistencyHeatmapGrid extends StatelessWidget {
  final _ConsistencyHeatmapViewModel viewModel;

  const _ConsistencyHeatmapGrid({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const weekCount = 12;
        final compact = constraints.maxWidth < 390;
        final labelWidth = compact ? 16.0 : 20.0;
        final gap = compact ? 3.0 : 4.0;
        final availableWidth = constraints.maxWidth - labelWidth - gap;
        final rawCellSize =
            (availableWidth - (gap * (weekCount - 1))) / weekCount;
        final cellSize = rawCellSize.clamp(10.0, 20.0).toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: EdgeInsets.only(top: compact ? 0 : 1),
                child: Column(
                  children: [
                    for (final label in viewModel.weekdayLabels)
                      SizedBox(
                        height: cellSize,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.46),
                              fontSize: compact ? 8 : 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var weekIndex = 0;
                    weekIndex < viewModel.weeks.length;
                    weekIndex++
                  )
                    _ConsistencyHeatmapWeekColumn(
                      week: viewModel.weeks[weekIndex],
                      cellSize: cellSize,
                      compact: compact,
                      showLabel: _showHeatmapWeekLabel(weekIndex),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _showHeatmapWeekLabel(int index) {
    return index == 0 || index == 11 || index % 3 == 0;
  }
}

class _ConsistencyHeatmapWeekColumn extends StatelessWidget {
  final _ConsistencyHeatmapWeek week;
  final double cellSize;
  final bool compact;
  final bool showLabel;

  const _ConsistencyHeatmapWeekColumn({
    required this.week,
    required this.cellSize,
    required this.compact,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: cellSize,
      child: Column(
        children: [
          for (final day in week.days)
            _ConsistencyHeatmapCell(day: day, size: cellSize),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: Text(
              showLabel ? week.label : '',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.40),
                fontSize: compact ? 7 : 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyHeatmapCell extends StatelessWidget {
  final _ConsistencyHeatmapDay day;
  final double size;

  const _ConsistencyHeatmapCell({required this.day, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _cellColor(cs, day.intensityLevel);
    final borderColor =
        day.isToday
            ? cs.secondary.withValues(alpha: 0.86)
            : cs.onSurface.withValues(alpha: day.isOutsideRange ? 0.05 : 0.08);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: '${day.tooltipTitle}\n${day.tooltipBody}',
        child: Semantics(
          label: '${day.dayLabel}, ${day.tooltipTitle}: ${day.tooltipBody}',
          value: day.count.toString(),
          hint: _semanticDate(day.date),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: borderColor,
                width: day.isToday ? 1.5 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Color _cellColor(ColorScheme cs, int level) {
    switch (level) {
      case 1:
        return cs.primary.withValues(alpha: 0.34);
      case 2:
        return cs.primary.withValues(alpha: 0.56);
      case 3:
        return cs.secondary.withValues(alpha: 0.78);
      default:
        return cs.surfaceContainerHighest.withValues(alpha: 0.26);
    }
  }
}

class _ConsistencyHeatmapLegend extends StatelessWidget {
  final List<_ConsistencyHeatmapLegendItem> items;

  const _ConsistencyHeatmapLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Treinos por dia',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConsistencyHeatmapLegendDot(level: item.intensityLevel),
              const SizedBox(width: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ConsistencyHeatmapLegendDot extends StatelessWidget {
  final int level;

  const _ConsistencyHeatmapLegendDot({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _ConsistencyHeatmapCell._cellColor(cs, level),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _ChartChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.82),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  final String? message;

  const _ChartEmptyState({required this.colorScheme, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_outlined, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            message ??
                'Registre treinos para visualizar sua consist\u00eancia.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'O gr\u00e1fico aparece quando houver sess\u00f5es no per\u00edodo selecionado.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TitansEmptyState(
          icon: Icons.insights_outlined,
          title: title,
          message: subtitle,
          compact: true,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsistencyHeatmapViewModel {
  final String title;
  final String subtitle;
  final List<_ConsistencyHeatmapWeek> weeks;
  final List<String> weekdayLabels;
  final List<_ConsistencyHeatmapLegendItem> legendItems;
  final int totalTrainingDays;
  final String emptyStateLabel;

  const _ConsistencyHeatmapViewModel({
    required this.title,
    required this.subtitle,
    required this.weeks,
    required this.weekdayLabels,
    required this.legendItems,
    required this.totalTrainingDays,
    required this.emptyStateLabel,
  });
}

class _ConsistencyHeatmapWeek {
  final String label;
  final List<_ConsistencyHeatmapDay> days;

  const _ConsistencyHeatmapWeek({required this.label, required this.days});
}

class _ConsistencyHeatmapDay {
  final DateTime date;
  final String dayLabel;
  final int count;
  final int intensityLevel;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isToday;
  final bool isOutsideRange;

  const _ConsistencyHeatmapDay({
    required this.date,
    required this.dayLabel,
    required this.count,
    required this.intensityLevel,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isToday,
    required this.isOutsideRange,
  });
}

class _ConsistencyHeatmapLegendItem {
  final String label;
  final int intensityLevel;

  const _ConsistencyHeatmapLegendItem({
    required this.label,
    required this.intensityLevel,
  });
}

class _ProgressChartViewModel {
  final String title;
  final String subtitle;
  final String periodLabel;
  final List<_ProgressChartPoint> points;
  final double? averageLine;
  final String trendLabel;
  final String emptyStateLabel;

  const _ProgressChartViewModel({
    required this.title,
    required this.subtitle,
    required this.periodLabel,
    required this.points,
    required this.averageLine,
    required this.trendLabel,
    required this.emptyStateLabel,
  });
}

class _ProgressChartPoint {
  final String label;
  final int value;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isHighlighted;

  const _ProgressChartPoint({
    required this.label,
    required this.value,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isHighlighted,
  });

  _ProgressChartPoint copyWith({bool? isHighlighted}) {
    return _ProgressChartPoint(
      label: label,
      value: value,
      tooltipTitle: tooltipTitle,
      tooltipBody: tooltipBody,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }
}

class _Series {
  final List<String> labels;
  final List<int> values;
  _Series({required this.labels, required this.values});
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;
  final int sessionsInCurrentBelt;
  final int sessionsRequiredCurrentBelt;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
    required this.sessionsInCurrentBelt,
    required this.sessionsRequiredCurrentBelt,
  });
}
