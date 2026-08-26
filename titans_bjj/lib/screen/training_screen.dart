import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';
import '../widgets/glass_card.dart';
import '../widgets/titans_expandable_section.dart';
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
  _TrainingChartPeriod _period = _TrainingChartPeriod.thirtyDays;

  late final TrainingRepository _repo = TrainingRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<List<TrainingSession>>? _sessionsStream;

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
      floatingActionButton:
          !widget.embedded && canEditTarget
              ? FloatingActionButton.extended(
                heroTag: 'training_fab',
                onPressed:
                    () => _openTrainingForm(academyId: academyId, uid: uid),
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

          final chart = _TrainingChartViewModel.from(
            sessions: sessions,
            selectedPeriod: _period,
          );
          final periodSessions = _filterSessionsForPeriod(sessions, _period);
          final summary = _buildTrainingSummary(periodSessions);
          final lastTrainingLabel =
              sessions.isEmpty
                  ? 'Último treino: sem registro'
                  : 'Último treino: ${_smartDateLabel(sessions.last.date)}';

          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 80);

          return ListView(
            padding: listPadding,
            children: [
              _TrainingSummaryCard(
                summary: summary,
                lastTrainingLabel: lastTrainingLabel,
                period: _period,
                onPeriodChanged: (p) => setState(() => _period = p),
                canAddTraining: widget.embedded && canEditTarget,
                onAddTraining:
                    widget.embedded && canEditTarget
                        ? () =>
                            _openTrainingForm(academyId: academyId, uid: uid)
                        : null,
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Evolução dos treinos',
                subtitle: chart.totalLabel,
                initiallyExpanded: true,
                child: _TrainingChartCard(viewModel: chart),
              ),
              const SizedBox(height: 12),
              TitansExpandableSection(
                title: 'Registros de treino',
                subtitle:
                    '${_trainingCountLabel(sessions.length)} • $lastTrainingLabel',
                child:
                    sessions.isEmpty
                        ? TitansEmptyState(
                          icon: Icons.fitness_center_outlined,
                          title: 'Sem treinos registrados',
                          message:
                              'Adicione uma sessão para iniciar o histórico.',
                          compact: true,
                          action:
                              canEditTarget
                                  ? FilledButton.icon(
                                    onPressed:
                                        () => _openTrainingForm(
                                          academyId: academyId,
                                          uid: uid,
                                        ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar treino'),
                                  )
                                  : null,
                        )
                        : Column(
                          children: [
                            for (final s in sessions.reversed)
                              Padding(
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
                              ),
                          ],
                        ),
              ),
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

  static String _fmt2(int n) => n.toString().padLeft(2, '0');

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
    _TrainingChartPeriod period,
  ) {
    final now = DateTime.now();
    final window = _TrainingChartWindow.forPeriod(period, now);
    return sessions.where((session) {
      final date = _dateOnly(session.date);
      return !date.isBefore(window.start) && !date.isAfter(window.end);
    }).toList();
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
  final String lastTrainingLabel;
  final _TrainingChartPeriod period;
  final ValueChanged<_TrainingChartPeriod> onPeriodChanged;
  final bool canAddTraining;
  final VoidCallback? onAddTraining;

  const _TrainingSummaryCard({
    required this.summary,
    required this.lastTrainingLabel,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Histórico de treinos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (canAddTraining)
                IconButton.filledTonal(
                  tooltip: 'Adicionar treino',
                  onPressed: onAddTraining,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth < 390
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _SummaryMetric(
                      label: 'Treinos',
                      value: summary.total.toString(),
                      color: cs.primary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryMetric(
                      label: 'Técnicas',
                      value: summary.techniques.toString(),
                      color: TitansUI.info,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryMetric(
                      label: 'Intensidade',
                      value:
                          intensity == null
                              ? 'Sem dados'
                              : '${intensity.toStringAsFixed(1)}/5',
                      color: TitansUI.warning,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryMetric(
                      label: 'Aplicação',
                      value: summary.applicationCount.toString(),
                      color: TitansUI.success,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _PeriodFilter(
            period: period,
            periods: _TrainingChartPeriodOption.defaults,
            onChanged: onPeriodChanged,
          ),
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
  final _TrainingChartPeriod period;
  final List<_TrainingChartPeriodOption> periods;
  final ValueChanged<_TrainingChartPeriod> onChanged;

  const _PeriodFilter({
    required this.period,
    required this.periods,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in periods)
              _PeriodChip(
                label: option.label,
                selected: period == option.id,
                onSelected: () => onChanged(option.id),
              ),
          ],
        ),
      ),
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
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.72),
        fontWeight: FontWeight.w900,
      ),
      selectedColor: cs.primary,
      backgroundColor: Colors.transparent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
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
  final base =
      '${_TrainingScreenState._fmt2(date.day)} ${_monthLabel(date.month)} ${date.year}';
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

enum _TrainingChartPeriod { sevenDays, thirtyDays, threeMonths, twelveMonths }

enum _TrainingChartAggregationMode { day, week, month }

class _TrainingChartPeriodOption {
  final _TrainingChartPeriod id;
  final String label;
  final _TrainingChartAggregationMode aggregationMode;

  const _TrainingChartPeriodOption({
    required this.id,
    required this.label,
    required this.aggregationMode,
  });

  static const defaults = [
    _TrainingChartPeriodOption(
      id: _TrainingChartPeriod.sevenDays,
      label: '7 dias',
      aggregationMode: _TrainingChartAggregationMode.day,
    ),
    _TrainingChartPeriodOption(
      id: _TrainingChartPeriod.thirtyDays,
      label: '30 dias',
      aggregationMode: _TrainingChartAggregationMode.week,
    ),
    _TrainingChartPeriodOption(
      id: _TrainingChartPeriod.threeMonths,
      label: '3 meses',
      aggregationMode: _TrainingChartAggregationMode.week,
    ),
    _TrainingChartPeriodOption(
      id: _TrainingChartPeriod.twelveMonths,
      label: '12 meses',
      aggregationMode: _TrainingChartAggregationMode.month,
    ),
  ];

  static _TrainingChartPeriodOption byId(_TrainingChartPeriod id) {
    return defaults.firstWhere((option) => option.id == id);
  }
}

class _TrainingChartViewModel {
  final String title;
  final String subtitle;
  final _TrainingChartPeriod selectedPeriod;
  final List<_TrainingChartPeriodOption> periods;
  final List<_TrainingChartPoint> points;
  final String totalLabel;
  final String emptyStateLabel;

  const _TrainingChartViewModel({
    required this.title,
    required this.subtitle,
    required this.selectedPeriod,
    required this.periods,
    required this.points,
    required this.totalLabel,
    required this.emptyStateLabel,
  });

  factory _TrainingChartViewModel.from({
    required List<TrainingSession> sessions,
    required _TrainingChartPeriod selectedPeriod,
  }) {
    final now = DateTime.now();
    final option = _TrainingChartPeriodOption.byId(selectedPeriod);
    final window = _TrainingChartWindow.forPeriod(selectedPeriod, now);
    final buckets = _TrainingChartBucket.build(window, option.aggregationMode);
    final counts = {for (final bucket in buckets) bucket.key: 0};

    for (final session in sessions) {
      final date = _dateOnly(session.date);
      if (date.isBefore(window.start) || date.isAfter(window.end)) continue;
      final key = _TrainingChartBucket.keyFor(
        date,
        window,
        option.aggregationMode,
      );
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final maxValue = counts.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final points = [
      for (final bucket in buckets)
        _TrainingChartPoint(
          date: bucket.date,
          label: bucket.label,
          value: counts[bucket.key] ?? 0,
          tooltipTitle: bucket.tooltipTitle,
          tooltipBody: _trainingCountLabel(counts[bucket.key] ?? 0),
          isHighlighted: maxValue > 0 && counts[bucket.key] == maxValue,
        ),
    ];
    final total = points.fold<int>(0, (sum, point) => sum + point.value);

    return _TrainingChartViewModel(
      title: 'Treinos registrados',
      subtitle: _subtitleFor(option),
      selectedPeriod: selectedPeriod,
      periods: _TrainingChartPeriodOption.defaults,
      points: points,
      totalLabel: 'Total no per\u00edodo: ${_trainingCountLabel(total)}',
      emptyStateLabel: 'Nenhum treino registrado neste per\u00edodo.',
    );
  }

  bool get isEmpty => points.every((point) => point.value == 0);

  static String _subtitleFor(_TrainingChartPeriodOption option) {
    switch (option.aggregationMode) {
      case _TrainingChartAggregationMode.day:
        return 'Contagem por dia, usando apenas datas dos treinos.';
      case _TrainingChartAggregationMode.week:
        return 'Contagem por semana, usando apenas datas dos treinos.';
      case _TrainingChartAggregationMode.month:
        return 'Contagem por m\u00eas, usando apenas datas dos treinos.';
    }
  }
}

class _TrainingChartPoint {
  final DateTime date;
  final String label;
  final int value;
  final String tooltipTitle;
  final String tooltipBody;
  final bool isHighlighted;

  const _TrainingChartPoint({
    required this.date,
    required this.label,
    required this.value,
    required this.tooltipTitle,
    required this.tooltipBody,
    required this.isHighlighted,
  });
}

class _TrainingChartCard extends StatelessWidget {
  final _TrainingChartViewModel viewModel;

  const _TrainingChartCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final periodLabel =
        _TrainingChartPeriodOption.byId(viewModel.selectedPeriod).label;

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TrainingActionChip(label: periodLabel, color: cs.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            viewModel.isEmpty
                ? 'A evolução aparece quando houver treinos no período selecionado.'
                : 'Leitura simples da frequência registrada neste período.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (viewModel.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TitansEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'Sem registros no período',
                message: viewModel.emptyStateLabel,
                compact: true,
              ),
            )
          else
            SizedBox(
              height: 238,
              child: _TrainingBarChart(points: viewModel.points),
            ),
        ],
      ),
    );
  }
}

class _TrainingBarChart extends StatelessWidget {
  final List<_TrainingChartPoint> points;

  const _TrainingBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxValue = points.fold<int>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue < 3 ? 3.0 : (maxValue + 1).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelEvery = _labelEvery(points.length, constraints.maxWidth);

        return BarChart(
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
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipRoundedRadius: 10,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  if (groupIndex < 0 || groupIndex >= points.length) {
                    return null;
                  }
                  final point = points[groupIndex];
                  return BarTooltipItem(
                    '${point.tooltipTitle}\n',
                    TextStyle(
                      color: cs.onInverseSurface,
                      fontWeight: FontWeight.w900,
                    ),
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
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].value.toDouble(),
                      width: _barWidth(points.length, constraints.maxWidth),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                      color:
                          points[i].isHighlighted
                              ? cs.secondary
                              : cs.primary.withValues(alpha: 0.78),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: cs.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        );
      },
    );
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

class _TrainingChartWindow {
  final DateTime start;
  final DateTime end;

  const _TrainingChartWindow({required this.start, required this.end});

  static _TrainingChartWindow forPeriod(
    _TrainingChartPeriod period,
    DateTime now,
  ) {
    final today = _dateOnly(now);
    final start = switch (period) {
      _TrainingChartPeriod.sevenDays => today.subtract(const Duration(days: 6)),
      _TrainingChartPeriod.thirtyDays => today.subtract(
        const Duration(days: 29),
      ),
      _TrainingChartPeriod.threeMonths => DateTime(
        today.year,
        today.month - 2,
        1,
      ),
      _TrainingChartPeriod.twelveMonths => DateTime(
        today.year,
        today.month - 11,
        1,
      ),
    };
    return _TrainingChartWindow(start: start, end: today);
  }
}

class _TrainingChartBucket {
  final DateTime date;
  final String key;
  final String label;
  final String tooltipTitle;

  const _TrainingChartBucket({
    required this.date,
    required this.key,
    required this.label,
    required this.tooltipTitle,
  });

  static List<_TrainingChartBucket> build(
    _TrainingChartWindow window,
    _TrainingChartAggregationMode mode,
  ) {
    switch (mode) {
      case _TrainingChartAggregationMode.day:
        return _dayBuckets(window);
      case _TrainingChartAggregationMode.week:
        return _weekBuckets(window);
      case _TrainingChartAggregationMode.month:
        return _monthBuckets(window);
    }
  }

  static String keyFor(
    DateTime date,
    _TrainingChartWindow window,
    _TrainingChartAggregationMode mode,
  ) {
    switch (mode) {
      case _TrainingChartAggregationMode.day:
        return _dayKey(date);
      case _TrainingChartAggregationMode.week:
        final offset = date.difference(window.start).inDays ~/ 7;
        return _dayKey(window.start.add(Duration(days: offset * 7)));
      case _TrainingChartAggregationMode.month:
        return _monthKey(date);
    }
  }

  static List<_TrainingChartBucket> _dayBuckets(_TrainingChartWindow window) {
    final buckets = <_TrainingChartBucket>[];
    var cursor = window.start;
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        _TrainingChartBucket(
          date: cursor,
          key: _dayKey(cursor),
          label: _shortDayLabel(cursor),
          tooltipTitle: _shortDayLabel(cursor),
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return buckets;
  }

  static List<_TrainingChartBucket> _weekBuckets(_TrainingChartWindow window) {
    final buckets = <_TrainingChartBucket>[];
    var cursor = window.start;
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        _TrainingChartBucket(
          date: cursor,
          key: _dayKey(cursor),
          label: _shortDayLabel(cursor),
          tooltipTitle: 'Semana ${_shortDayLabel(cursor)}',
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }
    return buckets;
  }

  static List<_TrainingChartBucket> _monthBuckets(_TrainingChartWindow window) {
    final buckets = <_TrainingChartBucket>[];
    var cursor = DateTime(window.start.year, window.start.month, 1);
    while (!cursor.isAfter(window.end)) {
      buckets.add(
        _TrainingChartBucket(
          date: cursor,
          key: _monthKey(cursor),
          label: _monthYearLabel(cursor),
          tooltipTitle: _monthYearLabel(cursor),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return buckets;
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${_TrainingScreenState._fmt2(date.month)}-${_TrainingScreenState._fmt2(date.day)}';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${_TrainingScreenState._fmt2(date.month)}';
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _shortDayLabel(DateTime date) {
  return '${_TrainingScreenState._fmt2(date.day)}/${_TrainingScreenState._fmt2(date.month)}';
}

String _monthYearLabel(DateTime date) {
  return '${_monthLabel(date.month)} ${date.year}';
}

String _trainingCountLabel(int count) {
  return count == 1 ? '1 treino registrado' : '$count treinos registrados';
}
