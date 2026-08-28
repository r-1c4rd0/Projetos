import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../model/grading_rules.dart';

class StudentPermissionDeniedException implements Exception {
  const StudentPermissionDeniedException();

  static const message =
      'Sem permissão para listar alunos. Ajuste Firestore Rules para professor/admin.';

  @override
  String toString() => message;
}

class StudentVm {
  final String uid;
  final String name;
  final String role;
  final String academyId;
  final BeltColor belt;
  final int degree;
  final bool hasAuthLink;
  final String? migratedFromPendingProfileId;

  const StudentVm({
    required this.uid,
    required this.name,
    required this.role,
    required this.academyId,
    required this.belt,
    required this.degree,
    this.hasAuthLink = false,
    this.migratedFromPendingProfileId,
  });

  factory StudentVm.fromMap(
    String uid,
    Map<String, dynamic> data, {
    required String academyId,
  }) {
    return StudentVm(
      uid: uid,
      name: (data['name'] ?? data['email'] ?? 'Aluno').toString(),
      role: (data['role'] ?? 'athlete').toString(),
      academyId: (data['academyId'] ?? academyId).toString(),
      belt: beltColorFromString(data['belt']),
      degree: _degreeFromValue(data['degree']),
      hasAuthLink: data['authLinkedAt'] != null,
      migratedFromPendingProfileId:
          data['migratedFromPendingProfileId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'academyId': academyId,
      'belt': belt.name,
      'degree': degree,
    };
  }

  StudentVm copyWith({
    String? uid,
    String? name,
    String? role,
    String? academyId,
    BeltColor? belt,
    int? degree,
    bool? hasAuthLink,
    String? migratedFromPendingProfileId,
  }) {
    return StudentVm(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      role: role ?? this.role,
      academyId: academyId ?? this.academyId,
      belt: belt ?? this.belt,
      degree: degree ?? this.degree,
      hasAuthLink: hasAuthLink ?? this.hasAuthLink,
      migratedFromPendingProfileId:
          migratedFromPendingProfileId ?? this.migratedFromPendingProfileId,
    );
  }

  static int _degreeFromValue(Object? value) {
    if (value is int) return value.clamp(0, 12).toInt();
    if (value is num) return value.toInt().clamp(0, 12).toInt();
    return (int.tryParse(value?.toString() ?? '') ?? 0).clamp(0, 12).toInt();
  }
}

abstract class IStudentRepository {
  Future<StudentVm?> getStudent({
    required String academyId,
    required String uid,
  });

  Future<List<StudentVm>> listStudents({required String academyId});

  Stream<List<StudentVm>> watchStudents({required String academyId});

  Future<void> upsertStudent(StudentVm student);

  Future<void> archiveStudent({
    required String academyId,
    required String uid,
    required String archivedByUid,
    required String archivedByRole,
  });

  Future<void> deleteStudent({required String academyId, required String uid});
}

class StudentRepository implements IStudentRepository {
  const StudentRepository(this.db);

  final FirebaseFirestore db;

  static IStudentRepository create({bool useMocks = AppConfig.useMocks}) {
    if (useMocks || AppConfig.useMocks) return InMemoryStudentRepository();
    return StudentRepository(FirebaseFirestore.instance);
  }

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
  }

  CollectionReference<Map<String, dynamic>> _collectionRef(String academyId) {
    return _academyRef(academyId).collection('users');
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return _collectionRef(academyId).doc(uid);
  }

  bool _isAthlete(Map<String, dynamic> data) {
    final role = data['role']?.toString();
    return role == null || role.isEmpty || role == 'athlete';
  }

