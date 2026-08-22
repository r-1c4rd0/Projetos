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
import '../widgets/titans_scaffold.dart';

class ProgressScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;

  const ProgressScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
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
    final resolverTarget =
        TargetResolver.maybeOf(context, mode: widget.targetMode);
    final target = widget.explicitTarget ?? resolverTarget;
    final canEditTarget = target != null &&
        _canEditTarget(loggedUser: actor, target: target);
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

      return TitansScaffold(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Progresso')),
        body: widget.targetMode == TargetMode.selectedStudent
            ? const TitansStateView.noStudent(
                message: 'Selecione um aluno no Painel do Mestre para acessar Progresso.',
              )
            : const TitansStateView.error(
                title: 'Perfil nao carregado',
                message:
                    'Nao foi possivel identificar seu usuario para carregar Progresso.',
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

    return TitansScaffold(
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
                    child: Text('Mês'),
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
                    return const TitansStateView.loading();
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
                      title: 'Regras da academia não configuradas.',
                      subtitle:
                          'Não foi possível ler academies/{academyId}/grading_rules/default.',
                    );
                  }

                  return StreamBuilder<AppUser?>(
                    stream: _athleteStream,
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const TitansStateView.loading();
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
                          title: 'Atleta não encontrado.',
                          subtitle:
                              'Crie academies/{academyId}/users/{uid} com belt e degree.',
                        );
                      }

                      return StreamBuilder<UserProgressProfile?>(
                        stream: _profileStream,
                        builder: (context, profileSnap) {
                          if (profileSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
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
                              title: 'Perfil de progresso não encontrado.',
                              subtitle:
                                  'Crie academies/{academyId}/users/{uid}/progress/profile (beltStartAt, estimatedSessionsInBelt).',
                            );
                          }

                          return StreamBuilder<List<TrainingSession>>(
                            stream: _sessionsStream,
                            builder: (context, trainSnap) {
                              if (trainSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (trainSnap.hasError) {
                                return _ErrorState(
                                  title: 'Erro ao carregar treinos',
                                  message: trainSnap.error.toString(),
                                );
                              }

                              final sessions = TrainingAggregator.uniqueSessions(
                                List<TrainingSession>.from(
                                  trainSnap.data ?? const <TrainingSession>[],
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

                              filtered.sort(
                                (a, b) => a.date.compareTo(b.date),
                              );

                              final metrics = TrainingAggregator.metrics(filtered);

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

                              final listPadding = TitansUI.listPadding(context);

                              return ListView(
                                padding: listPadding,
                                children: [
                                  _BeltProgressCard(
                                    progress: beltProgress,
                                    onEditGraduation: canEditTarget
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

  bool _canEditTarget({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    if (loggedUser == null) return false;
    final canManage = loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return loggedUser.academyId == target.academyId &&
        (loggedUser.uid == target.uid || canManage);
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
              title: const Text('Editar graduacao'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<BeltColor>(
                    initialValue: selectedBelt,
                    decoration: const InputDecoration(
                      labelText: 'Faixa',
                      prefixIcon: Icon(Icons.horizontal_rule),
                    ),
                    items: BeltColor.values
                        .map(
                          (belt) => DropdownMenuItem(
                            value: belt,
                            child: Text(_BeltProgressCard.beltName(belt)),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (belt) {
                            if (belt == null) return;
                            setDialogState(() {
                              selectedBelt = belt;
                              selectedDegree = selectedDegree
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
                    onChanged: saving
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
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          final messenger = ScaffoldMessenger.of(this.context);
                          setDialogState(() {
                            saving = true;
                            errorMessage = null;
                          });
                          try {
                            final clampedDegree = selectedDegree
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
                                content: Text('Graduacao atualizada.'),
                              ),
                            );
                          } catch (error) {
                            setDialogState(() {
                              saving = false;
                              errorMessage =
                                  'Nao foi possivel salvar. $error';
                            });
                          }
                        },
                  icon: saving
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

    final percent = (sessionsInBelt / sessionsRequired).clamp(0.0, 1.0).toDouble();

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
        return 'Consistência (14 dias)';
      case ProgressPeriod.month:
        return 'Consistência (12 meses)';
      case ProgressPeriod.year:
        return 'Consistência (5 anos)';
    }
  }
}

class _BeltProgressCard extends StatelessWidget {
  final _BeltProgress progress;
  final VoidCallback? onEditGraduation;

  const _BeltProgressCard({
    required this.progress,
    this.onEditGraduation,
  });


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = _beltUiColor(progress.belt, context);

    final pctText = '${(progress.percentToNextBelt * 100).toStringAsFixed(0)}%';
    final subtitle =
        '${progress.sessionsInCurrentBelt}/${progress.sessionsRequiredCurrentBelt} treinos (estimativa)';

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
                    'Faixa atual',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _beltName(progress.belt),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: beltColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LinearProgressIndicator(
                minHeight: 16,
                value: progress.percentToNextBelt,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(beltColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Graus: ${progress.degree}/${progress.maxDegree}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  pctText,
                  style: TextStyle(
                    color: beltColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            ),
            if (onEditGraduation != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEditGraduation,
                icon: const Icon(Icons.military_tech_outlined),
                label: const Text('Editar graduacao'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _beltUiColor(BeltColor belt, BuildContext context) {
    return TitansUI.beltColor(belt.name);
  }
  static String beltName(BeltColor belt) => _beltName(belt);

  static String _beltName(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return 'Branca';
      case BeltColor.blue:
        return 'Azul';
      case BeltColor.purple:
        return 'Roxa';
      case BeltColor.brown:
        return 'Marrom';
      case BeltColor.black:
        return 'Preta';
    }
  }
}

class _TrainingMetricsCard extends StatelessWidget {
  final TrainingMetrics metrics;

  const _TrainingMetricsCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Treinos realizados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: columns == 4 ? 1.9 : 2.2,
                  children: [
                    _MetricTile(label: 'Total', value: metrics.total.toString()),
                    _MetricTile(label: 'Mes', value: metrics.month.toString()),
                    _MetricTile(label: 'Ano', value: metrics.year.toString()),
                    _MetricTile(
                      label: '30 dias',
                      value: '${(metrics.recentFrequency * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: cs.primary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
    final maxY =
        values.isEmpty
            ? 4.0
            : (values.reduce((a, b) => a > b ? a : b)).toDouble() + 1;

    final spots =
        values
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
            .toList();

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
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Total: $totalInWindow',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY < 4 ? 4 : maxY,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
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
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget:
                            (v, _) => Text(
                              v.toInt().toString(),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: _bottomInterval(labels.length),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          final text = labels[idx];
                          final rotate = text.length >= 6; // ex 02/2026

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Transform.rotate(
                              angle: rotate ? -0.6 : 0,
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                  fontSize: 10,
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
                      barWidth: 3.5,
                      color: cs.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _bottomInterval(int len) {
    if (len <= 7) return 1;
    if (len <= 14) return 2;
    return 3;
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});


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
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
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
