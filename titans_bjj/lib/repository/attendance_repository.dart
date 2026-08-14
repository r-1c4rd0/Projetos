import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/attendance_models.dart';
import '../model/grading_rules.dart';
import '../model/training_session.dart';
import 'training_repository.dart';

class AttendanceRepository {
  AttendanceRepository._(FirebaseFirestore db)
      : _db = db,
        _trainingRepository = TrainingRepository(db);

  AttendanceRepository(
    FirebaseFirestore db, {
    TrainingRepository? trainingRepository,
  })  : _db = db,
        _trainingRepository = trainingRepository ?? TrainingRepository(db);

  final FirebaseFirestore _db;
  final TrainingRepository _trainingRepository;

  static final AttendanceRepository instance =
      AttendanceRepository._(FirebaseFirestore.instance);

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return _db.collection('academies').doc(_requiredId(academyId, 'academyId'));
  }

  String _requiredId(String value, String name) {
    final resolvedValue = value.trim();
    if (resolvedValue.isEmpty) {
      throw ArgumentError.value(value, name, 'nao pode ser vazio');
    }

    return resolvedValue;
  }

  CollectionReference<Map<String, dynamic>> _sessionsCollectionRef({
    required String academyId,
  }) {
    return _academyRef(academyId).collection('attendance_sessions');
  }

  DocumentReference<Map<String, dynamic>> _sessionRef({
    required String academyId,
    required String sessionId,
  }) {
    return _sessionsCollectionRef(
      academyId: academyId,
    ).doc(_requiredId(sessionId, 'sessionId'));
  }

  CollectionReference<Map<String, dynamic>> _checkInsCollectionRef({
    required String academyId,
    required String sessionId,
  }) {
    return _sessionRef(academyId: academyId, sessionId: sessionId)
        .collection('checkins');
  }

  DocumentReference<Map<String, dynamic>> _checkInRef({
    required String academyId,
    required String sessionId,
    required String uid,
  }) {
    return _checkInsCollectionRef(
      academyId: academyId,
      sessionId: sessionId,
    ).doc(_requiredId(uid, 'uid'));
  }

  Future<String> createSession({
    required String academyId,
    required String title,
    required String classType,
    required String instructorUid,
    required String instructorName,
    required DateTime startsAt,
    required DateTime endsAt,
    AttendanceSessionStatus status = AttendanceSessionStatus.open,
  }) async {
    final resolvedAcademyId = _requiredId(academyId, 'academyId');
    final ref = _sessionsCollectionRef(academyId: resolvedAcademyId).doc();

    await ref.set({
      'id': ref.id,
      'academyId': resolvedAcademyId,
      'title': title.trim(),
      'classType': classType.trim(),
      'instructorUid': instructorUid.trim(),
      'instructorName': instructorName.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Stream<List<AttendanceSession>> watchSessions({
    required String academyId,
    AttendanceSessionStatus? status,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _sessionsCollectionRef(
      academyId: academyId,
    ).orderBy('startsAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
          (snap) => snap.docs
              .map((doc) => AttendanceSession.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<AttendanceCheckIn>> watchSessionCheckIns({
    required String academyId,
    required String sessionId,
  }) {
    return _checkInsCollectionRef(
      academyId: academyId,
      sessionId: sessionId,
    ).orderBy('checkedInAt', descending: false).snapshots().map(
          (snap) => snap.docs
              .map((doc) => AttendanceCheckIn.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addManualCheckIn({
    required String academyId,
    required String sessionId,
    required String uid,
    required String studentName,
    required BeltColor belt,
    required int degree,
    required String createdByUid,
  }) async {
    final resolvedAcademyId = _requiredId(academyId, 'academyId');
    final resolvedSessionId = _requiredId(sessionId, 'sessionId');
    final resolvedUid = _requiredId(uid, 'uid');
    final resolvedCreatedByUid = _requiredId(createdByUid, 'createdByUid');

    final sessionSnap = await _sessionRef(
      academyId: resolvedAcademyId,
      sessionId: resolvedSessionId,
    ).get();
    final sessionData = sessionSnap.data();
    if (!sessionSnap.exists || sessionData == null) {
      throw StateError('Sessao de presenca nao encontrada.');
    }

    final attendanceSession = AttendanceSession.fromDoc(
      sessionSnap.id,
      sessionData,
    );
    if (attendanceSession.status != AttendanceSessionStatus.open) {
      throw StateError('Check-in permitido somente em sessao aberta.');
    }

    final trainingSessionId = _trainingRepository.attendanceLinkedSessionId(
      attendanceSessionId: resolvedSessionId,
      attendanceCheckInUid: resolvedUid,
    );

    final trainingSession = TrainingSession(
      id: trainingSessionId,
      date: attendanceSession.startsAt,
      place: TrainingPlace.academy,
      notes: _attendanceTrainingNotes(attendanceSession),
      academyId: resolvedAcademyId,
      uid: resolvedUid,
      source: 'attendance',
      attendanceSessionId: resolvedSessionId,
      attendanceCheckInUid: resolvedUid,
      classType: attendanceSession.classType,
      instructorUid: attendanceSession.instructorUid,
      instructorName: attendanceSession.instructorName,
    );

    final batch = _db.batch();
    batch.set(
      _checkInRef(
        academyId: resolvedAcademyId,
        sessionId: resolvedSessionId,
        uid: resolvedUid,
      ),
      {
        'uid': resolvedUid,
        'studentName': studentName.trim(),
        'belt': belt.name,
        'degree': degree.clamp(0, 12).toInt(),
        'source': AttendanceCheckInSource.manual.name,
        'checkedInAt': FieldValue.serverTimestamp(),
        'createdByUid': resolvedCreatedByUid,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    _trainingRepository.setAttendanceDerivedSessionInBatch(
      batch: batch,
      academyId: resolvedAcademyId,
      uid: resolvedUid,
      session: trainingSession,
    );

    await batch.commit();
  }

  Future<void> removeCheckIn({
    required String academyId,
    required String sessionId,
    required String uid,
  }) async {
    final resolvedAcademyId = _requiredId(academyId, 'academyId');
    final resolvedSessionId = _requiredId(sessionId, 'sessionId');
    final resolvedUid = _requiredId(uid, 'uid');

    final batch = _db.batch();
    batch.delete(
      _checkInRef(
        academyId: resolvedAcademyId,
        sessionId: resolvedSessionId,
        uid: resolvedUid,
      ),
    );

    _trainingRepository.deleteAttendanceDerivedSessionInBatch(
      batch: batch,
      academyId: resolvedAcademyId,
      uid: resolvedUid,
      attendanceSessionId: resolvedSessionId,
      attendanceCheckInUid: resolvedUid,
    );

    await batch.commit();
  }

  Future<void> closeSession({
    required String academyId,
    required String sessionId,
  }) {
    return _updateSessionStatus(
      academyId: academyId,
      sessionId: sessionId,
      status: AttendanceSessionStatus.closed,
    );
  }

  Future<void> cancelSession({
    required String academyId,
    required String sessionId,
  }) {
    return _updateSessionStatus(
      academyId: academyId,
      sessionId: sessionId,
      status: AttendanceSessionStatus.cancelled,
    );
  }

  Future<void> _updateSessionStatus({
    required String academyId,
    required String sessionId,
    required AttendanceSessionStatus status,
  }) async {
    await _sessionRef(academyId: academyId, sessionId: sessionId).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _attendanceTrainingNotes(AttendanceSession session) {
    final instructor = session.instructorName.trim().isEmpty
        ? session.instructorUid.trim()
        : session.instructorName.trim();
    final title = session.title.trim().isEmpty ? 'Aula' : session.title.trim();
    final classType = session.classType.trim().isEmpty
        ? 'Treino'
        : session.classType.trim();

    return 'Presenca confirmada: $title - $classType. Instrutor: $instructor.';
  }
}