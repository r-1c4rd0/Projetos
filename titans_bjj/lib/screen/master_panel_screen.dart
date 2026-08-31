import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/invite_repository.dart';
import '../repository/students_repository.dart';
import '../repository/user_repository.dart';
import '../service/selected_student.dart';
import '../service/selected_student_scope.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';
import 'athlete_console_screen.dart';
import 'athlete_registration_screen.dart';

class MasterPanelScreen extends StatefulWidget {
  const MasterPanelScreen({super.key});

  @override
  State<MasterPanelScreen> createState() => _MasterPanelScreenState();
}

class _MasterPanelScreenState extends State<MasterPanelScreen> {
  late final IStudentRepository _studentRepo = StudentRepository.create();
  late final InviteRepository _inviteRepo = InviteRepository.instance;
  late final GradingRulesRepository _rulesRepo =
      GradingRulesRepository.instance;
  late final UserRepository _userRepo = UserRepository.instance;

  @override
  Widget build(BuildContext context) {
    final loggedUser = UserScope.of(context);

    return TitansScaffold(
      appBar: AppBar(
        title: const Text('Painel do Mestre'),
        actions: [
          IconButton(
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _openOwnProfile(loggedUser),
          ),
        ],
      ),
      body: StreamBuilder<GradingRules?>(
        stream: _rulesRepo.watch(loggedUser.academyId),
        builder: (context, rulesSnap) {
          if (rulesSnap.connectionState == ConnectionState.waiting &&
              !rulesSnap.hasData) {
            return const TitansStateView.loading();
          }
          if (rulesSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(TitansUI.spaceMd),
                child: _ErrorState(
                  title: 'Erro ao carregar regras',
                  message: rulesSnap.error.toString(),
                ),
              ),
            );
          }

          final rules = rulesSnap.data ?? GradingRules.defaults();

          return StreamBuilder<List<StudentVm>>(
            stream: _studentRepo.watchStudents(academyId: loggedUser.academyId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const TitansStateView.loading();
              }
              if (snap.hasError) {
                final error = snap.error;
                final message =
                    error is StudentPermissionDeniedException
                        ? StudentPermissionDeniedException.message
                        : error.toString();

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(TitansUI.spaceMd),
                    child: _ErrorState(
                      title: 'Erro ao carregar alunos',
                      message: message,
                    ),
                  ),
                );
              }

              final students = snap.data ?? const <StudentVm>[];
              if (students.isEmpty) {
                return TitansStateView.empty(
                  title: 'Nenhum aluno encontrado',
                  message:
                      'Cadastre o primeiro atleta para iniciar o acompanhamento.',
                  action: FilledButton.icon(
                    onPressed: () => _openRegistration(loggedUser),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Cadastrar atleta'),
                  ),
                );
              }

              return StreamBuilder<List<AcademyInvite>>(
                stream: _inviteRepo.watchAcademyInvites(
                  academyId: loggedUser.academyId,
                ),
                builder: (context, inviteSnap) {
                  final studentAccess = _StudentAccessEntry.resolve(
                    students: students,
                    invites: inviteSnap.data ?? const <AcademyInvite>[],
                  );

                  return _StudentsGrid(
                    actor: loggedUser,
                    students: studentAccess,
                    rules: rules,
                    onCreate: () => _openRegistration(loggedUser),
                    onOpen:
                        (entry) =>
                            _openStudent(entry.targetStudent, loggedUser),
                    onEdit:
                        (entry) => _openStudentRegistration(
                          actor: loggedUser,
                          student: entry.targetStudent,
                        ),
                    onEditGraduation:
                        (entry) => _openGraduationSheet(
                          actor: loggedUser,
                          student: entry.targetStudent,
                          rules: rules,
                        ),
                    onInviteAction:
                        (action, entry) => _handleInviteAction(
                          action: action,
                          entry: entry,
                          actor: loggedUser,
                        ),
                    onArchive:
                        (entry) => _confirmArchiveStudent(
                          actor: loggedUser,
                          entry: entry,
                        ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleInviteAction({
    required _StudentInviteAction action,
    required _StudentAccessEntry entry,
    required AppUser actor,
  }) async {
    final student = entry.displayStudent;
    final messenger = ScaffoldMessenger.of(context);

    try {
      switch (action) {
        case _StudentInviteAction.send:
          final targetUser = await _userRepo.getUser(
            academyId: student.academyId,
            uid: student.uid,
          );
          if (!mounted) return;

          final email = targetUser?.email.trim() ?? '';
          if (email.isEmpty) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Cadastre um e-mail para enviar o convite.'),
              ),
            );
            return;
          }

          final invite = await _inviteRepo.createInviteForStudent(
            academyId: student.academyId,
            email: email,
            role: 'athlete',
            pendingProfileId: student.uid,
            invitedByUid: actor.uid,
            invitedByRole: actor.role.name,
          );
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                invite.status == 'pending'
                    ? 'Convite preparado para $email.'
                    : 'Já existe convite preparado para este aluno.',
              ),
            ),
          );
          break;
        case _StudentInviteAction.copy:
          final invite = entry.invite;
          if (invite == null) return;
          await Clipboard.setData(
            ClipboardData(
              text: _manualInviteText(
                actor: actor,
                entry: entry,
                invite: invite,
              ),
            ),
          );
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Convite copiado.')),
          );
          break;
        case _StudentInviteAction.resend:
          final inviteId = entry.invite?.id;
          if (inviteId == null || inviteId.isEmpty) return;
          await _inviteRepo.resendInvite(
            academyId: student.academyId,
            inviteId: inviteId,
          );
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Convite reenviado.')),
          );
          break;
        case _StudentInviteAction.revoke:
          final inviteId = entry.invite?.id;
          if (inviteId == null || inviteId.isEmpty) return;
          await _inviteRepo.revokeInvite(
            academyId: student.academyId,
            inviteId: inviteId,
          );
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Convite revogado.')),
          );
          break;
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Nao foi possivel atualizar convite: $error')),
      );
    }
  }

  Future<void> _confirmArchiveStudent({
    required AppUser actor,
    required _StudentAccessEntry entry,
  }) async {
    final student = entry.displayStudent;
    final capabilities = _TargetCapabilities.resolve(
      actor: actor,
      targetUid: student.uid,
      targetAcademyId: student.academyId,
      targetMode: TargetMode.selectedStudent,
    );

    if (!capabilities.canArchiveProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem permissao para arquivar este perfil.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Arquivar perfil?'),
            content: const Text(
              'Este perfil sair\u00e1 da listagem principal, mas os dados ser\u00e3o preservados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Arquivar perfil'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _studentRepo.archiveStudent(
        academyId: student.academyId,
        uid: student.uid,
        archivedByUid: actor.uid,
        archivedByRole: actor.role.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil arquivado. Os dados foram preservados.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel arquivar perfil: $error')),
      );
    }
  }

  String _manualInviteText({
    required AppUser actor,
    required _StudentAccessEntry entry,
    required AcademyInvite invite,
  }) {
    final academyLabel = actor.academyId.trim();
    return [
      'Convite Titans BJJ',
      'Academia: $academyLabel',
      'Aluno: ${entry.displayStudent.name}',
      'E-mail convidado: ${invite.emailNormalized}',
      'academyId: ${invite.academyId}',
      'inviteId: ${invite.id}',
      'Este convite está preparado para ativação futura.',
      'No ambiente atual, o aceite automático ainda não está disponível.',
      'Quando for habilitado, entre ou crie uma conta com o mesmo e-mail.',
    ].join(String.fromCharCode(10));
  }

  void _openOwnProfile(AppUser loggedUser) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AthleteConsoleScreen(
              masterView: false,
              titleOverride: 'Meu perfil',
              targetMode: TargetMode.self,
              loggedUser: loggedUser,
            ),
      ),
    );
  }

  void _openRegistration(AppUser loggedUser) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AthleteRegistrationScreen(
              academyId: loggedUser.academyId,
              mode: AthleteRegistrationMode.createAthlete,
            ),
      ),
    );
  }

  void _openStudentRegistration({
    required AppUser actor,
    required StudentVm student,
  }) {
    if (student.uid.trim().isEmpty || student.academyId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aluno alvo n\u00e3o informado para edi\u00e7\u00e3o.'),
        ),
      );
      return;
    }

    debugPrint(
      '[ATHLETE_EDIT_OPEN] source=MasterPanel actor.uid=${actor.uid} '
      'actor.role=${actor.role} target.uid=${student.uid} '
      'target.academyId=${student.academyId}',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AthleteRegistrationScreen(
              academyId: student.academyId,
              athleteUid: student.uid,
              mode: AthleteRegistrationMode.editStudent,
            ),
      ),
    );
  }

  void _openStudent(StudentVm student, AppUser loggedUser) {
    final selectedStudent = SelectedStudent(
      academyId: student.academyId,
      uid: student.uid,
      name: student.name,
    );
    SelectedStudentScope.of(context).select(selectedStudent);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AthleteConsoleScreen(
              masterView: true,
              titleOverride: 'Aluno: ${student.name}',
              targetMode: TargetMode.selectedStudent,
              selectedStudent: selectedStudent,
              loggedUser: loggedUser,
            ),
      ),
    );
  }

  Future<void> _openGraduationSheet({
    required AppUser actor,
    required StudentVm student,
    required GradingRules rules,
  }) async {
    final capabilities = _TargetCapabilities.resolve(
      actor: actor,
      targetUid: student.uid,
      targetAcademyId: student.academyId,
      targetMode: TargetMode.selectedStudent,
    );

    debugPrint(
      '[TARGET_CAPABILITIES] screen=MasterPanelScreen actor.uid=${actor.uid} '
      'actor.role=${actor.role} target.uid=${student.uid} '
      'canEditGraduation=${capabilities.canEditGraduation}',
    );

    if (!capabilities.canEditGraduation) return;

    final targetUser = await _userRepo.getUser(
      academyId: student.academyId,
      uid: student.uid,
    );
    if (!mounted) return;

    final currentBelt = targetUser?.belt ?? student.belt;
    final oldDegree =
        (targetUser?.degree ?? student.degree)
            .clamp(0, rules.maxDegrees(currentBelt))
            .toInt();
    final draft = await TitansBottomSheet.show<_GraduationDraft>(
      context: context,
      builder:
          (context) => _GraduationBottomSheet(
            currentBelt: currentBelt,
            currentDegree: oldDegree,
            rules: rules,
          ),
    );

    if (draft == null) return;

    debugPrint(
      '[GRADUATION_SHEET] save actor.uid=${actor.uid} actor.role=${actor.role} '
      'target.uid=${student.uid} old=${currentBelt.name}/$oldDegree '
      'new=${draft.belt.name}/${draft.degree}',
    );

    await _updateStudentDegree(
      academyId: student.academyId,
      uid: student.uid,
      belt: draft.belt,
      degree: draft.degree,
    );
  }

  Future<void> _updateStudentDegree({
    required String academyId,
    required String uid,
    required BeltColor belt,
    required int degree,
  }) async {
    try {
      await _userRepo.updateBeltDegree(
        academyId: academyId,
        uid: uid,
        belt: belt,
        degree: degree,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('N\u00e3o foi poss\u00edvel atualizar grau: $error'),
        ),
      );
    }
  }
}

