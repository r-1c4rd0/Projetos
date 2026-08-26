import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.academyId,
    required this.emailNormalized,
    required this.role,
    required this.status,
    this.pendingProfileId,
  });

  final String id;
  final String academyId;
  final String emailNormalized;
  final String role;
  final String status;
  final String? pendingProfileId;

  factory PendingInvite.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return PendingInvite(
      id: doc.id,
      academyId: (data['academyId'] ?? '').toString(),
      emailNormalized: (data['emailNormalized'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      pendingProfileId: data['pendingProfileId']?.toString(),
    );
  }
}

class AcademyInvite {
  const AcademyInvite({
    required this.id,
    required this.academyId,
    required this.emailNormalized,
    required this.role,
    required this.status,
    this.pendingProfileId,
    this.acceptedAuthUid,
  });

  final String id;
  final String academyId;
  final String emailNormalized;
  final String role;
  final String status;
  final String? pendingProfileId;
  final String? acceptedAuthUid;

  factory AcademyInvite.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AcademyInvite(
      id: doc.id,
      academyId: (data['academyId'] ?? '').toString(),
      emailNormalized: (data['emailNormalized'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      pendingProfileId: data['pendingProfileId']?.toString(),
      acceptedAuthUid: data['acceptedAuthUid']?.toString(),
    );
  }
}

class InviteRepository {
  InviteRepository._(this.db, this.functions);
  InviteRepository(this.db, {FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore db;
  final FirebaseFunctions functions;

  static final InviteRepository instance = InviteRepository._(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  );

  String normalizeEmail(String email) => email.trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> _invitesRef(String academyId) {
    return db.collection('academies').doc(academyId).collection('invites');
  }

  Stream<PendingInvite?> watchPendingInviteForEmail({
    required String academyId,
    required String email,
  }) {
    final emailNormalized = normalizeEmail(email);
    if (emailNormalized.isEmpty) return Stream.value(null);

    return _invitesRef(academyId)
        .where('emailNormalized', isEqualTo: emailNormalized)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return PendingInvite.fromDoc(snap.docs.first);
        });
  }

  Stream<List<AcademyInvite>> watchAcademyInvites({required String academyId}) {
    return _invitesRef(
      academyId,
    ).snapshots().map((snap) => snap.docs.map(AcademyInvite.fromDoc).toList());
  }

  Future<bool> acceptInviteForCurrentUser({
    required String academyId,
    required String inviteId,
    required User firebaseUser,
  }) async {
    final authEmail = normalizeEmail(firebaseUser.email ?? '');
    if (firebaseUser.uid.trim().isEmpty || authEmail.isEmpty) return false;

    final callable = functions.httpsCallable('acceptAcademyInvite');
    await callable.call<void>({'academyId': academyId, 'inviteId': inviteId});
    return true;
  }
}
