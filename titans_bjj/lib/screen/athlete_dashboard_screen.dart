import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme_controller.dart';
import '../core/titans_live_motion.dart';
import '../core/titans_ui.dart';
import '../features/home/application/home_dashboard_use_cases.dart';
import '../features/home/domain/home_dashboard_models.dart';
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
import '../widgets/charts/titans_technical_radar.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import '../widgets/quick_log_sheet.dart';
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
  late final GetHomeDashboardSummary _getHomeDashboardSummary =
      const GetHomeDashboardSummary();
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
                      final isSelfProfile =
                          widget.targetMode == TargetMode.self &&
                          actor?.uid == uid;
                      final isAthleteSelfView =
                          actor?.role == UserRole.athlete && isSelfProfile;

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

                      void openQuickLog() {
                        showQuickLogSheet(
                          context: context,
                          academyId: academyId,
                          uid: uid,
                          recentSessions: filtered,
                          canSave: canEditTarget,
                          onOpenFullForm: openRegisterTraining,
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
                                    _AthleteMinimalHeader(
                                      onToggleTheme: themeController.toggle,
                                      onSignOut:
                                          () => FirebaseAuth.instance.signOut(),
                                    ),
                                    const SizedBox(height: 12),
                                    _AthleteHomeCockpitHero(
                                      cs: cs,
                                      focus: recommendedFocus,
                                      nextTraining: nextTraining,
                                      lastSession:
                                          lastSessions.isEmpty
                                              ? null
                                              : lastSessions.first,
                                      onRegisterTraining: openQuickLog,
                                    ),
                                    const SizedBox(height: 12),
                                    _AthleteMinimalMetricsCard(
                                      cs: cs,
                                      frequency: frequency,
                                      metrics: metrics,
                                    ),
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
                                      hasOfficialRule:
                                          beltProgress.hasOfficialRule,
                                    ),
                                  ] else ...[
                                    if (isSelfProfile) ...[
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _AthleteHomeAccountMenu(
                                          onToggleTheme: themeController.toggle,
                                          onSignOut:
                                              () =>
                                                  FirebaseAuth.instance
                                                      .signOut(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
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
                                          hasOfficialRule:
                                              beltProgress.hasOfficialRule,
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
                                                            (
                                                              _,
                                                            ) => AthleteRegistrationScreen(
                                                              academyId:
                                                                  academyId,
                                                              athleteUid: uid,
                                                              mode:
                                                                  isSelfProfile
                                                                      ? AthleteRegistrationMode
                                                                          .editSelf
                                                                      : AthleteRegistrationMode
                                                                          .editStudent,
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
                                      _HomeIntelligenceDeck(
                                        cs: cs,
                                        dashboard: homeViewModel,
                                        radar: technicalRadar,
                                        beltProgress: beltProgress,
                                        onOpenMap: openGameMap,
                                        onOpenTraining: openTraining,
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
                                        _HomeIntelligenceDeck(
                                          cs: cs,
                                          dashboard: homeViewModel,
                                          radar: technicalRadar,
                                          beltProgress: beltProgress,
                                          onOpenMap: openGameMap,
                                          onOpenTraining: openTraining,
                                          onRegisterTraining:
                                              openRegisterTraining,
                                        ),
                                        if (lastSessions.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          _RecentActivityTimelineCard(
                                            cs: cs,
                                            items: lastSessions,
                                            compact: true,
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
                                        _HomeIntelligenceDeck(
                                          cs: cs,
                                          dashboard: homeViewModel,
                                          radar: technicalRadar,
                                          beltProgress: beltProgress,
                                          onOpenMap: openGameMap,
                                          onOpenTraining: openTraining,
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
                          beltSelectionOrder
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

    final next = _HomeDashboardViewModel.fromSummary(
      _getHomeDashboardSummary(sessions),
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
    final hasOfficialRule = rules.hasExplicitRule(belt);

    final progressInBelt =
        hasOfficialRule
            ? (sessionsInBelt / sessionsRequired).clamp(0.0, 1.0).toDouble()
            : 0.0;

    return _BeltProgress(
      belt: belt,
      degree: safeDegree,
      maxDegree: maxDeg,
      sessionsInBelt: sessionsInBelt,
      sessionsRequired: sessionsRequired,
      hasOfficialRule: hasOfficialRule,
      percentToNextBelt: progressInBelt,
    );
  }
}

class _HomeDashboardViewModel {
  final List<TrainingSession> sessions;
  final List<TrainingSession> recentSessions;
  final List<TrainingSession> lastSessions;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final HomeDebriefInsights debriefInsights;
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

  factory _HomeDashboardViewModel.fromSummary(HomeDashboardSummary summary) {
    return _HomeDashboardViewModel(
      sessions: summary.sessions,
      recentSessions: summary.recentSessions,
      lastSessions: summary.lastSessions,
      metrics: summary.metrics,
      frequency: summary.frequency,
      debriefInsights: summary.debriefInsights,
      gameMapLite: summary.gameMapLite,
      skillMatrix: summary.skillMatrix,
      technicalRadar: _HomeTechnicalRadarViewModel.fromSummary(
        summary.technicalRadar,
      ),
      recommendedFocus: summary.recommendedFocus,
      nextTraining: summary.nextTraining,
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

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final int sessionsInBelt;
  final int sessionsRequired;
  final bool hasOfficialRule;
  final double percentToNextBelt;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    required this.hasOfficialRule,
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
  return TitansUI.beltColor(belt.name);
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
  final bool hasOfficialRule;
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
    required this.hasOfficialRule,
    this.onEditProfile,
    this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ringColor = _beltProgressRingColor(belt);
    final identity = email.isEmpty ? 'ID ${_shortUid(uid)}' : email;
    final sessionLabel =
        hasOfficialRule
            ? '$sessionsInBelt/$sessionsRequired treinos na faixa atual'
            : '$sessionsInBelt treinos registrados nesta faixa';
    final hasActions = onEditProfile != null || onEditGraduation != null;

    return _GlassCard(
      accent: ringColor.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderCompact(title: 'ALUNO EM ACOMPANHAMENTO'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final info = _StudentSnapshotInfo(
                cs: cs,
                name: name,
                identity: identity,
                belt: belt,
                degree: degree,
                maxDegree: maxDegree,
                sessionsRequired: sessionsRequired,
                hasOfficialRule: hasOfficialRule,
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _BeltProgressRing(
                        colorScheme: cs,
                        value: percentToNext,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    info,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BeltProgressRing(
                    colorScheme: cs,
                    value: percentToNext,
                    color: ringColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: info),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            sessionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasActions) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
                    label: const Text('Editar gradua\u00e7\u00e3o'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSnapshotInfo extends StatelessWidget {
  final ColorScheme cs;
  final String name;
  final String identity;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final int sessionsRequired;
  final bool hasOfficialRule;

  const _StudentSnapshotInfo({
    required this.cs,
    required this.name,
    required this.identity,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.sessionsRequired,
    required this.hasOfficialRule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
              label: '${_beltLabel(belt)} \u00b7 $degree\u00ba grau',
              color: TitansUI.beltColor(belt.name),
              icon: Icons.military_tech_outlined,
            ),
            if (hasOfficialRule)
              _InsightBadge(
                label: 'Ref. $sessionsRequired treinos',
                color: TitansUI.technicalBlue,
                icon: Icons.flag_outlined,
              ),
            _DegreeDots(degree: degree, maxDegree: maxDegree, cs: cs),
          ],
        ),
      ],
    );
  }
}

enum _AthleteHomeAccountAction { theme, signOut }

class _AthleteHomeAccountMenu extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const _AthleteHomeAccountMenu({
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AthleteHomeAccountAction>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) {
        switch (action) {
          case _AthleteHomeAccountAction.theme:
            onToggleTheme();
            break;
          case _AthleteHomeAccountAction.signOut:
            onSignOut();
            break;
        }
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: _AthleteHomeAccountAction.theme,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.brightness_6_outlined),
                title: Text('Tema'),
              ),
            ),
            PopupMenuItem(
              value: _AthleteHomeAccountAction.signOut,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded),
                title: Text('Sair'),
              ),
            ),
          ],
    );
  }
}

class _AthleteMinimalHeader extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const _AthleteMinimalHeader({
    required this.onToggleTheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        _AthleteHomeAccountMenu(
          onToggleTheme: onToggleTheme,
          onSignOut: onSignOut,
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
  final bool hasOfficialRule;

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
    required this.hasOfficialRule,
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
                  hasOfficialRule
                      ? '$sessionsInBelt/$sessionsRequired treinos na faixa atual'
                      : '$sessionsInBelt treinos registrados nesta faixa',
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

class _AthleteHomeCockpitHero extends StatelessWidget {
  final ColorScheme cs;
  final RecommendedTrainingFocus focus;
  final NextTrainingRecommendation nextTraining;
  final TrainingSession? lastSession;
  final VoidCallback onRegisterTraining;

  const _AthleteHomeCockpitHero({
    required this.cs,
    required this.focus,
    required this.nextTraining,
    required this.lastSession,
    required this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _priorityColor(cs, focus.priority, nextTraining.priority);
    final title =
        focus.hasRecommendation
            ? focus.title
            : nextTraining.hasRecommendation
            ? nextTraining.title
            : 'Foco do treino em construção';
    final subtitle =
        focus.hasRecommendation
            ? focus.summary
            : nextTraining.hasRecommendation
            ? nextTraining.subtitle
            : 'Registre treinos e debriefs para alimentar seu próximo passo.';
    final support = _supportText();
    final tags =
        <String>[
          if (focus.hasRecommendation) ...focus.tags,
          if (!focus.hasRecommendation && nextTraining.hasRecommendation)
            ...nextTraining.tags,
        ].take(2).toList();
    final lastActivity =
        lastSession == null
            ? 'Sem treino registrado ainda'
            : 'Última atividade ${_formatShortDate(lastSession!.date)}';

    return _GlassCard(
      accent: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(Icons.flag_outlined, color: accent, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOCO DO TREINO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            support,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.60),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InsightBadge(
                label: lastActivity,
                color: cs.onSurface.withValues(alpha: 0.46),
                icon: Icons.history_rounded,
                muted: true,
              ),
              for (final tag in tags) _InsightBadge(label: tag, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width:
                    constraints.maxWidth < 360
                        ? double.infinity
                        : constraints.maxWidth.clamp(180.0, 260.0),
                child: FilledButton.icon(
                  onPressed: onRegisterTraining,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Registro rápido'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TitansUI.actionGold,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _supportText() {
    if (focus.hasRecommendation) return focus.reason;
    if (nextTraining.hasRecommendation) return nextTraining.objective;
    return nextTraining.emptyMessage ?? nextTraining.subtitle;
  }

  Color _priorityColor(
    ColorScheme cs,
    RecommendedTrainingFocusPriority focusPriority,
    RecommendedTrainingFocusPriority nextPriority,
  ) {
    final priority =
        focusPriority == RecommendedTrainingFocusPriority.none
            ? nextPriority
            : focusPriority;
    switch (priority) {
      case RecommendedTrainingFocusPriority.high:
        return cs.error;
      case RecommendedTrainingFocusPriority.medium:
        return TitansUI.actionGold;
      case RecommendedTrainingFocusPriority.low:
        return TitansUI.successGreen;
      case RecommendedTrainingFocusPriority.none:
        return cs.primary;
    }
  }
}

class _AthleteMinimalMetricsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final HomeTrainingMetrics metrics;

  const _AthleteMinimalMetricsCard({
    required this.cs,
    required this.frequency,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.md),
        color: TitansUI.subtleFillColor(context, alpha: 0.62),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.48)),
      ),
      child: TitansCompactMetricGrid(
        fourColumnMinWidth: 440,
        spacing: 8,
        children: [
          _StatMini(
            title: '8 SEMANAS',
            value: '$frequency%',
            highlight: cs.primary,
          ),
          _StatMini(
            title: '30 DIAS',
            value: metrics.recent.toString(),
            highlight: TitansUI.successGreen,
          ),
          _StatMini(
            title: 'ANO',
            value: metrics.year.toString(),
            highlight: TitansUI.actionGold,
          ),
          _StatMini(
            title: 'TOTAL',
            value: metrics.total.toString(),
            highlight: cs.secondary,
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
    return TitansCompactMetricCard(
      label: title,
      value: value,
      color: highlight,
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final HomeTrainingMetrics metrics;

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
  final HomeDebriefInsights insights;

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
  final HomeTrainingMetrics metrics;
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
  final HomeTrainingMetrics metrics;
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
              spacing: 6,
              runSpacing: 6,
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

  String get dominantAxisName {
    final axis = topAxis;
    return axis?.displayLabel ?? 'em formação';
  }

  String get awaitingEvidenceLabel {
    final suffix =
        awaitingClassificationCount == 1
            ? 'evidência aguardando classificação'
            : 'evidências aguardando classificação';
    return '$awaitingClassificationCount $suffix';
  }

  String get readingLabel {
    final axis = topAxis;
    if (axis == null) {
      return 'Sua leitura técnica ainda está sendo construída pelos treinos.';
    }
    return '${axis.displayLabel} aparece com mais frequência nas suas evidências.';
  }

  String get nextStepLabel {
    if (!hasClassifiedEvidence) {
      return 'Registre treinos para construir sua leitura técnica.';
    }
    return 'Use o mapa para entender onde seu jogo aparece com mais frequência.';
  }

  factory _HomeTechnicalRadarViewModel.fromSummary(
    HomeTechnicalRadarSummary summary,
  ) {
    return _HomeTechnicalRadarViewModel(
      axisEvidence: summary.axisEvidence,
      classifiedEvidenceCount: summary.classifiedEvidenceCount,
      awaitingClassificationCount: summary.awaitingClassificationCount,
      sessionsCount: summary.sessionsCount,
      topAxis: summary.topAxis,
    );
  }
}

class _HomeIntelligenceDeck extends StatefulWidget {
  final ColorScheme cs;
  final _HomeDashboardViewModel dashboard;
  final _HomeTechnicalRadarViewModel radar;
  final _BeltProgress beltProgress;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenTraining;
  final VoidCallback? onRegisterTraining;

  const _HomeIntelligenceDeck({
    required this.cs,
    required this.dashboard,
    required this.radar,
    required this.beltProgress,
    required this.onOpenMap,
    required this.onOpenTraining,
    this.onRegisterTraining,
  });

  @override
  State<_HomeIntelligenceDeck> createState() => _HomeIntelligenceDeckState();
}

class _HomeIntelligenceDeckState extends State<_HomeIntelligenceDeck> {
  int _index = 0;

  static const _pages = [
    _HomeDeckPageMeta(label: 'Radar', icon: Icons.radar_outlined),
    _HomeDeckPageMeta(label: 'Treinos', icon: Icons.show_chart_rounded),
    _HomeDeckPageMeta(
      label: 'Progresso',
      icon: Icons.workspace_premium_outlined,
    ),
    _HomeDeckPageMeta(
      label: 'Repert\u00f3rio',
      icon: Icons.account_tree_outlined,
    ),
  ];

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index.clamp(0, _pages.length - 1));
  }

  void _next() => _goTo((_index + 1) % _pages.length);

  void _previous() => _goTo((_index - 1 + _pages.length) % _pages.length);

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120) _next();
            if (velocity > 120) _previous();
          },
          child: AnimatedSwitcher(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              if (reduceMotion) return child;
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0.03),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _buildPage(context),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _HomeDeckIndicator(
          pages: _pages,
          selectedIndex: _index,
          onSelect: _goTo,
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context) {
    switch (_index) {
      case 0:
        return _HomeRadarInsight(
          cs: widget.cs,
          radar: widget.radar,
          onOpenMap: widget.onOpenMap,
          onRegisterTraining: widget.onRegisterTraining,
        );
      case 1:
        return _HomeTrainingInsight(
          cs: widget.cs,
          metrics: widget.dashboard.metrics,
          recentSessions: widget.dashboard.recentSessions,
          lastSession:
              widget.dashboard.lastSessions.isEmpty
                  ? null
                  : widget.dashboard.lastSessions.first,
          onOpenTraining: widget.onOpenTraining,
          onRegisterTraining: widget.onRegisterTraining,
        );
      case 2:
        return _HomeProgressInsight(
          cs: widget.cs,
          beltProgress: widget.beltProgress,
          metrics: widget.dashboard.metrics,
          frequency: widget.dashboard.frequency,
        );
      default:
        return _HomeConsistencyInsight(
          cs: widget.cs,
          frequency: widget.dashboard.frequency,
          gameMap: widget.dashboard.gameMapLite,
          skillMatrix: widget.dashboard.skillMatrix,
          onOpenMap: widget.onOpenMap,
        );
    }
  }
}

class _HomeDeckPageMeta {
  final String label;
  final IconData icon;

  const _HomeDeckPageMeta({required this.label, required this.icon});
}

class _HomeDeckIndicator extends StatelessWidget {
  final List<_HomeDeckPageMeta> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _HomeDeckIndicator({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var i = 0; i < pages.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selectedIndex == i ? 10 : 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    selectedIndex == i
                        ? cs.primary.withValues(alpha: 0.14)
                        : cs.onSurface.withValues(alpha: 0.045),
                border: Border.all(
                  color:
                      selectedIndex == i
                          ? cs.primary.withValues(alpha: 0.34)
                          : cs.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pages[i].icon,
                    size: 13,
                    color:
                        selectedIndex == i
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.58),
                  ),
                  if (selectedIndex == i) ...[
                    const SizedBox(width: 6),
                    Text(
                      pages[i].label,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeRadarInsight extends StatelessWidget {
  final ColorScheme cs;
  final _HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;
  final VoidCallback? onRegisterTraining;

  const _HomeRadarInsight({
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

class _HomeTrainingInsight extends StatelessWidget {
  final ColorScheme cs;
  final HomeTrainingMetrics metrics;
  final List<TrainingSession> recentSessions;
  final TrainingSession? lastSession;
  final VoidCallback onOpenTraining;
  final VoidCallback? onRegisterTraining;

  const _HomeTrainingInsight({
    required this.cs,
    required this.metrics,
    required this.recentSessions,
    required this.lastSession,
    required this.onOpenTraining,
    this.onRegisterTraining,
  });

  @override
  Widget build(BuildContext context) {
    final lastTrainingLabel =
        lastSession == null
            ? 'Sem treino recente'
            : _formatShortDate(lastSession!.date);
    final hasRecent = recentSessions.isNotEmpty;

    return _GlassCard(
      accent: TitansUI.successGreen.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Ritmo de treino',
            badgeLabel: '${metrics.recent} em 30 dias',
            badgeIcon: Icons.show_chart_rounded,
            accent: TitansUI.successGreen,
          ),
          const SizedBox(height: 14),
          _HomeTrainingTimeline(
            sessions: recentSessions,
            accent: TitansUI.successGreen,
          ),
          const SizedBox(height: 14),
          _HomeDeckInsightLine(
            icon: Icons.calendar_month_outlined,
            accent: TitansUI.successGreen,
            text:
                hasRecent
                    ? 'Voc\u00ea treinou ${metrics.recent} vezes nos \u00faltimos 30 dias. \u00daltimo treino: $lastTrainingLabel.'
                    : 'Registre treinos para construir essa leitura.',
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label:
                onRegisterTraining == null ? 'Ver treinos' : 'Registrar treino',
            icon:
                onRegisterTraining == null
                    ? Icons.fitness_center_outlined
                    : Icons.add_task_outlined,
            onPressed: onRegisterTraining ?? onOpenTraining,
            filled: onRegisterTraining != null,
          ),
        ],
      ),
    );
  }
}

class _HomeProgressInsight extends StatelessWidget {
  final ColorScheme cs;
  final _BeltProgress beltProgress;
  final HomeTrainingMetrics metrics;
  final int frequency;

  const _HomeProgressInsight({
    required this.cs,
    required this.beltProgress,
    required this.metrics,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = _beltProgressRingColor(beltProgress.belt);
    final ruleLabel =
        beltProgress.hasOfficialRule
            ? '${beltProgress.sessionsInBelt}/${beltProgress.sessionsRequired} sess\u00f5es na faixa'
            : '${beltProgress.sessionsInBelt} sess\u00f5es registradas';

    return _GlassCard(
      accent: ringColor.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Progresso de faixa',
            badgeLabel:
                '${_beltLabel(beltProgress.belt)} · ${beltProgress.degree}\u00ba grau',
            badgeIcon: Icons.workspace_premium_outlined,
            accent: ringColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BeltProgressRing(
                colorScheme: cs,
                value: beltProgress.percentToNextBelt,
                color: ringColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeProgressMiniBar(
                      label: ruleLabel,
                      value: beltProgress.percentToNextBelt,
                      color: ringColor,
                    ),
                    const SizedBox(height: 10),
                    _HomeDeckInsightLine(
                      icon: Icons.insights_outlined,
                      accent: ringColor,
                      text:
                          'Base real: ${metrics.total} treinos totais e $frequency% de regularidade em 8 semanas.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HomeDeckPassiveCta(
            icon: Icons.workspace_premium_outlined,
            text: 'Leitura de progresso exibida aqui sem abrir nova rota.',
          ),
        ],
      ),
    );
  }
}

class _HomeConsistencyInsight extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final List<GameMapEntry> gameMap;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final VoidCallback onOpenMap;

  const _HomeConsistencyInsight({
    required this.cs,
    required this.frequency,
    required this.gameMap,
    required this.skillMatrix,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final topPosition = _topGameMapPosition(gameMap);
    final topTechnique = _topSkillMatrixTechnique(skillMatrix);
    final totalTechniques = skillMatrix.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );

    return _GlassCard(
      accent: cs.secondary.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeDeckHeader(
            title: 'COCKPIT T\u00c9CNICO',
            subtitle: 'Consist\u00eancia e repert\u00f3rio',
            badgeLabel: '$frequency% em 8 semanas',
            badgeIcon: Icons.account_tree_outlined,
            accent: cs.secondary,
          ),
          const SizedBox(height: 14),
          _HomeConsistencyConstellation(
            gameMap: gameMap,
            skillMatrix: skillMatrix,
            accent: cs.secondary,
          ),
          const SizedBox(height: 14),
          _HomeDeckInsightLine(
            icon: Icons.hub_outlined,
            accent: cs.secondary,
            text:
                topPosition == null && topTechnique == null
                    ? 'Repert\u00f3rio em forma\u00e7\u00e3o. Registre posi\u00e7\u00e3o e t\u00e9cnica para construir essa leitura.'
                    : 'Mais presente: ${topPosition ?? topTechnique}. Repert\u00f3rio com $totalTechniques t\u00e9cnicas registradas.',
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _HomeDeckHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color accent;

  const _HomeDeckHeader({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeaderCompact(title: title),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _InsightBadge(label: badgeLabel, color: accent, icon: badgeIcon),
      ],
    );
  }
}

class _HomeTrainingTimeline extends StatelessWidget {
  final List<TrainingSession> sessions;
  final Color accent;

  const _HomeTrainingTimeline({required this.sessions, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = sessions.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child:
          items.isEmpty
              ? Text(
                'Dados em forma\u00e7\u00e3o',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              )
              : Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(
                      child: _HomeTrainingTimelineNode(
                        session: items[items.length - 1 - i],
                        accent: accent,
                      ),
                    ),
                    if (i != items.length - 1)
                      Container(
                        width: 10,
                        height: 2,
                        color: cs.onSurface.withValues(alpha: 0.10),
                      ),
                  ],
                ],
              ),
    );
  }
}

class _HomeTrainingTimelineNode extends StatelessWidget {
  final TrainingSession session;
  final Color accent;

  const _HomeTrainingTimelineNode({
    required this.session,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.22),
            border: Border.all(color: accent.withValues(alpha: 0.72)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatShortDate(session.date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HomeProgressMiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HomeProgressMiniBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeValue = value.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 7,
            backgroundColor: cs.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _HomeConsistencyConstellation extends StatelessWidget {
  final List<GameMapEntry> gameMap;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final Color accent;

  const _HomeConsistencyConstellation({
    required this.gameMap,
    required this.skillMatrix,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final positions = gameMap.take(4).toList();
    final techniques =
        <SkillMatrixTechniqueEntry>[
          for (final entry in skillMatrix) ...entry.techniques.take(2),
        ].take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child:
          positions.isEmpty && techniques.isEmpty
              ? Text(
                'Dados em forma\u00e7\u00e3o',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w800,
                ),
              )
              : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in positions)
                    _InsightBadge(
                      label: entry.position,
                      color: accent,
                      icon: Icons.place_outlined,
                    ),
                  for (final technique in techniques)
                    _InsightBadge(
                      label: technique.technique,
                      color: cs.primary,
                      icon: Icons.bubble_chart_outlined,
                      muted: true,
                    ),
                ],
              ),
    );
  }
}

class _HomeDeckInsightLine extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;

  const _HomeDeckInsightLine({
    required this.icon,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDeckPassiveCta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HomeDeckPassiveCta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cs.onSurface.withValues(alpha: 0.045),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.62)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.66),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _topGameMapPosition(List<GameMapEntry> entries) {
  if (entries.isEmpty) return null;
  final ordered = List<GameMapEntry>.from(entries)
    ..sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
  return ordered.first.position;
}

String? _topSkillMatrixTechnique(List<SkillMatrixCategoryEntry> entries) {
  final techniques = <SkillMatrixTechniqueEntry>[
    for (final entry in entries) ...entry.techniques,
  ];
  if (techniques.isEmpty) return null;
  techniques.sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
  return techniques.first.technique;
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
      accent: cs.primary.withValues(alpha: 0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Inicial',
            badgeIcon: Icons.radar_outlined,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final visual = const _HomeEmbeddedTechnicalRadar(
                stateLabel: 'Mapa técnico em formação',
              );
              final details = _HomeRadarEmptyInsightStack(
                cs: cs,
                compact: compact,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [visual, const SizedBox(height: 14), details],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: visual),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label:
                onRegisterTraining == null
                    ? 'Explorar mapa técnico'
                    : 'Registrar treino',
            icon: onRegisterTraining == null ? Icons.map_outlined : Icons.add,
            onPressed: onRegisterTraining ?? onOpenMap,
            filled: true,
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
      accent: cs.primary.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Base: ${radar.sessionLabel}',
            badgeIcon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final radarVisual = _HomeEmbeddedTechnicalRadar(
                radar: radar,
                stateLabel: 'Mapa técnico em formação',
              );
              final radarDetails = _HomeRadarInsightStack(
                cs: cs,
                radar: radar,
                compact: compact,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    radarVisual,
                    const SizedBox(height: 10),
                    radarDetails,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 7, child: radarVisual),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: radarDetails),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa técnico',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
            filled: true,
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
      accent: cs.secondary.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel: 'Base: ${radar.sessionLabel}',
            badgeIcon: Icons.fitness_center_outlined,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final radarVisual = _HomeEmbeddedTechnicalRadar(
                radar: radar,
                stateLabel: 'Radar técnico ativo',
              );
              final radarDetails = _HomeRadarInsightStack(
                cs: cs,
                radar: radar,
                compact: compact,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    radarVisual,
                    const SizedBox(height: 10),
                    radarDetails,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 7, child: radarVisual),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: radarDetails),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HomeRadarCta(
            label: 'Explorar mapa técnico',
            icon: Icons.map_outlined,
            onPressed: onOpenMap,
            filled: true,
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_rounded, size: 16),
      ],
    );

    final minimumSize = const Size.fromHeight(42);
    final stylePadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    );
    final button =
        filled
            ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: minimumSize,
                visualDensity: VisualDensity.compact,
                padding: stylePadding,
                backgroundColor: cs.secondary,
                foregroundColor: Colors.black,
              ),
              child: child,
            )
            : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: minimumSize,
                visualDensity: VisualDensity.compact,
                padding: stylePadding,
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.secondary.withValues(alpha: 0.32)),
                backgroundColor: cs.secondary.withValues(alpha: 0.05),
              ),
              child: child,
            );

    return SizedBox(width: double.infinity, child: button);
  }
}

