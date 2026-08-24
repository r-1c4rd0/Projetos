import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/glass_card.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
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

class _TrainingScreenState extends State<TrainingScreen> {
  ProgressPeriod _period = ProgressPeriod.month;

  late final TrainingRepository _repo = TrainingRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<List<TrainingSession>>? _sessionsStream;

  TargetProfile? _resolveTarget(BuildContext context) {
    return widget.explicitTarget ??
        TargetResolver.maybeOf(context, mode: widget.targetMode);
  }

  void _syncStream({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
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
                      'N\u00e3o foi poss\u00edvel identificar seu usuario para carregar Treinos.',
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

    final cs = Theme.of(context).colorScheme;

    return _wrapModule(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Treinos'),
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
      floatingActionButton:
          !widget.embedded && canEditTarget
              ? FloatingActionButton.extended(
                heroTag: 'training_fab',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => AddTrainingSessionScreen(
                            academyId: academyId,
                            uid: uid,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Treino'),
              )
              : null,
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

          final sessions = List<TrainingSession>.from(
            snap.data ?? const <TrainingSession>[],
          )..sort((a, b) => a.date.compareTo(b.date));

          final series = _buildSeries(sessions, _period);
          final totalInWindow = series.values.fold<int>(0, (a, b) => a + b);

          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 80);

          return ListView(
            padding: listPadding,
            children: [
              if (widget.embedded)
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<ProgressPeriod>(
                    tooltip: 'Filtrar periodo',
                    initialValue: _period,
                    onSelected: (p) => setState(() => _period = p),
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
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                ),
              if (widget.embedded && canEditTarget) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => AddTrainingSessionScreen(
                                academyId: academyId,
                                uid: uid,
                              ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar treino'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              glassCard(
                context,
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleForPeriod(_period),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      height: 240,
                      child: _LineChart(
                        labels: series.labels,
                        values: series.values,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                TitansEmptyState(
                  icon: Icons.fitness_center_outlined,
                  title: 'Sem treinos registrados',
                  message: 'Adicione uma sess\u00e3o para iniciar o hist\u00f3rico.',
                  compact: true,
                  action:
                      canEditTarget
                          ? FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => AddTrainingSessionScreen(
                                        academyId: academyId,
                                        uid: uid,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar treino'),
                          )
                          : null,
                )
              else
                ...sessions.reversed.map((s) {
                  debugPrint(
                    '[TRAINING_EDIT] canEditTarget=$canEditTarget '
                    'actor.uid=${actor?.uid} target.uid=$uid '
                    'academyId=$academyId session.id=${s.id}',
                  );
                  if (_hasDebrief(s)) {
                    debugPrint(
                      '[TRAINING_DEBRIEF_CARD] mode=card session.id=${s.id} '
                      'target.uid=$uid position=${s.position} '
                      'technique=${s.technique} intensity=${s.intensity}',
                    );
                  }
                  return Card(
                    child: ListTile(
                      leading: Icon(_iconForPlace(s.place), color: cs.primary),
                      title: Text(
                        _fmtDateTime(s.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sessionSummary(s),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _TrainingActionChip(
                                  label: 'Notas: ${s.scores.length}',
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                                if (canEditTarget)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () async {
                                      debugPrint(
                                        '[TRAINING_EDIT_OPEN] actor.uid=${actor?.uid} '
                                        'target.uid=$uid canEditTarget=$canEditTarget '
                                        'academyId=$academyId session.id=${s.id}',
                                      );
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => AddTrainingSessionScreen(
                                                academyId: academyId,
                                                uid: uid,
                                                session: s,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Editar'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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

  IconData _iconForPlace(TrainingPlace p) {
    switch (p) {
      case TrainingPlace.academy:
        return Icons.sports_mma_outlined;
      case TrainingPlace.home:
        return Icons.home_outlined;
      case TrainingPlace.other:
        return Icons.place_outlined;
    }
  }

  String _titleForPeriod(ProgressPeriod p) {
    switch (p) {
      case ProgressPeriod.day:
        return 'Treinos por dia (\u00faltimos 14 dias)';
      case ProgressPeriod.month:
        return 'Treinos por m\u00eas (\u00faltimos 12 meses)';
      case ProgressPeriod.year:
        return 'Treinos por ano (\u00faltimos 5 anos)';
    }
  }

  _Series _buildSeries(List<TrainingSession> sessions, ProgressPeriod period) {
    final now = DateTime.now();
    final labels = <String>[];
    final map = <String, int>{};

    if (period == ProgressPeriod.day) {
      for (int i = 13; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${_fmt2(d.day)}/${_fmt2(d.month)}';
        labels.add(key);
        map[key] = 0;
      }
    } else if (period == ProgressPeriod.month) {
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = '${_fmt2(d.month)}/${d.year}';
        labels.add(key);
        map[key] = 0;
      }
    } else {
      for (int i = 4; i >= 0; i--) {
        final key = (now.year - i).toString();
        labels.add(key);
        map[key] = 0;
      }
    }

    for (final s in sessions) {
      final d = s.date;
      final key =
          (period == ProgressPeriod.day)
              ? '${_fmt2(d.day)}/${_fmt2(d.month)}'
              : (period == ProgressPeriod.month)
              ? '${_fmt2(d.month)}/${d.year}'
              : '${d.year}';

      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    return _Series(
      labels: labels,
      values: labels.map((k) => map[k] ?? 0).toList(),
    );
  }

  static String _fmt2(int n) => n.toString().padLeft(2, '0');

  String _fmtDateTime(DateTime d) {
    return '${_fmt2(d.day)}/${_fmt2(d.month)}/${d.year} ${_fmt2(d.hour)}:${_fmt2(d.minute)}';
  }

  bool _hasDebrief(TrainingSession session) {
    return (session.position?.trim().isNotEmpty ?? false) ||
        (session.technique?.trim().isNotEmpty ?? false) ||
        session.intensity != null ||
        (session.applicationContext?.trim().isNotEmpty ?? false) ||
        (session.techniqueOutcome?.trim().isNotEmpty ?? false);
  }

  String _sessionSummary(TrainingSession session) {
    final lines = <String>[];
    final notes = session.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      lines.add(notes);
    }

    final debrief = <String>[];
    final technique = session.technique?.trim();
    final position = session.position?.trim();
    if (technique != null && technique.isNotEmpty) {
      debrief.add('T\u00e9cnica: $technique');
    }
    if (position != null && position.isNotEmpty) {
      debrief.add('Posi\u00e7\u00e3o: $position');
    }
    if (session.intensity != null) {
      debrief.add('Intensidade: ${session.intensity}/5');
    }
    final application = _applicationSummary(session);
    if (application != null) {
      debrief.add(application);
    }

    if (debrief.isNotEmpty) {
      lines.add(debrief.join(' - '));
    }

    return lines.isEmpty ? '-' : lines.join('\n');
  }

  String? _applicationSummary(TrainingSession session) {
    final context = TrainingSession.applicationContextLabel(
      session.applicationContext,
    );
    final outcome = TrainingSession.techniqueOutcomeLabel(
      session.techniqueOutcome,
    );
    final parts = <String>[
      if (context != null) context,
      if (outcome != null) outcome,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' - ');
  }
}

class _TrainingActionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TrainingActionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Series {
  final List<String> labels;
  final List<int> values;
  _Series({required this.labels, required this.values});
}

class _LineChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;

  const _LineChart({required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final maxVal = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal < 3) ? 3.0 : (maxVal + 1).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true),
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
              reservedSize: 36,
              interval: 1,
              getTitlesWidget:
                  (v, _) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _bottomIntervalFor(values.length),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
              (i) => FlSpot(i.toDouble(), values[i].toDouble()),
            ),
            isCurved: true,
            barWidth: 3,
            color: cs.primary,
            dotData: FlDotData(show: values.length <= 20),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  double _bottomIntervalFor(int len) {
    if (len <= 5) return 1;
    if (len <= 12) return 2;
    return 3;
  }
}
