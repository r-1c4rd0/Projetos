import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/grading_rules.dart';
import '../repository/students_repository.dart';
import '../service/selected_student.dart';
import '../service/selected_student_scope.dart';
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
  late final StudentRepository _repo =
  StudentRepository(FirebaseFirestore.instance);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final master = UserScope.of(context); // AppUser logado

    final media = MediaQuery.of(context);
    final bottomPad = media.padding.bottom;
    const navBarHeight = 80.0; // aproximação boa do NavigationBar M3
    final extraBottom = navBarHeight + bottomPad + 24;

    return TitansScaffold(
      appBar: AppBar(
        title: const Text('Painel do Mestre'),
        actions: [
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
      body: StreamBuilder<List<StudentVm>>(
        stream: _repo.watchStudents(academyId: master.academyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorState(
                  title: 'Erro ao carregar alunos',
                  message: snap.error.toString(),
                ),
              ),
            );
          }

          final students = snap.data ?? const <StudentVm>[];
          if (students.isEmpty) {
            return Center(
              child: Text(
                'Nenhum aluno encontrado',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
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
              final s = students[i];

              final vm = _StudentCardVm(
                uid: s.uid,
                name: s.name,
                belt: BeltColor.white,
                degree: 0,
                frequency: 0,
                readiness: 0,
              );

              return _StudentCard(
                s: vm,
                cs: cs,
                onPlusDegree: () {},
                onMinusDegree: () {},
                onTap: () {
                  final controller = SelectedStudentScope.of(context);
                  controller.select(
                    SelectedStudent(
                      academyId: master.academyId,
                      uid: vm.uid,
                      name: vm.name,
                    ),
                  );

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AthleteConsoleScreen(
                        masterView: true,
                        titleOverride: 'Aluno: ${vm.name}',
                      ),
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
}

class _StudentCard extends StatelessWidget {
  final _StudentCardVm s;
  final ColorScheme cs;
  final VoidCallback onPlusDegree;
  final VoidCallback onMinusDegree;
  final VoidCallback onTap;

  const _StudentCard({
    required this.s,
    required this.cs,
    required this.onPlusDegree,
    required this.onMinusDegree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final beltColor = TitansUI.beltColor(s.belt.name);

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
                    s.name.toUpperCase(),
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
                          value: '${s.frequency}%',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniStat(
                          cs: cs,
                          title: 'PRONT.',
                          value: '${s.readiness}%',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_beltName(s.belt)} • G${s.degree}',
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

class _StudentCardVm {
  final String uid;
  final String name;
  final BeltColor belt;
  final int degree;
  final int frequency;
  final int readiness;

  _StudentCardVm({
    required this.uid,
    required this.name,
    required this.belt,
    required this.degree,
    required this.frequency,
    required this.readiness,
  });
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
