import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/titans_ui.dart';
import '../main.dart';
import '../model/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../service/target_resolver.dart';
import '../widgets/titans_scaffold.dart';

class NutritionScreen extends StatefulWidget {
  final String? titleOverride;
  final TargetMode targetMode;
  final TargetProfile? explicitTarget;

  /// Mock condicional para teste/local.
  final bool useMock;

  /// Dentro do console do atleta normalmente nao queremos leading (logo).
  final bool showLeading;

  const NutritionScreen({
    super.key,
    this.titleOverride,
    this.targetMode = TargetMode.self,
    this.explicitTarget,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final target = TargetResolver.maybeOf(
        context,
        mode: widget.targetMode,
        explicitTarget: widget.explicitTarget,
      );
    if (target == null) {
      _repoReady = false;
      return;
    }

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

  void _reloadNutritionData() {
    setState(() {
      _profileFuture = _repo.getProfileCached();
      _mealsFuture = _repo.listMealsCached();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_repoReady) {
      final target = TargetResolver.maybeOf(
        context,
        mode: widget.targetMode,
        explicitTarget: widget.explicitTarget,
      );
      if (target == null) {
        return TitansScaffold(
          appBar: AppBar(title: Text(widget.titleOverride ?? 'Nutricao')),
          body: widget.targetMode == TargetMode.selectedStudent
            ? const TitansStateView.noStudent(
                message: 'Selecione um aluno no Painel do Mestre para acessar Nutricao.',
              )
            : const TitansStateView.error(
                title: 'Perfil nao carregado',
                message:
                    'Nao foi possivel identificar seu usuario para carregar Nutricao.',
              ),
        );
      }

      return const TitansStateView.loading();
    }

    return TitansScaffold(
      appBar: AppBar(
        leading: widget.showLeading ? const AppLogoLeading() : null,
        title: Text(widget.titleOverride ?? 'Nutrição'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'nutrition_fab',
        onPressed: _addMeal,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<MealEntry>>(
        future: _mealsFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const TitansStateView.loading();
          }

          final meals = snap.data!;
          final listPadding = TitansUI.listPadding(context, extra: 80);

          return ListView(
            padding: listPadding,
            children: [
              if (_fallbackToMock)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Firestore sem permissão para Nutrição. Rodando em modo teste (mock).',
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
                      'Erro no repositório: $_repoError',
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
                            'Seu gasto calórico estimado (TDEE)',
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
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar perfil'),
                              onPressed: _editProfile,
                            ),
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
                    title: Text('${_fmt(meal.date)} • ${meal.mealType}'),
                    subtitle: Text(
                      meal.items.map((item) => item.name).join(', '),
                    ),
                    trailing: Text('${meal.totalKcal()} kcal'),
                  ),
                ),
              ),
              if (meals.isEmpty)
                const TitansStateView.empty(
                  title: 'Sem refeicoes registradas',
                  message: 'Use o botao adicionar para registrar a primeira refeicao.',
                  compact: true,
                ),
            ],
          );
        },
      ),
    );
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
            BarChartRodData(
              toY: (map[keys[i]] ?? 0).toDouble(),
              width: 12,
            ),
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
              'Calorias (últimos 7 dias)',
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
  String _mealType = 'Almoço';
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
              'Nova refeição',
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
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
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
                      DropdownMenuItem(value: 'Café', child: Text('Café')),
                      DropdownMenuItem(value: 'Almoço', child: Text('Almoço')),
                      DropdownMenuItem(value: 'Jantar', child: Text('Jantar')),
                      DropdownMenuItem(value: 'Lanche', child: Text('Lanche')),
                    ],
                    onChanged: (value) {
                      setState(() => _mealType = value ?? 'Almoço');
                    },
                    decoration: const InputDecoration(labelText: 'Refeição'),
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
              children: _selected
                  .asMap()
                  .entries
                  .map(
                    (entry) => Chip(
                      label: Text(
                        '${entry.value.name} • ${entry.value.kcal}',
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
                onPressed: _selected.isEmpty
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
                DropdownMenuItem(value: 1.2, child: Text('Sedentário (1.20)')),
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
