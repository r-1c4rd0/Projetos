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
                final message = error is StudentPermissionDeniedException
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
                students: students,
                rules: rules,
                onCreate: () => _openRegistration(loggedUser),
                onOpen: (student) => _openStudent(student, loggedUser),
                onEdit: (student) => _openRegistration(
                  loggedUser,
                  athleteUid: student.uid,
                ),
                onMinusDegree: (student, degree) => _updateStudentDegree(
                  academyId: loggedUser.academyId,
                  uid: student.uid,
                  belt: student.belt,
                  degree: degree - 1,
                ),
                onPlusDegree: (student, degree) => _updateStudentDegree(
                  academyId: loggedUser.academyId,
                  uid: student.uid,
                  belt: student.belt,
                  degree: degree + 1,
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
        builder: (_) => AthleteConsoleScreen(
          masterView: false,
          titleOverride: 'Meu perfil',
          targetMode: TargetMode.self,
          loggedUser: loggedUser,
        ),
      ),
    );
  }

  void _openRegistration(AppUser loggedUser, {String? athleteUid}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AthleteRegistrationScreen(
          academyId: loggedUser.academyId,
          athleteUid: athleteUid,
        ),
      ),
    );
  }

  void _openStudent(StudentVm student, AppUser loggedUser) {
    final selectedStudent = SelectedStudent(
      academyId: loggedUser.academyId,
      uid: student.uid,
      name: student.name,
    );
    SelectedStudentScope.of(context).select(selectedStudent);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AthleteConsoleScreen(
          masterView: true,
          titleOverride: 'Aluno: ${student.name}',
          targetMode: TargetMode.selectedStudent,
          selectedStudent: selectedStudent,
          loggedUser: loggedUser,
        ),
      ),
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
        SnackBar(content: Text('Nao foi possivel atualizar grau: $error')),
      );
    }
  }
}

class _StudentsGrid extends StatelessWidget {
  final List<StudentVm> students;
  final GradingRules rules;
  final VoidCallback onCreate;
  final ValueChanged<StudentVm> onOpen;
  final ValueChanged<StudentVm> onEdit;
  final void Function(StudentVm student, int degree) onMinusDegree;
  final void Function(StudentVm student, int degree) onPlusDegree;

  const _StudentsGrid({
    required this.students,
    required this.rules,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onMinusDegree,
    required this.onPlusDegree,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        TitansUI.listPadding(context, extra: TitansUI.spaceLg).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = width < 390
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final student = students[index];
                    final maxDegree = rules.maxDegrees(student.belt);
                    final degree = student.degree.clamp(0, maxDegree).toInt();

                    return _StudentCard(
                      student: student,
                      degree: degree,
                      maxDegree: maxDegree,
                      onOpen: () => onOpen(student),
                      onEdit: () => onEdit(student),
                      onMinusDegree: degree == 0
                          ? null
                          : () => onMinusDegree(student, degree),
                      onPlusDegree: degree == maxDegree
                          ? null
                          : () => onPlusDegree(student, degree),
                    );
                  },
                  childCount: students.length,
                ),
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

  const _MasterListHeader({
    required this.total,
    required this.onCreate,
  });

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
  final VoidCallback? onPlusDegree;
  final VoidCallback? onMinusDegree;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  const _StudentCard({
    required this.student,
    required this.degree,
    required this.maxDegree,
    required this.onPlusDegree,
    required this.onMinusDegree,
    required this.onEdit,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = _beltUiColor(student.belt);
    final beltLabel = '${_beltName(student.belt)} - Grau $degree/$maxDegree';

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
                    _StudentActionsMenu(
                      onEdit: onEdit,
                      onMinusDegree: onMinusDegree,
                      onPlusDegree: onPlusDegree,
                    ),
                  ],
                ),
                const SizedBox(height: TitansUI.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: _CompactMetric(
                        label: 'Frequencia',
                        value: '0%',
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: TitansUI.spaceXs),
                    Expanded(
                      child: _CompactMetric(
                        label: 'Prontidao',
                        value: '0%',
                        color: TitansUI.neonGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TitansUI.spaceXs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final lastTraining = Text(
                      'Ultimo treino: sem registro',
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

                    return Row(
                      children: [
                        Expanded(child: lastTraining),
                        open,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _beltUiColor(BeltColor belt) {
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

  String _beltName(BeltColor belt) {
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

enum _StudentAction { edit, decrementDegree, incrementDegree }

class _StudentActionsMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback? onMinusDegree;
  final VoidCallback? onPlusDegree;

  const _StudentActionsMenu({
    required this.onEdit,
    required this.onMinusDegree,
    required this.onPlusDegree,
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
          case _StudentAction.decrementDegree:
            onMinusDegree?.call();
            break;
          case _StudentAction.incrementDegree:
            onPlusDegree?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _StudentAction.edit,
          child: _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Editar atleta',
          ),
        ),
        PopupMenuItem(
          value: _StudentAction.decrementDegree,
          enabled: onMinusDegree != null,
          child: const _MenuItem(
            icon: Icons.remove_circle_outline,
            label: 'Diminuir grau',
          ),
        ),
        PopupMenuItem(
          value: _StudentAction.incrementDegree,
          enabled: onPlusDegree != null,
          child: const _MenuItem(
            icon: Icons.add_circle_outline,
            label: 'Aumentar grau',
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({
    required this.icon,
    required this.label,
  });

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
