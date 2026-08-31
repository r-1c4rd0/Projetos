import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../model/nutrition_models.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/nutrition_repository.dart';
import '../repository/training_repository.dart';
import '../repository/user_progress_repository.dart';
import '../repository/user_repository.dart';
import '../service/target_resolver.dart';
import '../service/training_aggregator.dart';
import '../service/user_session.dart';
import '../widgets/titans_belt_status_card.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import 'add_training_session_screen.dart';
import 'athlete_registration_screen.dart';
import 'game_map_screen.dart';
import 'nutrition_screen.dart';
import 'skills_screen.dart';
import 'training_screen.dart';

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
  Stream<UserProfile?>? _nutritionProfileStream;
  Stream<List<MealEntry>>? _nutritionMealsStream;
  String? _homeDashboardCacheKey;
  _HomeDashboardViewModel? _homeDashboardCache;
  bool _nutritionFallbackToMock = false;
  Object? _nutritionLoadError;

  void _syncStreams({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
    _homeDashboardCacheKey = null;
    _homeDashboardCache = null;
    _athleteStream = _userRepo.watchUser(academyId: academyId, uid: uid);
    _profileStream = _progressRepo.watchProfile(academyId: academyId, uid: uid);
    _rulesStream = _rulesRepo.watch(academyId);
    _sessionsStream = _trainingRepo.watchSessions(
      academyId: academyId,
      uid: uid,
    );
    _nutritionFallbackToMock = false;
    _nutritionLoadError = null;
    final nutritionRepo = NutritionRepositoryFactory.create(
      academyId: academyId,
      uid: uid,
      onPermissionDeniedFallback: () {
        if (mounted) setState(() => _nutritionFallbackToMock = true);
      },
      onError: (error) {
        if (mounted) setState(() => _nutritionLoadError = error);
      },
    );
    _nutritionProfileStream = nutritionRepo.watchProfile();
    _nutritionMealsStream = nutritionRepo.watchMeals();
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
        appBar: AppBar(title: Text(widget.titleOverride ?? 'In\u00edcio')),
        body:
            widget.targetMode == TargetMode.selectedStudent
                ? const TitansStateView.noStudent(
                  message:
                      'Selecione um aluno no Painel do Mestre para acessar o console do atleta.',
                )
                : const TitansStateView.error(
                  title: 'Perfil n\u00e3o carregado',
                  message:
                      'N\u00e3o foi poss\u00edvel identificar seu usu\u00e1rio para carregar o dashboard.',
                ),
      );
    }

    _syncStreams(academyId: target.academyId, uid: target.uid);

    final cs = Theme.of(context).colorScheme;

    final academyId = target.academyId;
    final uid = target.uid;

    return _wrapModule(
      appBar: AppBar(title: Text(widget.titleOverride ?? 'In\u00edcio')),
      body: StreamBuilder<AppUser?>(
        stream: _athleteStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
          }
          if (userSnap.hasError) {
            return _ErrorState(
              title: 'Erro ao carregar usu\u00e1rio',
              message: userSnap.error.toString(),
            );
          }

          final athlete = userSnap.data;
          if (athlete == null) {
            return const _EmptyState(
              title: 'Usu\u00e1rio n\u00e3o encontrado.',
              subtitle:
                  'Crie academies/{academyId}/users/{uid} com perfil, faixa e grau.',
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
                  title: 'Perfil de progresso n\u00e3o encontrado.',
                  subtitle:
                      'Crie o perfil de progresso com data de in\u00edcio da faixa e estimativa de sess\u00f5es.',
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
                      final homeViewModel = _homeDashboardViewModelFor(
                        academyId: academyId,
                        uid: uid,
                        contextKey:
                            '${widget.targetMode.name}|${actor?.role.name ?? 'none'}',
                        sessions: filtered,
                      );
                      final lastSessions = homeViewModel.lastSessions;
                      final metrics = homeViewModel.metrics;
                      final debriefInsights = homeViewModel.debriefInsights;
                      final gameMapLite = homeViewModel.gameMapLite;
                      final skillMatrix = homeViewModel.skillMatrix;
                      final technicalRadar = homeViewModel.technicalRadar;
                      final recommendedFocus = homeViewModel.recommendedFocus;
                      final nextTraining = homeViewModel.nextTraining;
                      final frequency = homeViewModel.frequency;
                      final isStaffViewingStudent = _isStaffViewingStudent(
                        actor: actor,
                        target: target,
                      );
                      final coachHomeState =
                          isStaffViewingStudent
                              ? _coachStudentHomeStateFor(filtered.length)
                              : null;
                      final isAthleteSelfView =
                          actor?.role == UserRole.athlete && actor?.uid == uid;

                      void openTraining() {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => TrainingScreen(
                                  titleOverride:
                                      widget.targetMode ==
                                              TargetMode.selectedStudent
                                          ? 'Treinos do aluno'
                                          : 'Treinos',
                                  targetMode: widget.targetMode,
                                  explicitTarget: target,
                                  loggedUser: actor,
                                ),
                          ),
                        );
                      }

                      void openRegisterTraining() {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => AddTrainingSessionScreen(
                                  academyId: academyId,
                                  uid: uid,
                                ),
                          ),
                        );
                      }

                      void openNutrition() {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => NutritionScreen(
                                  titleOverride:
                                      isStaffViewingStudent
                                          ? 'Nutri\u00e7\u00e3o do aluno'
                                          : 'Nutri\u00e7\u00e3o',
                                  targetMode: widget.targetMode,
                                  explicitTarget: target,
                                  loggedUser: actor,
                                ),
                          ),
                        );
                      }

                      void openGameMap() {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => GameMapScreen(
                                  academyId: academyId,
                                  uid: uid,
                                  targetName: headerName,
                                  loggedUser: actor,
                                ),
                          ),
                        );
                      }

                      void openSkills() {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => SkillsScreen(
                                  academyId: academyId,
                                  uid: uid,
                                  targetName: headerName,
                                  loggedUser: actor,
                                ),
                          ),
                        );
                      }

                      if (coachHomeState == _CoachStudentHomeState.empty) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final content = SingleChildScrollView(
                              padding:
                                  widget.embedded
                                      ? TitansUI.listPadding(
                                        context,
                                        extra: TitansUI.spaceMd,
                                      )
                                      : TitansUI.listPadding(
                                        context,
                                        extra: 96,
                                      ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: _CoachStudentEmptyCard(
                                  cs: cs,
                                  studentName: headerName,
                                  onRegisterTraining: openRegisterTraining,
                                ),
                              ),
                            );
                            return widget.embedded
                                ? content
                                : SafeArea(bottom: false, child: content);
                          },
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final content = SingleChildScrollView(
                            padding:
                                widget.embedded
                                    ? TitansUI.listPadding(
                                      context,
                                      extra: TitansUI.spaceMd,
                                    )
                                    : TitansUI.listPadding(context, extra: 96),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isAthleteSelfView) ...[
                                    const _AthleteMinimalHeader(),
                                    const SizedBox(height: 12),
                                    _AthleteMinimalIdentityCard(
                                      cs: cs,
                                      name: headerName,
                                      email: headerEmail,
                                      uid: uid,
                                      belt: beltProgress.belt,
                                      degree: beltProgress.degree,
                                      maxDegree: beltProgress.maxDegree,
                                      percentToNext:
                                          beltProgress.percentToNextBelt,
                                      sessionsInBelt:
                                          beltProgress.sessionsInBelt,
                                      sessionsRequired:
                                          beltProgress.sessionsRequired,
                                    ),
                                    const SizedBox(height: 12),
                                    _AthleteMinimalActionsCard(
                                      cs: cs,
                                      onRegisterTraining: openRegisterTraining,
                                      onOpenTraining: openTraining,
                                    ),
                                  ] else ...[
                                    LayoutBuilder(
                                      builder: (context, _) {
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
                                          maxDegree: beltProgress.maxDegree,
                                          percentToNext:
                                              beltProgress.percentToNextBelt,
                                          sessionsInBelt:
                                              beltProgress.sessionsInBelt,
                                          sessionsRequired:
                                              beltProgress.sessionsRequired,
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
                                                                  athleteUid:
                                                                      uid,
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

                                        return athleteCard;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (coachHomeState ==
                                      _CoachStudentHomeState.foundation) ...[
                                    _CoachStudentFoundationCard(
                                      cs: cs,
                                      studentName: headerName,
                                      belt: beltProgress.belt,
                                      degree: beltProgress.degree,
                                      metrics: metrics,
                                      lastSession:
                                          lastSessions.isEmpty
                                              ? null
                                              : lastSessions.first,
                                      onRegisterTraining: openRegisterTraining,
                                    ),
                                    if (recommendedFocus.hasRecommendation ||
                                        nextTraining.hasRecommendation) ...[
                                      const SizedBox(height: 12),
                                      _CoachTechnicalFocusCard(
                                        cs: cs,
                                        focus: recommendedFocus,
                                        nextTraining: nextTraining,
                                        compact: true,
                                        onOpenEvidence: openTraining,
                                        onOpenSkills: openSkills,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    _RecentActivityTimelineCard(
                                      cs: cs,
                                      items: lastSessions,
                                      onOpenTraining: openTraining,
                                    ),
                                  ] else ...[
                                    if (isStaffViewingStudent) ...[
                                      _CoachStudentActiveSummaryCard(
                                        cs: cs,
                                        studentName: headerName,
                                        belt: beltProgress.belt,
                                        degree: beltProgress.degree,
                                        metrics: metrics,
                                        frequency: frequency,
                                        lastSession:
                                            lastSessions.isEmpty
                                                ? null
                                                : lastSessions.first,
                                        focus: recommendedFocus,
                                        onOpenEvidence: openTraining,
                                      ),
                                      const SizedBox(height: 12),
                                      _CoachTechnicalFocusCard(
                                        cs: cs,
                                        focus: recommendedFocus,
                                        nextTraining: nextTraining,
                                        compact: false,
                                        onOpenEvidence: openTraining,
                                        onOpenSkills: openSkills,
                                      ),
                                      const SizedBox(height: 12),
                                      _HomeTechnicalRadarSlot(
                                        cs: cs,
                                        radar: technicalRadar,
                                        onOpenMap: openGameMap,
                                      ),
                                      const SizedBox(height: 12),
                                      _CoachActiveLiteModules(
                                        cs: cs,
                                        metrics: metrics,
                                        frequency: frequency,
                                        insights: debriefInsights,
                                        skillMatrix: skillMatrix,
                                        gameMap: gameMapLite,
                                        profileStream: _nutritionProfileStream,
                                        mealsStream: _nutritionMealsStream,
                                        isNutritionFallback:
                                            _nutritionFallbackToMock,
                                        hasNutritionLoadError:
                                            _nutritionLoadError != null,
                                        onOpenSkills: openSkills,
                                        onOpenGameMap: openGameMap,
                                        onOpenNutrition: openNutrition,
                                      ),
                                      const SizedBox(height: 12),
                                      _RecentActivityTimelineCard(
                                        cs: cs,
                                        items: lastSessions,
                                        onOpenTraining: openTraining,
                                      ),
                                    ] else ...[
                                      if (isAthleteSelfView) ...[
                                        _AthleteMinimalNextTrainingCard(
                                          cs: cs,
                                          recommendation: nextTraining,
                                        ),
                                        const SizedBox(height: 12),
                                        _HomeTechnicalRadarSlot(
                                          cs: cs,
                                          radar: technicalRadar,
                                          onOpenMap: openGameMap,
                                          onRegisterTraining:
                                              openRegisterTraining,
                                        ),
                                        const SizedBox(height: 12),
                                        _AthleteMinimalMetricsCard(
                                          cs: cs,
                                          frequency: frequency,
                                          metrics: metrics,
                                        ),
                                        if (lastSessions.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          _RecentActivityTimelineCard(
                                            cs: cs,
                                            items: lastSessions,
                                            onOpenTraining: openTraining,
                                          ),
                                        ],
                                      ] else ...[
                                        _NextTrainingCard(
                                          cs: cs,
                                          recommendation: nextTraining,
                                        ),
                                        const SizedBox(height: 12),
                                        _DashboardPrimaryActionCard(
                                          cs: cs,
                                          nextTraining: nextTraining,
                                          onRegisterTraining:
                                              openRegisterTraining,
                                          onOpenTraining: openTraining,
                                        ),
                                        const SizedBox(height: 12),
                                        _RecommendedFocusCard(
                                          cs: cs,
                                          focus: recommendedFocus,
                                        ),
                                        const SizedBox(height: 12),
                                        _DashboardQuickActionsCard(
                                          cs: cs,
                                          onOpenGameMap: openGameMap,
                                          onOpenSkills: openSkills,
                                        ),
                                        const SizedBox(height: 12),
                                        _HomeTechnicalRadarSlot(
                                          cs: cs,
                                          radar: technicalRadar,
                                          onOpenMap: openGameMap,
                                          onRegisterTraining:
                                              openRegisterTraining,
                                        ),
                                        const SizedBox(height: 12),
                                        LayoutBuilder(
                                          builder: (context, c) {
                                            final isWide = c.maxWidth >= 980;
                                            final left = _StatsCard(
                                              cs: cs,
                                              frequency: frequency,
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
                                                  Expanded(
                                                    flex: 4,
                                                    child: left,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    flex: 6,
                                                    child: right,
                                                  ),
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
                                        _NutritionDashboardLiteCard(
                                          cs: cs,
                                          profileStream:
                                              _nutritionProfileStream,
                                          mealsStream: _nutritionMealsStream,
                                          isStudentView: isStaffViewingStudent,
                                          isFallback: _nutritionFallbackToMock,
                                          hasLoadError:
                                              _nutritionLoadError != null,
                                          hideWhenEmpty: isStaffViewingStudent,
                                          onOpenNutrition: openNutrition,
                                        ),
                                        const SizedBox(height: 12),
                                        _SkillMatrixSummaryCard(
                                          cs: cs,
                                          entries: skillMatrix,
                                          onOpenSkillMatrix: openGameMap,
                                        ),
                                        const SizedBox(height: 12),
                                        _GameMapLiteCard(
                                          cs: cs,
                                          entries: gameMapLite,
                                          onOpenFullMap: openGameMap,
                                        ),
                                        const SizedBox(height: 12),
                                        _RecentActivityTimelineCard(
                                          cs: cs,
                                          items: lastSessions,
                                          onOpenTraining: openTraining,
                                        ),
                                      ],
                                    ],
                                  ],
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
    final isStaff =
        loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return isStaff && loggedUser.academyId == target.academyId;
  }

  bool _isStaffViewingStudent({
    required AppUser? actor,
    required TargetProfile target,
  }) {
    if (actor == null) return false;
    final isStaff =
        actor.role == UserRole.admin || actor.role == UserRole.professor;
    return isStaff &&
        actor.academyId == target.academyId &&
        actor.uid != target.uid;
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
                                    'Gradua\u00e7\u00e3o atualizada',
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

  _HomeDashboardViewModel _homeDashboardViewModelFor({
    required String academyId,
    required String uid,
    required String contextKey,
    required List<TrainingSession> sessions,
  }) {
    final cacheKey = _homeDashboardSnapshotKey(
      academyId: academyId,
      uid: uid,
      contextKey: contextKey,
      sessions: sessions,
    );
    final cached = _homeDashboardCache;
    if (_homeDashboardCacheKey == cacheKey && cached != null) {
      return cached;
    }

    final next = _HomeDashboardViewModel.fromSessions(
      sessions,
      buildDebriefInsights: _buildDebriefInsights,
      calcFrequency: _calcFrequency,
    );
    _homeDashboardCacheKey = cacheKey;
    _homeDashboardCache = next;
    return next;
  }

  String _homeDashboardSnapshotKey({
    required String academyId,
    required String uid,
    required String contextKey,
    required List<TrainingSession> sessions,
  }) {
    final today = DateTime.now();
    final buffer =
        StringBuffer()
          ..write(academyId)
          ..write('|')
          ..write(uid)
          ..write('|')
          ..write(contextKey)
          ..write('|')
          ..write(today.year)
          ..write('-')
          ..write(today.month)
          ..write('-')
          ..write(today.day)
          ..write('|')
          ..write(sessions.length);

    for (final session in sessions) {
      buffer
        ..write('|s:')
        ..write(session.id)
        ..write('@')
        ..write(session.date.microsecondsSinceEpoch)
        ..write(':')
        ..write(session.place.name)
        ..write(':')
        ..write(session.academyId ?? '')
        ..write(':')
        ..write(session.uid ?? '')
        ..write(':')
        ..write(session.source ?? '')
        ..write(':')
        ..write(session.attendanceSessionId ?? '')
        ..write(':')
        ..write(session.classType ?? '')
        ..write(':')
        ..write(session.position ?? '')
        ..write(':')
        ..write(session.technique ?? '')
        ..write(':')
        ..write(session.successes ?? '')
        ..write(':')
        ..write(session.difficulties ?? '')
        ..write(':')
        ..write(session.intensity ?? '')
        ..write(':')
        ..write(session.debriefNotes ?? '')
        ..write(':')
        ..write(session.applicationContext ?? '')
        ..write(':')
        ..write(session.techniqueOutcome ?? '');

      final scoreKeys = session.scores.keys.toList()..sort();
      for (final key in scoreKeys) {
        buffer
          ..write('|score:')
          ..write(key)
          ..write('=')
          ..write(session.scores[key]);
      }

      for (final entry in session.effectiveTechniqueEntries) {
        buffer
          ..write('|t:')
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
    }

    return buffer.toString();
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

    final progressInBelt =
        (sessionsInBelt / sessionsRequired).clamp(0.0, 1.0).toDouble();

    return _BeltProgress(
      belt: belt,
      degree: safeDegree,
      maxDegree: maxDeg,
      sessionsInBelt: sessionsInBelt,
      sessionsRequired: sessionsRequired,
      percentToNextBelt: progressInBelt,
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
      for (final entry in session.effectiveTechniqueEntries) {
        final technique = _cleanDebriefText(entry.technique);
        if (technique == null) {
          continue;
        }
        final position =
            _cleanDebriefText(entry.position) ??
            _cleanDebriefText(session.position);
        focus.add(position == null ? technique : '$technique em $position');
      }

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

class _HomeDashboardViewModel {
  final List<TrainingSession> sessions;
  final List<TrainingSession> recentSessions;
  final List<TrainingSession> lastSessions;
  final TrainingMetrics metrics;
  final int frequency;
  final _DebriefInsights debriefInsights;
  final List<GameMapEntry> gameMapLite;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final _HomeTechnicalRadarViewModel technicalRadar;
  final RecommendedTrainingFocus recommendedFocus;
  final NextTrainingRecommendation nextTraining;

  const _HomeDashboardViewModel({
    required this.sessions,
    required this.recentSessions,
    required this.lastSessions,
    required this.metrics,
    required this.frequency,
    required this.debriefInsights,
    required this.gameMapLite,
    required this.skillMatrix,
    required this.technicalRadar,
    required this.recommendedFocus,
    required this.nextTraining,
  });

  factory _HomeDashboardViewModel.fromSessions(
    List<TrainingSession> sessions, {
    required _DebriefInsights Function(List<TrainingSession> sessions)
    buildDebriefInsights,
    required int Function(List<TrainingSession> sessions) calcFrequency,
  }) {
    final stableSessions = List<TrainingSession>.unmodifiable(sessions);
    final recentSessions = List<TrainingSession>.unmodifiable(
      stableSessions.reversed.take(10),
    );
    final lastSessions = List<TrainingSession>.unmodifiable(
      recentSessions.take(5),
    );

    return _HomeDashboardViewModel(
      sessions: stableSessions,
      recentSessions: recentSessions,
      lastSessions: lastSessions,
      metrics: TrainingAggregator.metrics(stableSessions),
      frequency: calcFrequency(stableSessions),
      debriefInsights: buildDebriefInsights(recentSessions),
      gameMapLite: List<GameMapEntry>.unmodifiable(
        TrainingAggregator.buildGameMap(recentSessions, limit: 10),
      ),
      skillMatrix: List<SkillMatrixCategoryEntry>.unmodifiable(
        TrainingAggregator.buildSkillMatrix(stableSessions, limit: 50),
      ),
      technicalRadar: _HomeTechnicalRadarViewModel.fromSessions(stableSessions),
      recommendedFocus: TrainingAggregator.buildRecommendedFocus(
        stableSessions,
        recentLimit: 20,
      ),
      nextTraining: TrainingAggregator.buildNextTrainingRecommendation(
        stableSessions,
        recentLimit: 20,
      ),
    );
  }
}

enum _CoachStudentHomeState { empty, foundation, active }

_CoachStudentHomeState _coachStudentHomeStateFor(int trainingCount) {
  if (trainingCount <= 0) {
    return _CoachStudentHomeState.empty;
  }
  if (trainingCount <= 4) {
    return _CoachStudentHomeState.foundation;
  }
  return _CoachStudentHomeState.active;
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
  return TitansUI.beltLabel(belt.name);
}

Color _beltProgressRingColor(BeltColor belt) {
  switch (belt) {
    case BeltColor.white:
      return Colors.white.withValues(alpha: 0.92);
    case BeltColor.blue:
      return TitansUI.neonBlue;
    case BeltColor.purple:
      return TitansUI.neonPurple;
    case BeltColor.brown:
      return const Color(0xFF8D6E63);
    case BeltColor.black:
      return const Color(0xFF2B2F38);
  }
}

class _AthleteCard extends StatelessWidget {
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNext;
  final int sessionsInBelt;
  final int sessionsRequired;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditGraduation;

  const _AthleteCard({
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNext,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    this.onEditProfile,
    this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TitansBeltStatusCard(
            belt: belt,
            degree: degree,
            maxDegree: maxDegree,
            title: 'Gradua\u00e7\u00e3o atual',
            progressPercent: percentToNext,
            progressLabel: 'Progresso da faixa',
            subtitle:
                '$sessionsInBelt/$sessionsRequired sess\u00f5es na faixa atual',
            compact: true,
            framed: false,
            onEdit: onEditGraduation,
          ),
          if (onEditProfile != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar perfil'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AthleteMinimalHeader extends StatelessWidget {
  const _AthleteMinimalHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TITANS BJJ',
          style: TextStyle(
            color: cs.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Início',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _BeltProgressRing extends StatefulWidget {
  final ColorScheme colorScheme;
  final double value;
  final Color color;

  const _BeltProgressRing({
    required this.colorScheme,
    required this.value,
    required this.color,
  });

  @override
  State<_BeltProgressRing> createState() => _BeltProgressRingState();
}

class _BeltProgressRingState extends State<_BeltProgressRing> {
  static const _motion = TitansMotionSpec.emphasis();
  late double _beginValue;
  late double _targetValue;

  @override
  void initState() {
    super.initState();
    _beginValue = 0;
    _targetValue = _safeValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant _BeltProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = _safeValue(widget.value);
    if (nextValue == _targetValue) return;
    _beginValue = _targetValue;
    _targetValue = nextValue;
  }

  @override
  Widget build(BuildContext context) {
    final duration = TitansMotion.duration(context, _motion);
    final curve = TitansMotion.curve(_motion);
    if (duration == Duration.zero) {
      return _buildRing(_targetValue);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _beginValue, end: _targetValue),
      duration: duration,
      curve: curve,
      onEnd: () {
        _beginValue = _targetValue;
      },
      builder: (context, animatedValue, child) {
        return _buildRing(animatedValue);
      },
    );
  }

  Widget _buildRing(double animatedValue) {
    final cs = widget.colorScheme;
    final safeValue = _safeValue(animatedValue);
    final finalValue = _safeValue(widget.value);

    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: safeValue,
              strokeWidth: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(finalValue * 100).round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'faixa',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _safeValue(double value) => value.clamp(0.0, 1.0).toDouble();
}

class _AthleteMinimalIdentityCard extends StatelessWidget {
  final ColorScheme cs;
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNext;
  final int sessionsInBelt;
  final int sessionsRequired;

  const _AthleteMinimalIdentityCard({
    required this.cs,
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNext,
    required this.sessionsInBelt,
    required this.sessionsRequired,
  });

  @override
  Widget build(BuildContext context) {
    final identity = email.isEmpty ? 'ID ${_shortUid(uid)}' : email;
    final ringColor = _beltProgressRingColor(belt);

    return _GlassCard(
      accent: ringColor.withValues(alpha: 0.30),
      child: Row(
        children: [
          _BeltProgressRing(
            colorScheme: cs,
            value: percentToNext,
            color: ringColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InsightBadge(
                      label: '${_beltLabel(belt)} · $degreeº grau',
                      color: TitansUI.beltColor(belt.name),
                      icon: Icons.military_tech_outlined,
                    ),
                    _DegreeDots(degree: degree, maxDegree: maxDegree, cs: cs),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$sessionsInBelt/$sessionsRequired treinos na faixa atual',
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
        ],
      ),
    );
  }
}

class _DegreeDots extends StatelessWidget {
  final int degree;
  final int maxDegree;
  final ColorScheme cs;

  const _DegreeDots({
    required this.degree,
    required this.maxDegree,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final dots = maxDegree <= 0 ? 4 : maxDegree;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dots; i++) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i < degree
                      ? Colors.amber
                      : cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
          if (i != dots - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _AthleteMinimalActionsCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onRegisterTraining;
  final VoidCallback onOpenTraining;

  const _AthleteMinimalActionsCard({
    required this.cs,
    required this.onRegisterTraining,
    required this.onOpenTraining,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: Colors.amber.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onRegisterTraining,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Registrar treino'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onOpenTraining,
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: const Text('Treinos'),
          ),
        ],
      ),
    );
  }
}

class _AthleteMinimalNextTrainingCard extends StatelessWidget {
  final ColorScheme cs;
  final NextTrainingRecommendation recommendation;

  const _AthleteMinimalNextTrainingCard({
    required this.cs,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(cs, recommendation.priority);
    final tags = recommendation.tags.take(3).toList();

    return _GlassCard(
      accent: priorityColor.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeaderCompact(title: 'PRÓXIMO TREINO'),
          const SizedBox(height: 10),
          Text(
            recommendation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.hasRecommendation
                ? recommendation.subtitle
                : (recommendation.emptyMessage ?? recommendation.subtitle),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (recommendation.hasRecommendation) ...[
            const SizedBox(height: 8),
            Text(
              recommendation.objective,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  _InsightBadge(label: tag, color: priorityColor),
              ],
            ),
          ],
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
        return cs.primary;
    }
  }
}

class _AthleteMinimalMetricsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final TrainingMetrics metrics;

  const _AthleteMinimalMetricsCard({
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
          const _SectionHeaderCompact(title: 'MÉTRICAS RÁPIDAS'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _StatMini(
                title: '8 SEMANAS',
                value: '$frequency%',
                highlight: cs.primary,
              ),
              _StatMini(
                title: '30 DIAS',
                value: metrics.recent.toString(),
                highlight: Colors.lightGreenAccent,
              ),
              _StatMini(
                title: 'ANO',
                value: metrics.year.toString(),
                highlight: Colors.amber,
              ),
              _StatMini(
                title: 'TOTAL',
                value: metrics.total.toString(),
                highlight: cs.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortUid(String uid) {
  if (uid.length <= 6) return uid.toUpperCase();
  return uid.substring(0, 6).toUpperCase();
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
            'FREQUÊNCIA RECENTE',
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
            title: 'FOCO T\u00c9CNICO',
            value: insights.technicalFocus,
            empty:
                'Registre debriefs nos treinos para gerar foco t\u00e9cnico.',
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'PONTO DE ATENÇÃO',
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
                    : 'Média recente: ${insights.averageIntensity!.toStringAsFixed(1)}/5',
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
          hasValue ? text : empty,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: hasValue ? 0.86 : 0.62),
          ),
        ),
      ],
    );
  }
}

class _CoachStudentEmptyCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final VoidCallback onRegisterTraining;

  const _CoachStudentEmptyCard({
    required this.cs,
    required this.studentName,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = studentName.trim().split(RegExp(r'\s+')).first;
    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'COME\u00c7AR A ACOMPANHAR'),
          const SizedBox(height: 12),
          Text(
            "$firstName ainda n\u00e3o tem treinos registrados.",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Registre o primeiro treino para iniciar o acompanhamento.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRegisterTraining,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Registrar primeiro treino'),
          ),
        ],
      ),
    );
  }
}

class _CoachStudentFoundationCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final BeltColor belt;
  final int degree;
  final TrainingMetrics metrics;
  final TrainingSession? lastSession;
  final VoidCallback onRegisterTraining;

  const _CoachStudentFoundationCard({
    required this.cs,
    required this.studentName,
    required this.belt,
    required this.degree,
    required this.metrics,
    required this.lastSession,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : _formatShortDate(lastSession!.date);
    return _GlassCard(
      accent: cs.secondary.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'VISÃO DO ALUNO'),
          const SizedBox(height: 12),
          Text(
            studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${_beltLabel(belt)} - $degreeº grau',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'TREINOS',
                value: metrics.total.toString(),
                color: cs.primary,
              ),
              _MetricPill(
                label: '30 DIAS',
                value: metrics.recent.toString(),
                color: Colors.amber,
              ),
              _MetricPill(
                label: 'ÚLTIMO',
                value: lastTrainingLabel,
                color: cs.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Perfil técnico ainda em formação. Continue registrando treinos para ampliar as evidências.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 14),
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRegisterTraining,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Registrar treino'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachStudentActiveSummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final String studentName;
  final BeltColor belt;
  final int degree;
  final TrainingMetrics metrics;
  final int frequency;
  final TrainingSession? lastSession;
  final RecommendedTrainingFocus focus;
  final VoidCallback onOpenEvidence;

  const _CoachStudentActiveSummaryCard({
    required this.cs,
    required this.studentName,
    required this.belt,
    required this.degree,
    required this.metrics,
    required this.frequency,
    required this.lastSession,
    required this.focus,
    required this.onOpenEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : _formatShortDate(lastSession!.date);
    final attentionLabel = _activeAttentionLabel(focus);

    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(
            title: 'VISÃO DO ALUNO',
            action: TextButton.icon(
              onPressed: onOpenEvidence,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Ver evidências'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            studentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${_beltLabel(belt)} - $degreeº grau',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                label: 'TREINOS',
                value: metrics.total.toString(),
                color: cs.primary,
              ),
              _MetricPill(
                label: '30 DIAS',
                value: metrics.recent.toString(),
                color: Colors.amber,
              ),
              _MetricPill(
                label: '8 SEMANAS',
                value: '$frequency%',
                color: cs.secondary,
              ),
              _MetricPill(
                label: 'ÚLTIMO',
                value: lastTrainingLabel,
                color: Colors.lightGreenAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InsightBlock(
            title: 'ATENÇÃO TÉCNICA PRINCIPAL',
            value: attentionLabel,
            empty: 'Atenção técnica ainda não definida.',
          ),
        ],
      ),
    );
  }

  String? _activeAttentionLabel(RecommendedTrainingFocus focus) {
    if (!focus.hasRecommendation) return null;
    final technique = focus.technique?.trim();
    if (technique == null || technique.isEmpty) return null;
    final position = focus.position?.trim();
    if (position == null || position.isEmpty) return technique;
    return '$technique em $position';
  }
}

class _CoachTechnicalFocusCard extends StatelessWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;
  final NextTrainingRecommendation nextTraining;
  final bool compact;
  final VoidCallback onOpenEvidence;
  final VoidCallback onOpenSkills;

  const _CoachTechnicalFocusCard({
    required this.cs,
    required this.focus,
    required this.nextTraining,
    required this.compact,
    required this.onOpenEvidence,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    final technique = _technicalFocusTechnique();
    final position = _technicalFocusPosition();
    final hasFocus = technique != null || position != null;
    final status = _technicalFocusStatus();
    final reason = _shortFocusText(
      focus.hasRecommendation ? focus.reason : nextTraining.subtitle,
      fallback: 'Foco técnico ainda em construção.',
      maxLength: compact ? 96 : 132,
    );
    final action = _shortFocusText(
      focus.hasRecommendation
          ? focus.suggestedAction
          : nextTraining.technicalDrill,
      fallback: 'Registrar debrief completo no próximo treino.',
      maxLength: compact ? 80 : 112,
    );
    final accent = _technicalFocusColor(cs, focus.priority);

    if (compact && !hasFocus) {
      return const SizedBox.shrink();
    }

    return _GlassCard(
      accent: accent.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'FOCO PARA O PRÓXIMO TREINO'),
          const SizedBox(height: 10),
          Text(
            technique ?? 'Foco técnico em formação',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          if (position != null) ...[
            const SizedBox(height: 3),
            Text(
              position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            reason,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
          ),
          const SizedBox(height: 10),
          Text(
            'Recomendação:',
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
            action,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.84),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenEvidence,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Ver evidências'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSkills,
                  icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: const Text('Abrir Skills'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _technicalFocusTechnique() {
    final focusTechnique = focus.technique?.trim();
    if (focusTechnique != null && focusTechnique.isNotEmpty) {
      return focusTechnique;
    }
    final nextTechnique = nextTraining.focusTechnique?.trim();
    if (nextTechnique != null && nextTechnique.isNotEmpty) {
      return nextTechnique;
    }
    return null;
  }

  String? _technicalFocusPosition() {
    final focusPosition = focus.position?.trim();
    if (focusPosition != null && focusPosition.isNotEmpty) {
      return focusPosition;
    }
    final nextPosition = nextTraining.focusPosition?.trim();
    if (nextPosition != null && nextPosition.isNotEmpty) {
      return nextPosition;
    }
    return null;
  }

  String _technicalFocusStatus() {
    if (!focus.hasRecommendation && !nextTraining.hasRecommendation) {
      return focus.confidenceLabel;
    }
    switch (focus.priority) {
      case RecommendedTrainingFocusPriority.high:
      case RecommendedTrainingFocusPriority.medium:
        return 'Precisa de ajuste';
      case RecommendedTrainingFocusPriority.low:
        return 'Repetir para ganhar recorrência';
      case RecommendedTrainingFocusPriority.none:
        return focus.confidenceLabel;
    }
  }

  Color _technicalFocusColor(
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
        return cs.primary;
    }
  }

  String _shortFocusText(
    String? value, {
    required String fallback,
    required int maxLength,
  }) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return fallback;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3).trimRight()}...';
  }
}

class _HomeTechnicalRadarViewModel {
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final int classifiedEvidenceCount;
  final int awaitingClassificationCount;
  final int sessionsCount;
  final TechnicalRadarAxis? topAxis;

  const _HomeTechnicalRadarViewModel({
    required this.axisEvidence,
    required this.classifiedEvidenceCount,
    required this.awaitingClassificationCount,
    required this.sessionsCount,
    required this.topAxis,
  });

  bool get hasClassifiedEvidence => classifiedEvidenceCount > 0;

  int get occupiedAxisCount {
    return axisEvidence.values.where((value) => value > 0).length;
  }

  bool get hasRadarChart => occupiedAxisCount >= 2;

  bool get hasEvidenceSummary => classifiedEvidenceCount > 0;

  String get evidenceLabel {
    final suffix = classifiedEvidenceCount == 1 ? 'evidência' : 'evidências';
    return '$classifiedEvidenceCount $suffix';
  }

  String get sessionLabel {
    final suffix = sessionsCount == 1 ? 'sessão' : 'sessões';
    return '$sessionsCount $suffix';
  }

  String get classifiedEvidenceLabel {
    final suffix =
        classifiedEvidenceCount == 1
            ? 'evidência classificada'
            : 'evidências classificadas';
    return '$classifiedEvidenceCount $suffix';
  }

  String get topAxisLabel {
    final axis = topAxis;
    if (axis == null) return 'Evidências em construção';
    return '${axis.displayLabel} mais presente';
  }

  factory _HomeTechnicalRadarViewModel.fromSessions(
    List<TrainingSession> sessions,
  ) {
    final summary = const GetTechnicalRadarSummary()(
      sessions,
      limit: sessions.length,
    );

    return _HomeTechnicalRadarViewModel(
      axisEvidence: summary.axisEvidence,
      classifiedEvidenceCount: summary.classifiedEvidences,
      awaitingClassificationCount: summary.unclassifiedEvidences,
      sessionsCount: summary.sessionsCount,
      topAxis: summary.topAxis,
    );
  }
}

class _HomeTechnicalRadarSlot extends StatelessWidget {
  final ColorScheme cs;
  final _HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;
  final VoidCallback? onRegisterTraining;

  const _HomeTechnicalRadarSlot({
    required this.cs,
    required this.radar,
    required this.onOpenMap,
    this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    if (radar.hasRadarChart) {
      return _HomeTechnicalRadarCard(
        cs: cs,
        radar: radar,
        onOpenMap: onOpenMap,
      );
    }

    if (radar.hasEvidenceSummary) {
      return _HomeTechnicalRadarSummaryCard(
        cs: cs,
        radar: radar,
        onOpenMap: onOpenMap,
      );
    }

    return _HomeTechnicalRadarInitialCard(
      cs: cs,
      onOpenMap: onOpenMap,
      onRegisterTraining: onRegisterTraining,
    );
  }
}

class _HomeTechnicalRadarInitialCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onOpenMap;
  final VoidCallback? onRegisterTraining;

  const _HomeTechnicalRadarInitialCard({
    required this.cs,
    required this.onOpenMap,
    this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Inicial',
            badgeIcon: Icons.radar_outlined,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final radarSize = _homeRadarSizeForWidth(
                constraints.maxWidth,
                desired: compact ? 160.0 : 176.0,
              );
              final visual = _HomeRadarVisualShell(
                cs: cs,
                size: radarSize,
                child: CustomPaint(
                  size: Size.square(radarSize),
                  painter: _HomeTechnicalRadarInitialPainter(cs),
                ),
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registre treinos para ativar seu mapa técnico',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.90),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A leitura técnica aparece conforme suas evidências de treino evoluem.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Baseado em evidências dos treinos.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    visual,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: details),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  visual,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label:
                onRegisterTraining == null
                    ? 'Explorar mapa'
                    : 'Registrar treino',
            icon: onRegisterTraining == null ? Icons.map_outlined : Icons.add,
            onPressed: onRegisterTraining ?? onOpenMap,
            filled: onRegisterTraining != null,
          ),
        ],
      ),
    );
  }
}

class _HomeTechnicalRadarSummaryCard extends StatelessWidget {
  final ColorScheme cs;
  final _HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;

  const _HomeTechnicalRadarSummaryCard({
    required this.cs,
    required this.radar,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Base: ${radar.sessionLabel}',
            badgeIcon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final radarSize = _homeRadarSizeForWidth(
                constraints.maxWidth,
                desired: compact ? 164.0 : 182.0,
              );
              final visual = _HomeRadarVisualShell(
                cs: cs,
                size: radarSize,
                highlightedAxis: radar.topAxis,
                child: CustomPaint(
                  size: Size.square(radarSize),
                  painter: _HomeTechnicalRadarFormationPainter(
                    cs,
                    axisEvidence: radar.axisEvidence,
                    highlightedAxis: radar.topAxis,
                  ),
                ),
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mapa técnico em formação',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.90),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trilhas apagadas indicam eixos ainda sem evidência registrada.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InsightBadge(
                        label:
                            'Eixo mais presente: ${radar.topAxis?.displayLabel ?? 'em formação'}',
                        color: cs.secondary,
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _InsightBadge(
                        label: radar.classifiedEvidenceLabel,
                        color: cs.primary,
                        icon: Icons.radar_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Baseado em evidências dos treinos.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    visual,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: details),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  visual,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
          ),
        ],
      ),
    );
  }
}

class _HomeTechnicalRadarCard extends StatelessWidget {
  final ColorScheme cs;
  final _HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;

  const _HomeTechnicalRadarCard({
    required this.cs,
    required this.radar,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Base: ${radar.sessionLabel}',
            badgeIcon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final radarSize = _homeRadarSizeForWidth(
                constraints.maxWidth,
                desired: compact ? 168.0 : 190.0,
              );
              final radarVisual = _HomeRadarVisualShell(
                cs: cs,
                size: radarSize,
                highlightedAxis: radar.topAxis,
                child: CustomPaint(
                  size: Size.square(radarSize),
                  painter: _HomeTechnicalRadarPainter(
                    cs,
                    axisEvidence: radar.axisEvidence,
                    highlightedAxis: radar.topAxis,
                  ),
                ),
              );
              final radarDetails = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InsightBadge(
                        label: 'Destaque: ${radar.topAxisLabel}',
                        color: cs.secondary,
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _InsightBadge(
                        label: radar.classifiedEvidenceLabel,
                        color: cs.primary,
                        icon: Icons.radar_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Baseado em evid\u00eancias dos treinos.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    radarVisual,
                    const SizedBox(height: 14),
                    radarDetails,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  radarVisual,
                  const SizedBox(width: 16),
                  Expanded(child: radarDetails),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
          ),
        ],
      ),
    );
  }
}

class _HomeRadarHeader extends StatelessWidget {
  final ColorScheme cs;
  final String badgeLabel;
  final IconData badgeIcon;

  const _HomeRadarHeader({
    required this.cs,
    required this.badgeLabel,
    required this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeaderCompact(title: 'MAPA TÉCNICO'),
            const SizedBox(height: 4),
            Text(
              'Leitura técnica por evidências',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
        final badge = _InsightBadge(
          label: badgeLabel,
          color: cs.primary,
          icon: badgeIcon,
        );

        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 8), badge],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 10),
            badge,
          ],
        );
      },
    );
  }
}

class _HomeRadarVisualShell extends StatelessWidget {
  final ColorScheme cs;
  final double size;
  final Widget child;
  final TechnicalRadarAxis? highlightedAxis;

  const _HomeRadarVisualShell({
    required this.cs,
    required this.size,
    required this.child,
    this.highlightedAxis,
  });

  @override
  Widget build(BuildContext context) {
    final outerWidth = size + 132;
    final outerHeight = size + 76;

    return RepaintBoundary(
      child: SizedBox(
        width: outerWidth,
        height: outerHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HomeRadarOrbitPainter(
                  cs: cs,
                  radarSize: size,
                  highlightedAxis: highlightedAxis,
                ),
              ),
            ),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.20),
                      cs.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.58, 1],
                  ),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.18),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox.square(dimension: size, child: child),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _HomeRadarAxisEndpointLabel(
                  cs: cs,
                  axis: TechnicalRadarAxis.retention,
                  selected: highlightedAxis == TechnicalRadarAxis.retention,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: (outerHeight - 28) / 2,
              child: _HomeRadarAxisEndpointLabel(
                cs: cs,
                axis: TechnicalRadarAxis.transition,
                selected: highlightedAxis == TechnicalRadarAxis.transition,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _HomeRadarAxisEndpointLabel(
                  cs: cs,
                  axis: TechnicalRadarAxis.control,
                  selected: highlightedAxis == TechnicalRadarAxis.control,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: (outerHeight - 28) / 2,
              child: _HomeRadarAxisEndpointLabel(
                cs: cs,
                axis: TechnicalRadarAxis.attack,
                selected: highlightedAxis == TechnicalRadarAxis.attack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRadarOrbitPainter extends CustomPainter {
  final ColorScheme cs;
  final double radarSize;
  final TechnicalRadarAxis? highlightedAxis;

  const _HomeRadarOrbitPainter({
    required this.cs,
    required this.radarSize,
    required this.highlightedAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = radarSize / 2 + 20;
    final orbitPaint =
        Paint()
          ..color = cs.primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
    final orbitGlowPaint =
        Paint()
          ..color = cs.primary.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7;

    _paintHomeRadarPolygon(canvas, center, orbitRadius, orbitGlowPaint);
    _paintHomeRadarPolygon(canvas, center, orbitRadius, orbitPaint);

    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final axisColor =
          axis == highlightedAxis
              ? cs.secondary
              : _homeRadarAxisColor(axis, cs);
      final start = _homeRadarPoint(center, radarSize / 2 + 6, i);
      final end = _homeRadarPoint(center, orbitRadius - 8, i);
      final selected = axis == highlightedAxis;

      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = axisColor.withValues(alpha: selected ? 0.34 : 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : 1.0,
      );
      canvas.drawCircle(
        end,
        selected ? 4.6 : 3.2,
        Paint()..color = axisColor.withValues(alpha: selected ? 0.70 : 0.32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HomeRadarOrbitPainter oldDelegate) {
    return oldDelegate.cs != cs ||
        oldDelegate.radarSize != radarSize ||
        oldDelegate.highlightedAxis != highlightedAxis;
  }
}

class _HomeRadarAxisEndpointLabel extends StatelessWidget {
  final ColorScheme cs;
  final TechnicalRadarAxis axis;
  final bool selected;

  const _HomeRadarAxisEndpointLabel({
    required this.cs,
    required this.axis,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? cs.secondary : _homeRadarAxisColor(axis, cs);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 62, maxWidth: 74),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: selected ? 0.20 : 0.09),
              accent.withValues(alpha: selected ? 0.07 : 0.025),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0.62 : 0.26),
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 16,
                      spreadRadius: -7,
                    ),
                  ]
                  : const [],
        ),
        child: SizedBox(
          height: 26,
          child: Center(
            child: Text(
              axis.displayLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    selected
                        ? cs.secondary
                        : cs.onSurface.withValues(alpha: 0.78),
                fontSize: 10.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeRadarCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  const _HomeRadarCta({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (!filled) ...[
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 16),
        ],
      ],
    );

    final cs = Theme.of(context).colorScheme;
    final minimumSize = const Size.fromHeight(44);

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minimumSize,
            backgroundColor: cs.secondary,
            foregroundColor: Colors.black,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: minimumSize,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.secondary.withValues(alpha: 0.38)),
          backgroundColor: cs.secondary.withValues(alpha: 0.07),
        ),
        child: child,
      ),
    );
  }
}