enum _StudentAccessStatus { active, pending, noAccess, expired, revoked }

class _StudentAccessEntry {
  final StudentVm displayStudent;
  final StudentVm targetStudent;
  final _StudentAccessStatus status;
  final AcademyInvite? invite;

  const _StudentAccessEntry({
    required this.displayStudent,
    required this.targetStudent,
    required this.status,
    this.invite,
  });

  static List<_StudentAccessEntry> resolve({
    required List<StudentVm> students,
    required List<AcademyInvite> invites,
  }) {
    final studentsByUid = {
      for (final student in students) student.uid: student,
    };
    final inviteByPendingId = <String, AcademyInvite>{};

    for (final invite in invites) {
      final pendingId = invite.pendingProfileId?.trim();
      if (pendingId == null || pendingId.isEmpty) continue;
      final current = inviteByPendingId[pendingId];
      if (current == null ||
          _statusPriority(invite.status) < _statusPriority(current.status)) {
        inviteByPendingId[pendingId] = invite;
      }
    }

    final hiddenLegacyUids = <String>{};
    for (final invite in invites) {
      final pendingId = invite.pendingProfileId?.trim();
      final authUid = invite.acceptedAuthUid?.trim();
      if (invite.status != 'accepted' ||
          pendingId == null ||
          pendingId.isEmpty ||
          authUid == null ||
          authUid.isEmpty) {
        continue;
      }
      if (studentsByUid.containsKey(authUid)) hiddenLegacyUids.add(pendingId);
    }

    final entries = <_StudentAccessEntry>[];
    for (final student in students) {
      if (hiddenLegacyUids.contains(student.uid)) continue;

      final invite = inviteByPendingId[student.uid];
      final acceptedAuthUid = invite?.acceptedAuthUid?.trim();
      final hasAcceptedInvite =
          invite?.status == 'accepted' &&
          acceptedAuthUid != null &&
          acceptedAuthUid.isNotEmpty;
      final isActive =
          student.hasAuthLink ||
          (student.migratedFromPendingProfileId?.trim().isNotEmpty ?? false) ||
          invites.any((invite) => invite.acceptedAuthUid == student.uid) ||
          hasAcceptedInvite;

      final targetStudent =
          hasAcceptedInvite && acceptedAuthUid != student.uid
              ? student.copyWith(uid: acceptedAuthUid, hasAuthLink: true)
              : student;

      entries.add(
        _StudentAccessEntry(
          displayStudent: student,
          targetStudent: targetStudent,
          status: isActive ? _StudentAccessStatus.active : _statusFrom(invite),
          invite: invite,
        ),
      );
    }

    entries.sort(
      (a, b) => a.displayStudent.name.compareTo(b.displayStudent.name),
    );
    return entries;
  }

