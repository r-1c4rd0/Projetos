import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
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
  final AppUser? loggedUser;

  const AthleteConsoleScreen({
    super.key,
    required this.masterView,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.selectedStudent,
    this.loggedUser,
  });

  @override
  Widget build(BuildContext context) {
    final actor = loggedUser ?? UserScope.maybeOf(context);
    debugPrint(
      '[ATHLETE_CONSOLE] build targetMode=$targetMode '
      'titleOverride=$titleOverride masterView=$masterView '
      'selectedStudent.uid=${selectedStudent?.uid} '
      'actor.uid=${actor?.uid} actor.role=${actor?.role} '
      'actor.academyId=${actor?.academyId}',
    );

    if (actor == null) {
      return TitansScaffold(
        scroll: false,
        appBar: AppBar(title: Text(titleOverride ?? 'Inicio')),
        body: const TitansStateView.error(
          title: 'Usuario logado nao encontrado',
          message:
              'Nao foi possivel identificar o usuario logado para carregar o console.',
        ),
      );
    }

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
          loggedUser: actor,
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
            loggedUser: actor,
            masterView: true,
          );
        },
      );
    }

    final selfTarget = TargetProfile(
      uid: actor.uid,
      academyId: actor.academyId,
    );

    return _ConsoleBody(
      title: titleOverride ?? 'Inicio',
      athleteNameOverride: null,
      targetMode: TargetMode.self,
      target: selfTarget,
      loggedUser: actor,
      masterView: masterView || titleOverride == 'Meu perfil',
    );
  }
}

class _ConsoleBody extends StatelessWidget {
  final String title;
  final String? athleteNameOverride;
  final TargetMode targetMode;
  final TargetProfile target;
  final bool masterView;
  final AppUser loggedUser;

  const _ConsoleBody({
    required this.title,
    required this.masterView,
    required this.targetMode,
    required this.target,
    required this.loggedUser,
    this.athleteNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final selectedMode = targetMode == TargetMode.selectedStudent;
    final canEditTarget = _canEditTarget(loggedUser, target);
    debugPrint(
      '[ATHLETE_CONSOLE] tabs targetMode=$targetMode title=$title '
      'masterView=$masterView actor.uid=${loggedUser.uid} '
      'actor.role=${loggedUser.role} target.uid=${target.uid} '
      'target.academyId=${target.academyId} canEditTarget=$canEditTarget',
    );

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
                    loggedUser: loggedUser,
                  ),
                  TrainingScreen(
                    titleOverride: selectedMode ? 'Treinos do aluno' : 'Treinos',
                    targetMode: targetMode,
                    explicitTarget: target,
                    loggedUser: loggedUser,
                  ),
                  ProgressScreen(
                    titleOverride:
                        selectedMode ? 'Progresso do aluno' : 'Progresso',
                    targetMode: targetMode,
                    explicitTarget: target,
                    loggedUser: loggedUser,
                  ),
                  NutritionScreen(
                    titleOverride: selectedMode ? 'Nutricao do aluno' : 'Nutricao',
                    targetMode: targetMode,
                    explicitTarget: target,
                    loggedUser: loggedUser,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  bool _canEditTarget(AppUser actor, TargetProfile target) {
    final canManage = actor.role == UserRole.admin ||
        actor.role == UserRole.professor;
    return actor.academyId == target.academyId &&
        (actor.uid == target.uid || canManage);
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
