import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/app_user.dart';
import '../model/grading_rules.dart';

class UserRepository {
  UserRepository._(this.db);
  UserRepository(this.db);

  final FirebaseFirestore db;

  static final UserRepository instance =
      UserRepository._(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    final resolvedAcademyId = academyId.trim();
    if (resolvedAcademyId.isEmpty) {
      throw ArgumentError.value(academyId, 'academyId', 'nao pode ser vazio');
    }
    return db.collection('academies').doc(resolvedAcademyId);
  }

  CollectionReference<Map<String, dynamic>> _usersCollectionRef(
    String academyId,
  ) {
    return _academyRef(academyId).collection('users');
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return _usersCollectionRef(academyId).doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _progressProfileRef({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid)
        .collection('progress')
        .doc('profile');
  }

  DocumentReference<Map<String, dynamic>> _nutritionProfileRef({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid)
        .collection('nutrition')
        .doc('profile');
  }

  Future<AppUser?> getUser({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _userRef(academyId: academyId, uid: uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return AppUser.fromMap(uid, data);
  }

  Stream<AppUser?> watchUser({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return AppUser.fromMap(uid, data);
    });
  }

  Future<void> upsertUser({
    required String academyId,
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    final ref = _userRef(academyId: academyId, uid: uid);
    final snap = await ref.get();
    final data = {
      ...payload,
      'academyId': academyId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists && !payload.containsKey('createdAt'))
        'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> updateBeltDegree({
    required String academyId,
    required String uid,
    BeltColor? belt,
    int? degree,
  }) async {
    if (belt == null && degree == null) return;

    final maxDegree =
        belt == null ? 12 : GradingRules.fallbackMaxDegrees(belt);
    final payload = <String, dynamic>{
      if (belt != null) 'belt': belt.name,
      if (degree != null) 'degree': degree.clamp(0, maxDegree).toInt(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userRef(academyId: academyId, uid: uid).set(
      payload,
      SetOptions(merge: true),
    );
  }

  Future<void> deleteUser({
    required String academyId,
    required String uid,
  }) async {
    await _userRef(academyId: academyId, uid: uid).delete();
  }

  Future<AppUser> ensureUserDoc({
    required String uid,
    required String email,
    required String academyId,
  }) async {
    final ref = _userRef(academyId: academyId, uid: uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // MVP: new users start as athlete. Promote professor/admin manually in Firestore.
      await ref.set({
        'email': email,
        'academyId': academyId,
        'role': UserRole.athlete.name,
        'belt': BeltColor.white.name,
        'degree': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = snap.data() ?? {};
      final roleStr = (data['role'] ?? UserRole.athlete.name).toString();

      await ref.set({
        'email': email,
        'academyId': academyId,
        'role': roleStr,
        if (!data.containsKey('belt')) 'belt': BeltColor.white.name,
        if (!data.containsKey('degree')) 'degree': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await ensureBootstrapDocs(academyId: academyId, uid: uid);

    final fresh = await ref.get();
    return AppUser.fromMap(uid, fresh.data() ?? {});
  }

  Future<void> ensureBootstrapDocs({
    required String academyId,
    required String uid,
    BeltColor? belt,
    int? degree,
  }) async {
    final batch = db.batch();

    final progressProfile = _progressProfileRef(
      academyId: academyId,
      uid: uid,
    );
    batch.set(progressProfile, {
      'currentBelt': belt?.name ?? 'white',
      'currentDegree': degree ?? 0,
      'beltStartAt': FieldValue.serverTimestamp(),
      'estimatedSessionsInBelt': 40,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final nutritionProfile = _nutritionProfileRef(
      academyId: academyId,
      uid: uid,
    );
    batch.set(nutritionProfile, {
      'age': 30,
      'sex': 'male',
      'weightKg': 80.0,
      'heightCm': 180.0,
      'activityFactor': 1.375,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
