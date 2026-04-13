import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

class StudentVm {
  final String uid;
  final String name;
  final String role; // athlete/master
  final String academyId;

  StudentVm({
    required this.uid,
    required this.name,
    required this.role,
    required this.academyId,
  });

  factory StudentVm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudentVm(
      uid: doc.id,
      name: (data['name'] ?? data['email'] ?? 'Aluno').toString(),
      role: (data['role'] ?? 'athlete').toString(),
      academyId: (data['academyId'] ?? 'default').toString(),
    );
  }
}

class StudentRepository {
  final FirebaseFirestore db;
  const StudentRepository(this.db);

  Stream<List<StudentVm>> watchStudents({
    required String academyId,
  }) {
    if (AppConfig.useMocks) {
      return Stream.value([
        StudentVm(uid: 'mock1', name: 'Marco "Caveira" Santos', role: 'athlete', academyId: academyId),
        StudentVm(uid: 'mock2', name: 'Luna Cyberfist', role: 'athlete', academyId: academyId),
        StudentVm(uid: 'mock3', name: 'Renato "Blade" Silva', role: 'athlete', academyId: academyId),
      ]);
    }

    return db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .where('role', isEqualTo: 'athlete')
        .snapshots()
        .map((q) => q.docs.map(StudentVm.fromDoc).toList());
  }
}
