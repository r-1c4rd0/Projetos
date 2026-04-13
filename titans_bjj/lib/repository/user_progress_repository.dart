import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_progress_profile.dart';
import '../model/grading_rules.dart';

class UserProgressRepository {
  final FirebaseFirestore db;
  const UserProgressRepository(this.db);

  DocumentReference<Map<String, dynamic>> _ref({
    required String academyId,
    required String uid,
  }) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('profile');
  }

  Stream<UserProgressProfile?> watch({
    required String academyId,
    required String uid,
  }) {
    return _ref(academyId: academyId, uid: uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return UserProgressProfile.fromMap(data);
    });
  }

  Future<void> ensureDefault({
    required String academyId,
    required String uid,
  }) async {
    final ref = _ref(academyId: academyId, uid: uid);
    final snap = await ref.get();
    if (snap.exists) return;

    // Default: Branca 2 graus, start 28/04/2025 (ajuste se quiser)
    final profile = UserProgressProfile(
      currentBelt: BeltColor.white,
      currentDegree: 2,
      beltStartAt: DateTime(2025, 4, 28),
    );

    await ref.set(profile.toMap());
  }

  Future<void> save({
    required String academyId,
    required String uid,
    required UserProgressProfile profile,
  }) async {
    await _ref(academyId: academyId, uid: uid).set(profile.toMap());
  }
}