class _HomeTechnicalRadarInitialPainter extends CustomPainter {
  final ColorScheme cs;

  const _HomeTechnicalRadarInitialPainter(this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, math.min(size.width, size.height) / 2 - 16);
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              cs.primary.withValues(alpha: 0.18),
              cs.primary.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius * 1.16),
          );
    final gridPaint =
        Paint()
          ..color = cs.onSurface.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final softGridPaint =
        Paint()
          ..color = cs.primary.withValues(alpha: 0.11)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2;
    final axisPaint =
        Paint()
          ..color = cs.onSurface.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius * 1.12, glowPaint);
    for (final step in const [0.2, 0.4, 0.6, 0.8, 1.0]) {
      _paintHomeRadarPolygon(
        canvas,
        center,
        radius * step,
        step == 1.0 ? softGridPaint : gridPaint,
      );
    }

    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final axisColor = _homeRadarAxisColor(axis, cs);
      final end = _homeRadarPoint(center, radius, i);
      canvas.drawLine(center, end, axisPaint);
      canvas.drawCircle(
        end,
        7.2,
        Paint()..color = axisColor.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        end,
        3.9,
        Paint()..color = axisColor.withValues(alpha: 0.50),
      );
    }

    canvas.drawCircle(
      center,
      5.8,
      Paint()..color = cs.primary.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      center,
      3.2,
      Paint()..color = cs.primary.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeTechnicalRadarInitialPainter oldDelegate) {
    return oldDelegate.cs != cs;
  }
}

