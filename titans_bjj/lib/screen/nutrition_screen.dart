import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../main.dart';
import '../model/nutrition_models.dart';
import '../service/target_resolver.dart';
import '../widgets/titans_scaffold.dart';

class NutritionScreen extends StatefulWidget {
  final String? titleOverride;

  /// ✅ Mock condicional para teste/local
  final bool useMock;

  /// ✅ Dentro do console do atleta normalmente não queremos leading (logo)
  final bool showLeading;

  const NutritionScreen({
    super.key,
    this.titleOverride,
    this.useMock = false,
    this.showLeading = true,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final INutritionRepository _repo;
  bool _repoReady = false;

  // Se Firestore falhar por permissão, cai em mock automaticamente (sem travar app)
  bool _fallbackToMock = false;
  Object? _repoError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repoReady) return;

    final target = TargetResolver.of(context);
    final academyId = target.academyId;
    final uid = target.uid;

    if (widget.useMock) {
      _repo = InMemoryNutritionRepository();
      _repoReady = true;
      return;
    }

    _repo = FirestoreNutritionRepository(
      FirebaseFirestore.instance,
      academyId: academyId,
      uid: uid,
      fallbackFoodDb: InMemoryNutritionRepository(), // usa base de alimentos do mock
      onPermissionDeniedFallback: () {
        // fallback para não travar em ambiente local sem rules ajustadas
        if (mounted) {
          setState(() => _fallbackToMock = true);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _repoError = e);
        }
      },
    );

    _repoReady = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_repoReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final repo = _fallbackToMock ? InMemoryNutritionRepository() : _repo;

