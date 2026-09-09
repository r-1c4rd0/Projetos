import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../features/nutrition/application/nutrition_use_cases.dart';
import '../features/nutrition/domain/nutrition_models.dart';
import '../main.dart';
import '../model/app_user.dart';
import '../model/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_feedback.dart';
import '../widgets/titans_scaffold.dart';

class NutritionScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;
  final AppUser? loggedUser;
  final bool embedded;

  /// Mock condicional para teste/local.
  final bool useMock;

  /// Dentro do console do atleta normalmente nao queremos leading (logo).
  final bool showLeading;

  const NutritionScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
    this.loggedUser,
    this.embedded = false,
    this.useMock = false,
    this.showLeading = true,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionRepository _repo;
  late Future<UserProfile?> _profileFuture;
  late Future<List<MealEntry>> _mealsFuture;

  bool _repoReady = false;
  String? _targetAcademyId;
  String? _targetUid;
  bool _fallbackToMock = false;
  Object? _repoError;
  late final GetNutritionDashboardSummary _getNutritionDashboardSummary =
      const GetNutritionDashboardSummary();

  TargetProfile? _resolveTarget(BuildContext context) {
    return widget.explicitTarget ??
        TargetResolver.maybeOf(context, mode: widget.targetMode);
  }

  void _syncRepository(TargetProfile target) {
    if (_repoReady &&
        _targetAcademyId == target.academyId &&
        _targetUid == target.uid) {
      return;
    }

    _targetAcademyId = target.academyId;
    _targetUid = target.uid;
    _fallbackToMock = false;
    _repoError = null;

    _repo = NutritionRepositoryFactory.create(
      academyId: target.academyId,
      uid: target.uid,
      useMock: widget.useMock,
      onPermissionDeniedFallback: () {
        if (mounted) {
          setState(() => _fallbackToMock = true);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _repoError = error);
        }
      },
    );

    _profileFuture = _repo.getProfileCached();
    _mealsFuture = _repo.listMealsCached();
    _repoReady = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final target = _resolveTarget(context);
    if (target == null) {
      _repoReady = false;
      return;
    }

    _syncRepository(target);
  }

  @override
  void didUpdateWidget(covariant NutritionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.explicitTarget == widget.explicitTarget &&
        oldWidget.targetMode == widget.targetMode &&
        oldWidget.loggedUser == widget.loggedUser &&
        oldWidget.useMock == widget.useMock) {
      return;
    }

    final target = _resolveTarget(context);
    if (target == null) {
      _repoReady = false;
      return;
    }

    _syncRepository(target);
  }

  void _reloadNutritionData() {
    setState(() {
      _profileFuture = _repo.getProfileCached();
      _mealsFuture = _repo.listMealsCached();
    });
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.loggedUser ?? UserScope.maybeOf(context);

    if (!_repoReady) {
      final resolverTarget = TargetResolver.maybeOf(
        context,
        mode: widget.targetMode,
      );
      final target = widget.explicitTarget ?? resolverTarget;
      final canEditNutrition =
          target != null &&
          _canEditNutrition(loggedUser: actor, target: target);
      debugPrint(
        '[NUTRITION_TARGET] screen=NutritionScreen '
        'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
        'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
        'explicit.academyId=${widget.explicitTarget?.academyId} '
        'resolver.uid=${resolverTarget?.uid} '
        'resolver.academyId=${resolverTarget?.academyId} '
        'target.uid=${target?.uid} target.academyId=${target?.academyId} '
        'canEditNutrition=$canEditNutrition',
      );
      if (target == null) {
        debugPrint(
          '[NUTRITION_ACTIONS] showAddMeal=false showEditNutritionProfile=false '
          'canEditNutrition=$canEditNutrition hiddenBy=missing-target '
          'actor.uid=${actor?.uid} actor.role=${actor?.role}',
        );
        return _wrapModule(
          appBar: AppBar(
            leading: _mainScreenLeading(context),
            title: Text(widget.titleOverride ?? 'Nutri\u00e7\u00e3o'),
          ),
          body:
              widget.targetMode == TargetMode.selectedStudent
                  ? const TitansStateView.noStudent(
                    message:
                        'Selecione um aluno no Painel do Mestre para acessar Nutri\u00e7\u00e3o.',
                  )
                  : const TitansStateView.error(
                    title: 'Perfil n\u00e3o carregado',
                    message:
                        'N\u00e3o foi poss\u00edvel identificar seu usu\u00e1rio para carregar Nutri\u00e7\u00e3o.',
                  ),
        );
      }

      return const TitansSkeletonCard(lines: 4);
    }

    final target = _resolveTarget(context);
    final canEditNutrition =
        target != null && _canEditNutrition(loggedUser: actor, target: target);
    final isReadOnlyStudentView =
        target != null &&
        _isStaff(actor) &&
        !_isSelfTarget(loggedUser: actor, target: target);
    debugPrint(
      '[NUTRITION_ACTIONS] showAddMeal=$canEditNutrition '
      'showEditNutritionProfile=$canEditNutrition canEditNutrition=$canEditNutrition '
      "hiddenBy=${canEditNutrition ? 'none' : 'canEditNutrition=false'} "
      'actor.uid=${actor?.uid} actor.role=${actor?.role} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId}',
    );
    debugPrint(
      '[NUTRITION_TARGET] screen=NutritionScreen '
      'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
      'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
      'explicit.academyId=${widget.explicitTarget?.academyId} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId} '
      'canEditNutrition=$canEditNutrition',
    );

    return _wrapModule(
      appBar: AppBar(
        leading: _mainScreenLeading(context),
        title: Text(widget.titleOverride ?? 'Nutri\u00e7\u00e3o'),
      ),
      floatingActionButton:
          !widget.embedded && canEditNutrition && !_hasUnavailableNutritionData
              ? FloatingActionButton.extended(
                heroTag: 'nutrition_fab',
                onPressed: _addMeal,
                backgroundColor: TitansUI.actionGold,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.add),
                label: const Text('Registrar refei\u00e7\u00e3o'),
              )
              : null,
      body: FutureBuilder<List<MealEntry>>(
        future: _mealsFuture,
        builder: (context, snap) {
          if (_hasUnavailableNutritionData || snap.hasError) {
            return _NutritionUnavailableView(
              title: widget.titleOverride ?? 'Nutri\u00e7\u00e3o',
              embedded: widget.embedded,
            );
          }

          if (!snap.hasData) {
            return const TitansSkeletonCard(lines: 4);
          }

          final meals = snap.data!;
          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: TitansUI.spaceXl);

          return ListView(
            padding: listPadding,
            children: [
              _NutritionHeader(
                title: widget.titleOverride ?? 'Nutri\u00e7\u00e3o',
                showTitle: widget.embedded,
              ),
              const SizedBox(height: 12),
              if (isReadOnlyStudentView) ...[
                const _NutritionInfoCard(
                  icon: Icons.visibility_outlined,
                  title: 'Visualiza\u00e7\u00e3o do aluno',
                  message:
                      'Edi\u00e7\u00e3o nutricional dispon\u00edvel apenas para o pr\u00f3prio usu\u00e1rio.',
                ),
                const SizedBox(height: 12),
              ],
              FutureBuilder<UserProfile?>(
                future: _profileFuture,
                builder: (context, profSnap) {
                  if (profSnap.connectionState == ConnectionState.waiting) {
                    return const TitansSkeletonCard(lines: 3);
                  }

                  final profile = profSnap.data;
                  final showMealSectionAddAction =
                      widget.embedded ||
                      MediaQuery.sizeOf(context).width >= 720;
                  final dashboard = _getNutritionDashboardSummary(
                    profile: profile,
                    meals: meals,
                  );
                  final profileArea =
                      profile == null
                          ? Column(
                            children: [
                              _NutritionProfilePlaceholder(
                                canEditNutrition: canEditNutrition,
                                status: dashboard.profileStatus,
                                onComplete:
                                    canEditNutrition ? _editProfile : null,
                              ),
                              const SizedBox(height: 12),
                              const _NutritionEnergyPendingCard(),
                            ],
                          )
                          : Column(
                            children: [
                              _NutritionProfileCard(
                                profile: profile,
                                canEditNutrition: canEditNutrition,
                                onEdit: _editProfile,
                              ),
                              const SizedBox(height: 12),
                              _NutritionEnergyCard(
                                profile: profile,
                                status: dashboard.profileStatus,
                              ),
                            ],
                          );

                  return _NutritionCompactDashboard(
                    statusCard: _NutritionDashboardStatusCard(
                      dashboard: dashboard,
                    ),
                    profileArea: profileArea,
                    weeklyChart: _DailyCaloriesChart(
                      meals: meals,
                      points: dashboard.weeklyCalories,
                    ),
                    mealsSection: _NutritionMealsSection(
                      mealLog: dashboard.mealLog,
                      canEditNutrition: canEditNutrition,
                      showAddMealAction: showMealSectionAddAction,
                      onAddMeal: _addMeal,
                    ),
                    safetyCopy: const _NutritionInfoCard(
                      icon: Icons.info_outline,
                      title: 'Informa\u00e7\u00f5es educativas',
                      message:
                          'Estas informa\u00e7\u00f5es s\u00e3o educativas e ajudam no registro da rotina. Para um plano alimentar individual, consulte um profissional de sa\u00fade ou nutri\u00e7\u00e3o.',
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget? _mainScreenLeading(BuildContext context) {
    if (!widget.showLeading ||
        widget.embedded ||
        Navigator.of(context).canPop()) {
      return null;
    }
    return const AppLogoLeading();
  }

  Widget _wrapModule({
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    required Widget body,
  }) {
    if (widget.embedded) return body;
    return TitansScaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }

  bool _canEditNutrition({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    return _isSelfTarget(loggedUser: loggedUser, target: target);
  }

  bool _isSelfTarget({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    if (loggedUser == null) return false;
    return loggedUser.academyId == target.academyId &&
        loggedUser.uid == target.uid;
  }

  bool _isStaff(AppUser? loggedUser) {
    return loggedUser?.role == UserRole.admin ||
        loggedUser?.role == UserRole.professor;
  }

  bool get _hasUnavailableNutritionData =>
      _fallbackToMock || _repoError != null;

  Future<void> _editProfile() async {
    final profile = await _repo.getProfileCached();
    if (!mounted) return;

    final updated = await showDialog<UserProfile>(
      context: context,
      builder:
          (_) =>
              _ProfileDialog(existing: profile ?? _defaultProfileForEditing()),
    );

    if (updated != null) {
      await _repo.upsertProfile(updated);
      if (mounted) _reloadNutritionData();
    }
  }

  Future<void> _addMeal() async {
    final recentFoods = _recentFoodsFrom(await _repo.listMealsCached());
    if (!mounted) return;

    final created = await showModalBottomSheet<MealEntry?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MealSheet(repo: _repo, recentFoods: recentFoods),
    );

    if (created != null) {
      await _repo.addMeal(created);
      if (mounted) _reloadNutritionData();
    }
  }

  UserProfile _defaultProfileForEditing() {
    return UserProfile(
      weightKg: 80,
      heightCm: 180,
      age: 30,
      sex: Sex.male,
      activityFactor: 1.375,
    );
  }

  static String _fmtDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _fmtMealTime(BuildContext context, DateTime date) {
  return TimeOfDay.fromDateTime(date).format(context);
}

String _itemsPreview(List<FoodItem> items) {
  if (items.isEmpty) return 'Sem alimentos informados';

  final names = items.take(3).map((food) => food.name).join(', ');
  final remaining = items.length - 3;
  if (remaining <= 0) return names;

  return '$names +$remaining';
}

String _foodEnergyLabel(FoodItem food) {
  if (food.kcal <= 0) return 'Energia n\u00e3o informada';
  return '${food.kcal} kcal';
}

String _normalizeFoodName(String value) => value.trim().toLowerCase();

List<FoodItem> _recentFoodsFrom(List<MealEntry> meals) {
  final byName = <String, FoodItem>{};
  for (final meal in meals.reversed) {
    for (final food in meal.items) {
      final key = _normalizeFoodName(food.name);
      if (key.isEmpty || byName.containsKey(key)) continue;
      byName[key] = food;
      if (byName.length >= 8) return byName.values.toList(growable: false);
    }
  }
  return byName.values.toList(growable: false);
}

class _NutritionCompactDashboard extends StatelessWidget {
  final Widget statusCard;
  final Widget profileArea;
  final Widget weeklyChart;
  final Widget mealsSection;
  final Widget safetyCopy;

  const _NutritionCompactDashboard({
    required this.statusCard,
    required this.profileArea,
    required this.weeklyChart,
    required this.mealsSection,
    required this.safetyCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        statusCard,
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 820) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: profileArea),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: weeklyChart),
                ],
              );
            }

            return Column(
              children: [profileArea, const SizedBox(height: 12), weeklyChart],
            );
          },
        ),
        const SizedBox(height: 12),
        mealsSection,
        const SizedBox(height: 12),
        safetyCopy,
      ],
    );
  }
}