class _HomeTechnicalRadarFormationPainter extends CustomPainter {
  final ColorScheme cs;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final TechnicalRadarAxis? highlightedAxis;

  const _HomeTechnicalRadarFormationPainter(
    this.cs, {
    required this.axisEvidence,
    required this.highlightedAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, math.min(size.width, size.height) / 2 - 16);
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              cs.primary.withValues(alpha: 0.16),
              cs.secondary.withValues(alpha: 0.05),
              cs.primary.withValues(alpha: 0),
            ],
            stops: const [0, 0.58, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    final gridPaint =
        Paint()
          ..color = cs.onSurface.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final outerGridPaint =
        Paint()
          ..color = cs.primary.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2;

    canvas.drawCircle(center, radius * 1.12, glowPaint);
    for (final step in const [0.2, 0.4, 0.6, 0.8, 1.0]) {
      _paintHomeRadarPolygon(
        canvas,
        center,
        radius * step,
        step == 1.0 ? outerGridPaint : gridPaint,
      );
    }

    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final axisColor = _homeRadarAxisColor(axis, cs);
      final end = _homeRadarPoint(center, radius, i);
      final hasEvidence = (axisEvidence[axis] ?? 0) > 0;
      final isHighlighted = axis == highlightedAxis && hasEvidence;
      final lineColor = isHighlighted ? cs.secondary : axisColor;
      final lineAlpha = isHighlighted ? 0.72 : (hasEvidence ? 0.34 : 0.16);

      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = lineColor.withValues(alpha: lineAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 2.2 : 1.2,
      );
      if (isHighlighted) {
        canvas.drawLine(
          center,
          end,
          Paint()
            ..color = cs.secondary.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7,
        );
      }
      canvas.drawCircle(
        end,
        isHighlighted ? 8.6 : 6.4,
        Paint()
          ..color = lineColor.withValues(alpha: isHighlighted ? 0.18 : 0.08),
      );
      canvas.drawCircle(
        end,
        isHighlighted ? 4.8 : 3.2,
        Paint()
          ..color = lineColor.withValues(alpha: isHighlighted ? 0.94 : 0.36),
      );
      if (!hasEvidence) {
        final lockedPoint = _homeRadarPoint(center, radius * 0.58, i);
        canvas.drawCircle(
          lockedPoint,
          2.1,
          Paint()..color = cs.onSurface.withValues(alpha: 0.16),
        );
      }
    }

