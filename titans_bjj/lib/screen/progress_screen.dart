import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/progress/application/progress_use_cases.dart';
import '../features/progress/domain/progress_models.dart';
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
import '../service/training_aggregator.dart' show TrainingMetrics;
import '../widgets/titans_belt_status_card.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import '../widgets/glass_card.dart';

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

  late final PrepareProgressSessions _prepareProgressSessions =
      const PrepareProgressSessions();
  late final GetProgressOverview _getProgressOverview =
      const GetProgressOverview();
  late final GetBeltProgressSummary _getBeltProgressSummary =
      const GetBeltProgressSummary();
  late final GetProgressSeries _getProgressSeries = const GetProgressSeries();
  late final GetConsistencyHeatmap _getConsistencyHeatmap =
      const GetConsistencyHeatmap();

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

                              final filtered = _prepareProgressSessions(
                                trainSnap.data ?? const <TrainingSession>[],
                                rules: rules,
                              );
                              final metrics = _getProgressOverview(filtered);
                              final beltProgress = _BeltProgress.fromSummary(
                                _getBeltProgressSummary(
                                  rules: rules,
                                  athlete: athlete,
                                  profile: profile,
                                  sessions: filtered,
                                ),
                              );
                              final series = _Series.fromSummary(
                                _getProgressSeries(filtered, _period),
                              );
                              final totalInWindow = series.values.fold<int>(
                                0,
                                (a, b) => a + b,
                              );
                              final heatmap =
                                  _ConsistencyHeatmapViewModel.fromSummary(
                                    _getConsistencyHeatmap(filtered),
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
                                  _ProgressBeltHero(
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
                                  const SizedBox(height: 10),
                                  _ProgressCompactMetrics(
                                    progress: beltProgress,
                                    metrics: metrics,
                                    totalInWindow: totalInWindow,
                                    periodTitle: _titleForPeriod(_period),
                                  ),
                                  const SizedBox(height: 10),
                                  _ProgressVisualPanel(
                                    heatmap: heatmap,
                                    series: series,
                                    totalInWindow: totalInWindow,
                                    period: _period,
                                    periodTitle: _titleForPeriod(_period),
                                  ),
                                  const SizedBox(height: 10),
                                  _ProgressDetailsSection(
                                    metrics: metrics,
                                    totalInWindow: totalInWindow,
                                    periodTitle: _titleForPeriod(_period),
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
                          beltSelectionOrder
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

  String _titleForPeriod(ProgressPeriod p) {
    switch (p) {
      case ProgressPeriod.day:
        return '\u00daltimos 14 dias';
      case ProgressPeriod.month:
        return '\u00daltimos 12 meses';
      case ProgressPeriod.year:
        return '\u00daltimos 5 anos';
    }
  }
}

class _BeltProgressCard extends StatelessWidget {
  final _BeltProgress progress;

  const _BeltProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pctText = '${(progress.percentToNextBelt * 100).toStringAsFixed(0)}%';
    final sessionLabel =
        progress.hasOfficialRule
            ? '${progress.sessionsInCurrentBelt}/${progress.sessionsRequiredCurrentBelt} sess\u00f5es na faixa atual'
            : '${progress.sessionsInCurrentBelt} treinos registrados nesta faixa';

    return TitansBeltStatusCard(
      belt: progress.belt,
      degree: progress.degree,
      maxDegree: progress.maxDegree,
      progressPercent: progress.percentToNextBelt,
      progressValueLabel: pctText,
      subtitle:
          '$sessionLabel\nBaseado em sess\u00f5es registradas nesta faixa.',
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
              'Cada n\u00famero mostra um escopo temporal diferente.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansCompactMetricGrid(
              fourColumnMinWidth: 560,
              children: [
                TitansCompactMetricCard(
                  label: 'Total da carreira',
                  value: metrics.total.toString(),
                ),
                TitansCompactMetricCard(
                  label: 'Este m\u00eas',
                  value: metrics.month.toString(),
                ),
                TitansCompactMetricCard(
                  label: 'Este ano',
                  value: metrics.year.toString(),
                ),
                TitansCompactMetricCard(
                  label: '\u00daltimos 30 dias',
                  value: metrics.recent.toString(),
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
            TitansCompactMetricGrid(
              fourColumnMinWidth: 420,
              children: [
                TitansCompactMetricCard(
                  label: 'Regularidade 30 dias',
                  value: recentPercent,
                  color: cs.secondary,
                ),
                TitansCompactMetricCard(
                  label: 'Treinos nos 30 dias',
                  value: metrics.recent.toString(),
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Frequ\u00eancia recente \u00e9 um subconjunto dos \u00faltimos 30 dias, separado do total da carreira.',
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
              'Consist\u00eancia usa apenas o recorte selecionado no filtro.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TitansCompactMetricGrid(
              fourColumnMinWidth: 420,
              children: [
                TitansCompactMetricCard(
                  label: 'Treinos no recorte',
                  value: totalInWindow.toString(),
                  color: cs.primary,
                ),
                TitansCompactMetricCard(
                  label: 'Recorte',
                  value: title,
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
                  'Recorte: $totalInWindow',
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
          'Sess\u00f5es registradas dentro do recorte selecionado. O gr\u00e1fico mostra regularidade, n\u00e3o gradua\u00e7\u00e3o.',
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

class _ProgressAreaChart extends StatefulWidget {
  final _ProgressChartViewModel viewModel;

  const _ProgressAreaChart({required this.viewModel});

  @override
  State<_ProgressAreaChart> createState() => _ProgressAreaChartState();
}

class _ProgressAreaChartState extends State<_ProgressAreaChart> {
  static const _motion = TitansMotionSpec.emphasis();
  bool _entrancePlayed = false;
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _ProgressAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pointsLength = widget.viewModel.points.length;
    final selectedIndex = _selectedIndex;
    if (selectedIndex != null && selectedIndex >= pointsLength) {
      _selectedIndex = pointsLength <= 0 ? null : pointsLength - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero) {
      return _buildChart(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _entrancePlayed ? 1 : 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () {
        _entrancePlayed = true;
      },
      builder: (context, progress, child) {
        return _buildChart(context, progress.clamp(0.0, 1.0).toDouble());
      },
    );
  }

  Widget _buildChart(BuildContext context, double revealProgress) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;

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
        final animatedSpots = _animatedSpots(spots, revealProgress);
        final currentIndex =
            viewModel.points.isEmpty ? null : viewModel.points.length - 1;
        final selectedIndex = _selectedIndex;
        final barData = _lineBarData(
          context,
          viewModel,
          animatedSpots,
          compact: compact,
          currentIndex: currentIndex,
          selectedIndex: selectedIndex,
        );

        return RepaintBoundary(
          child: SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineTouchData: _touchData(
                  context,
                  viewModel,
                  onPointSelected: _selectPoint,
                ),
                showingTooltipIndicators: _tooltipIndicators(
                  barData,
                  selectedIndex,
                ),
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
                lineBarsData: [barData],
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
          ),
        );
      },
    );
  }

  void _selectPoint(int index) {
    if (index < 0 || index >= widget.viewModel.points.length) return;
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  static LineChartBarData _lineBarData(
    BuildContext context,
    _ProgressChartViewModel viewModel,
    List<FlSpot> spots, {
    required bool compact,
    required int? currentIndex,
    required int? selectedIndex,
  }) {
    final cs = Theme.of(context).colorScheme;

    return LineChartBarData(
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
          return index == selectedIndex ||
              index == currentIndex ||
              viewModel.points[index].isHighlighted ||
              viewModel.points.length <= 7;
        },
        getDotPainter: (spot, percent, barData, index) {
          final selected = index == selectedIndex;
          final current = index == currentIndex;
          final highlighted =
              index >= 0 &&
              index < viewModel.points.length &&
              viewModel.points[index].isHighlighted;
          final color =
              selected
                  ? cs.tertiary
                  : highlighted || current
                  ? cs.secondary
                  : cs.primary;
          return FlDotCirclePainter(
            radius:
                selected
                    ? 5.4
                    : highlighted || current
                    ? 4.6
                    : 3.2,
            color: color,
            strokeWidth: selected ? 2.4 : 2,
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
    );
  }

  static LineTouchData _touchData(
    BuildContext context,
    _ProgressChartViewModel viewModel, {
    required ValueChanged<int> onPointSelected,
  }) {
    final cs = Theme.of(context).colorScheme;

    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchSpotThreshold: 18,
      touchCallback: (event, response) {
        if (!event.isInterestedForInteractions) return;
        final spots = response?.lineBarSpots;
        if (spots == null || spots.isEmpty) return;
        onPointSelected(spots.first.spotIndex);
      },
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

  static List<ShowingTooltipIndicators> _tooltipIndicators(
    LineChartBarData barData,
    int? selectedIndex,
  ) {
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= barData.spots.length) {
      return const [];
    }
    return [
      ShowingTooltipIndicators([
        LineBarSpot(barData, 0, barData.spots[selectedIndex]),
      ]),
    ];
  }

  static List<FlSpot> _animatedSpots(List<FlSpot> spots, double progress) {
    return spots.map((spot) => FlSpot(spot.x, spot.y * progress)).toList();
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

class _ConsistencyHeatmapGrid extends StatefulWidget {
  final _ConsistencyHeatmapViewModel viewModel;

  const _ConsistencyHeatmapGrid({required this.viewModel});

  @override
  State<_ConsistencyHeatmapGrid> createState() =>
      _ConsistencyHeatmapGridState();
}

class _ConsistencyHeatmapGridState extends State<_ConsistencyHeatmapGrid> {
  static final _motion = TitansMotionSpec.emphasis();

  bool _entrancePlayed = false;
  _ConsistencyHeatmapDay? _selectedDay;

  @override
  void didUpdateWidget(covariant _ConsistencyHeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedDay;
    if (selected == null) return;

    final stillExists = widget.viewModel.weeks.any(
      (week) => week.days.any((day) => _isSameDay(day.date, selected.date)),
    );
    if (!stillExists) _selectedDay = null;
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    if (duration == Duration.zero || _entrancePlayed) {
      return _buildGrid(context, 1);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: TitansMotion.curve(_motion),
      onEnd: () => _entrancePlayed = true,
      builder: (context, progress, _) => _buildGrid(context, progress),
    );
  }

  Widget _buildGrid(BuildContext context, double revealProgress) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = widget.viewModel;
    final totalCells = viewModel.weeks.fold<int>(
      0,
      (total, week) => total + week.days.length,
    );
    final progress = revealProgress.clamp(0.0, 1.0).toDouble();

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

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            weekIndex: weekIndex,
                            totalCells: totalCells,
                            revealProgress: progress,
                            selectedDay: _selectedDay,
                            onDaySelected: _selectDay,
                            cellSize: cellSize,
                            compact: compact,
                            showLabel: _showHeatmapWeekLabel(weekIndex),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_selectedDay != null) ...[
                const SizedBox(height: 10),
                _ConsistencyHeatmapSelection(day: _selectedDay!),
              ],
            ],
          ),
        );
      },
    );
  }

  void _selectDay(_ConsistencyHeatmapDay day) {
    final selected = _selectedDay;
    if (selected != null && _isSameDay(selected.date, day.date)) return;
    setState(() => _selectedDay = day);
  }

  static bool _showHeatmapWeekLabel(int index) {
    return index == 0 || index == 11 || index % 3 == 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ConsistencyHeatmapWeekColumn extends StatelessWidget {
  final _ConsistencyHeatmapWeek week;
  final int weekIndex;
  final int totalCells;
  final double revealProgress;
  final _ConsistencyHeatmapDay? selectedDay;
  final ValueChanged<_ConsistencyHeatmapDay> onDaySelected;
  final double cellSize;
  final bool compact;
  final bool showLabel;

  const _ConsistencyHeatmapWeekColumn({
    required this.week,
    required this.weekIndex,
    required this.totalCells,
    required this.revealProgress,
    required this.selectedDay,
    required this.onDaySelected,
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
          for (var dayIndex = 0; dayIndex < week.days.length; dayIndex++)
            _ConsistencyHeatmapCell(
              day: week.days[dayIndex],
              size: cellSize,
              animationProgress: _cellProgress(
                (weekIndex * 7) + dayIndex,
                totalCells,
                revealProgress,
              ),
              isSelected: _isSelected(week.days[dayIndex]),
              onTap: () => onDaySelected(week.days[dayIndex]),
            ),
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

  bool _isSelected(_ConsistencyHeatmapDay day) {
    final selected = selectedDay;
    if (selected == null) return false;
    return selected.date.year == day.date.year &&
        selected.date.month == day.date.month &&
        selected.date.day == day.date.day;
  }

  double _cellProgress(int index, int total, double reveal) {
    if (total <= 1 || reveal >= 1) return 1;
    final start = (index / total).clamp(0.0, 1.0) * 0.42;
    final local = ((reveal - start) / (1 - start)).clamp(0.0, 1.0).toDouble();
    return Curves.easeOutCubic.transform(local);
  }
}

class _ConsistencyHeatmapCell extends StatelessWidget {
  final _ConsistencyHeatmapDay day;
  final double size;
  final double animationProgress;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConsistencyHeatmapCell({
    required this.day,
    required this.size,
    required this.animationProgress,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _cellColor(cs, day.intensityLevel);
    final borderColor =
        isSelected
            ? cs.primary.withValues(alpha: 0.92)
            : day.isToday
            ? cs.secondary.withValues(alpha: 0.86)
            : cs.onSurface.withValues(alpha: day.isOutsideRange ? 0.05 : 0.08);
    final opacity =
        (0.36 + (animationProgress * 0.64)).clamp(0.0, 1.0).toDouble();
    final scale =
        (0.72 + (animationProgress * 0.28)).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${day.dayLabel}, ${day.tooltipTitle}: ${day.tooltipBody}',
        value: day.count.toString(),
        hint: _semanticDate(day.date),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || day.isToday ? 1.5 : 1,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.18),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static Color _cellColor(ColorScheme cs, int intensity) {
    switch (intensity) {
      case 0:
        return cs.surfaceContainerHighest.withValues(alpha: 0.20);
      case 1:
        return cs.primary.withValues(alpha: 0.28);
      case 2:
        return cs.primary.withValues(alpha: 0.52);
      case 3:
        return cs.primary.withValues(alpha: 0.76);
      default:
        return cs.primary;
    }
  }
}

class _ConsistencyHeatmapSelection extends StatelessWidget {
  final _ConsistencyHeatmapDay day;

  const _ConsistencyHeatmapSelection({required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _ConsistencyHeatmapCell._cellColor(cs, day.intensityLevel),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color:
                    day.isToday
                        ? cs.secondary.withValues(alpha: 0.86)
                        : cs.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.tooltipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.tooltipBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (day.isToday) ...[
            const SizedBox(width: 8),
            Text(
              'Hoje',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
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
    return TitansStatusChip(label: label, color: color, compact: true);
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

class _ProgressBeltHero extends StatelessWidget {
  final _BeltProgress progress;
  final VoidCallback? onEditGraduation;

  const _ProgressBeltHero({required this.progress, this.onEditGraduation});

  @override
  Widget build(BuildContext context) {
    final beltKey = progress.belt.name.toLowerCase();
    final beltColor = TitansUI.beltColor(beltKey);
    final beltLabel = TitansUI.beltLabel(beltKey);
    final percent = progress.percentToNextBelt.clamp(0.0, 1.0).toDouble();
    final pctText = '${(percent * 100).toStringAsFixed(0)}%';
    final sessionLabel =
        '${progress.sessionsInCurrentBelt} de ${progress.sessionsRequiredCurrentBelt} sessões';

    return glassCard(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return _ProgressBeltHeroIntegrated(
            beltLabel: beltLabel,
            degree: progress.degree,
            maxDegree: progress.maxDegree,
            sessionLabel: sessionLabel,
            hasOfficialRule: progress.hasOfficialRule,
            percent: percent,
            pctText: pctText,
            beltColor: beltColor,
            onEditGraduation: onEditGraduation,
            compact: compact,
          );
        },
      ),
      accent: beltColor.withValues(alpha: 0.32),
    );
  }
}

class _ProgressBeltHeroIntegrated extends StatelessWidget {
  final String beltLabel;
  final int degree;
  final int maxDegree;
  final String sessionLabel;
  final bool hasOfficialRule;
  final double percent;
  final String pctText;
  final Color beltColor;
  final VoidCallback? onEditGraduation;
  final bool compact;

  const _ProgressBeltHeroIntegrated({
    required this.beltLabel,
    required this.degree,
    required this.maxDegree,
    required this.sessionLabel,
    required this.hasOfficialRule,
    required this.percent,
    required this.pctText,
    required this.beltColor,
    required this.onEditGraduation,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final degreeText = degree > 0 ? '$degreeº grau' : 'Grau inicial';
    final ringSize = compact ? 128.0 : 142.0;
    final innerSize = ringSize - 28;

    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: compact ? 8 : 9,
                backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(beltColor),
              ),
            ),
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: beltColor.withValues(alpha: 0.11),
                border: Border.all(color: beltColor.withValues(alpha: 0.28)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    beltLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: beltColor,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pctText,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'na faixa',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.54),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ProgressHeroChip(label: degreeText, color: beltColor),
            _ProgressHeroChip(label: sessionLabel, color: cs.primary),
            _ProgressDegreeDots(degree: degree, maxDegree: maxDegree),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          hasOfficialRule
              ? 'Evolução baseada nos treinos registrados nesta faixa.'
              : 'Referência de graduação infantil pendente. Acompanhe a evolução com o professor.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.66),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(TitansUI.radiusPill),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 5,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(beltColor),
          ),
        ),
        if (onEditGraduation != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEditGraduation,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar graduação'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressHeroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ProgressHeroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.78),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProgressDegreeDots extends StatelessWidget {
  final int degree;
  final int maxDegree;

  const _ProgressDegreeDots({required this.degree, required this.maxDegree});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = maxDegree <= 0 ? 4 : maxDegree;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i < degree
                      ? TitansUI.actionGold
                      : cs.onSurface.withValues(alpha: 0.16),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ProgressCompactMetrics extends StatelessWidget {
  final _BeltProgress progress;
  final TrainingMetrics metrics;
  final int totalInWindow;
  final String periodTitle;

  const _ProgressCompactMetrics({
    required this.progress,
    required this.metrics,
    required this.totalInWindow,
    required this.periodTitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = TitansUI.beltColor(progress.belt.name.toLowerCase());
    final recentPercent =
        '${(metrics.recentFrequency * 100).toStringAsFixed(0)}%';

    return glassCard(
      context,
      TitansCompactMetricGrid(
        fourColumnMinWidth: 560,
        spacing: TitansUI.spaceXs,
        children: [
          TitansCompactMetricCard(
            label: 'NA FAIXA',
            value: progress.sessionsInCurrentBelt.toString(),
            subtitle:
                progress.hasOfficialRule
                    ? '/${progress.sessionsRequiredCurrentBelt}'
                    : 'registrados',
            color: beltColor,
          ),
          TitansCompactMetricCard(
            label: 'CONSISTÊNCIA',
            value: recentPercent,
            subtitle: '30 dias',
            color: cs.secondary,
          ),
          TitansCompactMetricCard(
            label: 'ÚLTIMO RECORTE',
            value: totalInWindow.toString(),
            subtitle: periodTitle,
            color: cs.primary,
          ),
          TitansCompactMetricCard(
            label: 'CARREIRA',
            value: metrics.total.toString(),
            subtitle: 'total',
            color: cs.onSurface.withValues(alpha: 0.70),
          ),
        ],
      ),
    );
  }
}

class _ProgressVisualPanel extends StatelessWidget {
  final _ConsistencyHeatmapViewModel heatmap;
  final _Series series;
  final int totalInWindow;
  final ProgressPeriod period;
  final String periodTitle;

  const _ProgressVisualPanel({
    required this.heatmap,
    required this.series,
    required this.totalInWindow,
    required this.period,
    required this.periodTitle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ConsistencyHeatmapCard(viewModel: heatmap),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _ConsistencyChartCard(
                      title: periodTitle,
                      totalInWindow: totalInWindow,
                      period: period,
                      labels: series.labels,
                      values: series.values,
                    ),
                  ),
                ],
              )
            else ...[
              _ConsistencyHeatmapCard(viewModel: heatmap),
              const SizedBox(height: 12),
              _ConsistencyChartCard(
                title: periodTitle,
                totalInWindow: totalInWindow,
                period: period,
                labels: series.labels,
                values: series.values,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProgressDetailsSection extends StatefulWidget {
  final TrainingMetrics metrics;
  final int totalInWindow;
  final String periodTitle;

  const _ProgressDetailsSection({
    required this.metrics,
    required this.totalInWindow,
    required this.periodTitle,
  });

  @override
  State<_ProgressDetailsSection> createState() =>
      _ProgressDetailsSectionState();
}

class _ProgressDetailsSectionState extends State<_ProgressDetailsSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalhes e métricas complementares',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _expanded
                                ? 'Toque para recolher'
                                : 'Toque para expandir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TitansUI.spaceSm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: SizeTransition(
              sizeFactor: _heightFactor,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConsistencySummaryCard(
                      title: widget.periodTitle,
                      totalInWindow: widget.totalInWindow,
                    ),
                    const SizedBox(height: 12),
                    _TrainingMetricsCard(metrics: widget.metrics),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  factory _ConsistencyHeatmapViewModel.fromSummary(
    ConsistencyHeatmapSummary summary,
  ) {
    return _ConsistencyHeatmapViewModel(
      title: summary.title,
      subtitle: summary.subtitle,
      weeks: summary.weeks.map(_ConsistencyHeatmapWeek.fromSummary).toList(),
      weekdayLabels: summary.weekdayLabels,
      legendItems:
          summary.legendItems
              .map(_ConsistencyHeatmapLegendItem.fromSummary)
              .toList(),
      totalTrainingDays: summary.totalTrainingDays,
      emptyStateLabel: summary.emptyStateLabel,
    );
  }
}

class _ConsistencyHeatmapWeek {
  final String label;
  final List<_ConsistencyHeatmapDay> days;

  const _ConsistencyHeatmapWeek({required this.label, required this.days});

  factory _ConsistencyHeatmapWeek.fromSummary(
    ConsistencyHeatmapWeekSummary summary,
  ) {
    return _ConsistencyHeatmapWeek(
      label: summary.label,
      days: summary.days.map(_ConsistencyHeatmapDay.fromSummary).toList(),
    );
  }
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

  factory _ConsistencyHeatmapDay.fromSummary(
    ConsistencyHeatmapDaySummary summary,
  ) {
    return _ConsistencyHeatmapDay(
      date: summary.date,
      dayLabel: summary.dayLabel,
      count: summary.count,
      intensityLevel: summary.intensityLevel,
      tooltipTitle: summary.tooltipTitle,
      tooltipBody: summary.tooltipBody,
      isToday: summary.isToday,
      isOutsideRange: summary.isOutsideRange,
    );
  }
}

class _ConsistencyHeatmapLegendItem {
  final String label;
  final int intensityLevel;

  const _ConsistencyHeatmapLegendItem({
    required this.label,
    required this.intensityLevel,
  });

  factory _ConsistencyHeatmapLegendItem.fromSummary(
    ConsistencyHeatmapLegendSummary summary,
  ) {
    return _ConsistencyHeatmapLegendItem(
      label: summary.label,
      intensityLevel: summary.intensityLevel,
    );
  }
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

  factory _Series.fromSummary(ProgressSeriesSummary summary) {
    return _Series(labels: summary.labels, values: summary.values);
  }
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;
  final int sessionsInCurrentBelt;
  final int sessionsRequiredCurrentBelt;
  final bool hasOfficialRule;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
    required this.sessionsInCurrentBelt,
    required this.sessionsRequiredCurrentBelt,
    required this.hasOfficialRule,
  });

  factory _BeltProgress.fromSummary(BeltProgressSummary summary) {
    return _BeltProgress(
      belt: summary.belt,
      degree: summary.degree,
      maxDegree: summary.maxDegree,
      percentToNextBelt: summary.percentToNextBelt,
      sessionsInCurrentBelt: summary.sessionsInCurrentBelt,
      sessionsRequiredCurrentBelt: summary.sessionsRequiredCurrentBelt,
      hasOfficialRule: summary.hasOfficialRule,
    );
  }
}