class _NutritionDashboardStatusCard extends StatelessWidget {
  final NutritionDashboardSummary dashboard;

  const _NutritionDashboardStatusCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMeals = !dashboard.mealLog.isEmpty;
    final registeredDays =
        dashboard.weeklyCalories.where((point) => point.totalKcal > 0).length;
    final accent =
        dashboard.profileStatus.hasProfile
            ? TitansUI.successGreen
            : TitansUI.actionGold;
    final registerLabel = hasMeals ? 'Registro ativo' : 'Registro pendente';
    final message =
        dashboard.profileStatus.hasProfile
            ? 'Perfil ativo e registro alimentar acompanhado por dados informados pelo usu\u00e1rio.'
            : 'Complete o perfil e registre refei\u00e7\u00f5es para acompanhar a rotina com seguran\u00e7a.';

    return TitansCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(Icons.restaurant_menu_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registro alimentar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: TitansUI.spaceXs,
            runSpacing: TitansUI.spaceXs,
            children: [
              TitansStatusChip(
                label: dashboard.profileStatus.profileStatusLabel,
                variant:
                    dashboard.profileStatus.hasProfile
                        ? TitansStatusChipVariant.success
                        : TitansStatusChipVariant.action,
                icon:
                    dashboard.profileStatus.hasProfile
                        ? Icons.check_circle_outline
                        : Icons.pending_actions_outlined,
                compact: true,
              ),
              TitansStatusChip(
                label: registerLabel,
                variant:
                    hasMeals
                        ? TitansStatusChipVariant.technical
                        : TitansStatusChipVariant.muted,
                icon:
                    hasMeals
                        ? Icons.local_dining_outlined
                        : Icons.playlist_add_outlined,
                compact: true,
              ),
              TitansStatusChip(
                label: '$registeredDays dias na semana',
                variant: TitansStatusChipVariant.muted,
                icon: Icons.calendar_today_outlined,
                compact: true,
              ),
              TitansStatusChip(
                label: '${dashboard.mealLog.items.length} refei\u00e7\u00f5es',
                variant: TitansStatusChipVariant.muted,
                icon: Icons.receipt_long_outlined,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutritionUnavailableView extends StatelessWidget {
  final String title;
  final bool embedded;

  const _NutritionUnavailableView({
    required this.title,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context) {
    final padding =
        embedded
            ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
            : TitansUI.listPadding(context, extra: 80);

    return ListView(
      padding: padding,
      children: [
        _NutritionHeader(title: title, showTitle: embedded),
        const SizedBox(height: 12),
        const _NutritionInfoCard(
          icon: Icons.info_outline,
          title: 'Informa\u00e7\u00f5es educativas',
          message:
              'As informa\u00e7\u00f5es de nutri\u00e7\u00e3o s\u00e3o educativas e n\u00e3o substituem orienta\u00e7\u00e3o profissional.',
        ),
        const SizedBox(height: 12),
        const TitansStateView.error(
          title: 'Dados nutricionais indispon\u00edveis',
          message:
              'N\u00e3o foi poss\u00edvel carregar os dados nutricionais. Tente novamente mais tarde.',
          compact: true,
        ),
      ],
    );
  }
}

class _NutritionHeader extends StatelessWidget {
  final String title;
  final bool showTitle;

  const _NutritionHeader({required this.title, required this.showTitle});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _NutritionScreenState._fmtDate(DateTime.now()),
            style: TitansTypography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Registro alimentar e energia para apoiar sua rotina de treinos.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}

class _NutritionStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _NutritionStatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

    return TitansCard(
      accent: color,
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TitansTypography.cardTitle(
                    context,
                  )?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: TitansUI.spaceXs),
                Text(message, style: TitansTypography.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _NutritionInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _NutritionStatusCard(icon: icon, title: title, message: message);
  }
}

class _NutritionProfilePlaceholder extends StatelessWidget {
  final bool canEditNutrition;
  final NutritionProfileStatus status;
  final VoidCallback? onComplete;

  const _NutritionProfilePlaceholder({
    required this.canEditNutrition,
    required this.status,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TitansEmptyState(
      icon: Icons.person_outline,
      title: 'Perfil nutricional ainda n\u00e3o preenchido',
      message:
          canEditNutrition
              ? 'Preencha o perfil para estimar energia de rotina.'
              : status.profileEmptyMessage,
      actionLabel:
          canEditNutrition && onComplete != null ? 'Completar perfil' : null,
      onAction: canEditNutrition ? onComplete : null,
      variant:
          canEditNutrition
              ? TitansEmptyStateVariant.action
              : TitansEmptyStateVariant.neutral,
      compact: true,
    );
  }
}

class _NutritionProfileCard extends StatelessWidget {
  final UserProfile profile;
  final bool canEditNutrition;
  final VoidCallback onEdit;

  const _NutritionProfileCard({
    required this.profile,
    required this.canEditNutrition,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);

    return TitansCard(
      accent: TitansUI.successGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              const _SectionTitle(
                title: 'Perfil nutricional',
                subtitle: 'Dados usados para estimar energia de rotina.',
              ),
              Wrap(
                spacing: TitansUI.spaceXs,
                runSpacing: TitansUI.spaceXs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const TitansStatusChip(
                    label: 'Perfil ativo',
                    variant: TitansStatusChipVariant.success,
                    icon: Icons.check_circle_outline,
                    compact: true,
                  ),
                  if (canEditNutrition)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      onPressed: onEdit,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProfileMetric(
                label: 'Sexo',
                value: profile.sex == Sex.male ? 'Masculino' : 'Feminino',
              ),
              _ProfileMetric(label: 'Idade', value: '${profile.age} anos'),
              _ProfileMetric(
                label: 'Peso',
                value: '${profile.weightKg.toStringAsFixed(1)} kg',
              ),
              _ProfileMetric(
                label: 'Altura',
                value: '${profile.heightCm.toStringAsFixed(0)} cm',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Esses dados ajudam a manter o registro consistente.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NutritionEnergyPendingCard extends StatelessWidget {
  const _NutritionEnergyPendingCard();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);

    return TitansCard(
      accent: TitansUI.actionGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Energia estimada',
            subtitle:
                'Refer\u00eancia de rotina, n\u00e3o prescri\u00e7\u00e3o alimentar.',
          ),
          const SizedBox(height: 12),
          Text(
            'Preencha o perfil para estimar energia de rotina.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NutritionEnergyCard extends StatelessWidget {
  final UserProfile profile;
  final NutritionProfileStatus status;

  const _NutritionEnergyCard({required this.profile, required this.status});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);
    final tdee = status.estimatedDailyKcal ?? profile.tdee();

    return TitansCard(
      accent: TitansUI.technicalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Energia estimada',
            subtitle:
                'Refer\u00eancia de rotina, n\u00e3o prescri\u00e7\u00e3o alimentar.',
          ),
          const SizedBox(height: 12),
          Text(
            '${tdee.toStringAsFixed(0)} kcal/dia',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: TitansUI.actionGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fator de atividade: ${profile.activityFactor.toStringAsFixed(2)} - usado apenas para estimar energia.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Use como registro e orienta\u00e7\u00e3o geral da rotina de treinos.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NutritionMealsSection extends StatefulWidget {
  final MealLogSummary mealLog;
  final bool canEditNutrition;
  final bool showAddMealAction;
  final VoidCallback onAddMeal;

  const _NutritionMealsSection({
    required this.mealLog,
    required this.canEditNutrition,
    required this.showAddMealAction,
    required this.onAddMeal,
  });

  @override
  State<_NutritionMealsSection> createState() => _NutritionMealsSectionState();
}

class _NutritionMealsSectionState extends State<_NutritionMealsSection> {
  static const _collapsedHistoryCount = 3;
  static const _expandedHistoryCount = 20;

  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final todayMeals = _todayMeals;
    final olderMeals = _olderMeals;
    final latestToday = todayMeals.isEmpty ? null : todayMeals.first.date;
    final weekCount = _weekMealCount(widget.mealLog.items);
    final canAdd = widget.canEditNutrition && widget.showAddMealAction;

    return TitansCard(
      accent:
          widget.mealLog.isEmpty ? TitansUI.actionGold : TitansUI.technicalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            spacing: TitansUI.spaceSm,
            overflowSpacing: TitansUI.spaceSm,
            children: [
              const _SectionTitle(
                title: 'Di\u00e1rio de hoje',
                subtitle: 'Registro alimentar descritivo, sem meta.',
              ),
              if (canAdd && !widget.mealLog.isEmpty)
                FilledButton.icon(
                  onPressed: widget.onAddMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar refei\u00e7\u00e3o'),
                ),
            ],
          ),
          const SizedBox(height: TitansUI.spaceSm),
          _MealLogSummaryRail(
            todayCount: todayMeals.length,
            latestTime:
                latestToday == null
                    ? 'Sem registro'
                    : _fmtMealTime(context, latestToday),
            weekCount: weekCount,
          ),
          const SizedBox(height: TitansUI.spaceMd),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                widget.mealLog.isEmpty
                    ? _MealLogEmptyState(
                      canEditNutrition: widget.canEditNutrition,
                      canAdd: canAdd,
                      onAddMeal: widget.onAddMeal,
                    )
                    : _MealLogContent(
                      todayMeals: todayMeals,
                      olderMeals: olderMeals,
                      showHistory: _showHistory,
                      onToggleHistory: _toggleHistory,
                    ),
          ),
        ],
      ),
    );
  }

  List<NutritionMealLogItem> get _todayMeals {
    final now = DateTime.now();
    return widget.mealLog.items
        .where((item) => _isSameDay(item.date, now))
        .toList(growable: false);
  }

  List<NutritionMealLogItem> get _olderMeals {
    final now = DateTime.now();
    return widget.mealLog.items
        .where((item) => !_isSameDay(item.date, now))
        .toList(growable: false);
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
  }

  int _weekMealCount(List<NutritionMealLogItem> meals) {
    final start = _dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    return meals.where((item) => !_dateOnly(item.date).isBefore(start)).length;
  }
}

class _MealLogSummaryRail extends StatelessWidget {
  final int todayCount;
  final String latestTime;
  final int weekCount;

  const _MealLogSummaryRail({
    required this.todayCount,
    required this.latestTime,
    required this.weekCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TitansUI.spaceSm,
      runSpacing: TitansUI.spaceSm,
      children: [
        _MealLogSummaryPill(
          icon: Icons.today_outlined,
          label: 'Hoje',
          value: '$todayCount',
        ),
        _MealLogSummaryPill(
          icon: Icons.schedule_outlined,
          label: '\u00daltima',
          value: latestTime,
        ),
        _MealLogSummaryPill(
          icon: Icons.calendar_view_week_outlined,
          label: '7 dias',
          value: '$weekCount',
        ),
      ],
    );
  }
}

class _MealLogSummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MealLogSummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 156),
      padding: const EdgeInsets.symmetric(
        horizontal: TitansUI.spaceSm,
        vertical: TitansUI.spaceXs,
      ),
      decoration: BoxDecoration(
        color: TitansUI.elevatedSurfaceColor(context).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: TitansUI.technicalBlue),
          const SizedBox(width: TitansUI.spaceXs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TitansTypography.caption(context)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealLogEmptyState extends StatelessWidget {
  final bool canEditNutrition;
  final bool canAdd;
  final VoidCallback onAddMeal;

  const _MealLogEmptyState({
    required this.canEditNutrition,
    required this.canAdd,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return TitansEmptyState(
      key: const ValueKey('nutrition-empty-meals'),
      icon: Icons.restaurant_outlined,
      title:
          canEditNutrition
              ? 'Seu di\u00e1rio de hoje est\u00e1 vazio.'
              : 'Di\u00e1rio de hoje vazio.',
      message:
          canEditNutrition
              ? 'Use o di\u00e1rio para manter um hist\u00f3rico do que voc\u00ea consumiu.'
              : 'Nenhuma refei\u00e7\u00e3o foi registrada para este usu\u00e1rio hoje.',
      actionLabel: canAdd ? 'Registrar primeira refei\u00e7\u00e3o' : null,
      onAction: canAdd ? onAddMeal : null,
      variant:
          canEditNutrition
              ? TitansEmptyStateVariant.action
              : TitansEmptyStateVariant.neutral,
      compact: true,
      showCard: false,
    );
  }
}

class _MealLogContent extends StatelessWidget {
  final List<NutritionMealLogItem> todayMeals;
  final List<NutritionMealLogItem> olderMeals;
  final bool showHistory;
  final VoidCallback onToggleHistory;

  const _MealLogContent({
    required this.todayMeals,
    required this.olderMeals,
    required this.showHistory,
    required this.onToggleHistory,
  });

  @override
  Widget build(BuildContext context) {
    final historyLimit =
        showHistory
            ? _NutritionMealsSectionState._expandedHistoryCount
            : _NutritionMealsSectionState._collapsedHistoryCount;
    final visibleOlderMeals = olderMeals.take(historyLimit).toList();
    final hiddenHistoryCount = olderMeals.length - visibleOlderMeals.length;

    return Column(
      key: const ValueKey('nutrition-meal-log-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayMeals.isEmpty)
          const TitansEmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Seu di\u00e1rio de hoje est\u00e1 vazio.',
            message: 'Os registros anteriores continuam no hist\u00f3rico.',
            compact: true,
            showCard: false,
          )
        else
          _MealTimelineList(items: todayMeals),
        if (olderMeals.isNotEmpty) ...[
          const SizedBox(height: TitansUI.spaceMd),
          _MealLogDayHeader(label: 'Refei\u00e7\u00f5es anteriores'),
          const SizedBox(height: TitansUI.spaceXs),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _MealTimelineList(items: visibleOlderMeals),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleHistory,
              icon: Icon(
                showHistory
                    ? Icons.expand_less_outlined
                    : Icons.expand_more_outlined,
                size: 18,
              ),
              label: Text(
                showHistory
                    ? 'Ocultar hist\u00f3rico'
                    : hiddenHistoryCount > 0
                    ? 'Ver hist\u00f3rico ($hiddenHistoryCount)'
                    : 'Ver hist\u00f3rico',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MealTimelineList extends StatelessWidget {
  final List<NutritionMealLogItem> items;

  const _MealTimelineList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          _MealTimelineRow(
            item: items[index],
            onTap: () => _showMealDetail(context, items[index]),
          ),
        ],
      ],
    );
  }
}

class _MealLogDayHeader extends StatelessWidget {
  final String label;

  const _MealLogDayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.56),
        ),
        const SizedBox(width: TitansUI.spaceXs),
        Text(
          label,
          style: TitansTypography.caption(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: TitansUI.spaceXs),
        Expanded(
          child: Container(
            height: 1,
            color: cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _MealTimelineRow extends StatelessWidget {
  final NutritionMealLogItem item;
  final VoidCallback onTap;

  const _MealTimelineRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foodCount = item.meal.items.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TitansUI.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  _fmtMealTime(context, item.date),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: TitansUI.technicalBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.mealType,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _itemsPreview(item.meal.items),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (foodCount > 0) ...[
                const SizedBox(width: TitansUI.spaceXs),
                TitansStatusChip(
                  label: '$foodCount',
                  variant: TitansStatusChipVariant.muted,
                  icon: Icons.restaurant_menu_outlined,
                  compact: true,
                ),
              ],
              const SizedBox(width: TitansUI.spaceXs),
              Icon(
                Icons.chevron_right,
                color: cs.onSurface.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealDetailSheet extends StatelessWidget {
  final NutritionMealLogItem item;

  const _MealDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TitansUI.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text(
              item.mealType,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: TitansUI.spaceXs),
            Text(
              '${_NutritionScreenState._fmtDate(item.date)} \u00e0s ${_fmtMealTime(context, item.date)}',
              style: TitansTypography.caption(context),
            ),
            const SizedBox(height: TitansUI.spaceMd),
            _MealEnergyBadge(kcal: item.totalKcal),
            const SizedBox(height: TitansUI.spaceMd),
            const _SectionTitle(
              title: 'Alimentos',
              subtitle: 'Itens registrados nesta refei\u00e7\u00e3o.',
            ),
            const SizedBox(height: TitansUI.spaceSm),
            if (item.meal.items.isEmpty)
              const Text('Registro alimentar sem itens.')
            else
              ...item.meal.items.map(
                (food) => _FoodCompactRow(
                  food: food,
                  trailing: Text(
                    _foodEnergyLabel(food),
                    style: TitansTypography.caption(context),
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            const SizedBox(height: TitansUI.spaceSm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMealDetail(BuildContext context, NutritionMealLogItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MealDetailSheet(item: item),
  );
}

class _MealEnergyBadge extends StatelessWidget {
  final int kcal;

  const _MealEnergyBadge({required this.kcal});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 74, maxWidth: 104),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TitansUI.actionGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(TitansRadius.sm),
          border: Border.all(
            color: TitansUI.actionGold.withValues(alpha: 0.24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TitansUI.spaceSm,
            vertical: TitansUI.spaceXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Energia',
                style: TitansTypography.caption(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$kcal kcal',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: TitansUI.actionGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 150),
      child: TitansCompactMetricCard(label: label, value: value),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DailyCaloriesChart extends StatelessWidget {
  final List<MealEntry> meals;
  final List<NutritionChartPoint> points;

  const _DailyCaloriesChart({required this.meals, required this.points});

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < points.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: points[i].totalKcal.toDouble(), width: 12),
          ],
        ),
      );
    }

    return TitansCard(
      accent: meals.isEmpty ? TitansUI.actionGold : TitansUI.successGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Gr\u00e1fico semanal',
            subtitle:
                'Calorias registradas nos \u00faltimos 7 dias; n\u00e3o indica meta alimentar.',
          ),

          const SizedBox(height: 12),
          if (meals.isEmpty)
            const TitansEmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'Sem refei\u00e7\u00f5es registradas',
              message:
                  'O gr\u00e1fico semanal aparece quando houver registros alimentares.',
              compact: true,
              showCard: false,
            )
          else
            SizedBox(
              height: 188,
              child: BarChart(
                BarChartData(
                  barGroups: groups,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final date = points[index].date;
                          return Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
        ],
      ),
    );
  }
}
// --- abaixo mantido do seu original ---

class _MealSheet extends StatefulWidget {
  final NutritionRepository repo;
  final List<FoodItem> recentFoods;

  const _MealSheet({required this.repo, required this.recentFoods});

  @override
  State<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<_MealSheet> {
  DateTime _date = DateTime.now();
  String _mealType = 'Almo\u00e7o';
  String _query = '';
  int _visibleFoodCount = 8;
  final List<FoodItem> _selected = [];

  int get _selectedKcal =>
      _selected.fold<int>(0, (sum, food) => sum + food.kcal);

  @override
  Widget build(BuildContext context) {
    final suggestionFoods = widget.repo.foodDb(_query);
    final recentFoods = _filteredRecentFoods;
    final hasQuery = _query.trim().isNotEmpty;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TitansUI.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              Text(
                'Registrar refei\u00e7\u00e3o',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: TitansUI.spaceXs),
              Text(
                'Informe o que foi consumido, sem meta ou julgamento.',
                style: TitansTypography.caption(context),
              ),
              const SizedBox(height: TitansUI.spaceMd),
              _MealTypeSelector(value: _mealType, onChanged: _setMealType),
              const SizedBox(height: TitansUI.spaceSm),
              _MealDateTimeFields(
                date: _date,
                onPickDate: _pickDate,
                onPickTime: _pickTime,
              ),
              const SizedBox(height: TitansUI.spaceLg),
              const _SectionTitle(
                title: 'Alimentos',
                subtitle: 'Busque uma sugest\u00e3o ou adicione manualmente.',
              ),
              const SizedBox(height: TitansUI.spaceSm),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Buscar alimento',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      hasQuery
                          ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _query = '';
                                _visibleFoodCount = 8;
                              });
                            },
                          )
                          : null,
                ),
                onChanged:
                    (value) => setState(() {
                      _query = value;
                      _visibleFoodCount = 8;
                    }),
              ),
              const SizedBox(height: TitansUI.spaceSm),
              FilledButton.tonalIcon(
                onPressed: _addManualFood,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar alimento manualmente'),
              ),
              if (!hasQuery && recentFoods.isNotEmpty) ...[
                const SizedBox(height: TitansUI.spaceMd),
                const _SectionTitle(
                  title: 'Recentes',
                  subtitle: 'Itens usados nos seus registros.',
                ),
                const SizedBox(height: TitansUI.spaceXs),
                _FoodSuggestionList(
                  foods: recentFoods,
                  onAdd: _addFood,
                  maxHeight: 160,
                ),
              ],
              const SizedBox(height: TitansUI.spaceMd),
              _FoodSearchResults(
                foods: suggestionFoods,
                visibleCount: _visibleFoodCount,
                onAdd: _addFood,
                onLoadMore:
                    suggestionFoods.length > _visibleFoodCount
                        ? () => setState(() => _visibleFoodCount += 8)
                        : null,
              ),
              const Divider(height: TitansUI.spaceLg),
              _SelectedFoodSection(
                selected: _selected,
                selectedKcal: _selectedKcal,
                onRemove: _removeFoodAt,
              ),
              const SizedBox(height: TitansUI.spaceMd),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: TitansUI.spaceSm,
                overflowSpacing: TitansUI.spaceSm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar refei\u00e7\u00e3o'),
                    onPressed: _selected.isEmpty ? null : _saveMeal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FoodItem> get _filteredRecentFoods {
    final query = _normalizeFoodName(_query);
    return widget.recentFoods
        .where(
          (food) =>
              query.isEmpty || _normalizeFoodName(food.name).contains(query),
        )
        .take(6)
        .toList(growable: false);
  }

  void _setMealType(String value) {
    setState(() => _mealType = value);
  }

  void _addFood(FoodItem food) {
    setState(() => _selected.add(food));
  }

  void _removeFoodAt(int index) {
    setState(() => _selected.removeAt(index));
  }

  Future<void> _addManualFood() async {
    final food = await showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualFoodSheet(),
    );

    if (food != null && mounted) {
      _addFood(food);
    }
  }

  void _saveMeal() {
    final entry = MealEntry(
      date: _date,
      mealType: _mealType,
      items: List.of(_selected),
    );
    Navigator.pop(context, entry);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;

    setState(() {
      _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        time.hour,
        time.minute,
      );
    });
  }
}

class _MealTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _MealTypeSelector({required this.value, required this.onChanged});

  static const _mealTypes = [
    'Caf\u00e9 da manh\u00e3',
    'Almo\u00e7o',
    'Lanche',
    'Jantar',
    'Outro',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: _mealTypes
            .map(
              (type) => ButtonSegment<String>(
                value: type,
                label: Text(type, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        selected: {value},
        onSelectionChanged: (values) => onChanged(values.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _MealDateTimeFields extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _MealDateTimeFields({
    required this.date,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateField = _MealDateField(
      label: 'Data',
      value: _NutritionScreenState._fmtDate(date),
      icon: Icons.calendar_today_outlined,
      onTap: onPickDate,
    );
    final timeField = _MealDateField(
      label: 'Hora',
      value: TimeOfDay.fromDateTime(date).format(context),
      icon: Icons.schedule_outlined,
      onTap: onPickTime,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            children: [
              dateField,
              const SizedBox(height: TitansUI.spaceXs),
              timeField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: dateField),
            const SizedBox(width: TitansUI.spaceSm),
            Expanded(child: timeField),
          ],
        );
      },
    );
  }
}

class _FoodSearchResults extends StatelessWidget {
  final List<FoodItem> foods;
  final int visibleCount;
  final ValueChanged<FoodItem> onAdd;
  final VoidCallback? onLoadMore;

  const _FoodSearchResults({
    required this.foods,
    required this.visibleCount,
    required this.onAdd,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final visibleFoods = foods.take(visibleCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sugest\u00f5es (${visibleFoods.length}/${foods.length})',
          style: TitansTypography.caption(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: TitansUI.spaceXs),
        _FoodSuggestionList(foods: visibleFoods, onAdd: onAdd, maxHeight: 220),
        if (onLoadMore != null)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text('Carregar mais (${foods.length - visibleCount})'),
            ),
          ),
      ],
    );
  }
}

class _FoodSuggestionList extends StatelessWidget {
  final List<FoodItem> foods;
  final ValueChanged<FoodItem> onAdd;
  final double maxHeight;

  const _FoodSuggestionList({
    required this.foods,
    required this.onAdd,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) return const Text('Nenhum alimento encontrado.');

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: foods.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final food = foods[index];
          return _FoodCompactRow(
            food: food,
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onAdd(food),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedFoodSection extends StatelessWidget {
  final List<FoodItem> selected;
  final int selectedKcal;
  final ValueChanged<int> onRemove;

  const _SelectedFoodSection({
    required this.selected,
    required this.selectedKcal,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child:
          selected.isEmpty
              ? const Text(
                key: ValueKey('selected-foods-empty'),
                'Adicione ao menos um alimento para salvar.',
              )
              : Column(
                key: const ValueKey('selected-foods-list'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Selecionados',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '$selectedKcal kcal registradas',
                        style: TitansTypography.caption(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: TitansUI.spaceXs),
                  ...selected.asMap().entries.map(
                    (entry) => _FoodCompactRow(
                      food: entry.value,
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => onRemove(entry.key),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _FoodCompactRow extends StatelessWidget {
  final FoodItem food;
  final Widget trailing;

  const _FoodCompactRow({required this.food, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        food.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        _foodEnergyLabel(food),
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.62)),
      ),
      trailing: trailing,
    );
  }
}

class _ManualFoodSheet extends StatefulWidget {
  const _ManualFoodSheet();

  @override
  State<_ManualFoodSheet> createState() => _ManualFoodSheetState();
}

class _ManualFoodSheetState extends State<_ManualFoodSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TitansUI.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              Text(
                'Alimento manual',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: TitansUI.spaceSm),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome do alimento',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: TitansUI.spaceSm),
              Text(
                'Energia fica como n\u00e3o informada.',
                style: TitansTypography.caption(context),
              ),
              const SizedBox(height: TitansUI.spaceMd),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: TitansUI.spaceSm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, FoodItem(name, 0));
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: TitansUI.spaceMd),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(TitansRadius.pill),
        ),
      ),
    );
  }
}

class _MealDateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _MealDateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  final UserProfile existing;

  const _ProfileDialog({required this.existing});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _a;
  Sex _sex = Sex.male;
  double _act = 1.375;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(
      text: widget.existing.weightKg.toStringAsFixed(1),
    );
    _h = TextEditingController(
      text: widget.existing.heightCm.toStringAsFixed(0),
    );
    _a = TextEditingController(text: widget.existing.age.toString());
    _sex = widget.existing.sex;
    _act = widget.existing.activityFactor;
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perfil nutricional'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _w,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _h,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Altura (cm)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _a,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Idade'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Sex>(
              initialValue: _sex,
              items: const [
                DropdownMenuItem(value: Sex.male, child: Text('Masculino')),
                DropdownMenuItem(value: Sex.female, child: Text('Feminino')),
              ],
              onChanged: (value) => setState(() => _sex = value ?? Sex.male),
              decoration: const InputDecoration(labelText: 'Sexo'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<double>(
              initialValue: _act,
              items: const [
                DropdownMenuItem(
                  value: 1.2,
                  child: Text('Sedent\u00e1rio (1.20)'),
                ),
                DropdownMenuItem(value: 1.375, child: Text('Leve (1.375)')),
                DropdownMenuItem(value: 1.55, child: Text('Moderado (1.55)')),
                DropdownMenuItem(value: 1.725, child: Text('Intenso (1.725)')),
                DropdownMenuItem(
                  value: 1.9,
                  child: Text('Muito intenso (1.90)'),
                ),
              ],
              onChanged: (value) => setState(() => _act = value ?? 1.375),
              decoration: const InputDecoration(
                labelText: 'Fator de atividade',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final profile = UserProfile(
              weightKg: double.tryParse(_w.text.replaceAll(',', '.')) ?? 80,
              heightCm: double.tryParse(_h.text.replaceAll(',', '.')) ?? 180,
              age: int.tryParse(_a.text) ?? 30,
              sex: _sex,
              activityFactor: _act,
            );
            Navigator.pop(context, profile);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
