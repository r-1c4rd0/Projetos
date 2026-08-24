import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/training_session.dart';

class TrainingRepository {
  TrainingRepository._(this._db);
  TrainingRepository(this._db);

  final FirebaseFirestore _db;

  static final TrainingRepository instance =
      TrainingRepository._(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return _db.collection('academies').doc(academyId);
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return _academyRef(academyId).collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _collectionRef({
    required String academyId,
    required String uid,
  }) {
    return _userRef(academyId: academyId, uid: uid)
        .collection('training_sessions');
  }

  DocumentReference<Map<String, dynamic>> _sessionRef({
    required String academyId,
    required String uid,
    required String sessionId,
  }) {
    return _collectionRef(academyId: academyId, uid: uid).doc(sessionId);
  }

  String attendanceLinkedSessionId({
    required String attendanceSessionId,
    required String attendanceCheckInUid,
  }) {
    return 'attendance_${_docSafe(attendanceSessionId)}_${_docSafe(attendanceCheckInUid)}';
  }

  void setAttendanceDerivedSessionInBatch({
    required WriteBatch batch,
    required String academyId,
    required String uid,
    required TrainingSession session,
  }) {
    batch.set(
      _sessionRef(
        academyId: academyId,
        uid: uid,
        sessionId: session.id,
      ),
      session.toMap(),
      SetOptions(merge: true),
    );
  }

  void deleteAttendanceDerivedSessionInBatch({
    required WriteBatch batch,
    required String academyId,
    required String uid,
    required String attendanceSessionId,
    required String attendanceCheckInUid,
  }) {
    batch.delete(
      _sessionRef(
        academyId: academyId,
        uid: uid,
        sessionId: attendanceLinkedSessionId(
          attendanceSessionId: attendanceSessionId,
          attendanceCheckInUid: attendanceCheckInUid,
        ),
      ),
    );
  }

  Future<TrainingSession?> getSession({
    required String academyId,
    required String uid,
    required String sessionId,
  }) async {
    final snap = await _sessionRef(
      academyId: academyId,
      uid: uid,
      sessionId: sessionId,
    ).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return TrainingSession.fromDoc(snap.id, data);
  }

  Future<List<TrainingSession>> listSessions({
    required String academyId,
    required String uid,
  }) async {
    final snap = await _collectionRef(academyId: academyId, uid: uid)
        .orderBy('date', descending: false)
        .get();
    return snap.docs
        .map((doc) => TrainingSession.fromDoc(doc.id, doc.data()))
        .toList();
  }

  Stream<List<TrainingSession>> watchSessions({
    required String academyId,
    required String uid,
  }) {
    return _collectionRef(academyId: academyId, uid: uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => TrainingSession.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> upsertSession({
    required String academyId,
    required String uid,
    required TrainingSession session,
  }) async {
    await _sessionRef(
      academyId: academyId,
      uid: uid,
      sessionId: session.id,
    ).set(
      session.toMap(includeApplicationDeletes: true),
      SetOptions(merge: true),
    );
  }

  Future<void> addSession({
    required String academyId,
    required String uid,
    required TrainingSession session,
  }) {
    return upsertSession(academyId: academyId, uid: uid, session: session);
  }

  Future<void> upsertSessionsBatch({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
  }) async {
    if (sessions.isEmpty) return;

    final batch = _db.batch();
    final col = _collectionRef(academyId: academyId, uid: uid);

    for (final session in sessions) {
      batch.set(
        session.id.isEmpty ? col.doc() : col.doc(session.id),
        session.toMap(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> addSessionsBatch({
    required String academyId,
    required String uid,
    required List<TrainingSession> sessions,
  }) {
    return upsertSessionsBatch(
      academyId: academyId,
      uid: uid,
      sessions: sessions,
    );
  }

  Future<void> deleteSession({
    required String academyId,
    required String uid,
    required String sessionId,
  }) async {
    await _sessionRef(
      academyId: academyId,
      uid: uid,
      sessionId: sessionId,
    ).delete();
  }

  String _docSafe(String value) {
    return value.trim().replaceAll('/', '_');
  }
}
