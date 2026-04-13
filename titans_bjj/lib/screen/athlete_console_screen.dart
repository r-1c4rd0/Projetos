import 'package:flutter/material.dart';

import '../widgets/titans_scaffold.dart';
import '../widgets/require_selected_student_gate.dart';
import '../service/selected_student.dart';

import 'athlete_dashboard_screen.dart';
import 'training_screen.dart';
import 'progress_screen.dart';
import 'nutrition_screen.dart';

class AthleteConsoleScreen extends StatelessWidget {
  final bool masterView;
  final String? titleOverride;

  const AthleteConsoleScreen({
    super.key,
    required this.masterView,
    this.titleOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (masterView) {
      return RequireSelectedStudentGate(
        builder: (context, SelectedStudent selected) {
          return _ConsoleBody(
            title: titleOverride ?? 'Aluno: ${selected.name}',
            athleteNameOverride: selected.name,
            masterView: true,
          );
        },
      );
    }

    return _ConsoleBody(
      title: titleOverride ?? 'Início',
      athleteNameOverride: null,
      masterView: false,
    );
  }
}

class _ConsoleBody extends StatelessWidget {
  final String title;
  final String? athleteNameOverride;
  final bool masterView;

  const _ConsoleBody({
    required this.title,
    required this.masterView,
    this.athleteNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: TitansScaffold(
        scroll: false,
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Início'),
              Tab(icon: Icon(Icons.sports_mma_outlined), text: 'Treinos'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Progresso'),
              Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutrição'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AthleteDashboardScreen(
              athleteNameOverride: masterView ? title.replaceFirst('Aluno: ', '') : null,
              titleOverride: masterView ? 'Resumo do aluno' : 'Início',
            ),
            TrainingScreen(
              titleOverride: masterView ? 'Treinos do aluno' : 'Treinos',
            ),
            ProgressScreen(
              titleOverride: masterView ? 'Progresso do aluno' : 'Progresso',
            ),
            NutritionScreen(
              titleOverride: masterView ? 'Nutrição do aluno' : 'Nutrição',
            ),
          ],
        ),
      ),
    );
  }
}
