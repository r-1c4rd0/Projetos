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
  late Future<UserProfile> _profileFuture;
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
      final canEditTarget =
          target != null && _canEditTarget(loggedUser: actor, target: target);
      debugPrint(
        '[NUTRITION_TARGET] screen=NutritionScreen '
        'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
        'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
        'explicit.academyId=${widget.explicitTarget?.academyId} '
        'resolver.uid=${resolverTarget?.uid} '
        'resolver.academyId=${resolverTarget?.academyId} '
        'target.uid=${target?.uid} target.academyId=${target?.academyId} '
        'canEditTarget=$canEditTarget',
      );
      if (target == null) {
        debugPrint(
          '[NUTRITION_ACTIONS] showAddMeal=false showEditNutritionProfile=false '
          'canEditTarget=$canEditTarget hiddenBy=missing-target '
          'actor.uid=${actor?.uid} actor.role=${actor?.role}',
        );
        return _wrapModule(
          appBar: AppBar(title: Text(widget.titleOverride ?? 'Nutricao')),
          body:
              widget.targetMode == TargetMode.selectedStudent
                  ? const TitansStateView.noStudent(
                    message:
                        'Selecione um aluno no Painel do Mestre para acessar Nutricao.',
                  )
                  : const TitansStateView.error(
                    title: 'Perfil nao carregado',
                    message:
                        'Nao foi possivel identificar seu usuario para carregar Nutricao.',
                  ),
        );
      }

      return const TitansSkeletonCard(lines: 4);
    }

    final target = _resolveTarget(context);
    final canEditTarget =
        target != null && _canEditTarget(loggedUser: actor, target: target);
    debugPrint(
      '[NUTRITION_ACTIONS] showAddMeal=$canEditTarget '
      'showEditNutritionProfile=$canEditTarget canEditTarget=$canEditTarget '
      "hiddenBy=${canEditTarget ? 'none' : 'canEditTarget=false'} "
      'actor.uid=${actor?.uid} actor.role=${actor?.role} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId}',
    );
    debugPrint(
      '[NUTRITION_TARGET] screen=NutritionScreen '
      'targetMode=${widget.targetMode} actor.uid=${actor?.uid} '
      'actor.role=${actor?.role} explicit.uid=${widget.explicitTarget?.uid} '
      'explicit.academyId=${widget.explicitTarget?.academyId} '
      'target.uid=${target?.uid} target.academyId=${target?.academyId} '
      'canEditTarget=$canEditTarget',
    );

    return _wrapModule(
      appBar: AppBar(
        leading: widget.showLeading ? const AppLogoLeading() : null,
        title: Text(widget.titleOverride ?? 'Nutricao'),
      ),
      floatingActionButton:
          !widget.embedded && canEditTarget
              ? FloatingActionButton(
                heroTag: 'nutrition_fab',
                onPressed: _addMeal,
                child: const Icon(Icons.add),
              )
              : null,
      body: FutureBuilder<List<MealEntry>>(
        future: _mealsFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const TitansSkeletonCard(lines: 4);
          }

          final meals = snap.data!;
          final listPadding =
              widget.embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 80);

          return ListView(
            padding: listPadding,
            children: [
              if (widget.embedded && canEditTarget) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _addMeal,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar refeicao'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_fallbackToMock)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Firestore sem permiss\u00e3o para Nutri\u00e7\u00e3o. Rodando em modo teste (mock).',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (_repoError != null && !_fallbackToMock)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Erro no reposit\u00f3rio: $_repoError',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              FutureBuilder<UserProfile>(
                future: _profileFuture,
                builder: (context, profSnap) {
                  if (!profSnap.hasData) return const SizedBox.shrink();

                  final profile = profSnap.data!;
                  final tdee = profile.tdee();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seu gasto cal\u00f3rico estimado (TDEE)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('${tdee.toStringAsFixed(0)} kcal/dia'),
                          const SizedBox(height: 10),
                          Text(
                            'Perfil: ${profile.sex == Sex.male ? 'Masculino' : 'Feminino'}, '
                            '${profile.age} anos, ${profile.weightKg.toStringAsFixed(1)} kg, '
                            '${profile.heightCm.toStringAsFixed(0)} cm',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fator atividade: ${profile.activityFactor.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child:
                                canEditTarget
                                    ? OutlinedButton.icon(
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Editar perfil'),
                                      onPressed: _editProfile,
                                    )
                                    : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _DailyCaloriesChart(meals: meals),
              const SizedBox(height: 12),
              ...meals.reversed.map(
                (meal) => Card(
                  child: ListTile(
                    title: Text('${_fmt(meal.date)} - ${meal.mealType}'),
                    subtitle: Text(
                      meal.items.map((item) => item.name).join(', '),
                    ),
                    trailing: Text('${meal.totalKcal()} kcal'),
                  ),
                ),
              ),
              if (meals.isEmpty)
                const TitansEmptyState(
                  icon: Icons.restaurant_outlined,
                  title: 'Sem refeicoes registradas',
                  message:
                      'Use o botao adicionar para registrar a primeira refeicao.',
                  compact: true,
                ),
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

  bool _canEditTarget({
    required AppUser? loggedUser,
    required TargetProfile target,
  }) {
    if (loggedUser == null) return false;
    final canManage =
        loggedUser.role == UserRole.admin ||
        loggedUser.role == UserRole.professor;
    return loggedUser.academyId == target.academyId &&
        (loggedUser.uid == target.uid || canManage);
  }

  Future<void> _editProfile() async {
    final profile = await _repo.getProfileCached();
    if (!mounted) return;

    final updated = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _ProfileDialog(existing: profile),
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

  static String _fmt(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
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
          showingTooltipIndicators: const [0],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calorias (\u00faltimos 7 dias)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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

  @override
  Widget build(BuildContext context) {
    final results = widget.repo.foodDb(_query);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nova refei\u00e7\u00e3o',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      if (!context.mounted) return;

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_date),
                      );

                      setState(() {
                        _date = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time?.hour ?? 0,
                          time?.minute ?? 0,
                        );
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data/Hora'),
                      child: Text(_NutritionScreenState._fmt(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mealType,
                    items: const [
                      DropdownMenuItem(
                        value: 'Caf\u00e9',
                        child: Text('Caf\u00e9'),
                      ),
                      DropdownMenuItem(
                        value: 'Almo\u00e7o',
                        child: Text('Almo\u00e7o'),
                      ),
                      DropdownMenuItem(value: 'Jantar', child: Text('Jantar')),
                      DropdownMenuItem(value: 'Lanche', child: Text('Lanche')),
                    ],
                    onChanged: (value) {
                      setState(() => _mealType = value ?? 'Almo\u00e7o');
                    },
                    decoration: const InputDecoration(
                      labelText: 'Refei\u00e7\u00e3o',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar alimento (ex: arroz, frango...)',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            for (final food in results.take(8))
              ListTile(
                title: Text(food.name),
                subtitle: Text('${food.kcal} kcal'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _selected.add(food)),
                ),
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecionados: ${_selected.fold<int>(0, (sum, food) => sum + food.kcal)} kcal',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children:
                  _selected
                      .asMap()
                      .entries
                      .map(
                        (entry) => Chip(
                          label: Text(
                            '${entry.value.name} - ${entry.value.kcal}',
                          ),
                          onDeleted: () {
                            setState(() => _selected.removeAt(entry.key));
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Adicionar'),
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
            ),
          ],
        ),
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
      title: const Text('Perfil'),
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
              decoration: const InputDecoration(labelText: 'Atividade'),
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