  static int _statusPriority(String status) {
    switch (status) {
      case 'accepted':
        return 0;
      case 'pending':
        return 1;
      case 'expired':
        return 2;
      case 'revoked':
        return 3;
      default:
        return 4;
    }
  }

  static _StudentAccessStatus _statusFrom(AcademyInvite? invite) {
    switch (invite?.status) {
      case 'pending':
        return _StudentAccessStatus.pending;
      case 'expired':
        return _StudentAccessStatus.expired;
      case 'revoked':
        return _StudentAccessStatus.revoked;
      case 'accepted':
        return _StudentAccessStatus.active;
      default:
        return _StudentAccessStatus.noAccess;
    }
  }
}

class _StudentsGrid extends StatelessWidget {
  final AppUser actor;
  final List<_StudentAccessEntry> students;
  final GradingRules rules;
  final VoidCallback onCreate;
  final ValueChanged<_StudentAccessEntry> onOpen;
  final ValueChanged<_StudentAccessEntry> onEdit;
  final ValueChanged<_StudentAccessEntry> onEditGraduation;
  final void Function(_StudentInviteAction, _StudentAccessEntry) onInviteAction;
  final ValueChanged<_StudentAccessEntry> onArchive;

  const _StudentsGrid({
    required this.actor,
    required this.students,
    required this.rules,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onInviteAction,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        TitansUI.listPadding(context, extra: TitansUI.spaceLg).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio =
            width < 390
                ? 1.95
                : width < 900
                ? 2.15
                : 2.35;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TitansUI.spaceMd,
                TitansUI.spaceMd,
                TitansUI.spaceMd,
                TitansUI.spaceSm,
              ),
              sliver: SliverToBoxAdapter(
                child: _MasterListHeader(
                  total: students.length,
                  onCreate: onCreate,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                TitansUI.spaceMd,
                0,
                TitansUI.spaceMd,
                bottomInset,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisSpacing: TitansUI.spaceSm,
                  crossAxisSpacing: TitansUI.spaceSm,
                  childAspectRatio: ratio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = students[index];
                  final student = entry.displayStudent;
                  final maxDegree = rules.maxDegrees(student.belt);
                  final degree = student.degree.clamp(0, maxDegree).toInt();

                  final capabilities = _TargetCapabilities.resolve(
                    actor: actor,
                    targetUid: student.uid,
                    targetAcademyId: student.academyId,
                    targetMode: TargetMode.selectedStudent,
                  );

                  return _StudentCard(
                    student: student,
                    degree: degree,
                    maxDegree: maxDegree,
                    capabilities: capabilities,
                    accessStatus: entry.status,
                    onOpen: () => onOpen(entry),
                    onEdit: () => onEdit(entry),
                    onEditGraduation: () => onEditGraduation(entry),
                    onInviteAction: (action) => onInviteAction(action, entry),
                    onArchive: () => onArchive(entry),
                    canCopyInvite: entry.invite != null,
                  );
                }, childCount: students.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MasterListHeader extends StatelessWidget {
  final int total;
  final VoidCallback onCreate;

  const _MasterListHeader({required this.total, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      padding: const EdgeInsets.all(TitansUI.spaceMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atletas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '$total aluno${total == 1 ? '' : 's'} vinculado${total == 1 ? '' : 's'} a esta academia',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Cadastrar atleta'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: TitansUI.spaceMd),
                action,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: TitansUI.spaceMd),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentVm student;
  final int degree;
  final int maxDegree;
  final _TargetCapabilities capabilities;
  final _StudentAccessStatus accessStatus;
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;
  final VoidCallback onOpen;
  final ValueChanged<_StudentInviteAction> onInviteAction;
  final VoidCallback onArchive;
  final bool canCopyInvite;

  const _StudentCard({
    required this.student,
    required this.degree,
    required this.maxDegree,
    required this.capabilities,
    required this.accessStatus,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onOpen,
    required this.onInviteAction,
    required this.onArchive,
    required this.canCopyInvite,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = beltUiColor(student.belt);
    final beltLabel = '${beltName(student.belt)} - Grau $degree/$maxDegree';

    return TitansCard(
      accent: beltColor,
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      onTap: onOpen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentProgressRing(
                degree: degree,
                maxDegree: maxDegree,
                color: beltColor,
              ),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      beltLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: TitansUI.spaceXs),
                    Wrap(
                      spacing: TitansUI.spaceXs,
                      runSpacing: TitansUI.spaceXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _AccessStatusBadge(status: accessStatus),
                        _StudentInfoPill(
                          icon: Icons.military_tech_outlined,
                          label: beltName(student.belt),
                          color: beltColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (capabilities.canViewAdminActions)
                _StudentActionsMenu(
                  canEditProfile: capabilities.canEditProfile,
                  canEditGraduation: capabilities.canEditGraduation,
                  canArchiveProfile: capabilities.canArchiveProfile,
                  onEdit: onEdit,
                  onEditGraduation: onEditGraduation,
                  onArchive: onArchive,
                  accessStatus: accessStatus,
                  onInviteAction: onInviteAction,
                  canCopyInvite: canCopyInvite,
                ),
            ],
          );
          final openAction = Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Abrir aluno'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(88, 36),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: TitansUI.spaceSm),
                openAction,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: TitansUI.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Acompanhamento pelo console do aluno selecionado.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.56),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  openAction,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Color beltUiColor(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return Colors.white.withValues(alpha: 0.95);
      case BeltColor.blue:
        return TitansUI.neonBlue;
      case BeltColor.purple:
        return TitansUI.neonPurple;
      case BeltColor.brown:
        return const Color(0xFF8D6E63);
      case BeltColor.black:
        return Colors.black;
    }
  }

  static String beltName(BeltColor belt) {
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

class _StudentProgressRing extends StatelessWidget {
  final int degree;
  final int maxDegree;
  final Color color;

  const _StudentProgressRing({
    required this.degree,
    required this.maxDegree,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeMax = maxDegree.clamp(1, 12).toInt();
    final safeDegree = degree.clamp(0, safeMax).toInt();
    final value = (safeDegree / safeMax).clamp(0.0, 1.0).toDouble();
    final textColor = color.computeLuminance() > 0.82 ? cs.onSurface : color;

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$safeDegree',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'grau',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StudentInfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = color.computeLuminance() > 0.82 ? cs.onSurface : color;

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.pill),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStatusBadge extends StatelessWidget {
  final _StudentAccessStatus status;

  const _AccessStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs);

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.pill),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        _label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case _StudentAccessStatus.active:
        return 'Ativo';
      case _StudentAccessStatus.pending:
        return 'Convite pendente';
      case _StudentAccessStatus.expired:
        return 'Expirado';
      case _StudentAccessStatus.revoked:
        return 'Revogado';
      case _StudentAccessStatus.noAccess:
        return 'Sem acesso';
    }
  }

  Color _color(ColorScheme cs) {
    switch (status) {
      case _StudentAccessStatus.active:
        return cs.primary;
      case _StudentAccessStatus.pending:
        return TitansUI.neonGold;
      case _StudentAccessStatus.expired:
      case _StudentAccessStatus.revoked:
        return cs.error;
      case _StudentAccessStatus.noAccess:
        return cs.onSurface.withValues(alpha: 0.62);
    }
  }
}

enum _StudentInviteAction { send, copy, resend, revoke }

enum _StudentAction {
  edit,
  editGraduation,
  sendInvite,
  copyInvite,
  resendInvite,
  revokeInvite,
  archive,
}

class _StudentActionsMenu extends StatelessWidget {
  final bool canEditProfile;
  final bool canEditGraduation;
  final bool canArchiveProfile;
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;
  final VoidCallback onArchive;
  final _StudentAccessStatus accessStatus;
  final ValueChanged<_StudentInviteAction> onInviteAction;
  final bool canCopyInvite;

  const _StudentActionsMenu({
    required this.canEditProfile,
    required this.canEditGraduation,
    required this.canArchiveProfile,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onArchive,
    required this.accessStatus,
    required this.onInviteAction,
    required this.canCopyInvite,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StudentAction>(
      tooltip: 'A\u00e7\u00f5es do atleta',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _StudentAction.edit:
            onEdit();
            break;
          case _StudentAction.editGraduation:
            onEditGraduation();
            break;
          case _StudentAction.sendInvite:
            onInviteAction(_StudentInviteAction.send);
            break;
          case _StudentAction.copyInvite:
            onInviteAction(_StudentInviteAction.copy);
            break;
          case _StudentAction.resendInvite:
            onInviteAction(_StudentInviteAction.resend);
            break;
          case _StudentAction.revokeInvite:
            onInviteAction(_StudentInviteAction.revoke);
            break;
          case _StudentAction.archive:
            onArchive();
            break;
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: _StudentAction.edit,
              enabled: canEditProfile,
              child: const _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Editar atleta',
              ),
            ),
            PopupMenuItem(
              value: _StudentAction.editGraduation,
              enabled: canEditGraduation,
              child: const _MenuItem(
                icon: Icons.workspace_premium_outlined,
                label: 'Editar gradua\u00e7\u00e3o',
              ),
            ),
            if (accessStatus == _StudentAccessStatus.noAccess)
              PopupMenuItem(
                value: _StudentAction.sendInvite,
                child: const _MenuItem(
                  icon: Icons.outgoing_mail,
                  label: 'Enviar convite',
                ),
              ),
            if (canCopyInvite &&
                (accessStatus == _StudentAccessStatus.pending ||
                    accessStatus == _StudentAccessStatus.expired))
              PopupMenuItem(
                value: _StudentAction.copyInvite,
                child: const _MenuItem(
                  icon: Icons.copy_outlined,
                  label: 'Copiar convite',
                ),
              ),
            if (accessStatus == _StudentAccessStatus.pending ||
                accessStatus == _StudentAccessStatus.expired)
              PopupMenuItem(
                value: _StudentAction.resendInvite,
                child: const _MenuItem(
                  icon: Icons.mark_email_unread_outlined,
                  label: 'Reenviar convite',
                ),
              ),
            if (accessStatus == _StudentAccessStatus.pending)
              PopupMenuItem(
                value: _StudentAction.revokeInvite,
                child: const _MenuItem(
                  icon: Icons.block_outlined,
                  label: 'Revogar convite',
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _StudentAction.archive,
              enabled: canArchiveProfile,
              child: const _MenuItem(
                icon: Icons.archive_outlined,
                label: 'Arquivar perfil',
              ),
            ),
          ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: TitansUI.spaceSm),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return TitansStateView.error(title: title, message: message);
  }
}

class _TargetCapabilities {
  final bool canEditProfile;
  final bool canEditGraduation;
  final bool canViewAdminActions;
  final bool canArchiveProfile;

  const _TargetCapabilities({
    required this.canEditProfile,
    required this.canEditGraduation,
    required this.canViewAdminActions,
    required this.canArchiveProfile,
  });

  factory _TargetCapabilities.resolve({
    required AppUser actor,
    required String targetUid,
    required String targetAcademyId,
    required TargetMode targetMode,
  }) {
    final isStaff =
        actor.role == UserRole.admin || actor.role == UserRole.professor;
    final sameAcademy = actor.academyId == targetAcademyId;
    final actingAsMaster = targetMode == TargetMode.selectedStudent;
    final isDifferentTarget = actor.uid != targetUid;
    final canManageTarget =
        isStaff && sameAcademy && actingAsMaster && isDifferentTarget;

    return _TargetCapabilities(
      canEditProfile: canManageTarget,
      canEditGraduation: canManageTarget,
      canViewAdminActions: canManageTarget,
      canArchiveProfile: canManageTarget,
    );
  }
}

class _GraduationDraft {
  final BeltColor belt;
  final int degree;

  const _GraduationDraft({required this.belt, required this.degree});
}

class _GraduationBottomSheet extends StatefulWidget {
  final BeltColor currentBelt;
  final int currentDegree;
  final GradingRules rules;

  const _GraduationBottomSheet({
    required this.currentBelt,
    required this.currentDegree,
    required this.rules,
  });

  @override
  State<_GraduationBottomSheet> createState() => _GraduationBottomSheetState();
}

class _GraduationBottomSheetState extends State<_GraduationBottomSheet> {
  late BeltColor _selectedBelt = widget.currentBelt;
  late int _selectedDegree = widget.currentDegree;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltOptions =
        widget.rules.beltOrder.isEmpty
            ? BeltColor.values
            : widget.rules.beltOrder;
    final maxDegree = widget.rules.maxDegrees(_selectedBelt);
    final degreeOptions = List<int>.generate(maxDegree + 1, (index) => index);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(TitansUI.spaceMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Editar gradua\u00e7\u00e3o',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceSm),
          TitansCard(
            accent: _StudentCard.beltUiColor(widget.currentBelt),
            padding: const EdgeInsets.all(TitansUI.spaceMd),
            radius: TitansUI.radiusSmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gradua\u00e7\u00e3o atual',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_StudentCard.beltName(widget.currentBelt)} - Grau ${widget.currentDegree}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TitansUI.spaceMd),
          DropdownButtonFormField<BeltColor>(
            initialValue: _selectedBelt,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nova faixa'),
            items: [
              for (final belt in beltOptions)
                DropdownMenuItem(
                  value: belt,
                  child: Text(_StudentCard.beltName(belt)),
                ),
            ],
            onChanged: (belt) {
              if (belt == null) return;
              setState(() {
                _selectedBelt = belt;
                _selectedDegree =
                    _selectedDegree
                        .clamp(0, widget.rules.maxDegrees(belt))
                        .toInt();
              });
            },
          ),
          const SizedBox(height: TitansUI.spaceMd),
          DropdownButtonFormField<int>(
            key: ValueKey('${_selectedBelt.name}-$_selectedDegree'),
            initialValue: _selectedDegree.clamp(0, maxDegree).toInt(),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Novo grau'),
            items: [
              for (final degree in degreeOptions)
                DropdownMenuItem(value: degree, child: Text('$degree')),
            ],
            onChanged: (degree) {
              if (degree == null) return;
              setState(() => _selectedDegree = degree);
            },
          ),
          const SizedBox(height: TitansUI.spaceMd),
          Divider(color: cs.onSurface.withValues(alpha: 0.12)),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: TitansUI.spaceSm,
            overflowSpacing: TitansUI.spaceSm,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _GraduationDraft(
                      belt: _selectedBelt,
                      degree: _selectedDegree.clamp(0, maxDegree).toInt(),
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