    canvas.drawCircle(
      center,
      5.4,
      Paint()..color = cs.primary.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      3.2,
      Paint()..color = cs.primary.withValues(alpha: 0.70),
    );
  }

  @override
  bool shouldRepaint(
    covariant _HomeTechnicalRadarFormationPainter oldDelegate,
  ) {
    return oldDelegate.cs != cs ||
        oldDelegate.axisEvidence != axisEvidence ||
        oldDelegate.highlightedAxis != highlightedAxis;
  }
}

class _HomeTechnicalRadarPainter extends CustomPainter {
  final ColorScheme cs;
  final Map<TechnicalRadarAxis, int> axisEvidence;
  final TechnicalRadarAxis? highlightedAxis;

  const _HomeTechnicalRadarPainter(
    this.cs, {
    required this.axisEvidence,
    required this.highlightedAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(0.0, math.min(size.width, size.height) / 2 - 16);
    final maxEvidence = _homeRadarMaxEvidence(axisEvidence);
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              cs.primary.withValues(alpha: 0.18),
              cs.secondary.withValues(alpha: 0.06),
              cs.primary.withValues(alpha: 0),
            ],
            stops: const [0, 0.56, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    final gridPaint =
        Paint()
          ..color = cs.onSurface.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final outerGridPaint =
        Paint()
          ..color = cs.primary.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2;

    canvas.drawCircle(center, radius * 1.12, glowPaint);
    for (final step in const [0.2, 0.4, 0.6, 0.8, 1.0]) {
      _paintHomeRadarPolygon(
        canvas,
        center,
        radius * step,
        step == 1.0 ? outerGridPaint : gridPaint,
      );
    }

    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final axisColor = _homeRadarAxisColor(axis, cs);
      final point = _homeRadarPoint(center, radius, i);
      final isHighlighted = axis == highlightedAxis;
      canvas.drawLine(
        center,
        point,
        Paint()
          ..color = (isHighlighted ? cs.secondary : axisColor).withValues(
            alpha: isHighlighted ? 0.58 : 0.32,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 1.8 : 1.15,
      );
    }

    final path = Path();
    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final value = axisEvidence[axis] ?? 0;
      final factor = value <= 0 ? 0.0 : 0.16 + (value / maxEvidence) * 0.78;
      final point = _homeRadarPoint(center, radius * factor, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = cs.primary.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            cs.primary.withValues(alpha: 0.26),
            cs.secondary.withValues(alpha: 0.10),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = cs.primary.withValues(alpha: 0.86)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
      final axis = _homeTechnicalRadarAxisOrder[i];
      final value = axisEvidence[axis] ?? 0;
      final hasEvidence = value > 0;
      final factor = hasEvidence ? 0.16 + (value / maxEvidence) * 0.78 : 0.0;
      final point = _homeRadarPoint(center, radius * factor, i);
      final axisColor = _homeRadarAxisColor(axis, cs);
      final isHighlighted = axis == highlightedAxis && hasEvidence;
      final nodeColor = isHighlighted ? cs.secondary : axisColor;

      canvas.drawCircle(
        point,
        isHighlighted ? 9.4 : (hasEvidence ? 7.2 : 3.0),
        Paint()
          ..color = nodeColor.withValues(alpha: isHighlighted ? 0.20 : 0.12),
      );
      canvas.drawCircle(
        point,
        isHighlighted ? 5.2 : (hasEvidence ? 4.2 : 2.4),
        Paint()..color = nodeColor.withValues(alpha: hasEvidence ? 0.92 : 0.18),
      );
    }

    canvas.drawCircle(
      center,
      5.8,
      Paint()..color = cs.primary.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      3.2,
      Paint()..color = cs.primary.withValues(alpha: 0.74),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeTechnicalRadarPainter oldDelegate) {
    return oldDelegate.cs != cs ||
        oldDelegate.axisEvidence != axisEvidence ||
        oldDelegate.highlightedAxis != highlightedAxis;
  }
}

void _paintHomeRadarPolygon(
  Canvas canvas,
  Offset center,
  double radius,
  Paint paint,
) {
  final path = Path();
  for (var i = 0; i < _homeTechnicalRadarAxisOrder.length; i++) {
    final point = _homeRadarPoint(center, radius, i);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  canvas.drawPath(path..close(), paint);
}

Offset _homeRadarPoint(Offset center, double radius, int index) {
  final angle = _homeRadarAngle(index);
  return center + Offset(math.cos(angle), math.sin(angle)) * radius;
}

Color _homeRadarAxisColor(TechnicalRadarAxis axis, ColorScheme cs) {
  final index = _homeTechnicalRadarAxisOrder.indexOf(axis);
  if (index < 0) return cs.primary;
  return _homeTechnicalRadarAxisColors[index];
}

int _homeRadarMaxEvidence(Map<TechnicalRadarAxis, int> axisEvidence) {
  return axisEvidence.values.fold<int>(
    1,
    (max, value) => value > max ? value : max,
  );
}

const _homeTechnicalRadarAxisColors = <Color>[
  Color(0xFF4CC9F0),
  Color(0xFFE9C46A),
  Color(0xFFB026FF),
  Color(0xFF2D6BFF),
];
double _homeRadarSizeForWidth(double maxWidth, {required double desired}) {
  if (!maxWidth.isFinite) return desired;
  const horizontalLabelReserve = 132.0;
  const minimumReadableSize = 140.0;
  final availableForCanvas = maxWidth - horizontalLabelReserve;
  if (availableForCanvas <= minimumReadableSize) {
    return math.max(128.0, availableForCanvas);
  }
  return math
      .min(desired, availableForCanvas)
      .clamp(minimumReadableSize, desired);
}

double _homeRadarAngle(int index) {
  return -math.pi / 2 +
      index * (math.pi * 2 / _homeTechnicalRadarAxisOrder.length);
}

const _homeTechnicalRadarAxisOrder = <TechnicalRadarAxis>[
  TechnicalRadarAxis.retention,
  TechnicalRadarAxis.transition,
  TechnicalRadarAxis.control,
  TechnicalRadarAxis.attack,
];

class _CoachActiveLiteModules extends StatelessWidget {
  final ColorScheme cs;
  final TrainingMetrics metrics;
  final int frequency;
  final _DebriefInsights insights;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final List<GameMapEntry> gameMap;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isNutritionFallback;
  final bool hasNutritionLoadError;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenNutrition;

  const _CoachActiveLiteModules({
    required this.cs,
    required this.metrics,
    required this.frequency,
    required this.insights,
    required this.skillMatrix,
    required this.gameMap,
    required this.profileStream,
    required this.mealsStream,
    required this.isNutritionFallback,
    required this.hasNutritionLoadError,
    required this.onOpenSkills,
    required this.onOpenGameMap,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = <Widget>[
          _CoachLiteModuleCard(
            cs: cs,
            title: 'CONSISTÊNCIA',
            icon: Icons.event_available_outlined,
            accent: cs.primary,
            lines: [
              _CoachLiteLine('Regularidade', '$frequency% em 8 semanas'),
              _CoachLiteLine('Últimos 30 dias', metrics.recent.toString()),
            ],
            note: _consistencyNote(),
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'LEITURA TÉCNICA',
            icon: Icons.visibility_outlined,
            accent: Colors.amber,
            lines: [
              _CoachLiteLine('Foco', insights.technicalFocus ?? '—'),
              _CoachLiteLine('Atenção', insights.attentionPoint ?? '—'),
              _CoachLiteLine('Intensidade', _intensityLabel()),
            ],
            note: 'Leitura baseada nos debriefs recentes.',
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'REPERTÓRIO TÉCNICO',
            icon: Icons.psychology_alt_outlined,
            accent: Colors.lightGreenAccent,
            lines: [
              _CoachLiteLine('Técnicas', _techniquesCount().toString()),
              _CoachLiteLine('Aplicações', _applicationsCount().toString()),
              _CoachLiteLine('Mais presente', _mainTechniqueLabel()),
            ],
            actionLabel: 'Abrir Skills',
            onAction: onOpenSkills,
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'GAME MAP INSIGHT',
            icon: Icons.account_tree_outlined,
            accent: cs.secondary,
            lines: [
              _CoachLiteLine('Posições', gameMap.length.toString()),
              _CoachLiteLine('Mais presente', _mainPositionLabel()),
            ],
            actionLabel: 'Explorar mapa',
            onAction: onOpenGameMap,
          ),
          _CoachNutritionCompactCard(
            cs: cs,
            profileStream: profileStream,
            mealsStream: mealsStream,
            isFallback: isNutritionFallback,
            hasLoadError: hasNutritionLoadError,
            onOpenNutrition: onOpenNutrition,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 10) / 2, child: card),
          ],
        );
      },
    );
  }

