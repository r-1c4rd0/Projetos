import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/progress/application/progress_use_cases.dart';
import '../features/progress/domain/progress_models.dart';
import '../main.dart';
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

part '../widgets/progress/progress_overview_sections.dart';
part '../widgets/progress/progress_visualizations.dart';
part '../widgets/progress/progress_screen_sections.dart';

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

  String? _progressCacheKey;
  _ProgressViewModel? _progressCache;

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
    _progressCacheKey = null;
    _progressCache = null;
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

    final academyId = target?.academyId;
    final uid = target?.uid;

    if (academyId == null || uid == null) {
      return _wrapModule(
        appBar: AppBar(
          leading: _mainScreenLeading(context),
          title: Text(widget.titleOverride ?? 'Progresso'),
        ),
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

    return _wrapModule(
      appBar: AppBar(
        leading: _mainScreenLeading(context),
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

                              final viewModel = _buildProgressViewModel(
                                academyId: academyId,
                                uid: uid,
                                rules: rules,
                                athlete: athlete,
                                profile: profile,
                                sessions:
                                    trainSnap.data ?? const <TrainingSession>[],
                                period: _period,
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
                                  ProgressScreenContent(
                                    beltProgress: viewModel.beltProgress,
                                    metrics: viewModel.metrics,
                                    series: viewModel.series,
                                    heatmap: viewModel.heatmap,
                                    totalInWindow: viewModel.totalInWindow,
                                    period: _period,
                                    periodTitle: _titleForPeriod(_period),
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

  _ProgressViewModel _buildProgressViewModel({
    required String academyId,
    required String uid,
    required GradingRules rules,
    required AppUser athlete,
    required UserProgressProfile profile,
    required List<TrainingSession> sessions,
    required ProgressPeriod period,
  }) {
    final cacheKey = _progressCacheSnapshotKey(
      academyId: academyId,
      uid: uid,
      rules: rules,
      athlete: athlete,
      profile: profile,
      sessions: sessions,
      period: period,
    );
    final cached = _progressCache;
    if (_progressCacheKey == cacheKey && cached != null) {
      return cached;
    }

    final filtered = _prepareProgressSessions(sessions, rules: rules);
    final metrics = _getProgressOverview(filtered);
    final beltProgress = _getBeltProgressSummary(
      rules: rules,
      athlete: athlete,
      profile: profile,
      sessions: filtered,
    );
    final series = _getProgressSeries(filtered, period);
    final heatmap = _getConsistencyHeatmap(filtered);
    final totalInWindow = series.values.fold<int>(0, (a, b) => a + b);

    final viewModel = _ProgressViewModel(
      metrics: metrics,
      beltProgress: beltProgress,
      series: series,
      heatmap: heatmap,
      totalInWindow: totalInWindow,
    );
    _progressCacheKey = cacheKey;
    _progressCache = viewModel;
    return viewModel;
  }

  String _progressCacheSnapshotKey({
    required String academyId,
    required String uid,
    required GradingRules rules,
    required AppUser athlete,
    required UserProgressProfile profile,
    required List<TrainingSession> sessions,
    required ProgressPeriod period,
  }) {
    final buffer =
        StringBuffer()
          ..write(academyId)
          ..write('|')
          ..write(uid)
          ..write('|')
          ..write(period.name)
          ..write('|')
          ..write(rules.hashCode)
          ..write('|')
          ..write(athlete.belt.index)
          ..write('|')
          ..write(athlete.degree)
          ..write('|')
          ..write(profile.beltStartAt.microsecondsSinceEpoch)
          ..write('|')
          ..write(profile.estimatedSessionsInBelt ?? 0)
          ..write('|')
          ..write(sessions.length);

    for (final session in sessions) {
      buffer
        ..write('|s:')
        ..write(session.id)
        ..write('@')
        ..write(session.date.microsecondsSinceEpoch);
    }

    return buffer.toString();
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

class _ProgressViewModel {
  final TrainingMetrics metrics;
  final BeltProgressSummary beltProgress;
  final ProgressSeriesSummary series;
  final ConsistencyHeatmapSummary heatmap;
  final int totalInWindow;

  const _ProgressViewModel({
    required this.metrics,
    required this.beltProgress,
    required this.series,
    required this.heatmap,
    required this.totalInWindow,
  });
}
