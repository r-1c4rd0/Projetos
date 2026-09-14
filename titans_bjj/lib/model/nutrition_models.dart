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

  /// Energia estimada de rotina
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
  final int? kcal;
  FoodItem(this.name, this.kcal);

  Map<String, dynamic> toMap() => {'name': name, 'kcal': kcal};

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    final kcalValue = map['kcal'];
    int? kcal;
    if (kcalValue is int) {
      kcal = kcalValue;
    } else if (kcalValue != null) {
      kcal = kcalValue.toInt();
    }
    return FoodItem(
      (map['name'] ?? '').toString(),
      kcal,
    );
  }
}

class MealEntry {
  final DateTime date;
  final String mealType; // Cafe/Almoco/Jantar/Lanche
  final List<FoodItem> items;

  MealEntry({required this.date, required this.mealType, required this.items});

  int? totalKcal() {
    var sum = 0;
    for (final item in items) {
      if (item.kcal == null) return null;
      sum += item.kcal!;
    }
    return sum;
  }

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'mealType': mealType,
    'items': items.map((food) => food.toMap()).toList(),
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

    final mealType = (map['mealType'] ?? 'Almoco').toString();
    final itemsRaw = (map['items'] as List?) ?? const [];
    final items =
        itemsRaw
            .whereType<Map>()
            .map(
              (item) => FoodItem(
                (item['name'] ?? '').toString(),
                (item['kcal'] ?? 0).toInt(),
              ),
            )
            .where((food) => food.name.trim().isNotEmpty)
            .toList();

    return MealEntry(date: date, mealType: mealType, items: items);
  }
}
