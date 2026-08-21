import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../model/grading_rules.dart';
import 'user_repository.dart';

/// Single source of truth for athlete sign-up logic.
class AthleteRegistrationRepository {
  AthleteRegistrationRepository(this.db) : _userRepository = UserRepository(db);

  final FirebaseFirestore db;
  final UserRepository _userRepository;
  final Uuid _uuid = const Uuid();

  static final AthleteRegistrationRepository instance =
      AthleteRegistrationRepository(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
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

  Future<Map<String, dynamic>?> getAthlete({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _userRef(academyId: academyId, uid: uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return data;
  }

  Stream<Map<String, dynamic>?> watchAthlete({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return data;
    });
  }

  Future<void> upsertAthletePayload({
    required String academyId,
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    await _userRef(academyId: academyId, uid: uid).set(
      {
        ...payload,
        'academyId': academyId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteAthlete({
    required String academyId,
    required String uid,
  }) async {
    await _userRef(academyId: academyId, uid: uid).delete();
  }

  Future<void> updateAthlete({
    required String academyId,
    required String uid,
    required String name,
    String? email,
    String? phone,
    required BeltColor belt,
    required int degree,
    double? weightKg,
    double? heightCm,
    String? sex,
    DateTime? birthDate,
    String? notes,
  }) async {
    final existing = await getAthlete(academyId: academyId, uid: uid);
    final existingRole = existing?['role']?.toString();
    final role = existingRole == 'admin' || existingRole == 'professor'
        ? existingRole
        : 'athlete';

    final payload = <String, dynamic>{
      'name': name,
      'role': role,
      'belt': belt.name,
      'degree': degree,
      'sex': sex ?? 'male',
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (weightKg != null) 'weightKg': weightKg,
      if (heightCm != null) 'heightCm': heightCm,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      if (notes != null) 'notes': notes,
    };

    debugPrint(
      '[ATHLETE_REPO_UPDATE] path=academies/$academyId/users/$uid '
      'payload=$payload',
    );

    try {
      await upsertAthletePayload(
        academyId: academyId,
        uid: uid,
        payload: payload,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        '[ATHLETE_REPO_UPDATE] FirebaseException '
        'code=${error.code} message=${error.message}',
      );
      rethrow;
    }

    try {
      await _userRepository.ensureBootstrapDocs(
        academyId: academyId,
        uid: uid,
        belt: belt,
        degree: degree,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        '[ATHLETE_REPO_UPDATE] FirebaseException bootstrap '
        'code=${error.code} message=${error.message}',
      );
      rethrow;
    }
  }

  Future<void> registerAthlete({
    required String academyId,
    required String name,
    String? email,
    String? phone,
    required BeltColor belt,
    required int degree,
    double? weightKg,
    double? heightCm,
    String? sex,
    DateTime? birthDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'role': 'athlete',
      'belt': belt.name,
      'degree': degree,
      'sex': sex ?? 'male',
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (weightKg != null) 'weightKg': weightKg,
      if (heightCm != null) 'heightCm': heightCm,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final uid = _uuid.v4();

    await upsertAthletePayload(
      academyId: academyId,
      uid: uid,
      payload: payload,
    );

    await _userRepository.ensureBootstrapDocs(
      academyId: academyId,
      uid: uid,
      belt: belt,
      degree: degree,
    );
  }
}
