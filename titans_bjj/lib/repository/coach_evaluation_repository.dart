import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/coach_evaluation.dart';

class CoachEvaluationRepository {
  CoachEvaluationRepository._(this._db);
  CoachEvaluationRepository(this._db);

  final FirebaseFirestore _db;

  static final CoachEvaluationRepository instance = CoachEvaluationRepository._(
    FirebaseFirestore.instance,
  );

  CollectionReference<Map<String, dynamic>> _collectionRef({
    required String academyId,
    required String athleteUid,
  }) {
    return _db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(athleteUid)
        .collection('coach_evaluations');
  }

  Stream<List<CoachEvaluation>> watchEvaluations({
    required String academyId,
    required String athleteUid,
  }) {
    return _collectionRef(academyId: academyId, athleteUid: athleteUid)
        .orderBy('evaluatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => CoachEvaluation.fromDoc(doc.id, doc.data()))
                  .toList(),
        );
  }

  Future<void> upsertEvaluation(CoachEvaluation evaluation) {
    final docId = _docSafe(evaluation.skillId);
    return _collectionRef(
          academyId: evaluation.academyId,
          athleteUid: evaluation.athleteUid,
        )
        .doc(docId)
        .set(
          evaluation.toMap(evaluatedAtOverride: FieldValue.serverTimestamp()),
          SetOptions(merge: true),
        );
  }

  String _docSafe(String value) {
    return value.trim().replaceAll('/', '_');
  }
}
