import 'package:flutter/material.dart';

import '../service/selected_student.dart';
import '../service/target_resolver.dart';
import '../widgets/require_selected_student_gate.dart';
import '../widgets/titans_scaffold.dart';

import 'athlete_dashboard_screen.dart';
import 'nutrition_screen.dart';
import 'progress_screen.dart';
import 'training_screen.dart';

class AthleteConsoleScreen extends StatelessWidget {
  final bool masterView;
  final String? titleOverride;
  final TargetMode targetMode;

  const AthleteConsoleScreen({
    super.key,
    required this.masterView,
    this.titleOverride,
    this.targetMode = TargetMode.self,
  });

  @override
  Widget build(BuildContext context) {
    if (targetMode == TargetMode.selectedStudent) {
      return RequireSelectedStudentGate(
        builder: (context, SelectedStudent selected) {
          return _ConsoleBody(
            title: titleOverride ?? 'Aluno: ${selected.name}',
            athleteNameOverride: selected.name,
            targetMode: TargetMode.selectedStudent,
            masterView: true,
          );
        },
      );
    }

    return _ConsoleBody(
      title: titleOverride ?? 'Inicio',
      athleteNameOverride: null,
      targetMode: TargetMode.self,
      masterView: masterView,
    );
  }
}

class _ConsoleBody extends StatelessWidget {
  final String title;
  final String? athleteNameOverride;
  final TargetMode targetMode;
  final bool masterView;

  const _ConsoleBody({
    required this.title,
    required this.masterView,
    required this.targetMode,
    this.athleteNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final selectedMode = targetMode == TargetMode.selectedStudent;

    return DefaultTabController(
      length: 4,
      child: TitansScaffold(
        scroll: false,
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Inicio'),
              Tab(icon: Icon(Icons.sports_mma_outlined), text: 'Treinos'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Progresso'),
              Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutricao'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AthleteDashboardScreen(
              athleteNameOverride: athleteNameOverride,
              titleOverride: selectedMode ? 'Resumo do aluno' : 'Inicio',
              targetMode: targetMode,
            ),
            TrainingScreen(
              titleOverride: selectedMode ? 'Treinos do aluno' : 'Treinos',
              targetMode: targetMode,
            ),
            ProgressScreen(
              titleOverride: selectedMode ? 'Progresso do aluno' : 'Progresso',
              targetMode: targetMode,
            ),
            NutritionScreen(
              titleOverride: selectedMode ? 'Nutricao do aluno' : 'Nutricao',
              targetMode: targetMode,
            ),
          ],
        ),
      ),
    );
  }
}