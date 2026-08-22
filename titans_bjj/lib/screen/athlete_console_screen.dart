import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../repository/user_repository.dart';
import '../service/selected_student.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/require_selected_student_gate.dart';
import '../widgets/titans_scaffold.dart';

import 'athlete_dashboard_screen.dart';
import 'game_map_screen.dart';
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

class _ConsoleBody extends StatefulWidget {
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
  State<_ConsoleBody> createState() => _ConsoleBodyState();
}

class _ConsoleBodyState extends State<_ConsoleBody> {
  late final UserRepository _userRepo = UserRepository.instance;
  late Stream<AppUser?> _targetUserStream;
  int _selectedModuleIndex = 0;

  @override
  void initState() {
    super.initState();
    _targetUserStream = _watchTargetUser();
  }

  @override
  void didUpdateWidget(covariant _ConsoleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.academyId != widget.target.academyId ||
        oldWidget.target.uid != widget.target.uid) {
      _targetUserStream = _watchTargetUser();
    }
  }

  Stream<AppUser?> _watchTargetUser() {
    return _userRepo.watchUser(
      academyId: widget.target.academyId,
      uid: widget.target.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = _buildModules();
    final selectedMode = widget.targetMode == TargetMode.selectedStudent;
    final selectedModule = modules[_selectedModuleIndex];
    final canEditTarget = _canEditTarget(widget.loggedUser, widget.target);
    debugPrint(
      '[ATHLETE_CONSOLE] moduleHub targetMode=${widget.targetMode} '
      'title=${widget.title} selectedModule=${selectedModule.id} '
      'masterView=${widget.masterView} actor.uid=${widget.loggedUser.uid} '
      'actor.role=${widget.loggedUser.role} target.uid=${widget.target.uid} '
      'target.academyId=${widget.target.academyId} canEditTarget=$canEditTarget',
    );

    final isStaffProfile = widget.loggedUser.role == UserRole.admin ||
        widget.loggedUser.role == UserRole.professor;
    final isSelfProfile = widget.targetMode == TargetMode.self &&
        widget.loggedUser.uid == widget.target.uid &&
        isStaffProfile;
    debugPrint(
      '[ATHLETE_CONSOLE_HEADER] targetMode=${widget.targetMode} '
      'actor.uid=${widget.loggedUser.uid} target.uid=${widget.target.uid} '
      'isSelfProfile=$isSelfProfile isSelectedStudent=$selectedMode',
    );

    return TitansScaffold(
      scroll: false,
      body: Column(
        children: [
          StreamBuilder<AppUser?>(
            initialData: widget.target.uid == widget.loggedUser.uid
                ? widget.loggedUser
                : null,
            stream: _targetUserStream,
            builder: (context, targetSnap) {
              final targetUser = targetSnap.data;
              final fallbackName = selectedMode
                  ? widget.athleteNameOverride
                  : widget.loggedUser.name;

              return _ConsoleContextHeader(
                targetMode: widget.targetMode,
                actor: widget.loggedUser,
                target: widget.target,
                targetUser: targetUser,
                fallbackName: fallbackName,
                isSelfProfile: isSelfProfile,
              );
            },
          ),
          const SizedBox(height: TitansUI.spaceSm),
          _ModuleHub(
            modules: modules,
            selectedIndex: _selectedModuleIndex,
            onSelected: (index) {
              if (index == _selectedModuleIndex || !modules[index].enabled) {
                return;
              }
              setState(() => _selectedModuleIndex = index);
            },
          ),
          const SizedBox(height: TitansUI.spaceSm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.02, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(selectedModule.id),
                child: selectedModule.builder(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_ConsoleModule> _buildModules() {
    final selectedMode = widget.targetMode == TargetMode.selectedStudent;
    final target = widget.target;
    final loggedUser = widget.loggedUser;

    return [
      _ConsoleModule(
        id: 'overview',
        label: 'Overview',
        shortLabel: 'Overview',
        icon: Icons.home_outlined,
        description: 'Resumo do perfil',
        builder: (context) => AthleteDashboardScreen(
          athleteNameOverride: widget.athleteNameOverride,
          titleOverride: 'Inicio',
          targetMode: widget.targetMode,
          explicitTarget: target,
          loggedUser: loggedUser,
          embedded: true,
        ),
      ),
      _ConsoleModule(
        id: 'training',
        label: 'Treinos',
        shortLabel: 'Treinos',
        icon: Icons.sports_mma_outlined,
        description: 'Historico e sessoes',
        builder: (context) => TrainingScreen(
          titleOverride: selectedMode ? 'Treinos do aluno' : 'Treinos',
          targetMode: widget.targetMode,
          explicitTarget: target,
          loggedUser: loggedUser,
          embedded: true,
        ),
      ),
      _ConsoleModule(
        id: 'progress',
        label: 'Progresso',
        shortLabel: 'Progresso',
        icon: Icons.insights_outlined,
        description: 'Evolucao e metas',
        builder: (context) => ProgressScreen(
          titleOverride: selectedMode ? 'Progresso do aluno' : 'Progresso',
          targetMode: widget.targetMode,
          explicitTarget: target,
          loggedUser: loggedUser,
          embedded: true,
        ),
      ),
      _ConsoleModule(
        id: 'gameMap',
        label: 'Game Map',
        shortLabel: 'Game Map',
        icon: Icons.map_outlined,
        description: 'Mapa tecnico',
        builder: (context) => GameMapScreen(
          academyId: target.academyId,
          uid: target.uid,
          title: selectedMode ? 'Game Map do aluno' : 'Game Map',
          targetName: null,
          embedded: true,
        ),
      ),
      _ConsoleModule(
        id: 'nutrition',
        label: 'Nutricao',
        shortLabel: 'Nutricao',
        icon: Icons.restaurant_outlined,
        description: 'Plano alimentar',
        builder: (context) => NutritionScreen(
          titleOverride: selectedMode ? 'Nutricao do aluno' : 'Nutricao',
          targetMode: widget.targetMode,
          explicitTarget: target,
          loggedUser: loggedUser,
          showLeading: false,
          embedded: true,
        ),
      ),
    ];
  }

  bool _canEditTarget(AppUser actor, TargetProfile target) {
    final canManage = actor.role == UserRole.admin ||
        actor.role == UserRole.professor;
    return actor.academyId == target.academyId &&
        (actor.uid == target.uid || canManage);
  }
}

class _ConsoleModule {
  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final String description;
  final WidgetBuilder builder;
  final bool enabled;

  const _ConsoleModule({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.description,
    required this.builder,
    this.enabled = true,
  });
}

class _ModuleHub extends StatelessWidget {
  final List<_ConsoleModule> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ModuleHub({
    required this.modules,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 900;
        final columns = isWide
            ? 5
            : width >= 620
                ? 3
                : 2;
        final gap = isWide ? TitansUI.spaceMd : TitansUI.spaceSm;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < modules.length; index++)
              SizedBox(
                width: cardWidth.clamp(148.0, 220.0).toDouble(),
                child: Tooltip(
                  message: modules[index].label,
                  child: _ModuleCard(
                    module: modules[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final _ConsoleModule module;
  final bool selected;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.selected ? cs.primary : cs.secondary;
    final enabled = widget.module.enabled;

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed && enabled ? 0.98 : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
            onTap: enabled ? widget.onTap : null,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.all(TitansUI.spaceSm),
              decoration: TitansUI.cardDecoration(
                context,
                accent: accent,
                radius: TitansUI.radiusSmall,
              ).copyWith(
                color: widget.selected
                    ? Color.lerp(TitansUI.card, accent, 0.12)
                    : TitansUI.card,
                border: Border.all(
                  color: widget.selected
                      ? accent.withValues(alpha: 0.72)
                      : cs.onSurface.withValues(alpha: 0.09),
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(
                        alpha: widget.selected ? 0.20 : 0.10,
                      ),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: widget.selected ? 0.55 : 0.24,
                        ),
                      ),
                    ),
                    child: Icon(widget.module.icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: TitansUI.spaceSm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.module.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.module.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.64),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsoleContextHeader extends StatelessWidget {
  final TargetMode targetMode;
  final AppUser actor;
  final TargetProfile target;
  final AppUser? targetUser;
  final String? fallbackName;
  final bool isSelfProfile;

  const _ConsoleContextHeader({
    required this.targetMode,
    required this.actor,
    required this.target,
    required this.targetUser,
    required this.fallbackName,
    required this.isSelfProfile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelectedStudent = targetMode == TargetMode.selectedStudent;
    final user = targetUser ?? (target.uid == actor.uid ? actor : null);
    final displayName = _displayName(user, fallbackName);
    final title = isSelfProfile ? 'MEU PERFIL' : displayName;
    final subtitle = isSelfProfile
        ? '$displayName - ${_roleLabel(actor.role)}'
        : user == null
            ? 'Faixa carregando - Grau --'
            : 'Faixa ${_beltName(user.belt)} - Grau ${user.degree}';
    final accent = isSelectedStudent ? cs.primary : cs.secondary;

    return TitansCard(
      accent: accent,
      padding: const EdgeInsets.all(TitansUI.spaceMd),
      radius: TitansUI.radiusSmall,
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            IconButton(
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: TitansUI.spaceXs),
          ],
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.36)),
            ),
            child: Icon(
              isSelectedStudent
                  ? Icons.person_pin_circle_outlined
                  : Icons.badge_outlined,
              color: accent,
            ),
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(AppUser? user, String? fallback) {
    final userName = user?.name.trim() ?? '';
    if (userName.isNotEmpty) return userName;
    final fallbackName = fallback?.trim() ?? '';
    if (fallbackName.isNotEmpty) return fallbackName;
    final email = user?.email.trim() ?? '';
    if (email.isNotEmpty) return email;
    return 'Atleta';
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.professor:
        return 'Professor';
      case UserRole.athlete:
        return 'Atleta';
    }
  }

  String _beltName(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return 'branca';
      case BeltColor.blue:
        return 'azul';
      case BeltColor.purple:
        return 'roxa';
      case BeltColor.brown:
        return 'marrom';
      case BeltColor.black:
        return 'preta';
    }
  }
}
