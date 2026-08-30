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
import 'athlete_registration_screen.dart';
import 'game_map_screen.dart';
import 'nutrition_screen.dart';
import 'progress_screen.dart';
import 'skills_screen.dart';
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
        appBar: AppBar(title: Text(titleOverride ?? 'In\u00edcio')),
        body: const TitansStateView.error(
          title: 'Usu\u00e1rio logado n\u00e3o encontrado',
          message:
              'N\u00e3o foi poss\u00edvel identificar o usu\u00e1rio logado para carregar o console.',
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
      title: titleOverride ?? 'In\u00edcio',
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
  _ConsoleHeaderVisualState _headerVisualState =
      _ConsoleHeaderVisualState.expanded;

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
      _headerVisualState = _ConsoleHeaderVisualState.expanded;
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

    final isStaffProfile =
        widget.loggedUser.role == UserRole.admin ||
        widget.loggedUser.role == UserRole.professor;
    final isSelfProfile =
        widget.targetMode == TargetMode.self &&
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
            initialData:
                widget.target.uid == widget.loggedUser.uid
                    ? widget.loggedUser
                    : null,
            stream: _targetUserStream,
            builder: (context, targetSnap) {
              final targetUser = targetSnap.data;
              final fallbackName =
                  selectedMode
                      ? widget.athleteNameOverride
                      : widget.loggedUser.name;

              final headerViewModel = _buildHeaderViewModel(
                modules: modules,
                selectedModule: selectedModule,
                targetUser: targetUser,
                fallbackName: fallbackName,
                isSelfProfile: isSelfProfile,
                canEditTarget: canEditTarget,
              );

              return _CollapsibleAthleteConsoleHeader(
                viewModel: headerViewModel,
                visualState: _headerVisualState,
                onBack:
                    Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                onEditProfile: () => _openTargetRegistration(),
                onModuleSelected: (index) {
                  if (index == _selectedModuleIndex ||
                      !modules[index].enabled) {
                    return;
                  }
                  setState(() {
                    _selectedModuleIndex = index;
                    _headerVisualState = _ConsoleHeaderVisualState.expanded;
                  });
                },
              );
            },
          ),
          const SizedBox(height: TitansUI.spaceSm),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleModuleScroll,
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
          ),
        ],
      ),
    );
  }

  bool _handleModuleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final pixels = notification.metrics.pixels;
    final nextState =
        pixels <= 24
            ? _ConsoleHeaderVisualState.expanded
            : pixels <= 120
            ? _ConsoleHeaderVisualState.compact
            : _ConsoleHeaderVisualState.pinned;

    if (nextState != _headerVisualState) {
      setState(() => _headerVisualState = nextState);
    }

    return false;
  }

  List<_ConsoleModule> _buildModules() {
    final selectedMode = widget.targetMode == TargetMode.selectedStudent;
    final target = widget.target;
    final loggedUser = widget.loggedUser;

    return [
      _ConsoleModule(
        id: 'overview',
        label: 'In\u00edcio',
        shortLabel: 'In\u00edcio',
        icon: Icons.home_outlined,
        description: 'Resumo do perfil',
        builder:
            (context) => AthleteDashboardScreen(
              athleteNameOverride: widget.athleteNameOverride,
              titleOverride: 'In\u00edcio',
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
        description: 'Hist\u00f3rico e sess\u00f5es',
        builder:
            (context) => TrainingScreen(
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
        description: 'Evolu\u00e7\u00e3o e metas',
        builder:
            (context) => ProgressScreen(
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
        description: 'Mapa t\u00e9cnico',
        builder:
            (context) => GameMapScreen(
              academyId: target.academyId,
              uid: target.uid,
              title: selectedMode ? 'Game Map do aluno' : 'Game Map',
              targetName: null,
              loggedUser: loggedUser,
              embedded: true,
            ),
      ),
      _ConsoleModule(
        id: 'skills',
        label: 'Skills',
        shortLabel: 'Skills',
        icon: Icons.psychology_alt_outlined,
        description: 'Repertório técnico',
        builder:
            (context) => SkillsScreen(
              academyId: target.academyId,
              uid: target.uid,
              title: selectedMode ? 'Skills do aluno' : 'Skills',
              targetName: null,
              loggedUser: loggedUser,
              embedded: true,
            ),
      ),
      _ConsoleModule(
        id: 'nutrition',
        label: 'Nutri\u00e7\u00e3o',
        shortLabel: 'Nutri\u00e7\u00e3o',
        icon: Icons.restaurant_outlined,
        description: 'Registro alimentar',
        builder:
            (context) => NutritionScreen(
              titleOverride:
                  selectedMode
                      ? 'Nutri\u00e7\u00e3o do aluno'
                      : 'Nutri\u00e7\u00e3o',
              targetMode: widget.targetMode,
              explicitTarget: target,
              loggedUser: loggedUser,
              showLeading: false,
              embedded: true,
            ),
      ),
    ];
  }

  _ConsoleHeaderViewModel _buildHeaderViewModel({
    required List<_ConsoleModule> modules,
    required _ConsoleModule selectedModule,
    required AppUser? targetUser,
    required String? fallbackName,
    required bool isSelfProfile,
    required bool canEditTarget,
  }) {
    final isViewingStudent = widget.targetMode == TargetMode.selectedStudent;
    final user =
        targetUser ??
        (widget.target.uid == widget.loggedUser.uid ? widget.loggedUser : null);
    final displayName = _displayName(user, fallbackName);
    final contextLabel =
        isSelfProfile
            ? 'Meu perfil'
            : isViewingStudent
            ? 'Aluno'
            : 'Atleta';
    final beltLabel =
        user == null ? 'Faixa carregando' : 'Faixa ${_beltName(user.belt)}';
    final degreeLabel = user == null ? 'Grau --' : 'Grau ${user.degree}';

    return _ConsoleHeaderViewModel(
      displayName: displayName,
      compactName: _compactName(displayName),
      contextLabel: contextLabel,
      beltLabel: beltLabel,
      degreeLabel: degreeLabel,
      currentModuleLabel: selectedModule.label,
      currentModuleIndex: _selectedModuleIndex,
      isSelf: isSelfProfile,
      isViewingStudent: isViewingStudent,
      canEditProfile: canEditTarget,
      modules: [
        for (var index = 0; index < modules.length; index++)
          _ModuleNavigationItem(
            id: modules[index].id,
            label: modules[index].label,
            compactLabel: modules[index].shortLabel,
            icon: modules[index].icon,
            isVisible: true,
            isSelected: index == _selectedModuleIndex,
            enabled: modules[index].enabled,
          ),
      ],
    );
  }

  void _openTargetRegistration() {
    if (widget.target.uid.trim().isEmpty ||
        widget.target.academyId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Perfil alvo n\u00e3o informado para edi\u00e7\u00e3o.',
          ),
        ),
      );
      return;
    }

    final mode =
        widget.targetMode == TargetMode.selectedStudent
            ? AthleteRegistrationMode.editStudent
            : AthleteRegistrationMode.editSelf;

    debugPrint(
      '[ATHLETE_EDIT_OPEN] source=AthleteConsole actor.uid=${widget.loggedUser.uid} '
      'actor.role=${widget.loggedUser.role} target.uid=${widget.target.uid} '
      'target.academyId=${widget.target.academyId} mode=$mode',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AthleteRegistrationScreen(
              academyId: widget.target.academyId,
              athleteUid: widget.target.uid,
              mode: mode,
            ),
      ),
    );
  }

  bool _canEditTarget(AppUser actor, TargetProfile target) {
    final canManage =
        actor.role == UserRole.admin || actor.role == UserRole.professor;
    return actor.academyId == target.academyId &&
        (actor.uid == target.uid || canManage);
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

  String _compactName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Atleta' : parts.first;
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
  }) : enabled = true;
}

