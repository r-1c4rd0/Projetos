import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../service/selected_student.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
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
  final SelectedStudent? selectedStudent;

  const AthleteConsoleScreen({
    super.key,
    required this.masterView,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.selectedStudent,
  });

  @override
  Widget build(BuildContext context) {
    if (targetMode == TargetMode.selectedStudent) {
      final explicitSelected = selectedStudent;
      if (explicitSelected != null) {
        return _ConsoleBody(
          title: titleOverride ?? 'Aluno: ${explicitSelected.name}',
          athleteNameOverride: explicitSelected.name,
          targetMode: TargetMode.selectedStudent,
          target: TargetProfile(
            academyId: explicitSelected.academyId,
            uid: explicitSelected.uid,
          ),
          masterView: true,
        );
      }

      return RequireSelectedStudentGate(
        builder: (context, SelectedStudent selected) {
          return _ConsoleBody(
            title: titleOverride ?? 'Aluno: ${selected.name}',
            athleteNameOverride: selected.name,
            targetMode: TargetMode.selectedStudent,
            target: TargetProfile(
              academyId: selected.academyId,
              uid: selected.uid,
            ),
            masterView: true,
          );
        },
      );
    }

    final loggedUser = UserScope.maybeOf(context);
    final selfTarget = loggedUser == null
        ? null
        : TargetProfile(uid: loggedUser.uid, academyId: loggedUser.academyId);

    return _ConsoleBody(
      title: titleOverride ?? 'Inicio',
      athleteNameOverride: null,
      targetMode: TargetMode.self,
      target: selfTarget,
      masterView: masterView || titleOverride == 'Meu perfil',
    );
  }
}

class _ConsoleBody extends StatelessWidget {
  final String title;
  final String? athleteNameOverride;
  final TargetMode targetMode;
  final TargetProfile? target;
  final bool masterView;

  const _ConsoleBody({
    required this.title,
    required this.masterView,
    required this.targetMode,
    required this.target,
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
        body: Column(
          children: [
            _ConsoleContextBanner(
              selectedMode: selectedMode,
              athleteName: athleteNameOverride,
              masterView: masterView,
            ),
            const SizedBox(height: TitansUI.spaceSm),
            Expanded(
              child: TabBarView(
                children: [
                  AthleteDashboardScreen(
                    athleteNameOverride: athleteNameOverride,
                    titleOverride: selectedMode ? 'Resumo do aluno' : 'Inicio',
                    targetMode: targetMode,
                    explicitTarget: target,
                  ),
                  TrainingScreen(
                    titleOverride: selectedMode ? 'Treinos do aluno' : 'Treinos',
                    targetMode: targetMode,
                    explicitTarget: target,
                  ),
                  ProgressScreen(
                    titleOverride:
                        selectedMode ? 'Progresso do aluno' : 'Progresso',
                    targetMode: targetMode,
                    explicitTarget: target,
                  ),
                  NutritionScreen(
                    titleOverride: selectedMode ? 'Nutricao do aluno' : 'Nutricao',
                    targetMode: targetMode,
                    explicitTarget: target,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleContextBanner extends StatelessWidget {
  final bool selectedMode;
  final bool masterView;
  final String? athleteName;

  const _ConsoleContextBanner({
    required this.selectedMode,
    required this.masterView,
    this.athleteName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = selectedMode
        ? 'Aluno selecionado'
        : masterView
            ? 'Meu perfil'
            : 'Area do atleta';
    final subtitle = selectedMode
        ? (athleteName == null || athleteName!.trim().isEmpty
            ? 'Dados do aluno ativo no Painel do Mestre'
            : athleteName!.trim())
        : masterView
            ? 'Visualizando seus dados, nao os de um aluno'
            : 'Seus treinos, progresso e nutricao';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceMd,
        vertical: TitansUI.spaceSm,
      ),
      decoration: TitansUI.cardDecoration(
        context,
        accent: selectedMode ? cs.primary : cs.secondary,
        radius: TitansUI.radiusSmall,
      ),
      child: Row(
        children: [
          Icon(
            selectedMode
                ? Icons.person_pin_circle_outlined
                : Icons.badge_outlined,
            color: selectedMode ? cs.primary : cs.secondary,
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
