import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/home/application/home_dashboard_use_cases.dart';
import '../features/home/domain/home_dashboard_models.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../features/training/domain/training_operation_context.dart';
import '../main.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
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
import '../widgets/athlete_dashboard/athlete_dashboard_content.dart';
import '../widgets/athlete_dashboard/dashboard_formatters.dart';
import '../widgets/athlete_dashboard/dashboard_states.dart';
import '../widgets/athlete_dashboard/home_view_models.dart';
import '../widgets/athlete_dashboard/recent_activity_timeline_card.dart'
    show HomeTechniqueNavigationTarget;
import '../widgets/quick_log_sheet.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import '../widgets/titans_theme_picker.dart';
import '../widgets/training_save_confirmation.dart';
import 'add_training_session_screen.dart';
import 'athlete_registration_screen.dart';
import 'game_map_screen.dart';
import 'nutrition_screen.dart';
import 'skill_detail_screen.dart';
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
  HomeDashboardViewModel? _homeDashboardCache;
  final Set<String> _trainingLifecycleSavingIds = <String>{};
  late final GetHomeDashboardSummary _getHomeDashboardSummary =
      const GetHomeDashboardSummary();
  late final GetTechnicalRadarSummary _getTechnicalRadarSummary =
      const GetTechnicalRadarSummary();
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
    final canRegisterTraining =
        target != null &&
        _canRegisterTraining(loggedUser: actor, target: target);

    if (target == null) {
      return _wrapModule(
        appBar: AppBar(
          leading: _mainScreenLeading(context),
          title: Text(widget.titleOverride ?? 'In\u00edcio'),
        ),
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
      appBar: AppBar(
        leading: _mainScreenLeading(context),
        title: Text(widget.titleOverride ?? 'In\u00edcio'),
      ),
      body: StreamBuilder<AppUser?>(
        stream: _athleteStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
          }
          if (userSnap.hasError) {
            return DashboardErrorState(
              title: 'Erro ao carregar usu\u00e1rio',
              message: userSnap.error.toString(),
            );
          }

          final athlete = userSnap.data;
          if (athlete == null) {
            return const DashboardEmptyState(
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
                return DashboardErrorState(
                  title: 'Erro ao carregar perfil',
                  message: profileSnap.error.toString(),
                );
              }

              final profile = profileSnap.data;
              if (profile == null) {
                return const DashboardEmptyState(
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
                    return DashboardErrorState(
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
                        return DashboardErrorState(
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

                      final completedFiltered =
                          TrainingAggregator.uniqueCompletedSessions(filtered);

                      final beltProgress = _calcBeltProgress(
                        rules: rules,
                        profile: profile,
                        belt: athlete.belt,
                        degree: athlete.degree,
                        sessions: completedFiltered,
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
                      final pendingConfirmation =
                          homeViewModel.pendingConfirmation;
                      final frequency = homeViewModel.frequency;
                      final isStaffViewingStudent = _isStaffViewingStudent(
                        actor: actor,
                        target: target,
                      );
                      final coachHomeState =
                          isStaffViewingStudent
                              ? _coachStudentHomeStateFor(
                                completedFiltered.length,
                              )
                              : null;
                      final isSelfProfile =
                          widget.targetMode == TargetMode.self &&
                          actor?.uid == uid;
                      final isAthleteSelfView =
                          actor?.role == UserRole.athlete && isSelfProfile;

                      void openTrainingHistory({String? focusSessionId}) {
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
                                  focusSessionId: focusSessionId,
                                ),
                          ),
                        );
                      }

                      void openTraining() => openTrainingHistory();

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

                      void openTrainingSession(TrainingSession session) {
                        Navigator.of(context).push(
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

                      void openTechniqueDetail(
                        HomeTechniqueNavigationTarget technique,
                      ) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => SkillDetailScreen(
                                  academyId: academyId,
                                  uid: uid,
                                  loggedUser: actor,
                                  skillId: technique.skillId,
                                  displayName: technique.displayName,
                                  category: technique.category,
                                  preferredPosition: technique.position,
                                  sessions: homeViewModel.sessions,
                                  evaluations: const <CoachEvaluation>[],
                                ),
                          ),
                        );
                      }

                      Future<void> confirmPendingTraining(
                        TrainingSession session,
                      ) async {
                        if (actor == null) return;
                        final operationContext = TrainingOperationContext(
                          actorUid: actor.uid,
                          academyId: academyId,
                          targetUid: uid,
                        );
                        final operationKey = operationContext.sessionKey(
                          session.id,
                        );
                        if (_trainingLifecycleSavingIds.contains(
                          operationKey,
                        )) {
                          return;
                        }
                        setState(() {
                          _trainingLifecycleSavingIds.add(operationKey);
                        });
                        try {
                          final effectiveDate = DateTime(
                            session.date.year,
                            session.date.month,
                            session.date.day,
                          );
                          await _trainingRepo.updateSessionLifecycle(
                            academyId: academyId,
                            uid: uid,
                            sessionId: session.id,
                            status: TrainingSessionStatus.completed,
                            effectiveDate: effectiveDate,
                          );
                          if (!mounted ||
                              !_isTrainingContextCurrent(operationContext)) {
                            return;
                          }
                          final confirmedSession = session.copyWith(
                            status: TrainingSessionStatus.completed,
                            effectiveDate: effectiveDate,
                          );
                          showTrainingSaveConfirmation(
                            context: this.context,
                            session: confirmedSession,
                            kind:
                                TrainingSaveConfirmationKind
                                    .plannedSessionConfirmed,
                            onViewTraining: () {
                              if (_isTrainingContextCurrent(operationContext)) {
                                openTrainingHistory(focusSessionId: session.id);
                              }
                            },
                          );
                        } catch (error) {
                          if (!mounted ||
                              !_isTrainingContextCurrent(operationContext)) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao confirmar treino: $error'),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _trainingLifecycleSavingIds.remove(operationKey);
                            });
                          }
                        }
                      }

                      Future<void> openQuickLog() async {
                        if (actor == null) return;
                        final operationContext = TrainingOperationContext(
                          actorUid: actor.uid,
                          academyId: academyId,
                          targetUid: uid,
                        );
                        final savedResult = await showQuickLogSheet(
                          context: this.context,
                          academyId: academyId,
                          uid: uid,
                          recentSessions: completedFiltered,
                          canSave: canRegisterTraining,
                          onOpenFullForm: openRegisterTraining,
                        );
                        if (!mounted ||
                            savedResult == null ||
                            !_isTrainingContextCurrent(operationContext)) {
                          return;
                        }
                        final savedSession = savedResult.session;
                        showTrainingSaveConfirmation(
                          context: this.context,
                          session: savedSession,
                          kind: TrainingSaveConfirmationKind.created,
                          visibleDetails: quickLogConfirmationDetails(
                            savedResult,
                          ),
                          onViewTraining: () {
                            if (_isTrainingContextCurrent(operationContext)) {
                              openTrainingHistory(
                                focusSessionId: savedSession.id,
                              );
                            }
                          },
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

                      final contentMode =
                          coachHomeState == _CoachStudentHomeState.empty
                              ? AthleteDashboardContentMode.coachEmpty
                              : coachHomeState ==
                                  _CoachStudentHomeState.foundation
                              ? AthleteDashboardContentMode.coachFoundation
                              : isStaffViewingStudent
                              ? AthleteDashboardContentMode.coachActive
                              : isAthleteSelfView
                              ? AthleteDashboardContentMode.athleteSelf
                              : AthleteDashboardContentMode.standard;

                      if (contentMode !=
                              AthleteDashboardContentMode.athleteSelf &&
                          contentMode !=
                              AthleteDashboardContentMode.coachEmpty) {
                        debugPrint(
                          '[DASHBOARD_EDIT] showEditProfile=$canEditTarget '
                          'canEditTarget=$canEditTarget actor.uid=${actor?.uid} '
                          'actor.role=${actor?.role} target.uid=$uid '
                          'target.academyId=$academyId',
                        );
                      }

                      return AthleteDashboardContent(
                        key: ValueKey(
                          'athlete-dashboard-content-$academyId-$uid-'
                          '${contentMode.name}',
                        ),
                        mode: contentMode,
                        embedded: widget.embedded,
                        isSelfProfile: isSelfProfile,
                        canEditTarget: canEditTarget,
                        athleteName: headerName,
                        athleteEmail: headerEmail,
                        athleteUid: uid,
                        dashboard: homeViewModel,
                        beltProgress: beltProgress,
                        nutritionProfileStream: _nutritionProfileStream,
                        nutritionMealsStream: _nutritionMealsStream,
                        nutritionFallbackToMock: _nutritionFallbackToMock,
                        hasNutritionLoadError: _nutritionLoadError != null,
                        cockpitConfirmingPending:
                            pendingConfirmation != null &&
                            _trainingLifecycleSavingIds.contains(
                              '$academyId|$uid|${pendingConfirmation.id}',
                            ),
                        primaryActionConfirmingPending:
                            pendingConfirmation != null &&
                            _trainingLifecycleSavingIds.contains(
                              pendingConfirmation.id,
                            ),
                        onChangeTheme: () => showTitansThemePicker(context),
                        onSignOut: () => FirebaseAuth.instance.signOut(),
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
                                          (_) => AthleteRegistrationScreen(
                                            academyId: academyId,
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
                        onConfirmPending:
                            pendingConfirmation == null
                                ? null
                                : () =>
                                    confirmPendingTraining(pendingConfirmation),
                        onQuickLog: openQuickLog,
                        onRegisterTraining: openRegisterTraining,
                        onOpenTraining: openTraining,
                        onOpenGameMap: openGameMap,
                        onOpenSkills: openSkills,
                        onOpenNutrition: openNutrition,
                        onOpenTrainingSession: openTrainingSession,
                        onOpenTechnique: openTechniqueDetail,
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

  bool _canRegisterTraining({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    if (loggedUser == null || loggedUser.academyId != target.academyId) {
      return false;
    }
    final isStaff =
        loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return loggedUser.uid == target.uid || isStaff;
  }

  bool _isTrainingContextCurrent(TrainingOperationContext operationContext) {
    if (!mounted) return false;
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);
    final target = TargetResolver.maybeOf(
      context,
      mode: widget.targetMode,
      explicitTarget: widget.explicitTarget,
    );
    return operationContext.matches(
      actorUid: actor?.uid,
      academyId: target?.academyId,
      targetUid: target?.uid,
    );
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
                                  child: Text(beltLabel(belt)),
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

  HomeDashboardViewModel _homeDashboardViewModelFor({
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

    final summary = _getHomeDashboardSummary(sessions);
    final radarSummary = _getTechnicalRadarSummary(sessions);
    final next = HomeDashboardViewModel.fromSummary(
      summary,
      technicalRadarOverride: HomeTechnicalRadarSummary(
        axisEvidence: radarSummary.axisEvidence,
        classifiedEvidenceCount: radarSummary.classifiedEvidences,
        awaitingClassificationCount: radarSummary.unclassifiedEvidences,
        sessionsCount: radarSummary.sessionsCount,
        topAxis: radarSummary.topAxis,
      ),
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
        ..write(session.techniqueOutcome ?? '')
        ..write(':')
        ..write(session.status?.name ?? '')
        ..write(':')
        ..write(session.plannedFor?.microsecondsSinceEpoch ?? 0)
        ..write(':')
        ..write(session.effectiveDate?.microsecondsSinceEpoch ?? 0)
        ..write(':')
        ..write(session.confirmedAt?.microsecondsSinceEpoch ?? 0);

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

  BeltProgress _calcBeltProgress({
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

    return BeltProgress(
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
