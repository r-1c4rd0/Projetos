import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/app_user.dart';
import '../model/grading_rules.dart';

class UserRepository {
  /// Named private constructor used by [instance].
  UserRepository._(this.db);

  /// Public constructor so screens can instantiate directly:
  ///   `UserRepository(FirebaseFirestore.instance)`
  UserRepository(this.db);

  final FirebaseFirestore db;

  static final UserRepository instance = UserRepository._(FirebaseFirestore.instance);

  // ────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return db.collection('academies').doc(academyId).collection('users').doc(uid);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────────────

  /// Reads and returns an [AppUser], or `null` if the document doesn't exist.
  Future<AppUser?> getUser({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _userRef(academyId: academyId, uid: uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return AppUser.fromMap(uid, data);
  }

  /// Writes (merge) an arbitrary [payload] to the user document.
  /// Used by signup_screen to persist name, role, belt, etc.
  Future<void> upsertUser({
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

  /// Ensures a default user doc exists; creates one with role=athlete if absent.
  /// Returns the (possibly newly created) [AppUser].
  Future<AppUser> ensureUserDoc({
    required String uid,
    required String email,
    required String academyId,
  }) async {
    final ref = _userRef(academyId: academyId, uid: uid);

    final snap = await ref.get();
    if (!snap.exists) {
      // MVP: default athlete
      // Você pode promover mestre manualmente no Firestore (role=professor/admin)
      await ref.set({
        'email': email,
        'academyId': academyId,
        'role': UserRole.athlete.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // bootstrap docs que suas telas esperam
      await ensureBootstrapDocs(academyId: academyId, uid: uid);
    } else {
      // garante campos essenciais e não "quebra" role existente
      final data = snap.data() ?? {};
      final roleStr = (data['role'] ?? UserRole.athlete.name) as String;

      await ref.set({
        'email': email,
        'academyId': academyId,
        'role': roleStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await ensureBootstrapDocs(academyId: academyId, uid: uid);
    }

    final fresh = await ref.get();
    final data = fresh.data() ?? {};
    return AppUser.fromMap(uid, data);
  }

  /// Creates the default Firestore sub-documents (progress/profile,
  /// nutrition/profile) that the app screens expect.
  ///
  /// Also accepts optional [belt] and [degree] so that signup_screen can
  /// seed progress data at registration time.
  Future<void> ensureBootstrapDocs({
    required String academyId,
    required String uid,
    BeltColor? belt,
    int? degree,
  }) async {
    final batch = db.batch();

    // progress/profile
    final progressProfile = db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('profile');

    batch.set(progressProfile, {
      'currentBelt': belt?.name ?? 'white',
      'currentDegree': degree ?? 0,
      'beltStartAt': FieldValue.serverTimestamp(),
      'estimatedSessionsInBelt': 40,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // nutrition/profile
    final nutritionProfile = db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('nutrition')
        .doc('profile');

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
