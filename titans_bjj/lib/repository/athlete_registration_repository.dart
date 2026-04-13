import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../model/grading_rules.dart';
import 'user_repository.dart';

/// Single source of truth for athlete sign-up logic.
class AthleteRegistrationRepository {
  AthleteRegistrationRepository(this.db) : _userRepository = UserRepository(db);

  final FirebaseFirestore db;
  final UserRepository _userRepository;
  final Uuid _uuid = const Uuid();

  /// Persists the athlete profile and boots the progress/nutrition docs.
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

    await _userRepository.upsertUser(
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
