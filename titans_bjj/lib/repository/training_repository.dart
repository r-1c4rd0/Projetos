import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/training_session.dart';

class TrainingRepository {
  final FirebaseFirestore _db;
  TrainingRepository(this._db);

  CollectionReference<Map<String, dynamic>> _col({
    required String academyId,
    required String uid,
  }) {
    return _db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('training_sessions');
  }

  Stream<List<TrainingSession>> watchSessions({
    required String academyId,
    required String uid,
  }) {
    return _col(academyId: academyId, uid: uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map((q) => q.docs.map((d) => TrainingSession.fromDoc(d.id, d.data())).toList());

  }

  Future<void> addSession({
    required String academyId,
    required String uid,
    required TrainingSession session,
  }) async {
    await _col(academyId: academyId, uid: uid)
        .doc(session.id)
        .set(session.toMap(), SetOptions(merge: true));
  }

  Future<void> addSessionsBatch({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
  }) async {
    if (sessions.isEmpty) return;

    final batch = _db.batch();
    final col = _col(academyId: academyId, uid: uid);

    for (final s in sessions) {
      batch.set(col.doc(s.id), s.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deleteSession({
    required String academyId,
    required String uid,
    required String sessionId,
  }) async {
    await _col(academyId: academyId, uid: uid).doc(sessionId).delete();
  }
}