  String _consistencyNote() {
    if (metrics.recent <= 0) return 'Sem treinos nos últimos 30 dias.';
    if (frequency <= 0) return 'Regularidade ainda sem sinal recente.';
    return 'Ritmo recente pronto para acompanhamento.';
  }

  String _intensityLabel() {
    final value = insights.averageIntensity;
    if (value == null) return '—';
    return '${value.toStringAsFixed(1)}/5';
  }

  int _techniquesCount() {
    return skillMatrix.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );
  }

  int _applicationsCount() {
    return skillMatrix.fold<int>(
      0,
      (sum, entry) =>
          sum +
          entry.techniques
              .where((technique) => technique.application == true)
              .length,
    );
  }

  String _mainTechniqueLabel() {
    final techniques = <SkillMatrixTechniqueEntry>[
      for (final entry in skillMatrix) ...entry.techniques,
    ];
    if (techniques.isEmpty) return '—';
    techniques.sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
    final technique = techniques.first;
    final position = technique.position?.trim();
    if (position == null || position.isEmpty) return technique.technique;
    return '${technique.technique} · $position';
  }

  String _mainPositionLabel() {
    if (gameMap.isEmpty) return '—';
    final entries = List<GameMapEntry>.from(gameMap)
      ..sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
    return entries.first.position;
  }
}