  bool _isActive(Map<String, dynamic> data) {
    return data['isActive'] != false;
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  List<StudentVm> _studentsFromDocs(
    String academyId,
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final students =
        docs
            .where((doc) => _isAthlete(doc.data()) && _isActive(doc.data()))
            .map(
              (doc) =>
                  StudentVm.fromMap(doc.id, doc.data(), academyId: academyId),
            )
            .toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  @override
  Future<StudentVm?> getStudent({
    required String academyId,
    required String uid,
  }) async {
    try {
      final snap = await _userRef(academyId: academyId, uid: uid).get();
      final data = snap.data();
      if (!snap.exists ||
          data == null ||
          !_isAthlete(data) ||
          !_isActive(data)) {
        return null;
      }
      return StudentVm.fromMap(snap.id, data, academyId: academyId);
    } catch (error) {
      if (_isPermissionDenied(error)) {
        throw const StudentPermissionDeniedException();
      }
      rethrow;
    }
  }

  @override
  Future<List<StudentVm>> listStudents({required String academyId}) async {
    try {
      final snap = await _collectionRef(academyId).get();
      return _studentsFromDocs(academyId, snap.docs);
    } catch (error) {
      if (_isPermissionDenied(error)) {
        throw const StudentPermissionDeniedException();
      }
      rethrow;
    }
  }

  @override
  Stream<List<StudentVm>> watchStudents({required String academyId}) {
    return _collectionRef(academyId)
        .snapshots()
        .map((snap) => _studentsFromDocs(academyId, snap.docs))
        .handleError((Object error) {
          if (_isPermissionDenied(error)) {
            throw const StudentPermissionDeniedException();
          }
          throw error;
        });
  }

  @override
  Future<void> upsertStudent(StudentVm student) async {
    await _userRef(academyId: student.academyId, uid: student.uid).set({
      ...student.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> archiveStudent({
    required String academyId,
    required String uid,
    required String archivedByUid,
    required String archivedByRole,
  }) async {
    await _userRef(academyId: academyId, uid: uid).set({
      'academyId': academyId,
      'isActive': false,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedByUid': archivedByUid,
      'archivedByRole': archivedByRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteStudent({
    required String academyId,
    required String uid,
  }) async {
    throw UnsupportedError('Use archiveStudent para preservar dados.');
  }
}

class InMemoryStudentRepository implements IStudentRepository {
  // TODO multi-academy: substituir pelo academyId ativo quando mocks suportarem
  // selecao de academia.
  static String get _fallbackAcademyId => AppConfig.resolveActiveAcademyId();

  final Set<String> _archivedStudentIds = <String>{};

  late final List<StudentVm> _students = [
    StudentVm(
      uid: 'mock1',
      name: 'Marco "Caveira" Santos',
      role: 'athlete',
      academyId: _fallbackAcademyId,
      belt: BeltColor.black,
      degree: 2,
    ),
    StudentVm(
      uid: 'mock2',
      name: 'Luna Cyberfist',
      role: 'athlete',
      academyId: _fallbackAcademyId,
      belt: BeltColor.purple,
      degree: 3,
    ),
    StudentVm(
      uid: 'mock3',
      name: 'Renato "Blade" Silva',
      role: 'athlete',
      academyId: _fallbackAcademyId,
      belt: BeltColor.blue,
      degree: 1,
    ),
  ];

  @override
  Future<StudentVm?> getStudent({
    required String academyId,
    required String uid,
  }) async {
    for (final student in _students) {
      if (student.uid == uid && !_archivedStudentIds.contains(uid)) {
        return StudentVm(
          uid: student.uid,
          name: student.name,
          role: student.role,
          academyId: academyId,
          belt: student.belt,
          degree: student.degree,
        );
      }
    }
    return null;
  }

  @override
  Future<List<StudentVm>> listStudents({required String academyId}) async {
    final students =
        _students
            .where((student) => !_archivedStudentIds.contains(student.uid))
            .map(
              (student) => StudentVm(
                uid: student.uid,
                name: student.name,
                role: student.role,
                academyId: academyId,
                belt: student.belt,
                degree: student.degree,
              ),
            )
            .toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  @override
  Stream<List<StudentVm>> watchStudents({required String academyId}) async* {
    yield await listStudents(academyId: academyId);
  }

  @override
  Future<void> upsertStudent(StudentVm student) async {}

  @override
  Future<void> archiveStudent({
    required String academyId,
    required String uid,
    required String archivedByUid,
    required String archivedByRole,
  }) async {
    _archivedStudentIds.add(uid);
  }

  @override
  Future<void> deleteStudent({
    required String academyId,
    required String uid,
  }) async {
    throw UnsupportedError('Use archiveStudent para preservar dados.');
  }
}
