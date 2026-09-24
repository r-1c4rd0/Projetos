import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/technical_domain/application/technical_domain_use_cases.dart';
import '../features/technical_domain/domain/technical_context.dart';
import '../features/technical_domain/presentation/skills_library.dart';
import '../features/technical_domain/presentation/skills_library_model.dart';
import '../features/technical_domain/presentation/skills_overview.dart';
import '../model/app_user.dart';
import '../model/coach_evaluation.dart';
import '../model/training_session.dart';
import '../repository/coach_evaluation_repository.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_expandable_section.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';
import 'skill_detail_screen.dart';
import 'training_screen.dart';

class SkillsScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? title;
  final String? targetName;
  final AppUser? loggedUser;
  final bool embedded;
  final Stream<List<TrainingSession>>? sessionsStream;
  final Stream<List<CoachEvaluation>>? coachEvaluationsStream;
  final String? initialPosition;
  final String? initialSkillId;

  const SkillsScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.title,
    this.targetName,
    this.loggedUser,
    this.embedded = false,
    this.sessionsStream,
    this.coachEvaluationsStream,
    this.initialPosition,
    this.initialSkillId,
  });

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  late final TrainingRepository _repository = TrainingRepository.instance;
  late final CoachEvaluationRepository _coachEvaluationRepository =
      CoachEvaluationRepository.instance;
  Stream<List<TrainingSession>>? _sessionsStream;
  Stream<List<CoachEvaluation>>? _coachEvaluationsStream;
  String? _contextKey;
  bool _hasAlignedAcademyContext = true;
  late final GetSkillMatrixSummary _getSkillMatrixSummary =
      const GetSkillMatrixSummary();
  late final GetGameMapEvidenceSummary _getGameMapEvidenceSummary =
      const GetGameMapEvidenceSummary();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncContext();
  }

  @override
  void didUpdateWidget(covariant SkillsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncContext();
  }

  AppUser? get _actor => UserScope.maybeOf(context) ?? widget.loggedUser;

  UserScope? get _userScope => UserScope.maybeScopeOf(context);

  TechnicalScreenContext _resolveContext() {
    final actor = _actor;
    final scope = _userScope;
    final activeAcademyId = scope?.activeAcademyId.trim();
    final workspaceAcademyId =
        activeAcademyId == null || activeAcademyId.isEmpty
            ? widget.academyId.trim()
            : activeAcademyId;
    final membership = scope?.activeMembership;
    final membershipState = [
      scope?.membershipSnapshot.status.name ?? 'legacy',
      membership?.academyId ?? '',
      membership?.role.name ?? '',
      membership?.isActive.toString() ?? '',
    ].join(':');

    return TechnicalScreenContext(
      actorUid: actor?.uid.trim() ?? '',
      actorRole: actor?.role.name ?? '',
      targetUid: widget.uid.trim(),
      targetAcademyId: widget.academyId.trim(),
      workspaceKey: 'academy:$workspaceAcademyId',
      membershipState: membershipState,
    );
  }

  bool get _canOpenTargetHistory {
    final actor = _actor;
    if (actor?.uid.trim() == widget.uid.trim()) return true;
    final scope = _userScope;
    return CoachEvaluationAuthorization.canEvaluate(
      actor: actor,
      targetUid: widget.uid,
      targetAcademyId: widget.academyId,
      activeAcademyId: scope?.activeAcademyId,
      activeMembership: scope?.activeMembership,
      membershipSnapshot: scope?.membershipSnapshot,
    );
  }

  void _syncContext() {
    final resolvedContext = _resolveContext();
    if (_contextKey == resolvedContext.key) return;

    final activeAcademyId = _userScope?.activeAcademyId.trim();
    _hasAlignedAcademyContext =
        activeAcademyId == null ||
        activeAcademyId.isEmpty ||
        activeAcademyId == widget.academyId.trim();
    _contextKey = resolvedContext.key;

    if (!_hasAlignedAcademyContext) {
      _sessionsStream = null;
      _coachEvaluationsStream = null;
      return;
    }

    _sessionsStream =
        widget.sessionsStream ??
        _repository.watchSessions(academyId: widget.academyId, uid: widget.uid);
    _coachEvaluationsStream =
        widget.coachEvaluationsStream ??
        _coachEvaluationRepository.watchEvaluations(
          academyId: widget.academyId,
          athleteUid: widget.uid,
        );
  }

  @override
  Widget build(BuildContext context) {
    final contextKey = _contextKey ?? _resolveContext().key;
    if (!_hasAlignedAcademyContext) {
      return _wrapModule(
        appBar: AppBar(title: Text(widget.title ?? 'Skills')),
        body: const TitansStateView.error(
          title: 'Contexto de academia alterado',
          message: 'Abra novamente Skills no workspace ativo.',
        ),
      );
    }

    final sessionsStream = _sessionsStream;
    final coachEvaluationsStream = _coachEvaluationsStream;
    if (sessionsStream == null || coachEvaluationsStream == null) {
      return _wrapModule(
        appBar: AppBar(title: Text(widget.title ?? 'Skills')),
        body: const TitansStateView.loading(),
      );
    }

    return _wrapModule(
      appBar: AppBar(title: Text(widget.title ?? 'Skills')),
      body: StreamBuilder<List<TrainingSession>>(
        key: ValueKey('skills-sessions:$contextKey'),
        stream: sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TitansSkeletonCard(lines: 5);
          }
          if (snapshot.hasError) {
            return TitansStateView.error(
              title: 'Erro ao carregar Skills',
              message: snapshot.error.toString(),
            );
          }

          final sessions = snapshot.data ?? const <TrainingSession>[];
          final skillMatrix = _getSkillMatrixSummary(sessions, limit: 50);
          final entries = _getGameMapEvidenceSummary(sessions, limit: 20);

          return StreamBuilder<List<CoachEvaluation>>(
            key: ValueKey('skills-evaluations:$contextKey'),
            stream: coachEvaluationsStream,
            builder: (context, evaluationSnapshot) {
              final evaluations =
                  evaluationSnapshot.data ?? const <CoachEvaluation>[];
              final summary = SkillsOverviewSummary.from(
                entries: entries,
                categories: skillMatrix,
                evaluations: evaluations,
              );
              final libraryModel = SkillsLibraryModel.from(
                sessions: sessions,
                evaluations: evaluations,
              );

              void openSkillDetail(SkillsLibraryTechnique skill) {
                if (_contextKey != contextKey) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => SkillDetailScreen(
                          academyId: widget.academyId,
                          uid: widget.uid,
                          loggedUser: _actor,
                          skillId: skill.skillId,
                          displayName: skill.name,
                          category: skill.category,
                          preferredPosition:
                              skill.positions.isEmpty
                                  ? null
                                  : skill.positions.first,
                          sessions: sessions,
                          evaluations: evaluations,
                        ),
                  ),
                );
              }

              return ListView(
                key: ValueKey('skills-content:$contextKey'),
                padding:
                    widget.embedded
                        ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                        : TitansUI.listPadding(context),
                children: [
                  SkillsOverview(
                    embedded: widget.embedded,
                    targetName: widget.targetName,
                    summary: summary,
                  ),
                  const SizedBox(height: 12),
                  TitansExpandableSection(
                    title: 'Biblioteca técnica',
                    subtitle:
                        'Posição ou categoria → técnica → registros e avaliação.',
                    initiallyExpanded: true,
                    child: SkillsLibrary(
                      key: ValueKey('skills-library:$contextKey'),
                      model: libraryModel,
                      contextKey: contextKey,
                      initialPosition: widget.initialPosition,
                      initialSkillId: widget.initialSkillId,
                      onOpenRecord:
                          (record) => _openTrainingRecord(
                            record,
                            actor: _actor,
                            expectedContextKey: contextKey,
                          ),
                      onOpenTechniqueDetail: openSkillDetail,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openTrainingRecord(
    SkillsLibraryRecord record, {
    required AppUser? actor,
    required String expectedContextKey,
  }) {
    if (!record.canOpen ||
        actor == null ||
        _contextKey != expectedContextKey ||
        !_canOpenTargetHistory) {
      return;
    }
    final isSelf = actor.uid.trim() == widget.uid.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TrainingScreen(
              titleOverride: isSelf ? 'Treinos' : 'Treinos do aluno',
              targetMode: isSelf ? TargetMode.self : TargetMode.selectedStudent,
              explicitTarget: TargetProfile(
                uid: widget.uid,
                academyId: widget.academyId,
              ),
              loggedUser: actor,
              focusSessionId: record.sessionId,
            ),
      ),
    );
  }

  Widget _wrapModule({PreferredSizeWidget? appBar, required Widget body}) {
    if (widget.embedded) return body;
    return TitansScaffold(appBar: appBar, body: body);
  }
}
