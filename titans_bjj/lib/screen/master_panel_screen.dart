import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../repository/grading_rules_repository.dart';
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

              return _StudentsGrid(
                actor: loggedUser,
                students: students,
                rules: rules,
                onCreate: () => _openRegistration(loggedUser),
                onOpen: (student) => _openStudent(student, loggedUser),
                onEdit:
                    (student) => _openStudentRegistration(
                      actor: loggedUser,
                      student: student,
                    ),
                onEditGraduation:
                    (student) => _openGraduationSheet(
                      actor: loggedUser,
                      student: student,
                      rules: rules,
                    ),
              );
            },
          );
        },
      ),
    );
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

class _StudentsGrid extends StatelessWidget {
  final AppUser actor;
  final List<StudentVm> students;
  final GradingRules rules;
  final VoidCallback onCreate;
  final ValueChanged<StudentVm> onOpen;
  final ValueChanged<StudentVm> onEdit;
  final ValueChanged<StudentVm> onEditGraduation;

  const _StudentsGrid({
    required this.actor,
    required this.students,
    required this.rules,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onEditGraduation,
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
                ? 1.30
                : width < 600
                ? 1.45
                : 2.25;

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
                  final student = students[index];
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
                    onOpen: () => onOpen(student),
                    onEdit: () => onEdit(student),
                    onEditGraduation: () => onEditGraduation(student),
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
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;
  final VoidCallback onOpen;

  const _StudentCard({
    required this.student,
    required this.degree,
    required this.maxDegree,
    required this.capabilities,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onOpen,
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
      child: Row(
        children: [
          Container(
            width: 6,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitansRadius.pill),
              color: beltColor,
            ),
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          const SizedBox(height: 5),
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
                        ],
                      ),
                    ),
                    if (capabilities.canViewAdminActions)
                      _StudentActionsMenu(
                        canEditProfile: capabilities.canEditProfile,
                        canEditGraduation: capabilities.canEditGraduation,
                        onEdit: onEdit,
                        onEditGraduation: onEditGraduation,
                      ),
                  ],
                ),
                const SizedBox(height: TitansUI.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: _CompactMetric(
                        label: 'Frequ\u00eancia',
                        value: 'Sem dados',
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: TitansUI.spaceXs),
                    Expanded(
                      child: _CompactMetric(
                        label: 'Prontid\u00e3o',
                        value: 'não calculada',
                        color: TitansUI.neonGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TitansUI.spaceXs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final lastTraining = Text(
                      '\u00daltimo treino: sem registro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final open = TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Abrir'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(56, 36),
                      ),
                    );

                    if (constraints.maxWidth < 280) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          lastTraining,
                          Align(alignment: Alignment.centerRight, child: open),
                        ],
                      );
                    }

                    return Row(children: [Expanded(child: lastTraining), open]);
                  },
                ),
              ],
            ),
          ),
        ],
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

enum _StudentAction { edit, editGraduation }

class _StudentActionsMenu extends StatelessWidget {
  final bool canEditProfile;
  final bool canEditGraduation;
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;

  const _StudentActionsMenu({
    required this.canEditProfile,
    required this.canEditGraduation,
    required this.onEdit,
    required this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StudentAction>(
      tooltip: 'Acoes do atleta',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _StudentAction.edit:
            onEdit();
            break;
          case _StudentAction.editGraduation:
            onEditGraduation();
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

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CompactMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceSm,
        vertical: TitansUI.spaceXs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        color: TitansUI.card2,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.52),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
    return TitansStateView.error(title: title, message: message);
  }
}

class _TargetCapabilities {
  final bool canEditProfile;
  final bool canEditGraduation;
  final bool canViewAdminActions;

  const _TargetCapabilities({
    required this.canEditProfile,
    required this.canEditGraduation,
    required this.canViewAdminActions,
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