class _ConsoleHeaderViewModel {
  final String displayName;
  final String compactName;
  final String contextLabel;
  final String beltLabel;
  final String degreeLabel;
  final String currentModuleLabel;
  final int currentModuleIndex;
  final bool isSelf;
  final bool isViewingStudent;
  final bool canEditProfile;
  final List<_ModuleNavigationItem> modules;

  const _ConsoleHeaderViewModel({
    required this.displayName,
    required this.compactName,
    required this.contextLabel,
    required this.beltLabel,
    required this.degreeLabel,
    required this.currentModuleLabel,
    required this.currentModuleIndex,
    required this.isSelf,
    required this.isViewingStudent,
    required this.canEditProfile,
    required this.modules,
  });
}

class _ModuleNavigationItem {
  final String id;
  final String label;
  final String compactLabel;
  final IconData icon;
  final bool isVisible;
  final bool isSelected;
  final bool enabled;

  const _ModuleNavigationItem({
    required this.id,
    required this.label,
    required this.compactLabel,
    required this.icon,
    required this.isVisible,
    required this.isSelected,
    required this.enabled,
  });
}

enum _ConsoleHeaderVisualState { expanded, compact, pinned }

enum _ConsoleHeaderAction { editProfile }

class _CollapsibleAthleteConsoleHeader extends StatelessWidget {
  final _ConsoleHeaderViewModel viewModel;
  final _ConsoleHeaderVisualState visualState;
  final ValueChanged<int> onModuleSelected;
  final VoidCallback? onBack;
  final VoidCallback? onEditProfile;

