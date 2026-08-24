import 'dart:async';

import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/training_repository.dart';
import '../repository/user_progress_repository.dart';
import '../repository/user_repository.dart';
import '../service/target_resolver.dart';
import '../service/jiu_jitsu_taxonomy.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import 'athlete_registration_screen.dart';
import 'game_map_screen.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final String? athleteNameOverride;
  final String? athleteEmailOverride;
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;
  final bool embedded;

  const AthleteDashboardScreen({
    super.key,
    this.athleteNameOverride,
    this.athleteEmailOverride,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
    this.embedded = false,
  });

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  late final TrainingRepository _trainingRepo = TrainingRepository.instance;
  late final GradingRulesRepository _rulesRepo =
      GradingRulesRepository.instance;
  late final UserProgressRepository _progressRepo =
      UserProgressRepository.instance;
  late final UserRepository _userRepo = UserRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<AppUser?>? _athleteStream;
  Stream<UserProgressProfile?>? _profileStream;
  Stream<GradingRules?>? _rulesStream;
  Stream<List<TrainingSession>>? _sessionsStream;

  TargetProfile? _resolveTarget(BuildContext context) {
    return widget.explicitTarget ??
        TargetResolver.maybeOf(context, mode: widget.targetMode);
  }

  void _syncStreams({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
    _athleteStream = _userRepo.watchUser(academyId: academyId, uid: uid);
    _profileStream = _progressRepo.watchProfile(academyId: academyId, uid: uid);
    _rulesStream = _rulesRepo.watch(academyId);
    _sessionsStream = _trainingRepo.watchSessions(
      academyId: academyId,
      uid: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolverTarget = TargetResolver.maybeOf(
      context,
      mode: widget.targetMode,
    );
    final target = widget.explicitTarget ?? resolverTarget;
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    final canEditTarget =
        target != null && _canEditTarget(loggedUser: actor, target: target);
    debugPrint(
      '[DASHBOARD_TARGET] screen=AthleteDashboardScreen '
      'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
      'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
      'explicit.academyId=${widget.explicitTarget?.academyId} '
      'resolver.uid=${resolverTarget?.uid} '
      'resolver.academyId=${resolverTarget?.academyId} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId} '
      'canEditTarget=$canEditTarget',
    );

    if (target == null) {
      debugPrint(
        '[DASHBOARD_TARGET] screen=AthleteDashboardScreen '
        'targetMode=${widget.targetMode} '
        'explicit.uid=${widget.explicitTarget?.uid} '
        'explicit.academyId=${widget.explicitTarget?.academyId} '
        'resolver.uid=${resolverTarget?.uid} '
        'resolver.academyId=${resolverTarget?.academyId} '
        'final.uid=${target?.uid} final.academyId=${target?.academyId}',
      );
      return _wrapModule(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Inicio')),
        body:
            widget.targetMode == TargetMode.selectedStudent
                ? const TitansStateView.noStudent(
                  message:
                      'Selecione um aluno no Painel do Mestre para acessar o console do atleta.',
                )
                : const TitansStateView.error(
                  title: 'Perfil nao carregado',
                  message:
                      'Nao foi possivel identificar seu usuario para carregar o dashboard.',
                ),
      );
    }

    _syncStreams(academyId: target.academyId, uid: target.uid);

    final cs = Theme.of(context).colorScheme;

    final academyId = target.academyId;
    final uid = target.uid;

    return _wrapModule(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Inicio'),
        actions: [
          IconButton(
            tooltip: 'Configuracoes',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: _athleteStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
          }
          if (userSnap.hasError) {
            return _ErrorState(
              title: 'Erro ao carregar usuario',
              message: userSnap.error.toString(),
            );
          }

          final athlete = userSnap.data;
          if (athlete == null) {
            return const _EmptyState(
              title: 'Usuario nao encontrado.',
              subtitle:
                  'Crie academies/{academyId}/users/{uid} com role, belt e degree.',
            );
          }

          final headerName =
              (widget.athleteNameOverride ?? '').trim().isNotEmpty
                  ? widget.athleteNameOverride!.trim()
                  : (athlete.name.trim().isNotEmpty
                      ? athlete.name.trim()
                      : 'Atleta');
          final headerEmail =
              (widget.athleteEmailOverride ?? '').trim().isNotEmpty
                  ? widget.athleteEmailOverride!.trim()
                  : athlete.email;

          return StreamBuilder<UserProgressProfile?>(
            stream: _profileStream,
            builder: (context, profileSnap) {
              if (profileSnap.connectionState == ConnectionState.waiting) {
                return const TitansSkeletonCard(lines: 5);
              }
              if (profileSnap.hasError) {
                return _ErrorState(
                  title: 'Erro ao carregar perfil',
                  message: profileSnap.error.toString(),
                );
              }

              final profile = profileSnap.data;
              if (profile == null) {
                return const _EmptyState(
                  title: 'Perfil de progresso nao encontrado.',
                  subtitle:
                      'Crie academies/{academyId}/users/{uid}/progress/profile (beltStartAt, estimatedSessionsInBelt).',
                );
              }

              return StreamBuilder<GradingRules?>(
                stream: _rulesStream,
                builder: (context, rulesSnap) {
                  if (rulesSnap.connectionState == ConnectionState.waiting &&
                      !rulesSnap.hasData) {
                    return const TitansSkeletonCard(lines: 5);
                  }
                  if (rulesSnap.hasError) {
                    return _ErrorState(
                      title: 'Erro ao carregar regras',
                      message: rulesSnap.error.toString(),
                    );
                  }

                  final rules = rulesSnap.data ?? GradingRules.defaults();

                  return StreamBuilder<List<TrainingSession>>(
                    stream: _sessionsStream,
                    builder: (context, trainSnap) {
                      if (trainSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const TitansSkeletonCard(lines: 5);
                      }
                      if (trainSnap.hasError) {
                        return _ErrorState(
                          title: 'Erro ao carregar treinos',
                          message: trainSnap.error.toString(),
                        );
                      }

                      final sessions = List<TrainingSession>.from(
                        trainSnap.data ?? const <TrainingSession>[],
                      );
                      sessions.sort((a, b) => a.date.compareTo(b.date));

                      final filtered =
                          rules.onlyAcademyPlace
                              ? sessions
                                  .where(
                                    (s) => s.place == TrainingPlace.academy,
                                  )
                                  .toList()
                              : List<TrainingSession>.from(sessions);

                      final beltProgress = _calcBeltProgress(
                        rules: rules,
                        profile: profile,
                        belt: athlete.belt,
                        degree: athlete.degree,
                        sessions: filtered,
                      );
                      final recentSessions =
                          filtered.reversed.take(10).toList();
                      final lastSessions = recentSessions.take(5).toList();
                      final metrics = TrainingAggregator.metrics(filtered);
                      final debriefInsights = _buildDebriefInsights(
                        recentSessions,
                      );
                      final gameMapLite = TrainingAggregator.buildGameMap(
                        recentSessions,
                        limit: 10,
                      );
                      final skillMatrix = TrainingAggregator.buildSkillMatrix(
                        filtered,
                        limit: 50,
                      );
                      final recommendedFocus =
                          TrainingAggregator.buildRecommendedFocus(
                        filtered,
                        recentLimit: 20,
                      );

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final content = SingleChildScrollView(
                            padding:
                                widget.embedded
                                    ? TitansUI.listPadding(
                                      context,
                                      extra: TitansUI.spaceMd,
                                    )
                                    : TitansUI.listPadding(context),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final isWide = c.maxWidth >= 980;
                                      debugPrint(
                                        '[DASHBOARD_EDIT] showEditProfile=$canEditTarget '
                                        'canEditTarget=$canEditTarget actor.uid=${actor?.uid} '
                                        'actor.role=${actor?.role} target.uid=$uid '
                                        'target.academyId=$academyId',
                                      );
                                      final athleteCard = _AthleteCard(
                                        name: headerName,
                                        email: headerEmail,
                                        uid: uid,
                                        belt: beltProgress.belt,
                                        degree: beltProgress.degree,
                                        percentToNext:
                                            beltProgress.percentToNextBelt,
                                        onEditProfile:
                                            canEditTarget
                                                ? () {
                                                  debugPrint(
                                                    '[DASHBOARD_EDIT_CLICK] clicked=true '
                                                    'athleteUid=$uid academyId=$academyId',
                                                  );
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              AthleteRegistrationScreen(
                                                                academyId:
                                                                    academyId,
                                                                athleteUid: uid,
                                                              ),
                                                    ),
                                                  );
                                                }
                                                : null,
                                        onEditGraduation:
                                            canEditTarget
                                                ? () => _showGraduationDialog(
                                                  academyId: academyId,
                                                  uid: uid,
                                                  athlete: athlete,
                                                  rules: rules,
                                                )
                                                : null,
                                      );

                                      if (isWide) {
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 4,
                                              child: athleteCard,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 6,
                                              child: _GraduationProgressCard(
                                                cs: cs,
                                                progress: beltProgress,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return Column(
                                        children: [
                                          athleteCard,
                                          const SizedBox(height: 12),
                                          _GraduationProgressCard(
                                            cs: cs,
                                            progress: beltProgress,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final isWide = c.maxWidth >= 980;
                                      final left = _StatsCard(
                                        cs: cs,
                                        frequency: _calcFrequency(filtered),
                                        metrics: metrics,
                                      );
                                      final right = _DebriefInsightsCard(
                                        cs: cs,
                                        insights: debriefInsights,
                                      );

                                      if (isWide) {
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(flex: 4, child: left),
                                            const SizedBox(width: 12),
                                            Expanded(flex: 6, child: right),
                                          ],
                                        );
                                      }

                                      return Column(
                                        children: [
                                          left,
                                          const SizedBox(height: 12),
                                          right,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _RecommendedFocusCard(
                                    cs: cs,
                                    focus: recommendedFocus,
                                  ),
                                  const SizedBox(height: 12),
                                  _SkillMatrixSummaryCard(
                                    cs: cs,
                                    entries: skillMatrix,
                                    onOpenSkillMatrix: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => GameMapScreen(
                                                academyId: academyId,
                                                uid: uid,
                                                targetName: headerName,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _GameMapLiteCard(
                                    cs: cs,
                                    entries: gameMapLite,
                                    onOpenFullMap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => GameMapScreen(
                                                academyId: academyId,
                                                uid: uid,
                                                targetName: headerName,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _RecentActivityCard(
                                    cs: cs,
                                    items: lastSessions,
                                  ),
                                ],
                              ),
                            ),
                          );
                          return widget.embedded
                              ? content
                              : SafeArea(bottom: false, child: content);
                        },
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
    final canManage =
        loggedUser.role == UserRole.admin ||
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
              title: const Text('Solicitar/Editar graduacao'),
              content: Column(
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
                                child: Text(_beltLabel(belt)),
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
                                  content: Text('Graduacao atualizada'),
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
                  icon:
                      saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
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
    required UserProgressProfile profile,
    required BeltColor belt,
    required int degree,
    required List<TrainingSession> sessions,
  }) {
    final maxDeg = rules.maxDegrees(belt).clamp(1, 12).toInt();
    final safeDegree = degree.clamp(0, maxDeg).toInt();

    final sessionsInBelt =
        sessions.where((s) => !s.date.isBefore(profile.beltStartAt)).length;

    final estimated = profile.estimatedSessionsInBelt;
    final requiredByRules = rules.requiredSessions(belt);
    final safeFallback = sessionsInBelt > 0 ? sessionsInBelt : maxDeg;
    final sessionsRequired =
        (estimated != null && estimated > 0)
            ? estimated
            : (requiredByRules > 0 ? requiredByRules : safeFallback)
                .clamp(1, 1 << 30)
                .toInt();

    final perSegment = sessionsRequired / maxDeg;
    final startOfThisSegment = safeDegree * perSegment;
    final doneIntoSegment = sessionsInBelt - startOfThisSegment;
    final pctSegment =
        perSegment <= 0 ? 0.0 : (doneIntoSegment / perSegment).clamp(0.0, 1.0);

    return _BeltProgress(
      belt: belt,
      degree: safeDegree,
      maxDegree: maxDeg,
      sessionsInBelt: sessionsInBelt,
      sessionsRequired: sessionsRequired,
      percentToNextBelt: pctSegment,
    );
  }

  int _calcFrequency(List<TrainingSession> sessions) {
    final now = DateTime.now();
    final weeks = <String, bool>{};
    for (int i = 0; i < 8; i++) {
      final d = now.subtract(Duration(days: i * 7));
      weeks[_weekKey(d)] = false;
    }
    for (final s in sessions) {
      final k = _weekKey(s.date);
      if (weeks.containsKey(k)) weeks[k] = true;
    }
    final total = weeks.length;
    final hit = weeks.values.where((v) => v).length;
    if (total == 0) return 0;
    return ((hit / total) * 100).round();
  }

  _DebriefInsights _buildDebriefInsights(List<TrainingSession> sessions) {
    final focus = <String>[];
    final attention = <String>[];
    final strength = <String>[];
    final intensities = <int>[];

    for (final session in sessions) {
      final technique = _cleanDebriefText(session.technique);
      final position = _cleanDebriefText(session.position);
      final focusParts = <String>[];
      if (technique != null) focusParts.add('Tecnica: $technique');
      if (position != null) focusParts.add('Posicao: $position');
      if (focusParts.isNotEmpty) focus.add(focusParts.join(' - '));

      final difficulties = _cleanDebriefText(session.difficulties);
      if (difficulties != null) attention.add(difficulties);

      final successes = _cleanDebriefText(session.successes);
      if (successes != null) strength.add(successes);

      final intensity = session.intensity;
      if (intensity != null && intensity >= 1 && intensity <= 5) {
        intensities.add(intensity);
      }
    }

    final intensityAverage =
        intensities.isEmpty
            ? null
            : intensities.fold<int>(0, (sum, value) => sum + value) /
                intensities.length;

    return _DebriefInsights(
      technicalFocus: _mostRecurringRecent(focus),
      attentionPoint: _mostRecurringRecent(attention),
      strengthPoint: _mostRecurringRecent(strength),
      averageIntensity: intensityAverage,
    );
  }

  String? _mostRecurringRecent(List<String> values) {
    final scores = <String, _InsightScore>{};

    for (var index = 0; index < values.length; index++) {
      final value = values[index].trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      final score = scores[key];
      if (score == null) {
        scores[key] = _InsightScore(value: value, count: 1, firstIndex: index);
      } else {
        score.count += 1;
      }
    }

    _InsightScore? best;
    for (final score in scores.values) {
      if (best == null ||
          score.count > best.count ||
          (score.count == best.count && score.firstIndex < best.firstIndex)) {
        best = score;
      }
    }

    return best?.value;
  }

  String _weekKey(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    final diff = d.difference(firstDay).inDays;
    final week = (diff / 7).floor();
    return '${d.year}-$week';
  }
}

// ---------------- UI ----------------

class _DebriefInsights {
  final String? technicalFocus;
  final String? attentionPoint;
  final String? strengthPoint;
  final double? averageIntensity;

  const _DebriefInsights({
    required this.technicalFocus,
    required this.attentionPoint,
    required this.strengthPoint,
    required this.averageIntensity,
  });
}

class _InsightScore {
  final String value;
  final int firstIndex;
  int count;

  _InsightScore({
    required this.value,
    required this.firstIndex,
    required this.count,
  });
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final int sessionsInBelt;
  final int sessionsRequired;
  final double percentToNextBelt;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    required this.percentToNextBelt,
  });
}

String? _cleanDebriefText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String? _shortDebriefText(String? value, {int maxLength = 72}) {
  final text = _cleanDebriefText(value);
  if (text == null) return null;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3).trimRight()}...';
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _beltLabel(BeltColor belt) {
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

class _AthleteCard extends StatelessWidget {
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final double percentToNext;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditGraduation;

  const _AthleteCard({
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.percentToNext,
    this.onEditProfile,
    this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = TitansUI.beltColor(belt.name);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.isEmpty
                          ? 'ID: ${uid.substring(0, 6).toUpperCase()}'
                          : '$email - ID: ${uid.substring(0, 6).toUpperCase()}',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _BeltPill(belt: belt, color: beltColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Progresso para o proximo grau',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: percentToNext.clamp(0.0, 1.0),
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(beltColor),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(percentToNext * 100).round()}%',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grau atual: $degree',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onEditProfile != null || onEditGraduation != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onEditProfile != null)
                  OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar perfil'),
                  ),
                if (onEditGraduation != null)
                  OutlinedButton.icon(
                    onPressed: onEditGraduation,
                    icon: const Icon(Icons.military_tech_outlined),
                    label: const Text('Editar graduacao'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BeltPill extends StatelessWidget {
  final BeltColor belt;
  final Color color;
  const _BeltPill({required this.belt, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (belt) {
      BeltColor.white => 'FAIXA WHITE',
      BeltColor.blue => 'FAIXA BLUE',
      BeltColor.purple => 'FAIXA PURPLE',
      BeltColor.brown => 'FAIXA BROWN',
      BeltColor.black => 'FAIXA BLACK',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GraduationProgressCard extends StatelessWidget {
  final ColorScheme cs;
  final _BeltProgress progress;

  const _GraduationProgressCard({required this.cs, required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress.percentToNextBelt * 100).round();
    final beltColor = TitansUI.beltColor(progress.belt.name);
    final remaining =
        (progress.sessionsRequired - progress.sessionsInBelt)
            .clamp(0, 1 << 30)
            .toInt();

    return _GlassCard(
      accent: beltColor.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROGRESSO DE GRADUACAO',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_beltLabel(progress.belt)} - grau ${progress.degree}/${progress.maxDegree}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.percentToNextBelt,
              backgroundColor: cs.onSurface.withValues(alpha: 0.12),
              color: beltColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: 'NA FAIXA',
                  value: progress.sessionsInBelt.toString(),
                  highlight: beltColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'ESTIMADO',
                  value: progress.sessionsRequired.toString(),
                  highlight: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'PROX. GRAU',
                  value: '$percent%',
                  highlight: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            remaining == 0
                ? 'Meta estimada desta etapa atingida pelos treinos registrados.'
                : 'Faltam cerca de $remaining sessoes para a referencia estimada da faixa.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final TrainingMetrics metrics;

  const _StatsCard({
    required this.cs,
    required this.frequency,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREQUENCIA RECENTE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: '8 SEMANAS',
                  value: '$frequency%',
                  highlight: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: '30 DIAS',
                  value: metrics.recent.toString(),
                  highlight: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: 'MES',
                  value: metrics.month.toString(),
                  highlight: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'ANO',
                  value: metrics.year.toString(),
                  highlight: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatMini(
            title: 'TOTAL DE TREINOS',
            value: metrics.total.toString(),
            highlight: Colors.lightGreenAccent,
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String title;
  final String value;
  final Color highlight;

  const _StatMini({
    required this.title,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: highlight,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebriefInsightsCard extends StatelessWidget {
  final ColorScheme cs;
  final _DebriefInsights insights;

  const _DebriefInsightsCard({required this.cs, required this.insights});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.error.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INTELLIGENCE LITE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'FOCO TECNICO',
            value: insights.technicalFocus,
            empty: 'Registre debriefs nos treinos para gerar foco tecnico.',
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'PONTO DE ATENCAO',
            value: insights.attentionPoint,
            empty: 'Sem dificuldades registradas nos debriefs recentes.',
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'PONTO FORTE RECENTE',
            value: insights.strengthPoint,
            empty: 'Sem sucessos registrados nos debriefs recentes.',
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'INTENSIDADE RECENTE',
            value:
                insights.averageIntensity == null
                    ? null
                    : 'Media recente: ${insights.averageIntensity!.toStringAsFixed(1)}/5',
            empty: 'Sem intensidade registrada nos debriefs recentes.',
          ),
        ],
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final String? value;
  final String empty;

  const _InsightBlock({
    required this.title,
    required this.value,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = value?.trim();
    final hasValue = text != null && text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasValue ? text! : empty,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: hasValue ? 0.86 : 0.62),
          ),
        ),
      ],
    );
  }
}

class _RecommendedFocusCard extends StatelessWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;

  const _RecommendedFocusCard({required this.cs, required this.focus});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(cs, focus.priority);
    final evidence = <String>[
      focus.evidenceLabel,
      if (focus.avgIntensity != null)
        'Intensidade media ${focus.avgIntensity!.toStringAsFixed(1)}/5',
      if (focus.lastTrainedAt != null)
        'Ultimo treino: ${_formatShortDate(focus.lastTrainedAt!)}',
    ];

    return _GlassCard(
      accent: priorityColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'FOCO RECOMENDADO'),
          const SizedBox(height: 12),
          Text(
            focus.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            focus.summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            focus.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, size: 18, color: priorityColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  focus.suggestedAction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InsightBadge(
                label: _priorityLabel(focus.priority),
                color: priorityColor,
                icon: Icons.bolt_outlined,
                muted: focus.priority == RecommendedTrainingFocusPriority.none,
              ),
              for (final tag in focus.tags)
                _InsightBadge(label: tag, color: priorityColor),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in evidence.take(3))
                _InsightBadge(
                  label: label,
                  color: cs.onSurface.withValues(alpha: 0.46),
                  icon: Icons.analytics_outlined,
                  muted: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _priorityColor(
    ColorScheme cs,
    RecommendedTrainingFocusPriority priority,
  ) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return cs.error;
      case RecommendedTrainingFocusPriority.medium:
        return Colors.amber;
      case RecommendedTrainingFocusPriority.low:
        return Colors.lightGreenAccent;
      case RecommendedTrainingFocusPriority.none:
        return cs.onSurface.withValues(alpha: 0.48);
    }
  }

  String _priorityLabel(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return 'Prioridade alta';
      case RecommendedTrainingFocusPriority.medium:
        return 'Prioridade media';
      case RecommendedTrainingFocusPriority.low:
        return 'Prioridade baixa';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }
}

class _SkillMatrixSummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final List<SkillMatrixCategoryEntry> entries;
  final VoidCallback onOpenSkillMatrix;

  const _SkillMatrixSummaryCard({
    required this.cs,
    required this.entries,
    required this.onOpenSkillMatrix,
  });

  @override
  Widget build(BuildContext context) {
    final activeCategories = List<SkillMatrixCategoryEntry>.from(entries)
      ..sort((a, b) {
        final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
        if (sessionsCompare != 0) return sessionsCompare;
        final techniquesCompare = b.techniquesCount.compareTo(a.techniquesCount);
        if (techniquesCompare != 0) return techniquesCompare;
        return a.category.label.compareTo(b.category.label);
      });
    final totalTechniques = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );
    final recurringTechniques = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.consistencyCount,
    );
    final measuredApplicationTechniques = entries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          entry.techniques
              .where((technique) => technique.application == true)
              .length,
    );
    final mainCategory =
        activeCategories.isEmpty ? '--' : activeCategories.first.category.label;

    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(
            title: 'SKILL MATRIX',
            action: TextButton.icon(
              onPressed: onOpenSkillMatrix,
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: const Text('Ver Skill Matrix'),
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'Registre posicao e tecnica nos debriefs para montar sua Skill Matrix.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricPill(
                  label: 'REGISTRADAS',
                  value: totalTechniques.toString(),
                  color: cs.primary,
                ),
                _MetricPill(
                  label: 'RECORRENTES',
                  value: recurringTechniques.toString(),
                  color: Colors.lightGreenAccent,
                ),
                _MetricPill(
                  label: 'CATEGORIA',
                  value: mainCategory,
                  color: cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Resumo dos debriefs: o mapa completo mostra posicao, categoria, recorrencia e intensidade por tecnica.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 12),
            _InsightBadge(
              label: measuredApplicationTechniques > 0
                  ? '$measuredApplicationTechniques tecnicas com aplicacao medida no mapa completo.'
                  : 'Aplicacao em rola/competicao ainda nao e medida nesta versao.',
              color: cs.onSurface.withValues(alpha: 0.42),
              icon: Icons.radio_button_unchecked,
              muted: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeaderCompact extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeaderCompact({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidget = Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        );

        if (action != null && constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, const SizedBox(height: 6), action!],
          );
        }

        return Row(
          children: [Expanded(child: titleWidget), if (action != null) action!],
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 156),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool muted;

  const _InsightBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon = Icons.circle,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedColor = muted ? cs.onSurface.withValues(alpha: 0.42) : color;
    final maxBadgeWidth =
        MediaQuery.sizeOf(context).width < 420 ? 220.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.26)),
        color: resolvedColor.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: resolvedColor),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBadgeWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: muted ? 0.62 : 0.86),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapLiteCard extends StatelessWidget {
  final ColorScheme cs;
  final List<GameMapEntry> entries;
  final VoidCallback onOpenFullMap;

  const _GameMapLiteCard({
    required this.cs,
    required this.entries,
    required this.onOpenFullMap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.secondary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAME MAP LITE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'Registre posicao e tecnica nos debriefs para montar o Game Map.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _GameMapPositionBlock(entry: entries[i]),
                  if (i != entries.length - 1)
                    Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenFullMap,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Ver mapa completo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapPositionBlock extends StatelessWidget {
  final GameMapEntry entry;

  const _GameMapPositionBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.position,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final technique in entry.techniques) ...[
            _GameMapTechniqueBlock(technique: technique),
            if (technique != entry.techniques.last)
              SizedBox(
                height: 12,
                child: Center(
                  child: Container(
                    height: 1,
                    color: cs.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GameMapTechniqueBlock extends StatelessWidget {
  final GameMapTechniqueSummary technique;

  const _GameMapTechniqueBlock({required this.technique});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final intensity = technique.averageIntensity;
    final summary = <String>[
      '${technique.sessionsCount} ${technique.sessionsCount == 1 ? 'sessao' : 'sessoes'}',
      'ultima em ${_formatShortDate(technique.lastTrainedAt)}',
      if (intensity != null)
        'intensidade media ${intensity.toStringAsFixed(1)}/5',
    ];
    final difficulty = _shortDebriefText(technique.recentDifficulty);
    final success = _shortDebriefText(technique.recentSuccess);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '- ${technique.technique}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          summary.join(' - '),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.66)),
        ),
        if (difficulty != null) ...[
          const SizedBox(height: 4),
          Text(
            'Dificuldade recente: $difficulty',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
        ],
        if (success != null) ...[
          const SizedBox(height: 4),
          Text(
            'Sucesso recente: $success',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
        ],
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final ColorScheme cs;
  final List<TrainingSession> items;

  const _RecentActivityCard({required this.cs, required this.items});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ULTIMOS TREINOS',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'Sem treinos registrados.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _TrainingActivityRow(session: items[i]),
                  if (i != items.length - 1)
                    Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TrainingActivityRow extends StatelessWidget {
  final TrainingSession session;

  const _TrainingActivityRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[
      _placeLabel(session.place),
      if ((session.classType ?? '').trim().isNotEmpty)
        session.classType!.trim(),
      if ((session.instructorName ?? '').trim().isNotEmpty)
        session.instructorName!.trim(),
    ];
    final debrief = <String>[
      if ((session.position ?? '').trim().isNotEmpty)
        'Posicao: ${session.position!.trim()}',
      if ((session.technique ?? '').trim().isNotEmpty)
        'Tecnica: ${session.technique!.trim()}',
      if (session.intensity != null) 'Intensidade: ${session.intensity}/5',
      if (_shortDebriefText(session.difficulties) != null)
        'Dificuldade: ${_shortDebriefText(session.difficulties)}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(session.date),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  details.join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (debrief.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              debrief.join(' - '),
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _placeLabel(TrainingPlace place) {
    switch (place) {
      case TrainingPlace.academy:
        return 'Academia';
      case TrainingPlace.home:
        return 'Casa';
      case TrainingPlace.other:
        return 'Outro';
    }
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _GlassCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glow = accent ?? cs.primary;

    return TitansAnimatedSection(
      child: TitansPressableCard(
        accent: glow,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TitansUI.radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        glow.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
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
          icon: Icons.person_search_outlined,
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
