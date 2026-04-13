import 'package:cloud_firestore/cloud_firestore.dart';

enum Sex { male, female }

class UserProfile {
  double weightKg;
  double heightCm;
  int age;
  Sex sex;
  double activityFactor; // 1.2 .. 1.9

  UserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.sex,
    this.activityFactor = 1.375, // leve
  });

  /// Mifflin-St Jeor BMR
  double bmr() {
    final s = sex == Sex.male ? 5 : -161;
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + s;
  }

  /// TDEE
  double tdee() => bmr() * activityFactor;

  Map<String, dynamic> toMap() => {
        'weightKg': weightKg,
        'heightCm': heightCm,
        'age': age,
        'sex': sex == Sex.female ? 'female' : 'male',
        'activityFactor': activityFactor,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final sexStr = (map['sex'] ?? 'male').toString();
    return UserProfile(
      weightKg: (map['weightKg'] ?? 80).toDouble(),
      heightCm: (map['heightCm'] ?? 180).toDouble(),
      age: (map['age'] ?? 30).toInt(),
      sex: sexStr == 'female' ? Sex.female : Sex.male,
      activityFactor: (map['activityFactor'] ?? 1.375).toDouble(),
    );
  }
}

class FoodItem {
  final String name;
  final int kcal; // por porção simples
  FoodItem(this.name, this.kcal);

  Map<String, dynamic> toMap() => {'name': name, 'kcal': kcal};

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      (map['name'] ?? '').toString(),
      (map['kcal'] ?? 0).toInt(),
    );
  }
}

class MealEntry {
  final DateTime date;
  final String mealType; // Café/Almoço/Jantar/Lanche
  final List<FoodItem> items;

  MealEntry({required this.date, required this.mealType, required this.items});

  int totalKcal() => items.fold(0, (a, b) => a + b.kcal);

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'mealType': mealType,
        'items': items.map((f) => f.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    final ts = map['date'];
    DateTime date;
    if (ts is Timestamp) {
      date = ts.toDate();
    } else {
      date = DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();
    }

    final mealType = (map['mealType'] ?? 'Almoço').toString();
    final itemsRaw = (map['items'] as List?) ?? const [];
    final items = itemsRaw
        .whereType<Map>()
        .map((it) => FoodItem(
              (it['name'] ?? '').toString(),
              (it['kcal'] ?? 0).toInt(),
            ))
        .where((f) => f.name.trim().isNotEmpty)
        .toList();

    return MealEntry(date: date, mealType: mealType, items: items);
  }
}

abstract class INutritionRepository {
  Future<void> upsertProfile(UserProfile p);
  Future<UserProfile> getProfile();

  Future<void> addMeal(MealEntry e);
  Future<List<MealEntry>> listMeals();

  List<FoodItem> foodDb(String query);
}

class InMemoryNutritionRepository implements INutritionRepository {
  UserProfile _profile = UserProfile(weightKg: 80, heightCm: 180, age: 30, sex: Sex.male);
  final _meals = <MealEntry>[];

  final _db = <FoodItem>[
    FoodItem('Arroz (1 concha)', 110),
    FoodItem('Feijão (1 concha)', 90),
    FoodItem('Frango grelhado (100g)', 165),
    FoodItem('Ovo cozido (1 un)', 78),
    FoodItem('Salada verde (1 prato)', 35),
    FoodItem('Banana (1 un)', 95),
    FoodItem('Maçã (1 un)', 80),
    FoodItem('Pão integral (1 fatia)', 70),
    FoodItem('Queijo minas (30g)', 85),
    FoodItem('Aveia (30g)', 115),
    FoodItem('Iogurte natural (170g)', 100),
  ];

  @override
  Future<void> upsertProfile(UserProfile p) async {
    _profile = p;
  }

  @override
  Future<UserProfile> getProfile() async => _profile;

  @override
  Future<void> addMeal(MealEntry e) async {
    _meals.add(e);
  }

  @override
  Future<List<MealEntry>> listMeals() async {
    _meals.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(_meals);
  }

  @override
  List<FoodItem> foodDb(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _db;
    return _db.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}