  const _CollapsibleAthleteConsoleHeader({
    required this.viewModel,
    required this.visualState,
    required this.onModuleSelected,
    this.onBack,
    this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = viewModel.isViewingStudent ? cs.primary : cs.secondary;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final duration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 220);
    final isPinned = visualState == _ConsoleHeaderVisualState.pinned;
    final headerPadding =
        isPinned
            ? const EdgeInsets.all(TitansUI.spaceSm)
            : const EdgeInsets.all(TitansUI.spaceMd);

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        child: TitansCard(
          accent: accent,
          padding: headerPadding,
          radius: TitansUI.radiusSmall,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConsoleHeaderSummary(
                viewModel: viewModel,
                accent: accent,
                visualState: visualState,
                animationDuration: duration,
                onBack: onBack,
                onEditProfile: viewModel.canEditProfile ? onEditProfile : null,
              ),
              SizedBox(height: isPinned ? TitansUI.spaceXs : TitansUI.spaceMd),
              _ConsoleModuleNavigation(
                modules: viewModel.modules,
                visualState: visualState,
                onModuleSelected: onModuleSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleHeaderSummary extends StatelessWidget {
  final _ConsoleHeaderViewModel viewModel;
  final Color accent;
  final _ConsoleHeaderVisualState visualState;
  final Duration animationDuration;
  final VoidCallback? onBack;
  final VoidCallback? onEditProfile;

  const _ConsoleHeaderSummary({
    required this.viewModel,
    required this.accent,
    required this.visualState,
    required this.animationDuration,
    required this.onBack,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = visualState == _ConsoleHeaderVisualState.expanded;
    final isPinned = visualState == _ConsoleHeaderVisualState.pinned;
    final avatarSize =
        isExpanded
            ? 42.0
            : isPinned
            ? 30.0
            : 36.0;
    final name = isExpanded ? viewModel.displayName : viewModel.compactName;
    final contextLabel =
        isPinned
            ? '${viewModel.contextLabel} - ${viewModel.currentModuleLabel}'
            : viewModel.contextLabel;

    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Voltar',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: TitansUI.spaceXs),
        ],
        AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.36)),
          ),
          child: Icon(
            viewModel.isViewingStudent
                ? Icons.person_pin_circle_outlined
                : Icons.badge_outlined,
            color: accent,
            size: isPinned ? 18 : 24,
          ),
        ),
        const SizedBox(width: TitansUI.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contextLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: isPinned ? 10 : 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: isPinned ? 15 : null,
                ),
              ),
              if (!isPinned) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: TitansUI.spaceXs,
                  runSpacing: 2,
                  children: [
                    _ConsoleHeaderPill(label: viewModel.beltLabel),
                    _ConsoleHeaderPill(label: viewModel.degreeLabel),
                    _ConsoleHeaderPill(
                      label: viewModel.currentModuleLabel,
                      icon: Icons.dashboard_customize_outlined,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (onEditProfile != null) ...[
          const SizedBox(width: TitansUI.spaceXs),
          PopupMenuButton<_ConsoleHeaderAction>(
            tooltip: 'A\u00e7\u00f5es do perfil',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _ConsoleHeaderAction.editProfile:
                  onEditProfile?.call();
                  break;
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: _ConsoleHeaderAction.editProfile,
                    child: _HeaderMenuItem(
                      icon: Icons.edit_outlined,
                      label: 'Editar cadastro',
                    ),
                  ),
                ],
          ),
        ],
      ],
    );
  }
}

class _ConsoleHeaderPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _ConsoleHeaderPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceXs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.70)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleModuleNavigation extends StatelessWidget {
  final List<_ModuleNavigationItem> modules;
  final _ConsoleHeaderVisualState visualState;
  final ValueChanged<int> onModuleSelected;

  const _ConsoleModuleNavigation({
    required this.modules,
    required this.visualState,
    required this.onModuleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < 390 ||
            visualState != _ConsoleHeaderVisualState.expanded;
        final isPinned = visualState == _ConsoleHeaderVisualState.pinned;
        final visibleModules =
            modules.where((module) => module.isVisible).toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < visibleModules.length; index++) ...[
                _ConsoleModuleNavItem(
                  item: visibleModules[index],
                  label:
                      isCompact
                          ? visibleModules[index].compactLabel
                          : visibleModules[index].label,
                  pinned: isPinned,
                  onPressed: () => onModuleSelected(index),
                ),
                if (index < visibleModules.length - 1)
                  SizedBox(width: isPinned ? 4 : TitansUI.spaceXs),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ConsoleModuleNavItem extends StatelessWidget {
  final _ModuleNavigationItem item;
  final String label;
  final bool pinned;
  final VoidCallback onPressed;

  const _ConsoleModuleNavItem({
    required this.item,
    required this.label,
    required this.pinned,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = item.isSelected;
    final accent = selected ? cs.primary : cs.secondary;
    final enabled = item.enabled;

    return Tooltip(
      message: item.label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: ChoiceChip(
          selected: selected,
          showCheckmark: false,
          avatar: Icon(item.icon, size: pinned ? 16 : 18, color: accent),
          label: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: pinned ? 96 : 124),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
          backgroundColor: TitansUI.card,
          selectedColor: Color.lerp(TitansUI.card, accent, 0.18),
          side: BorderSide(
            color:
                selected
                    ? accent.withValues(alpha: 0.78)
                    : cs.onSurface.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity(
            horizontal: pinned ? -1 : 0,
            vertical: pinned ? -1 : 0,
          ),
          onSelected: enabled ? (_) => onPressed() : null,
        ),
      ),
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderMenuItem({required this.icon, required this.label});

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
