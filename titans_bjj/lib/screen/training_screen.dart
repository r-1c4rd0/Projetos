import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/training_aggregator.dart';
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
                onPressed: () => _openTrainingForm(
                  academyId: academyId,
                  uid: uid,
                ),
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
          final periodSessions = _filterSessionsForPeriod(sessions, _period);
          final summary = _buildTrainingSummary(periodSessions);

          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 80);

          return ListView(
            padding: listPadding,
            children: [
              _TrainingSummaryCard(
                summary: summary,
                period: _period,
                onPeriodChanged: (p) => setState(() => _period = p),
                canAddTraining: widget.embedded && canEditTarget,
                onAddTraining:
                    widget.embedded && canEditTarget
                        ? () => _openTrainingForm(
                          academyId: academyId,
                          uid: uid,
                        )
                        : null,
              ),
              const SizedBox(height: 12),
              glassCard(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleForPeriod(_period),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
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
                            onPressed: () => _openTrainingForm(
                              academyId: academyId,
                              uid: uid,
                            ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrainingSessionCard(
                      session: s,
                      canEdit: canEditTarget,
                      onEdit:
                          canEditTarget
                              ? () {
                                debugPrint(
                                  '[TRAINING_EDIT_OPEN] actor.uid=${actor?.uid} '
                                  'target.uid=$uid canEditTarget=$canEditTarget '
                                  'academyId=$academyId session.id=${s.id}',
                                );
                                return _openTrainingForm(
                                  academyId: academyId,
                                  uid: uid,
                                  session: s,
                                );
                              }
                              : null,
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

  bool _hasDebrief(TrainingSession session) {
    return (session.position?.trim().isNotEmpty ?? false) ||
        (session.technique?.trim().isNotEmpty ?? false) ||
        session.intensity != null ||
        (session.applicationContext?.trim().isNotEmpty ?? false) ||
        (session.techniqueOutcome?.trim().isNotEmpty ?? false);
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

  List<TrainingSession> _filterSessionsForPeriod(
    List<TrainingSession> sessions,
    ProgressPeriod period,
  ) {
    final now = DateTime.now();
    final start = switch (period) {
      ProgressPeriod.day => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 13)),
      ProgressPeriod.month => DateTime(now.year, now.month - 11, 1),
      ProgressPeriod.year => DateTime(now.year - 4, 1, 1),
    };
    return sessions.where((session) => !session.date.isBefore(start)).toList();
  }

  _TrainingSummary _buildTrainingSummary(List<TrainingSession> sessions) {
    final techniqueKeys = <String>{};
    var intensitySum = 0;
    var intensityCount = 0;
    var applicationCount = 0;

    for (final session in sessions) {
      final technique = _cleanDisplayText(session.technique);
      if (technique != null) techniqueKeys.add(technique.toLowerCase());

      final intensity = session.intensity;
      if (intensity != null && intensity >= 1 && intensity <= 5) {
        intensitySum += intensity;
        intensityCount++;
      }

      if (TrainingSession.isApplicationContextMeasured(
            session.applicationContext,
          ) ||
          TrainingSession.isTechniqueOutcomeUseful(session.techniqueOutcome)) {
        applicationCount++;
      }
    }

    return _TrainingSummary(
      total: sessions.length,
      techniques: techniqueKeys.length,
      averageIntensity:
          intensityCount == 0 ? null : intensitySum / intensityCount,
      applicationCount: applicationCount,
    );
  }
}

class _TrainingSummary {
  final int total;
  final int techniques;
  final double? averageIntensity;
  final int applicationCount;

  const _TrainingSummary({
    required this.total,
    required this.techniques,
    required this.averageIntensity,
    required this.applicationCount,
  });
}

class _TrainingSummaryCard extends StatelessWidget {
  final _TrainingSummary summary;
  final ProgressPeriod period;
  final ValueChanged<ProgressPeriod> onPeriodChanged;
  final bool canAddTraining;
  final VoidCallback? onAddTraining;

  const _TrainingSummaryCard({
    required this.summary,
    required this.period,
    required this.onPeriodChanged,
    required this.canAddTraining,
    required this.onAddTraining,
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
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.start,
            children: [
              Text(
                'Hist\u00f3rico de treinos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (canAddTraining)
                FilledButton.icon(
                  onPressed: onAddTraining,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar treino'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryMetric(
                label: 'Treinos',
                value: summary.total.toString(),
                color: cs.primary,
              ),
              _SummaryMetric(
                label: 'T\u00e9cnicas',
                value: summary.techniques.toString(),
                color: TitansUI.info,
              ),
              _SummaryMetric(
                label: 'Intensidade',
                value:
                    intensity == null ? '--' : '${intensity.toStringAsFixed(1)}/5',
                color: TitansUI.warning,
              ),
              _SummaryMetric(
                label: 'Aplica\u00e7\u00e3o',
                value: summary.applicationCount.toString(),
                color: TitansUI.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodFilter(period: period, onChanged: onPeriodChanged),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  final ProgressPeriod period;
  final ValueChanged<ProgressPeriod> onChanged;

  const _PeriodFilter({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PeriodChip(
          label: 'Dia',
          selected: period == ProgressPeriod.day,
          onSelected: () => onChanged(ProgressPeriod.day),
        ),
        _PeriodChip(
          label: 'M\u00eas',
          selected: period == ProgressPeriod.month,
          onSelected: () => onChanged(ProgressPeriod.month),
        ),
        _PeriodChip(
          label: 'Ano',
          selected: period == ProgressPeriod.year,
          onSelected: () => onChanged(ProgressPeriod.year),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TrainingSessionCard extends StatelessWidget {
  final TrainingSession session;
  final bool canEdit;
  final Future<void> Function()? onEdit;

  const _TrainingSessionCard({
    required this.session,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final technique =
        _cleanDisplayText(session.technique) ?? 'Treino registrado';
    final position = _cleanDisplayText(session.position);
    final application = TrainingAggregator.applicationContextLabel(
      session.applicationContext,
    );
    final outcome = TrainingAggregator.techniqueOutcomeLabel(
      session.techniqueOutcome,
    );
    final primaryNote = _primarySessionNote(session);

    return glassCard(
      context,
      InkWell(
        borderRadius: BorderRadius.circular(TitansUI.radius),
        onTap: canEdit && onEdit != null ? () => onEdit!.call() : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _smartDateLabel(session.date).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: 'Op\u00e7\u00f5es do treino',
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
            const SizedBox(height: 8),
            Text(
              technique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if (position != null) ...[
              const SizedBox(height: 3),
              Text(
                position,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TrainingActionChip(
                  label: _placeLabel(session.place),
                  color: cs.primary,
                ),
                if (session.intensity != null)
                  _TrainingActionChip(
                    label: 'Intensidade ${session.intensity}/5',
                    color: TitansUI.warning,
                  ),
                if (application != null)
                  _TrainingActionChip(label: application, color: TitansUI.info),
                if (outcome != null)
                  _TrainingActionChip(
                    label: outcome,
                    color: _outcomeColor(outcome),
                  ),
                if (session.scores.isNotEmpty)
                  _TrainingActionChip(
                    label: 'Notas: ${session.scores.length}',
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
              ],
            ),
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
                maxLines: 2,
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
                  label: const Text('Detalhes'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimarySessionNote {
  final String label;
  final String text;

  const _PrimarySessionNote({required this.label, required this.text});
}

_PrimarySessionNote? _primarySessionNote(TrainingSession session) {
  final difficulty = _cleanDisplayText(session.difficulties);
  if (difficulty != null) {
    return _PrimarySessionNote(label: 'Dificuldade:', text: difficulty);
  }

  final success = _cleanDisplayText(session.successes);
  if (success != null) {
    return _PrimarySessionNote(label: 'Sucesso:', text: success);
  }

  final debrief = _cleanDisplayText(session.debriefNotes);
  if (debrief != null) {
    return _PrimarySessionNote(label: 'Debrief:', text: debrief);
  }

  final notes = _cleanDisplayText(session.notes);
  if (notes != null) {
    return _PrimarySessionNote(label: 'Nota:', text: notes);
  }

  return null;
}

String? _cleanDisplayText(String? value) {
  final clean = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean == null || clean.isEmpty) return null;
  final normalized = clean.toLowerCase();
  if (normalized == 'unknown' ||
      normalized == 'n/a' ||
      normalized == 'na' ||
      normalized == 'null') {
    return null;
  }
  return clean;
}

String _smartDateLabel(DateTime date) {
  final base = '${_TrainingScreenState._fmt2(date.day)} ${_monthLabel(date.month)} ${date.year}';
  if (date.hour == 0 && date.minute == 0) return base;
  return '$base ${_TrainingScreenState._fmt2(date.hour)}:${_TrainingScreenState._fmt2(date.minute)}';
}

String _monthLabel(int month) {
  const labels = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];
  final index = (month - 1).clamp(0, labels.length - 1).toInt();
  return labels[index];
}

String _placeLabel(TrainingPlace place) {
  switch (place) {
    case TrainingPlace.academy:
      return 'Academia';
    case TrainingPlace.home:
      return 'Casa';
    case TrainingPlace.other:
      return 'Outro local';
  }
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
              reservedSize: 34,
              interval: _bottomIntervalFor(values.length),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 9,
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