    return TitansScaffold(
      appBar: AppBar(
        leading: widget.showLeading ? const AppLogoLeading() : null,
        title: Text(widget.titleOverride ?? 'Nutrição'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMeal(repo),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<MealEntry>>(
        future: repo.listMeals(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final meals = snap.data!;

          final bottomPad = MediaQuery.of(context).padding.bottom;
          // ~80 do nav bar + padding safe area bottom + margem visual extra do FAB
          final extraBottom = 80.0 + bottomPad + 80.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, extraBottom),
            children: [
              if (_fallbackToMock)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '⚠️ Firestore sem permissão para Nutrição. Rodando em modo teste (mock).',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),

              if (_repoError != null && !_fallbackToMock)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Erro no repositório: $_repoError',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),

              FutureBuilder<UserProfile>(
                future: repo.getProfile(),
                builder: (context, profSnap) {
                  if (!profSnap.hasData) return const SizedBox.shrink();
                  final p = profSnap.data!;
                  final tdee = p.tdee();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Seu gasto calórico estimado (TDEE)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('${tdee.toStringAsFixed(0)} kcal/dia'),
                        const SizedBox(height: 10),
                        Text(
                          'Perfil: ${p.sex == Sex.male ? 'Masculino' : 'Feminino'}, ${p.age} anos, '
                              '${p.weightKg.toStringAsFixed(1)} kg, ${p.heightCm.toStringAsFixed(0)} cm',
                        ),
                        const SizedBox(height: 6),
                        Text('Fator atividade: ${p.activityFactor.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar perfil'),
                            onPressed: () => _editProfile(repo),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _DailyCaloriesChart(meals: meals),
              const SizedBox(height: 12),
              ...meals.reversed.map((m) => Card(
                child: ListTile(
                  title: Text('${_fmt(m.date)} • ${m.mealType}'),
                  subtitle: Text(m.items.map((i) => i.name).join(', ')),
                  trailing: Text('${m.totalKcal()} kcal'),
                ),
              )),
              if (meals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Sem refeições registradas',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editProfile(INutritionRepository repo) async {
    final p = await repo.getProfile();
    if (!mounted) return;
    final updated = await showDialog<UserProfile>(
      context: context,
      builder: (_) => _ProfileDialog(existing: p),
    );
    if (updated != null) {
      await repo.upsertProfile(updated);
      if (mounted) setState(() {});
    }
  }

  Future<void> _addMeal(INutritionRepository repo) async {
    final created = await showModalBottomSheet<MealEntry?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MealSheet(repo: repo),
    );
    if (created != null) {
      await repo.addMeal(created);
      if (mounted) setState(() {});
    }
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// ✅ Repositório Firestore (produção) com fallback de alimentos do mock
class FirestoreNutritionRepository implements INutritionRepository {
  final FirebaseFirestore db;
  final String academyId;
  final String uid;

  final InMemoryNutritionRepository fallbackFoodDb;

  final VoidCallback? onPermissionDeniedFallback;
  final void Function(Object e)? onError;

  FirestoreNutritionRepository(
      this.db, {
        required this.academyId,
        required this.uid,
        required this.fallbackFoodDb,
        this.onPermissionDeniedFallback,
        this.onError,
      });

  DocumentReference<Map<String, dynamic>> _profileRef() => db
      .collection('academies')
      .doc(academyId)
      .collection('users')
      .doc(uid)
      .collection('nutrition')
      .doc('profile');

  /// ✅ meals vira subcoleção do doc "profile"
  CollectionReference<Map<String, dynamic>> _mealsCol() =>
      _profileRef().collection('meals');

  bool _isPermissionDenied(Object e) {
    if (e is FirebaseException) return e.code == 'permission-denied';
    final msg = e.toString().toLowerCase();
    return msg.contains('permission-denied') ||
        msg.contains('insufficient permissions');
  }

  @override
  List<FoodItem> foodDb(String query) {
    return fallbackFoodDb.foodDb(query);
  }

  @override
  Future<UserProfile> getProfile() async {
    try {
      final snap = await _profileRef().get();
      final data = snap.data();

      if (data == null) {
        final p = UserProfile(
          weightKg: 80,
          heightCm: 180,
          age: 30,
          sex: Sex.male,
          activityFactor: 1.375,
        );
        await upsertProfile(p);
        return p;
      }

      final sexStr = (data['sex'] ?? 'male').toString();
      final sex = sexStr == 'female' ? Sex.female : Sex.male;

      return UserProfile(
        weightKg: (data['weightKg'] ?? 80).toDouble(),
        heightCm: (data['heightCm'] ?? 180).toDouble(),
        age: (data['age'] ?? 30).toInt(),
        sex: sex,
        activityFactor: (data['activityFactor'] ?? 1.375).toDouble(),
      );
    } catch (e) {
      onError?.call(e);
      if (_isPermissionDenied(e)) {
        onPermissionDeniedFallback?.call();
        return fallbackFoodDb.getProfile();
      }
      rethrow;
    }
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    try {
      await _profileRef().set({
        'weightKg': profile.weightKg,
        'heightCm': profile.heightCm,
        'age': profile.age,
        'sex': profile.sex == Sex.female ? 'female' : 'male',
        'activityFactor': profile.activityFactor,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      onError?.call(e);
      if (_isPermissionDenied(e)) {
        onPermissionDeniedFallback?.call();
        await fallbackFoodDb.upsertProfile(profile);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<MealEntry>> listMeals() async {
    try {
      final snap = await _mealsCol().orderBy('date', descending: false).get();
      final out = <MealEntry>[];

      for (final d in snap.docs) {
        final data = d.data();

        final ts = data['date'];
        DateTime date;
        if (ts is Timestamp) {
          date = ts.toDate();
        } else {
          date = DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();
        }

        final mealType = (data['mealType'] ?? 'Almoço').toString();
        final itemsRaw = (data['items'] as List?) ?? const [];
        final items = <FoodItem>[];

        for (final it in itemsRaw) {
          if (it is Map) {
            final name = (it['name'] ?? '').toString();
            final kcal = (it['kcal'] ?? 0).toInt();
            if (name.trim().isEmpty) continue;

            // ✅ FoodItem é posicional no seu model: FoodItem(this.name, this.kcal)
            items.add(FoodItem(name, kcal));
          }
        }

        out.add(MealEntry(date: date, mealType: mealType, items: items));
      }

      return out;
    } catch (e) {
      onError?.call(e);
      if (_isPermissionDenied(e)) {
        onPermissionDeniedFallback?.call();
        return fallbackFoodDb.listMeals();
      }
      rethrow;
    }
  }

  @override
  Future<void> addMeal(MealEntry meal) async {
    try {
      await _mealsCol().add({
        'date': Timestamp.fromDate(meal.date),
        'mealType': meal.mealType,
        'items': meal.items.map((f) => {'name': f.name, 'kcal': f.kcal}).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      onError?.call(e);
      if (_isPermissionDenied(e)) {
        onPermissionDeniedFallback?.call();
        await fallbackFoodDb.addMeal(meal);
        return;
      }
      rethrow;
    }
  }
}

class _DailyCaloriesChart extends StatelessWidget {
  final List<MealEntry> meals;
  const _DailyCaloriesChart({required this.meals});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final map = <DateTime, int>{};
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      map[d] = 0;
    }
    for (final m in meals) {
      final day = DateTime(m.date.year, m.date.month, m.date.day);
      if (day.isBefore(start) || day.isAfter(start.add(const Duration(days: 6)))) continue;
      map.update(day, (v) => v + m.totalKcal(), ifAbsent: () => m.totalKcal());
    }

    final keys = map.keys.toList()..sort();
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < keys.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: (map[keys[i]] ?? 0).toDouble(), width: 12)],
          showingTooltipIndicators: const [0],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Calorias (últimos 7 dias)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        final i = value.toInt();
                        if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                        final d = keys[i];
                        return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ]),
      ),
    );
  }
}

// --- abaixo mantido do seu original ---

class _MealSheet extends StatefulWidget {
  final INutritionRepository repo;
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Nova refeição', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  if (!context.mounted) return;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                  setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data/Hora'),
                  child: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')} '
                      '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}'),
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
                onChanged: (v) => setState(() => _mealType = v ?? 'Almoço'),
                decoration: const InputDecoration(labelText: 'Refeição'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'Buscar alimento (ex: arroz, frango...)'),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          for (final f in results.take(8))
            ListTile(
              title: Text(f.name),
              subtitle: Text('${f.kcal} kcal'),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() => _selected.add(f));
                },
              ),
            ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Selecionados: ${_selected.fold<int>(0, (a, b) => a + b.kcal)} kcal'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _selected
                .asMap()
                .entries
                .map((e) => Chip(
              label: Text('${e.value.name} • ${e.value.kcal}'),
              onDeleted: () => setState(() => _selected.removeAt(e.key)),
            ))
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
                final entry = MealEntry(date: _date, mealType: _mealType, items: List.of(_selected));
                Navigator.pop(context, entry);
              },
            ),
          ),
        ]),
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
  late TextEditingController _w;
  late TextEditingController _h;
  late TextEditingController _a;
  Sex _sex = Sex.male;
  double _act = 1.375;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(text: widget.existing.weightKg.toStringAsFixed(1));
    _h = TextEditingController(text: widget.existing.heightCm.toStringAsFixed(0));
    _a = TextEditingController(text: widget.existing.age.toString());
    _sex = widget.existing.sex;
    _act = widget.existing.activityFactor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perfil'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _w, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peso (kg)')),
          const SizedBox(height: 8),
          TextField(controller: _h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Altura (cm)')),
          const SizedBox(height: 8),
          TextField(controller: _a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idade')),
          const SizedBox(height: 8),
          DropdownButtonFormField<Sex>(
            initialValue: _sex,
            items: const [
              DropdownMenuItem(value: Sex.male, child: Text('Masculino')),
              DropdownMenuItem(value: Sex.female, child: Text('Feminino')),
            ],
            onChanged: (v) => setState(() => _sex = v ?? Sex.male),
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
              DropdownMenuItem(value: 1.9, child: Text('Muito intenso (1.90)')),
            ],
            onChanged: (v) => setState(() => _act = v ?? 1.375),
            decoration: const InputDecoration(labelText: 'Atividade'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final p = UserProfile(
              weightKg: double.tryParse(_w.text.replaceAll(',', '.')) ?? 80,
              heightCm: double.tryParse(_h.text.replaceAll(',', '.')) ?? 180,
              age: int.tryParse(_a.text) ?? 30,
              sex: _sex,
              activityFactor: _act,
            );
            Navigator.pop(context, p);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
