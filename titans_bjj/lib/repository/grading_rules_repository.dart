import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/grading_rules.dart';

class GradingRulesRepository {
  final FirebaseFirestore db;
  const GradingRulesRepository(this.db);

  DocumentReference<Map<String, dynamic>> _ref(String academyId) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('grading_rules')
        .doc('default');
  }

  Stream<GradingRules?> watch(String academyId) {
    return _ref(academyId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return GradingRules.fromMap(data);
    });
  }

  Future<void> ensureDefault(String academyId) async {
    final ref = _ref(academyId);
    final snap = await ref.get();
    if (snap.exists) return;

    final rules = GradingRules(
      beltOrder: const [
        BeltColor.white,
        BeltColor.blue,
        BeltColor.purple,
        BeltColor.brown,
        BeltColor.black,
      ],
      sessionsRequiredByBelt: const {
        BeltColor.white: 200,
        BeltColor.blue: 400,
        BeltColor.purple: 600,
        BeltColor.brown: 800,
        BeltColor.black: 1280,
      },
      maxDegreesByBelt: const {
        BeltColor.white: 4,
        BeltColor.blue: 4,
        BeltColor.purple: 4,
        BeltColor.brown: 4,
        BeltColor.black: 6,
      },
      onlyAcademyPlace: false,
    );

    await ref.set(rules.toMap());
  }
}
