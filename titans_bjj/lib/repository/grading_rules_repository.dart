import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/grading_rules.dart';

class GradingRulesRepository {
  const GradingRulesRepository(this.db);

  final FirebaseFirestore db;

  static final GradingRulesRepository instance =
      GradingRulesRepository(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
  }

  CollectionReference<Map<String, dynamic>> _collectionRef(String academyId) {
    return _academyRef(academyId).collection('grading_rules');
  }

  DocumentReference<Map<String, dynamic>> _rulesRef(
    String academyId, {
    String docId = 'default',
  }) {
    return _collectionRef(academyId).doc(docId);
  }

  Future<GradingRules?> get(
    String academyId, {
    String docId = 'default',
  }) async {
    final snap = await _rulesRef(academyId, docId: docId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return GradingRules.fromMap(data);
  }

  Stream<GradingRules?> watch(
    String academyId, {
    String docId = 'default',
  }) {
    return _rulesRef(academyId, docId: docId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return GradingRules.fromMap(data);
    });
  }

  Future<void> upsert(
    String academyId,
    GradingRules rules, {
    String docId = 'default',
  }) async {
    await _rulesRef(academyId, docId: docId).set(
      rules.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> delete(
    String academyId, {
    String docId = 'default',
  }) async {
    await _rulesRef(academyId, docId: docId).delete();
  }

  Future<void> ensureDefault(String academyId) async {
    final ref = _rulesRef(academyId);
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

    await upsert(academyId, rules);
  }
}