class _CoachLiteLine {
  final String label;
  final String value;

  const _CoachLiteLine(this.label, this.value);
}

class _CoachLiteModuleCard extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final IconData icon;
  final Color accent;
  final List<_CoachLiteLine> lines;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CoachLiteModuleCard({
    required this.cs,
    required this.title,
    required this.icon,
    required this.accent,
    required this.lines,
    this.note,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: _SectionHeaderCompact(title: title)),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            _CoachLiteDataRow(line: line),
            if (line != lines.last) const SizedBox(height: 7),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachLiteDataRow extends StatelessWidget {
  final _CoachLiteLine line;

  const _CoachLiteDataRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 98,
          child: Text(
            line.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            line.value.trim().isEmpty ? '—' : line.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachNutritionCompactCard extends StatelessWidget {
  final ColorScheme cs;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isFallback;
  final bool hasLoadError;
  final VoidCallback onOpenNutrition;

  const _CoachNutritionCompactCard({
    required this.cs,
    required this.profileStream,
    required this.mealsStream,
    required this.isFallback,
    required this.hasLoadError,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.tertiary.withValues(alpha: 0.22),
      child: StreamBuilder<UserProfile?>(
        stream: profileStream,
        builder: (context, profileSnap) {
          return StreamBuilder<List<MealEntry>>(
            stream: mealsStream,
            builder: (context, mealsSnap) {
              final isLoading =
                  profileSnap.connectionState == ConnectionState.waiting ||
                  mealsSnap.connectionState == ConnectionState.waiting;
              final profile = profileSnap.data;
              final meals = mealsSnap.data ?? const <MealEntry>[];
              final recentMeals = _recentMealsCount(meals);
              final status =
                  hasLoadError || isFallback
                      ? 'Indisponível'
                      : (profile == null ? 'Pendente' : 'Ativo');
              final summary =
                  hasLoadError || isFallback
                      ? 'Resumo indisponível agora.'
                      : (recentMeals == 0
                          ? 'Sem refeições recentes.'
                          : '$recentMeals refeições recentes.');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        color: cs.tertiary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _SectionHeaderCompact(title: 'NUTRIÇÃO'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const TitansSkeletonCard(lines: 2)
                  else ...[
                    _CoachLiteDataRow(line: _CoachLiteLine('Perfil', status)),
                    const SizedBox(height: 7),
                    _CoachLiteDataRow(line: _CoachLiteLine('Resumo', summary)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onOpenNutrition,
                        child: const Text('Ver Nutrição'),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  int _recentMealsCount(List<MealEntry> meals) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return meals.where((meal) => !meal.date.isBefore(since)).length;
  }
}

class _DashboardPrimaryActionCard extends StatelessWidget {
  final ColorScheme cs;
  final NextTrainingRecommendation nextTraining;
  final VoidCallback onRegisterTraining;
  final VoidCallback onOpenTraining;

  const _DashboardPrimaryActionCard({
    required this.cs,
    required this.nextTraining,
    required this.onRegisterTraining,
    required this.onOpenTraining,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.primary.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'A\u00c7\u00c3O PRINCIPAL'),
          const SizedBox(height: 10),
          Text(
            'Registrar treino',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            nextTraining.hasRecommendation
                ? 'Use o pr\u00f3ximo treino como guia e registre o resultado depois.'
                : 'Registre a pr\u00f3xima sess\u00e3o para liberar recomenda\u00e7\u00f5es mais precisas.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRegisterTraining,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Registrar treino'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenTraining,
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('Abrir treinos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickActionsCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenSkills;

  const _DashboardQuickActionsCard({
    required this.cs,
    required this.onOpenGameMap,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.tertiary.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeaderCompact(title: 'ATALHO ÚTIL'),
                const SizedBox(height: 5),
                Text(
                  'Game Map e repertório técnico em atalhos internos.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _QuickActionButton(
                    icon: Icons.map_outlined,
                    label: 'Game Map',
                    onPressed: onOpenGameMap,
                  ),
                  _QuickActionButton(
                    icon: Icons.psychology_alt_outlined,
                    label: 'Skills',
                    onPressed: onOpenSkills,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _NutritionDashboardLiteCard extends StatelessWidget {
  final ColorScheme cs;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isStudentView;
  final bool isFallback;
  final bool hasLoadError;
  final bool hideWhenEmpty;
  final VoidCallback onOpenNutrition;

  const _NutritionDashboardLiteCard({
    required this.cs,
    required this.profileStream,
    required this.mealsStream,
    required this.isStudentView,
    required this.isFallback,
    required this.hasLoadError,
    this.hideWhenEmpty = false,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.secondary.withValues(alpha: 0.26),
      child: StreamBuilder<UserProfile?>(
        stream: profileStream,
        builder: (context, profileSnap) {
          return StreamBuilder<List<MealEntry>>(
            stream: mealsStream,
            builder: (context, mealsSnap) {
              final isLoading =
                  profileSnap.connectionState == ConnectionState.waiting ||
                  mealsSnap.connectionState == ConnectionState.waiting;
              final profile = profileSnap.data;
              final meals = mealsSnap.data ?? const <MealEntry>[];
              final recentMeals = _recentMeals(meals);
              final registeredMeals = recentMeals.length;
              final recentKcal = recentMeals.fold<int>(
                0,
                (sum, meal) => sum + meal.totalKcal(),
              );
              if (hideWhenEmpty &&
                  !isLoading &&
                  !hasLoadError &&
                  !isFallback &&
                  profile == null &&
                  meals.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Nutri\u00e7\u00e3o',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenNutrition,
                        child: const Text('Abrir nutri\u00e7\u00e3o'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const TitansSkeletonCard(lines: 2)
                  else ...[
                    if (isStudentView) ...[
                      Text(
                        'Visualiza\u00e7\u00e3o do aluno.',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (hasLoadError || isFallback) ...[
                      Text(
                        'Resumo indispon\u00edvel agora.',
                        style: TextStyle(
                          color: cs.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'N\u00e3o foi poss\u00edvel carregar os dados nutricionais.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _NutritionLiteMetric(
                            label: 'Perfil nutricional',
                            value: profile == null ? 'Pendente' : 'Ativo',
                          ),
                          _NutritionLiteMetric(
                            label: 'Energia estimada',
                            value:
                                profile == null
                                    ? (isStudentView
                                        ? 'Pendente'
                                        : 'Completar perfil')
                                    : '${profile.tdee().toStringAsFixed(0)} kcal/dia',
                          ),
                          _NutritionLiteMetric(
                            label: 'Refei\u00e7\u00f5es',
                            value:
                                registeredMeals == 0
                                    ? 'Sem refei\u00e7\u00f5es registradas'
                                    : '$registeredMeals recentes',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile == null
                            ? (isStudentView
                                ? 'Perfil nutricional ainda n\u00e3o preenchido.'
                                : 'Complete seu perfil para estimar energia de rotina.')
                            : 'Refer\u00eancia de rotina, n\u00e3o prescri\u00e7\u00e3o.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontSize: 12,
                        ),
                      ),
                      if (registeredMeals > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Energia registrada recentemente: $recentKcal kcal.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.68),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<MealEntry> _recentMeals(List<MealEntry> meals) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return meals.where((meal) => !meal.date.isBefore(since)).toList();
  }
}

class _NutritionLiteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _NutritionLiteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: Colors.black.withValues(alpha: 0.16),
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
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RecommendedFocusCard extends StatefulWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;

  const _RecommendedFocusCard({required this.cs, required this.focus});

  @override
  State<_RecommendedFocusCard> createState() => _RecommendedFocusCardState();
}

class _RecommendedFocusCardState extends State<_RecommendedFocusCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final focus = widget.focus;
    final priorityColor = _priorityColor(cs, focus.priority);
    final primaryTags = focus.tags.take(1).toList();
    final secondaryTags = focus.tags.skip(1).toList();
    final evidence = <String>[
      ...focus.evidenceTags,
      focus.confidenceLabel,
      focus.evidenceLabel,
      if (focus.avgIntensity != null)
        'Intensidade média ${focus.avgIntensity!.toStringAsFixed(1)}/5',
      if (focus.lastTrainedAt != null)
        'Último treino: ${_formatShortDate(focus.lastTrainedAt!)}',
    ];

    return _GlassCard(
      accent: priorityColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeaderCompact(title: 'FOCO RECOMENDADO'),
                        const SizedBox(height: 10),
                        Text(
                          focus.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focus.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: priorityColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _focusStatusLabel(focus.priority),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: priorityColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            focus.reason,
            maxLines: _expanded ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
          ),
          const SizedBox(height: 10),
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
              for (final tag in primaryTags)
                _InsightBadge(label: tag, color: priorityColor),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: priorityColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ação sugerida:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.62),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            focus.suggestedAction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (secondaryTags.isNotEmpty || evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in secondaryTags.take(3))
                        _InsightBadge(label: tag, color: priorityColor),
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
              ],
            ),
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

  String _focusStatusLabel(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
      case RecommendedTrainingFocusPriority.medium:
        return 'Precisa de ajuste';
      case RecommendedTrainingFocusPriority.low:
        return 'Manter atenção';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }

  String _priorityLabel(RecommendedTrainingFocusPriority priority) {
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return 'Prioridade alta';
      case RecommendedTrainingFocusPriority.medium:
        return 'Prioridade média';
      case RecommendedTrainingFocusPriority.low:
        return 'Prioridade baixa';
      case RecommendedTrainingFocusPriority.none:
        return 'Aguardando debrief';
    }
  }
}

class _NextTrainingCard extends StatefulWidget {
  final ColorScheme cs;
  final NextTrainingRecommendation recommendation;

  const _NextTrainingCard({required this.cs, required this.recommendation});

  @override
  State<_NextTrainingCard> createState() => _NextTrainingCardState();
}

class _NextTrainingCardState extends State<_NextTrainingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final recommendation = widget.recommendation;
    final priorityColor = _priorityColor(cs, recommendation.priority);
    final visibleTags = recommendation.tags.take(2).toList();
    final hiddenTags = recommendation.tags.skip(2).toList();

    return _GlassCard(
      accent: priorityColor.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                recommendation.hasRecommendation
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeaderCompact(title: 'PRÓXIMO TREINO'),
                        const SizedBox(height: 10),
                        Text(
                          recommendation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendation.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.70),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommendation.hasRecommendation) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: priorityColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!recommendation.hasRecommendation) ...[
            Text(
              recommendation.emptyMessage ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.76)),
            ),
          ] else ...[
            Text(
              recommendation.objective,
              maxLines: _expanded ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.78)),
            ),
            if (visibleTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in visibleTags)
                    _InsightBadge(label: tag, color: priorityColor),
                ],
              ),
            ],
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState:
                  _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.self_improvement_outlined,
                    label: 'Aquecimento técnico',
                    text: recommendation.warmupSuggestion,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 10),
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.repeat_outlined,
                    label: 'Drill principal',
                    text: recommendation.technicalDrill,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 10),
                  _NextTrainingBlock(
                    cs: cs,
                    icon: Icons.fact_check_outlined,
                    label: 'Aplicação/checagem',
                    text: recommendation.applicationSuggestion,
                    color: priorityColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    recommendation.intensityGuidance,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hiddenTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in hiddenTags.take(2))
                          _InsightBadge(label: tag, color: priorityColor),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
}

class _NextTrainingBlock extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _NextTrainingBlock({
    required this.cs,
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
    final activeCategories = List<SkillMatrixCategoryEntry>.from(
      entries,
    )..sort((a, b) {
      final sessionsCompare = b.sessionsCount.compareTo(a.sessionsCount);
      if (sessionsCompare != 0) return sessionsCompare;
      final techniquesCompare = b.techniquesCount.compareTo(a.techniquesCount);
      if (techniquesCompare != 0) return techniquesCompare;
      return a.category.displayLabel.compareTo(b.category.displayLabel);
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
        activeCategories.isEmpty
            ? '--'
            : activeCategories.first.category.displayLabel;

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
              'Registre posi\u00e7\u00e3o e t\u00e9cnica nos debriefs para montar sua Skill Matrix.',
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
              'Resumo dos debriefs: o mapa completo mostra posi\u00e7\u00e3o, categoria, recorr\u00eancia e intensidade por t\u00e9cnica.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 12),
            _InsightBadge(
              label:
                  measuredApplicationTechniques > 0
                      ? '${TrainingAggregator.techniqueCountLabel(measuredApplicationTechniques)} com aplica\u00e7\u00e3o medida no mapa completo.'
                      : 'Aplica\u00e7\u00e3o ainda n\u00e3o medida.',
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
    final positionsCount = entries.length;
    final techniquesCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.techniques.length,
    );
    final sessionsCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.sessionsCount,
    );
    final mainEntry =
        entries.isEmpty
            ? null
            : (List<GameMapEntry>.from(entries)..sort(
              (a, b) => b.sessionsCount.compareTo(a.sessionsCount),
            )).first;
    final mainTechniques =
        mainEntry?.techniques.take(3).toList() ??
        const <GameMapTechniqueSummary>[];
    final recentSignal = _firstGameMapSignal(entries);

    return _GlassCard(
      accent: cs.secondary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAME MAP INSIGHT',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Baseado nos últimos treinos',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'Registre posição e técnica nos debriefs para montar o Game Map.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else if (mainEntry != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GameMapInsightPill(
                      label: 'Posições',
                      value: positionsCount.toString(),
                      color: cs.primary,
                    ),
                    _GameMapInsightPill(
                      label: 'Técnicas',
                      value: techniquesCount.toString(),
                      color: cs.secondary,
                    ),
                    _GameMapInsightPill(
                      label: 'Sessões',
                      value: sessionsCount.toString(),
                      color: Colors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Olhe primeiro para',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mainEntry.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final technique in mainTechniques)
                      _GameMapInsightTechniqueChip(technique: technique),
                  ],
                ),
                if (recentSignal != null) ...[
                  const SizedBox(height: 12),
                  _GameMapInsightSignal(signal: recentSignal),
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

class _GameMapInsightPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GameMapInsightPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightTechniqueChip extends StatelessWidget {
  final GameMapTechniqueSummary technique;

  const _GameMapInsightTechniqueChip({required this.technique});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart_outlined, size: 15, color: cs.secondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              technique.technique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            TrainingAggregator.sessionCountLabel(technique.sessionsCount),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightSignal extends StatelessWidget {
  final _GameMapInsightSignalViewModel signal;

  const _GameMapInsightSignal({required this.signal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: signal.color.withValues(alpha: 0.08),
        border: Border.all(color: signal.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signal.icon, size: 18, color: signal.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${signal.label}: ${signal.text}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameMapInsightSignalViewModel {
  final String label;
  final String text;
  final IconData icon;
  final Color color;

  const _GameMapInsightSignalViewModel({
    required this.label,
    required this.text,
    required this.icon,
    required this.color,
  });
}

_GameMapInsightSignalViewModel? _firstGameMapSignal(
  List<GameMapEntry> entries,
) {
  for (final entry in entries) {
    for (final technique in entry.techniques) {
      final difficulty = _shortDebriefText(technique.recentDifficulty);
      if (difficulty != null) {
        return _GameMapInsightSignalViewModel(
          label: 'Atenção recente',
          text: difficulty,
          icon: Icons.warning_amber_outlined,
          color: Colors.amber,
        );
      }

      final success = _shortDebriefText(technique.recentSuccess);
      if (success != null) {
        return _GameMapInsightSignalViewModel(
          label: 'Sucesso recente',
          text: success,
          icon: Icons.check_circle_outline,
          color: Colors.lightGreenAccent,
        );
      }
    }
  }

  return null;
}

class _RecentActivityTimelineCard extends StatelessWidget {
  final ColorScheme cs;
  final List<TrainingSession> items;
  final VoidCallback onOpenTraining;

  const _RecentActivityTimelineCard({
    required this.cs,
    required this.items,
    required this.onOpenTraining,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(3).toList();
    final usefulPlaces =
        visibleItems
            .map((session) => session.place)
            .where((place) => place != TrainingPlace.academy)
            .toSet();
    final showPlace = usefulPlaces.isNotEmpty;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ATIVIDADE RECENTE',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenTraining,
                child: const Text('Ver todos os treinos →'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleItems.isEmpty)
            Text(
              '—',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else
            Column(
              children: [
                for (var i = 0; i < visibleItems.length; i++) ...[
                  _RecentActivityTimelineRow(
                    session: visibleItems[i],
                    showPlace: showPlace,
                  ),
                  if (i != visibleItems.length - 1)
                    Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentActivityTimelineRow extends StatelessWidget {
  final TrainingSession session;
  final bool showPlace;

  const _RecentActivityTimelineRow({
    required this.session,
    required this.showPlace,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = _RecentActivityItem.fromSession(session);
    final detailParts = <String>[
      if (item.context != null) item.context!,
      if (item.outcome != null) item.outcome!,
      if (item.applicationFallback) 'Aplicação registrada',
      if (item.intensity != null) 'Intensidade ${item.intensity}/5',
      if (showPlace && session.place != TrainingPlace.academy)
        _coachTimelinePlaceLabel(session.place),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              _formatTimelineDate(session.date),
              style: TextStyle(
                color: cs.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  detailParts.isEmpty
                      ? 'Registro técnico'
                      : detailParts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityItem {
  final String title;
  final String? context;
  final String? outcome;
  final bool applicationFallback;
  final int? intensity;

  const _RecentActivityItem({
    required this.title,
    required this.context,
    required this.outcome,
    required this.applicationFallback,
    required this.intensity,
  });

  factory _RecentActivityItem.fromSession(TrainingSession session) {
    final entries = session.effectiveTechniqueEntries;
    TrainingTechniqueEntry? primaryEntry;
    for (final entry in entries) {
      if (_cleanDebriefText(entry.technique) != null) {
        primaryEntry = entry;
        break;
      }
    }

    final technique =
        _cleanDebriefText(primaryEntry?.technique) ??
        _cleanDebriefText(session.technique);
    final position =
        _cleanDebriefText(primaryEntry?.position) ??
        _cleanDebriefText(session.position);
    final context =
        TrainingSession.applicationContextLabel(
          primaryEntry?.applicationContext,
        ) ??
        TrainingSession.applicationContextLabel(session.applicationContext) ??
        _cleanDebriefText(session.classType);
    final outcome =
        TrainingSession.techniqueOutcomeLabel(primaryEntry?.techniqueOutcome) ??
        TrainingSession.techniqueOutcomeLabel(session.techniqueOutcome) ??
        _shortDebriefText(session.successes, maxLength: 42);
    final title = switch ((technique, position)) {
      (final String tech, final String pos) => '$tech · $pos',
      (final String tech, null) => tech,
      (null, final String pos) => pos,
      _ => 'Treino registrado',
    };

    return _RecentActivityItem(
      title: title,
      context: context,
      outcome: outcome,
      applicationFallback: technique != null && outcome == null,
      intensity: session.intensity,
    );
  }
}

String _coachTimelinePlaceLabel(TrainingPlace place) {
  switch (place) {
    case TrainingPlace.academy:
      return 'Academia';
    case TrainingPlace.home:
      return 'Casa';
    case TrainingPlace.other:
      return 'Outro local';
  }
}

String _formatTimelineDate(DateTime date) {
  const months = <String>[
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
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${months[date.month - 1]}';
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