class _HomeEmbeddedTechnicalRadar extends StatelessWidget {
  final _HomeTechnicalRadarViewModel? radar;
  final String stateLabel;

  const _HomeEmbeddedTechnicalRadar({this.radar, required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    final data = radar;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TitansTechnicalRadar(
          variant: TitansTechnicalRadarVariant.homePreview,
          interactive: false,
          enableSweep: true,
          enableHolographicMode: true,
          enablePerspectiveControls: false,
          initialPerspective: TitansRadarPerspective.live,
          enableHudDetails: true,
          showDistribution: false,
          showLegend: false,
          showGhostPolygon: false,
          showMetrics: false,
          showSafetyCopy: false,
          contained: false,
          axisEvidence: data?.axisEvidence ?? const {},
          classifiedEvidenceCount: data?.classifiedEvidenceCount ?? 0,
          awaitingClassificationCount: data?.awaitingClassificationCount ?? 0,
          stateLabel: stateLabel,
        ),
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
              'Leitura viva do seu jogo',
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

        if (constraints.maxWidth < 400) {
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

class _HomeRadarEmptyInsightStack extends StatelessWidget {
  final ColorScheme cs;
  final bool compact;

  const _HomeRadarEmptyInsightStack({required this.cs, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeRadarInsightBlock(
          label: 'Eixo dominante',
          value: 'em formação',
          icon: Icons.auto_awesome_outlined,
          accent: cs.secondary,
        ),
        const SizedBox(height: 6),
        _HomeRadarInsightBlock(
          label: 'Base técnica',
          value: 'sem treinos analisados',
          icon: Icons.fitness_center_outlined,
          accent: cs.primary,
        ),
        const SizedBox(height: 6),
        _HomeRadarInsightBlock(
          label: 'Evidências',
          value: '0 classificadas',
          icon: Icons.radar_outlined,
          accent: cs.tertiary,
        ),
        const SizedBox(height: 6),
        _HomeRadarInsightBlock(
          label: 'Próximo passo',
          value: 'Registre treinos para construir sua leitura técnica.',
          icon: Icons.route_outlined,
          accent: cs.tertiary,
          maxValueLines: compact ? 3 : 2,
        ),
      ],
    );
  }
}

class _HomeRadarInsightStack extends StatelessWidget {
  final ColorScheme cs;
  final _HomeTechnicalRadarViewModel radar;
  final bool compact;

  const _HomeRadarInsightStack({
    required this.cs,
    required this.radar,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 390;
        final itemWidth =
            useTwoColumns ? (constraints.maxWidth - 6) / 2 : constraints.maxWidth;
        final awaiting =
            radar.awaitingClassificationCount > 0
                ? radar.awaitingEvidenceLabel
                : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeRadarInsightBlock(
              label: 'Eixo dominante',
              value: radar.dominantAxisName,
              supporting: radar.readingLabel,
              icon: Icons.auto_awesome_outlined,
              accent: cs.secondary,
              emphasized: true,
              maxValueLines: 1,
              maxSupportingLines: 1,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _HomeRadarInsightBlock(
                    label: 'Base técnica',
                    value: radar.sessionLabel,
                    icon: Icons.fitness_center_outlined,
                    accent: cs.primary,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _HomeRadarInsightBlock(
                    label: 'Evidências',
                    value: radar.classifiedEvidenceLabel,
                    supporting: awaiting,
                    icon: Icons.radar_outlined,
                    accent: cs.tertiary,
                    maxSupportingLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _HomeRadarInsightBlock(
              label: 'Próximo passo',
              value: radar.nextStepLabel,
              icon: Icons.route_outlined,
              accent: cs.secondary,
              maxValueLines: compact ? 2 : 1,
            ),
          ],
        );
      },
    );
  }
}

class _HomeRadarInsightBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? supporting;
  final IconData icon;
  final Color accent;
  final bool emphasized;
  final int maxValueLines;
  final int maxSupportingLines;

  const _HomeRadarInsightBlock({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.supporting,
    this.emphasized = false,
    this.maxValueLines = 1,
    this.maxSupportingLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        color: accent.withValues(alpha: emphasized ? 0.10 : 0.055),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: accent.withValues(alpha: 0.11),
            ),
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.56),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: maxValueLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        emphasized ? accent : cs.onSurface.withValues(alpha: 0.90),
                    fontSize: emphasized ? 15 : 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (supporting != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    supporting!,
                    maxLines: maxSupportingLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (emphasized) ...[
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accent.withValues(alpha: 0.64),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachActiveLiteModules extends StatelessWidget {
  final ColorScheme cs;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final HomeDebriefInsights insights;
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: TitansCompactMetricCard(label: label, value: value),
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
  final bool compact;
  final VoidCallback onOpenTraining;

  const _RecentActivityTimelineCard({
    required this.cs,
    required this.items,
    this.compact = false,
    required this.onOpenTraining,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(compact ? 2 : 3).toList();
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
                  compact ? 'ÚLTIMOS TREINOS' : 'ATIVIDADE RECENTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenTraining,
                child: Text(compact ? 'Ver todos' : 'Ver todos os treinos →'),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
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
                    compact: compact,
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
  final bool compact;

  const _RecentActivityTimelineRow({
    required this.session,
    required this.showPlace,
    this.compact = false,
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
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
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
                  maxLines: compact ? 1 : 2,
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
