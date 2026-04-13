import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/nutrition_models.dart';

class NutritionRepository {
  final FirebaseFirestore db;
  const NutritionRepository(this.db);

  DocumentReference<Map<String, dynamic>> _profileRef({
    required String academyId,
    required String uid,
  }) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('nutrition')
        .doc('profile');
  }

  CollectionReference<Map<String, dynamic>> _mealsRef({
    required String academyId,
    required String uid,
  }) {
    // ✅ collection() em DocumentReference -> OK
    return _profileRef(academyId: academyId, uid: uid).collection('meals');
  }

  Future<UserProfile?> getProfile({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _profileRef(academyId: academyId, uid: uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<void> upsertProfile({
    required String academyId,
    required String uid,
    required UserProfile profile,
  }) async {
    await _profileRef(academyId: academyId, uid: uid).set(
      profile.toMap(),
      SetOptions(merge: true),
    );
  }

  Stream<List<MealEntry>> watchMeals({
    required String academyId,
    required String uid,
  }) {
    return _mealsRef(academyId: academyId, uid: uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map((q) {
      return q.docs.map((d) => MealEntry.fromMap(d.data())).toList();
    });
  }

  Future<void> addMeal({
    required String academyId,
    required String uid,
    required MealEntry meal,
  }) async {
    await _mealsRef(academyId: academyId, uid: uid).add(meal.toMap());
  }
}
