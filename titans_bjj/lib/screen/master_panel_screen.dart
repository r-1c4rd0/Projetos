import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
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
    final cs = Theme.of(context).colorScheme;
    final master = UserScope.of(context);

    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom;
    const navBarHeight = 80.0;
    final extraBottom = navBarHeight + bottomPad + 24;

    return TitansScaffold(
      appBar: AppBar(
        title: const Text('Painel do Mestre'),
        actions: [
          IconButton(
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AthleteConsoleScreen(
                    masterView: false,
                    titleOverride: 'Meu perfil',
                    targetMode: TargetMode.self,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'master_panel_fab',
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Cadastrar atleta'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AthleteRegistrationScreen(
                academyId: master.academyId,
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<GradingRules?>(
        stream: _rulesRepo.watch(master.academyId),
        builder: (context, rulesSnap) {
          if (rulesSnap.connectionState == ConnectionState.waiting &&
              !rulesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rulesSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorState(
                  title: 'Erro ao carregar regras',
                  message: rulesSnap.error.toString(),
                ),
              ),
            );
          }

          final rules = rulesSnap.data ?? GradingRules.defaults();

          return StreamBuilder<List<StudentVm>>(
            stream: _studentRepo.watchStudents(academyId: master.academyId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                final error = snap.error;
                final message = error is StudentPermissionDeniedException
                    ? StudentPermissionDeniedException.message
                    : error.toString();

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ErrorState(
                      title: 'Erro ao carregar alunos',
                      message: message,
                    ),
                  ),
                );
              }

              final students = snap.data ?? const <StudentVm>[];
              if (students.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhum aluno encontrado',
                    style:
                        TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, extraBottom),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.1,
                ),
                itemCount: students.length,
                itemBuilder: (context, i) {
                  final student = students[i];
                  final maxDegree = rules.maxDegrees(student.belt);
                  final degree =
                      student.degree.clamp(0, maxDegree).toInt();

                  return _StudentCard(
                    student: student,
                    degree: degree,
                    maxDegree: maxDegree,
                    cs: cs,
                    onMinusDegree: degree == 0
                        ? null
                        : () => _updateStudentDegree(
                              academyId: master.academyId,
                              uid: student.uid,
                              belt: student.belt,
                              degree: degree - 1,
                            ),
                    onPlusDegree: degree == maxDegree
                        ? null
                        : () => _updateStudentDegree(
                              academyId: master.academyId,
                              uid: student.uid,
                              belt: student.belt,
                              degree: degree + 1,
                            ),
                    onTap: () {
                      final controller = SelectedStudentScope.of(context);
                      controller.select(
                        SelectedStudent(
                          academyId: master.academyId,
                          uid: student.uid,
                          name: student.name,
                        ),
                      );

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AthleteConsoleScreen(
                            masterView: true,
                            titleOverride: 'Aluno: ${student.name}',
                            targetMode: TargetMode.selectedStudent,
                          ),
                        ),
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

class _StudentCard extends StatelessWidget {
  final StudentVm student;
  final int degree;
  final int maxDegree;
  final ColorScheme cs;
  final VoidCallback? onPlusDegree;
  final VoidCallback? onMinusDegree;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.degree,
    required this.maxDegree,
    required this.cs,
    required this.onPlusDegree,
    required this.onMinusDegree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final beltColor = _beltUiColor(student.belt);

    return InkWell(
      borderRadius: BorderRadius.circular(TitansUI.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitansUI.radius),
          color: TitansUI.card,
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: beltColor,
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat(
                          cs: cs,
                          title: 'FREQ.',
                          value: '0%',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniStat(
                          cs: cs,
                          title: 'PRONT.',
                          value: '0%',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_beltName(student.belt)} - G$degree/$maxDegree',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: onMinusDegree,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: onPlusDegree,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _miniStat({
    required ColorScheme cs,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: TitansUI.card2,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: cs.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error),
          ),
        ]),
      ),
    );
  }
}
