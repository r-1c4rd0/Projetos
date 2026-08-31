import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
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
        leading: widget.showLeading ? const AppLogoLeading() : null,
        title: Text(widget.titleOverride ?? 'Nutri\u00e7\u00e3o'),
      ),
      floatingActionButton:
          !widget.embedded && canEditNutrition && !_hasUnavailableNutritionData
              ? FloatingActionButton(
                heroTag: 'nutrition_fab',
                onPressed: _addMeal,
                backgroundColor: TitansUI.actionGold,
                foregroundColor: Colors.black,
                child: const Icon(Icons.add),
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
              const _NutritionInfoCard(
                icon: Icons.info_outline,
                title: 'Informa\u00e7\u00f5es educativas',
                message:
                    'Estas informa\u00e7\u00f5es s\u00e3o educativas e ajudam no registro da rotina. Para um plano alimentar individual, consulte um profissional de sa\u00fade ou nutri\u00e7\u00e3o.',
              ),
              const SizedBox(height: 12),
              FutureBuilder<UserProfile?>(
                future: _profileFuture,
                builder: (context, profSnap) {
                  if (profSnap.connectionState == ConnectionState.waiting) {
                    return const TitansSkeletonCard(lines: 3);
                  }

                  final profile = profSnap.data;

                  if (profile == null) {
                    return Column(
                      children: [
                        _NutritionProfilePlaceholder(
                          canEditNutrition: canEditNutrition,
                          onComplete: canEditNutrition ? _editProfile : null,
                        ),
                        const SizedBox(height: 12),
                        const _NutritionEnergyPendingCard(),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _NutritionProfileCard(
                        profile: profile,
                        canEditNutrition: canEditNutrition,
                        onEdit: _editProfile,
                      ),
                      const SizedBox(height: 12),
                      _NutritionEnergyCard(profile: profile),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _NutritionMealsSection(
                meals: meals,
                canEditNutrition: canEditNutrition,
                onAddMeal: _addMeal,
              ),
              const SizedBox(height: 12),
              _DailyCaloriesChart(meals: meals),
            ],
          );
        },
      ),
    );
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
    final created = await showModalBottomSheet<MealEntry?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MealSheet(repo: _repo),
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
        _NutritionHeader(title: title),
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

  const _NutritionHeader({required this.title});

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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  final VoidCallback? onComplete;

  const _NutritionProfilePlaceholder({
    required this.canEditNutrition,
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
              : 'Perfil nutricional ainda n\u00e3o preenchido.',
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

  const _NutritionEnergyCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.68);
    final tdee = profile.tdee();

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

class _NutritionMealsSection extends StatelessWidget {
  final List<MealEntry> meals;
  final bool canEditNutrition;
  final VoidCallback onAddMeal;

  const _NutritionMealsSection({
    required this.meals,
    required this.canEditNutrition,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return TitansCard(
      accent: meals.isEmpty ? TitansUI.actionGold : TitansUI.technicalBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              const _SectionTitle(
                title: 'Refei\u00e7\u00f5es',
                subtitle: 'Registros alimentares informados pelo usu\u00e1rio.',
              ),
              if (canEditNutrition && meals.isNotEmpty)
                FilledButton.icon(
                  onPressed: onAddMeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar refei\u00e7\u00e3o'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            TitansEmptyState(
              icon: Icons.restaurant_outlined,
              title: 'Sem refei\u00e7\u00f5es registradas',
              message:
                  canEditNutrition
                      ? 'Adicione registros alimentares para acompanhar sua rotina.'
                      : 'Nenhuma refei\u00e7\u00e3o foi registrada para este usu\u00e1rio.',
              actionLabel:
                  canEditNutrition ? 'Adicionar refei\u00e7\u00e3o' : null,
              onAction: canEditNutrition ? onAddMeal : null,
              variant:
                  canEditNutrition
                      ? TitansEmptyStateVariant.action
                      : TitansEmptyStateVariant.neutral,
              compact: true,
              showCard: false,
            )
          else
            ..._mealTiles(context),
        ],
      ),
    );
  }

  List<Widget> _mealTiles(BuildContext context) {
    final orderedMeals = meals.reversed.toList();
    final tiles = <Widget>[];

    for (var i = 0; i < orderedMeals.length; i++) {
      tiles.add(_MealLogTile(meal: orderedMeals[i]));
      if (i != orderedMeals.length - 1) {
        tiles.add(const SizedBox(height: TitansUI.spaceSm));
      }
    }

    return tiles;
  }
}

class _MealLogTile extends StatelessWidget {
  final MealEntry meal;

  const _MealLogTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = meal.items.map((item) => item.name).join(', ');
    final time = TimeOfDay.fromDateTime(meal.date).format(context);
    final mealChip = TitansStatusChip(
      label: meal.mealType,
      variant: TitansStatusChipVariant.technical,
      icon: Icons.restaurant_menu_outlined,
      compact: true,
    );
    final metaChip = TitansStatusChip(
      label: '${_NutritionScreenState._fmtDate(meal.date)} - $time',
      variant: TitansStatusChipVariant.muted,
      icon: Icons.schedule_outlined,
      compact: true,
    );
    final kcalBlock = _MealEnergyBadge(kcal: meal.totalKcal());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TitansUI.elevatedSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(TitansRadius.sm),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TitansUI.spaceSm),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 330;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: TitansUI.spaceXs,
                  runSpacing: TitansUI.spaceXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [mealChip, metaChip],
                ),
                const SizedBox(height: TitansUI.spaceSm),
                Text(
                  items.isEmpty ? 'Registro alimentar sem itens.' : items,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TitansUI.spaceXs),
                Text(
                  'Registro alimentar',
                  style: TitansTypography.caption(context),
                ),
              ],
            );

            if (isTight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: TitansUI.spaceSm),
                  Align(alignment: Alignment.centerLeft, child: kcalBlock),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: TitansUI.spaceSm),
                kcalBlock,
              ],
            );
          },
        ),
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.64),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
  const _DailyCaloriesChart({required this.meals});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final map = <DateTime, int>{};

    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      map[date] = 0;
    }

    for (final meal in meals) {
      final day = DateTime(meal.date.year, meal.date.month, meal.date.day);
      if (day.isBefore(start) ||
          day.isAfter(start.add(const Duration(days: 6)))) {
        continue;
      }
      map.update(
        day,
        (value) => value + meal.totalKcal(),
        ifAbsent: meal.totalKcal,
      );
    }

    final keys = map.keys.toList()..sort();
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < keys.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: (map[keys[i]] ?? 0).toDouble(), width: 12),
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
              height: 220,
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
                          if (index < 0 || index >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          final date = keys[index];
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

  const _MealSheet({required this.repo});

  @override
  State<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<_MealSheet> {
  DateTime _date = DateTime.now();
  String _mealType = 'Almo\u00e7o';
  String _query = '';
  final List<FoodItem> _selected = [];

  int get _selectedKcal =>
      _selected.fold<int>(0, (sum, food) => sum + food.kcal);

  @override
  Widget build(BuildContext context) {
    final results = widget.repo.foodDb(_query);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final dateField = _MealDateField(
      label: 'Data',
      value: _NutritionScreenState._fmtDate(_date),
      icon: Icons.calendar_today_outlined,
      onTap: _pickDate,
    );
    final timeField = _MealDateField(
      label: 'Hora',
      value: TimeOfDay.fromDateTime(_date).format(context),
      icon: Icons.schedule_outlined,
      onTap: _pickTime,
    );

    final mealTypeField = DropdownButtonFormField<String>(
      initialValue: _mealType,
      items: const [
        DropdownMenuItem(value: 'Caf\u00e9', child: Text('Caf\u00e9')),
        DropdownMenuItem(value: 'Almo\u00e7o', child: Text('Almo\u00e7o')),
        DropdownMenuItem(value: 'Jantar', child: Text('Jantar')),
        DropdownMenuItem(value: 'Lanche', child: Text('Lanche')),
      ],
      onChanged: (value) {
        setState(() => _mealType = value ?? 'Almo\u00e7o');
      },
      decoration: const InputDecoration(labelText: 'Refei\u00e7\u00e3o'),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nova refei\u00e7\u00e3o',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Registro alimentar informado pelo usu\u00e1rio.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                title: 'Dados da refei\u00e7\u00e3o',
                subtitle: 'Escolha o tipo, a data e a hora do registro.',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 390) {
                    return Column(
                      children: [
                        mealTypeField,
                        const SizedBox(height: 8),
                        dateField,
                        const SizedBox(height: 8),
                        timeField,
                      ],
                    );
                  }

                  return Column(
                    children: [
                      mealTypeField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: dateField),
                          const SizedBox(width: 8),
                          Expanded(child: timeField),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                title: 'Energia registrada',
                subtitle:
                    'Registro informado pelo usu\u00e1rio, n\u00e3o prescri\u00e7\u00e3o.',
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar alimento (ex: arroz, frango...)',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              for (final food in results.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Calorias: ${food.kcal} kcal'),
                  trailing: IconButton(
                    tooltip: 'Adicionar alimento',
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _selected.add(food)),
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Energia registrada: $_selectedKcal kcal',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${_selected.length} item(ns)',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selected.isEmpty)
                Text(
                  'Adicione ao menos um alimento para salvar o registro.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _selected
                          .asMap()
                          .entries
                          .map(
                            (entry) => Chip(
                              label: Text(
                                '${entry.value.name} - ${entry.value.kcal} kcal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: () {
                                setState(() => _selected.removeAt(entry.key));
                              },
                            ),
                          )
                          .toList(),
                ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                    onPressed:
                        _selected.isEmpty
                            ? null
                            : () {
                              final entry = MealEntry(
                                date: _date,
                                mealType: _mealType,
                                items: List.of(_selected),
                              );
                              Navigator.pop(context, entry);
                            },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
