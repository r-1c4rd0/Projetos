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
                                  ),
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
  final List<String> labels;
  final List<int> values;

  const _ConsistencyChartCard({
    required this.title,
    required this.totalInWindow,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = values.any((value) => value > 0);
    final trendLabel = _trendLabel(values);

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
                    'Consist\u00eancia de treinos',
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
              'Sess\u00f5es registradas por per\u00edodo. Use este gr\u00e1fico para acompanhar regularidade, n\u00e3o gradua\u00e7\u00e3o.',
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
                _ChartChip(label: title, color: cs.primary),
                _ChartChip(label: trendLabel, color: cs.secondary),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              _ChartEmptyState(colorScheme: cs)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = constraints.maxWidth;
                  final compact = chartWidth < 390;
                  final chartHeight = compact ? 190.0 : 220.0;
                  final maxY = _maxY(values);
                  final leftInterval = _leftInterval(maxY);
                  final bottomInterval = _bottomInterval(
                    labels.length,
                    chartWidth,
                  );
                  final spots = _spots(values);

                  return SizedBox(
                    height: chartHeight,
                    width: double.infinity,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: leftInterval,
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
                                if (v < 0 || v > maxY) {
                                  return const SizedBox.shrink();
                                }
                                if (v != v.roundToDouble()) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  v.toInt().toString(),
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.62),
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
                                    idx >= labels.length ||
                                    !_showBottomLabel(
                                      idx,
                                      labels.length,
                                      bottomInterval,
                                    )) {
                                  return const SizedBox.shrink();
                                }

                                final text = labels[idx];
                                final rotate = compact || text.length >= 6;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: rotate ? -0.68 : 0,
                                    child: Text(
                                      text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cs.onSurface.withValues(
                                          alpha: 0.62,
                                        ),
                                        fontSize: compact ? 9 : 10,
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
                            barWidth: compact ? 2.8 : 3.5,
                            color: cs.primary,
                            dotData: FlDotData(show: values.length <= 7),
                            belowBarData: BarAreaData(
                              show: true,
                              color: cs.primary.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static List<FlSpot> _spots(List<int> values) {
    return values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
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
    if (len <= 6) return 1;
    if (width < 390) return len > 10 ? 4 : 2;
    if (width < 430) return len > 10 ? 3 : 2;
    if (len <= 14) return 2;
    return 3;
  }

  static bool _showBottomLabel(int index, int len, double interval) {
    if (index == 0 || index == len - 1) return true;
    return index % interval.toInt() == 0;
  }

  static String _trendLabel(List<int> values) {
    final nonEmpty = values.where((value) => value > 0).toList();
    if (nonEmpty.isEmpty) return 'Sem registros no per\u00edodo';
    if (values.length < 2) return 'Tend\u00eancia inicial';

    final midpoint = values.length ~/ 2;
    final firstHalf = values
        .take(midpoint)
        .fold<int>(0, (sum, value) => sum + value);
    final secondHalf = values
        .skip(midpoint)
        .fold<int>(0, (sum, value) => sum + value);

    if (secondHalf > firstHalf) return 'Tend\u00eancia em alta';
    if (secondHalf < firstHalf) return 'Tend\u00eancia em queda';
    return 'Tend\u00eancia est\u00e1vel';
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

  const _ChartEmptyState({required this.colorScheme});

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
