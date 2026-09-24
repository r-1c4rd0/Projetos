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

part '../widgets/master_panel/master_panel_attention_section.dart';
part '../widgets/master_panel/master_panel_student_card.dart';
part '../widgets/master_panel/master_panel_student_roster.dart';

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
                  final studentAccess = MasterPanelStudentEntry.resolve(
                    students: students,
                    invites: inviteSnap.data ?? const <AcademyInvite>[],
                  );

                  return MasterPanelStudentRoster(
                    key: ValueKey(
                      'master-panel-roster-${loggedUser.academyId}',
                    ),
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
    required MasterPanelStudentInviteAction action,
    required MasterPanelStudentEntry entry,
    required AppUser actor,
  }) async {
    final student = entry.displayStudent;
    final messenger = ScaffoldMessenger.of(context);

    try {
      switch (action) {
        case MasterPanelStudentInviteAction.send:
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
        case MasterPanelStudentInviteAction.copy:
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
        case MasterPanelStudentInviteAction.resend:
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
        case MasterPanelStudentInviteAction.revoke:
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
    required MasterPanelStudentEntry entry,
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
    required MasterPanelStudentEntry entry,
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

enum MasterPanelStudentAccessStatus {
  active,
  pending,
  noAccess,
  expired,
  revoked,
}

enum _RosterStatusFilter { all, needsAttention, active }

class MasterPanelStudentEntry {
  final StudentVm displayStudent;
  final StudentVm targetStudent;
  final MasterPanelStudentAccessStatus status;
  final AcademyInvite? invite;

  const MasterPanelStudentEntry({
    required this.displayStudent,
    required this.targetStudent,
    required this.status,
    this.invite,
  });

  static List<MasterPanelStudentEntry> resolve({
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

    final entries = <MasterPanelStudentEntry>[];
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
        MasterPanelStudentEntry(
          displayStudent: student,
          targetStudent: targetStudent,
          status:
              isActive
                  ? MasterPanelStudentAccessStatus.active
                  : _statusFrom(invite),
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

  static MasterPanelStudentAccessStatus _statusFrom(AcademyInvite? invite) {
    switch (invite?.status) {
      case 'pending':
        return MasterPanelStudentAccessStatus.pending;
      case 'expired':
        return MasterPanelStudentAccessStatus.expired;
      case 'revoked':
        return MasterPanelStudentAccessStatus.revoked;
      case 'accepted':
        return MasterPanelStudentAccessStatus.active;
      default:
        return MasterPanelStudentAccessStatus.noAccess;
    }
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
