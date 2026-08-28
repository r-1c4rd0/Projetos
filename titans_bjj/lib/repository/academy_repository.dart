import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/academy_models.dart';

class AcademyRepository {
  AcademyRepository._(this.db);
  AcademyRepository(this.db);

  final FirebaseFirestore db;

  static final AcademyRepository instance = AcademyRepository._(
    FirebaseFirestore.instance,
  );

  Future<AcademyProfile> getAcademy(String academyId) async {
    final resolvedAcademyId = academyId.trim();
    if (resolvedAcademyId.isEmpty) {
      throw ArgumentError.value(academyId, 'academyId', 'não pode ser vazio');
    }

    final snap = await db.collection('academies').doc(resolvedAcademyId).get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      return AcademyProfile(name: resolvedAcademyId);
    }

    return AcademyProfile.fromMap(resolvedAcademyId, data);
  }
}
