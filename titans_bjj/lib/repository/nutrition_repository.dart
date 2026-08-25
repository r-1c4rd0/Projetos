import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../model/nutrition_models.dart';

abstract class NutritionRepository {
  Future<UserProfile?> getProfileCached();
  Stream<UserProfile?> watchProfile();
  Future<void> upsertProfile(UserProfile profile);

  Future<List<MealEntry>> listMealsCached();
  Stream<List<MealEntry>> watchMeals();
  Future<void> addMeal(MealEntry meal);
  Future<void> upsertMeal({required String mealId, required MealEntry meal});
  Future<void> deleteMeal(String mealId);

  List<FoodItem> foodDb(String query);
}

class NutritionRepositoryFactory {
  const NutritionRepositoryFactory._();

  static NutritionRepository create({
    required String academyId,
    required String uid,
    bool useMock = AppConfig.useMocks,
    void Function()? onPermissionDeniedFallback,
    void Function(Object error)? onError,
  }) {
    if (useMock || AppConfig.useMocks) {
      return InMemoryNutritionRepository();
    }

    return FirestoreNutritionRepository(
      FirebaseFirestore.instance,
      academyId: academyId,
      uid: uid,
      fallbackFoodDb: InMemoryNutritionRepository(),
      onPermissionDeniedFallback: onPermissionDeniedFallback,
      onError: onError,
    );
  }
}

class FirestoreNutritionRepository implements NutritionRepository {
  FirestoreNutritionRepository(
    this.db, {
    required this.academyId,
    required this.uid,
    required this.fallbackFoodDb,
    this.onPermissionDeniedFallback,
    this.onError,
  });

  final FirebaseFirestore db;
  final String academyId;
  final String uid;
  final InMemoryNutritionRepository fallbackFoodDb;
  final void Function()? onPermissionDeniedFallback;
  final void Function(Object error)? onError;

  Future<UserProfile?>? _profileFuture;
  Future<List<MealEntry>>? _mealsFuture;

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return _academyRef(academyId).collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _nutritionCollectionRef() {
    return _userRef(academyId: academyId, uid: uid).collection('nutrition');
  }

  DocumentReference<Map<String, dynamic>> _profileRef() {
    return _nutritionCollectionRef().doc('profile');
  }

  CollectionReference<Map<String, dynamic>> _mealsCollectionRef() {
    return _profileRef().collection('meals');
  }

  bool _shouldFallback(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' || error.code == 'unavailable';
    }

    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('insufficient permissions') ||
        message.contains('unavailable') ||
        message.contains('offline');
  }

  void _handleError(Object error) {
    onError?.call(error);
    if (_shouldFallback(error)) {
      onPermissionDeniedFallback?.call();
    }
  }

  @override
  Future<UserProfile?> getProfileCached() {
    _profileFuture ??= _loadProfile();
    return _profileFuture!;
  }

  Future<UserProfile?> _loadProfile() async {
    try {
      final snap = await _profileRef().get();
      final data = snap.data();

      if (data == null) {
        return null;
      }

      return UserProfile.fromMap(data);
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        return fallbackFoodDb.getProfileCached();
      }
      rethrow;
    }
  }

  @override
  Stream<UserProfile?> watchProfile() async* {
    try {
      await for (final snap in _profileRef().snapshots()) {
        final data = snap.data();
        yield data == null ? null : UserProfile.fromMap(data);
      }
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        yield await fallbackFoodDb.getProfileCached();
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    try {
      await _profileRef().set(profile.toMap(), SetOptions(merge: true));
      _profileFuture = null;
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        await fallbackFoodDb.upsertProfile(profile);
        _profileFuture = null;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<List<MealEntry>> listMealsCached() {
    _mealsFuture ??= _loadMeals();
    return _mealsFuture!;
  }

  Future<List<MealEntry>> _loadMeals() async {
    try {
      final snap =
          await _mealsCollectionRef().orderBy('date', descending: false).get();
      return snap.docs.map((doc) => MealEntry.fromMap(doc.data())).toList();
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        return fallbackFoodDb.listMealsCached();
      }
      rethrow;
    }
  }

  @override
  Stream<List<MealEntry>> watchMeals() async* {
    try {
      await for (final snap
          in _mealsCollectionRef()
              .orderBy('date', descending: false)
              .snapshots()) {
        yield snap.docs.map((doc) => MealEntry.fromMap(doc.data())).toList();
      }
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        yield await fallbackFoodDb.listMealsCached();
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> addMeal(MealEntry meal) async {
    try {
      await _mealsCollectionRef().add(meal.toMap());
      _mealsFuture = null;
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        await fallbackFoodDb.addMeal(meal);
        _mealsFuture = null;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> upsertMeal({
    required String mealId,
    required MealEntry meal,
  }) async {
    try {
      await _mealsCollectionRef()
          .doc(mealId)
          .set(meal.toMap(), SetOptions(merge: true));
      _mealsFuture = null;
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        await fallbackFoodDb.upsertMeal(mealId: mealId, meal: meal);
        _mealsFuture = null;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    try {
      await _mealsCollectionRef().doc(mealId).delete();
      _mealsFuture = null;
    } catch (error) {
      _handleError(error);
      if (_shouldFallback(error)) {
        await fallbackFoodDb.deleteMeal(mealId);
        _mealsFuture = null;
        return;
      }
      rethrow;
    }
  }

  @override
  List<FoodItem> foodDb(String query) {
    return fallbackFoodDb.foodDb(query);
  }
}

class InMemoryNutritionRepository implements NutritionRepository {
  UserProfile _profile = UserProfile(
    weightKg: 80,
    heightCm: 180,
    age: 30,
    sex: Sex.male,
  );

  final _meals = <String, MealEntry>{};

  final _db = <FoodItem>[
    FoodItem('Arroz (1 concha)', 110),
    FoodItem('Feijao (1 concha)', 90),
    FoodItem('Frango grelhado (100g)', 165),
    FoodItem('Ovo cozido (1 un)', 78),
    FoodItem('Salada verde (1 prato)', 35),
    FoodItem('Banana (1 un)', 95),
    FoodItem('Maca (1 un)', 80),
    FoodItem('Pao integral (1 fatia)', 70),
    FoodItem('Queijo minas (30g)', 85),
    FoodItem('Aveia (30g)', 115),
    FoodItem('Iogurte natural (170g)', 100),
  ];

  @override
  Future<UserProfile?> getProfileCached() async => _profile;

  @override
  Stream<UserProfile?> watchProfile() async* {
    yield _profile;
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<List<MealEntry>> listMealsCached() async {
    final meals = List<MealEntry>.from(_meals.values);
    meals.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(meals);
  }

  @override
  Stream<List<MealEntry>> watchMeals() async* {
    yield await listMealsCached();
  }

  @override
  Future<void> addMeal(MealEntry meal) async {
    _meals[DateTime.now().microsecondsSinceEpoch.toString()] = meal;
  }

  @override
  Future<void> upsertMeal({
    required String mealId,
    required MealEntry meal,
  }) async {
    _meals[mealId] = meal;
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    _meals.remove(mealId);
  }

  @override
  List<FoodItem> foodDb(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return List<FoodItem>.from(_db);
    return _db.where((food) => food.name.toLowerCase().contains(q)).toList();
  }
}
