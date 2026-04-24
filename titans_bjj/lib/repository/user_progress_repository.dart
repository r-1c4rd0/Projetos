import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/grading_rules.dart';
import '../model/user_progress_profile.dart';

class UserProgressRepository {
  const UserProgressRepository(this.db);

  final FirebaseFirestore db;

  static final UserProgressRepository instance =
      UserProgressRepository(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return _academyRef(academyId).collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _profileRef({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid)
        .collection('progress')
        .doc('profile');
  }

  Future<UserProgressProfile?> getProfile({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _profileRef(academyId: academyId, uid: uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return UserProgressProfile.fromMap(data);
  }

  Stream<UserProgressProfile?> watch({
    required String academyId,
    required String uid,
  }) {
    return watchProfile(academyId: academyId, uid: uid);
  }

  Stream<UserProgressProfile?> watchProfile({
    required String academyId,
    required String uid,
  }) {
    return _profileRef(academyId: academyId, uid: uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return UserProgressProfile.fromMap(data);
    });
  }

  Future<void> ensureDefault({
    required String academyId,
    required String uid,
  }) async {
    final ref = _profileRef(academyId: academyId, uid: uid);
    final snap = await ref.get();
    if (snap.exists) return;

    // Default: Branca 2 graus, start 28/04/2025 (ajuste se quiser)
    final profile = UserProgressProfile(
      currentBelt: BeltColor.white,
      currentDegree: 2,
      beltStartAt: DateTime(2025, 4, 28),
    );

    await upsertProfile(academyId: academyId, uid: uid, profile: profile);
  }

  Future<void> upsertProfile({
    required String academyId,
    required String uid,
    required UserProgressProfile profile,
  }) async {
    await _profileRef(academyId: academyId, uid: uid).set(
      profile.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> save({
    required String academyId,
    required String uid,
    required UserProgressProfile profile,
  }) {
    return upsertProfile(academyId: academyId, uid: uid, profile: profile);
  }

  Future<void> deleteProfile({
    required String academyId,
    required String uid,
  }) async {
    await _profileRef(academyId: academyId, uid: uid).delete();
  }
}
