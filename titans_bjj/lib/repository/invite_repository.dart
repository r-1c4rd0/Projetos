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

  factory AcademyInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
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

  Future<AcademyInvite?> findInviteForStudent({
    required String academyId,
    required String pendingProfileId,
    required String email,
    List<String> statuses = const ['pending', 'accepted', 'expired', 'revoked'],
  }) async {
    final profileId = pendingProfileId.trim();
    final emailNormalized = normalizeEmail(email);
    if (profileId.isEmpty && emailNormalized.isEmpty) return null;

    final byProfile =
        profileId.isEmpty
            ? null
            : await _invitesRef(academyId)
                .where('pendingProfileId', isEqualTo: profileId)
                .where('status', whereIn: statuses)
                .limit(1)
                .get();
    if (byProfile != null && byProfile.docs.isNotEmpty) {
      return AcademyInvite.fromDoc(byProfile.docs.first);
    }

    if (emailNormalized.isEmpty) return null;
    final byEmail =
        await _invitesRef(academyId)
            .where('emailNormalized', isEqualTo: emailNormalized)
            .where('status', whereIn: statuses)
            .limit(1)
            .get();
    if (byEmail.docs.isEmpty) return null;
    return AcademyInvite.fromDoc(byEmail.docs.first);
  }

  Future<AcademyInvite> createInviteForStudent({
    required String academyId,
    required String email,
    required String role,
    required String pendingProfileId,
    required String invitedByUid,
    required String invitedByRole,
    Duration ttl = const Duration(days: 14),
  }) async {
    final emailNormalized = normalizeEmail(email);
    final profileId = pendingProfileId.trim();
    if (emailNormalized.isEmpty) {
      throw StateError('Aluno sem e-mail para convite.');
    }
    if (profileId.isEmpty) {
      throw StateError('Aluno sem perfil pendente para convite.');
    }

    final existing = await findInviteForStudent(
      academyId: academyId,
      pendingProfileId: profileId,
      email: emailNormalized,
      statuses: const ['pending', 'accepted'],
    );
    if (existing != null) return existing;

    final doc = _invitesRef(academyId).doc();
    await doc.set({
      'academyId': academyId,
      'emailNormalized': emailNormalized,
      'role': role,
      'status': 'pending',
      'invitedByUid': invitedByUid,
      'invitedByRole': invitedByRole,
      'pendingProfileId': profileId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(ttl)),
      'lastSentAt': FieldValue.serverTimestamp(),
    });

    final snap = await doc.get();
    return AcademyInvite.fromDoc(snap);
  }

  Future<void> resendInvite({
    required String academyId,
    required String inviteId,
    Duration ttl = const Duration(days: 14),
  }) async {
    final ref = _invitesRef(academyId).doc(inviteId);
    await db.runTransaction<void>((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data();
      final status = data?['status']?.toString();
      if (!snap.exists || (status != 'pending' && status != 'expired')) {
        throw StateError('Convite nao pode ser reenviado neste status.');
      }
      transaction.update(ref, {
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(ttl)),
        'lastSentAt': FieldValue.serverTimestamp(),
        'revokedAt': FieldValue.delete(),
      });
    });
  }

  Future<void> revokeInvite({
    required String academyId,
    required String inviteId,
  }) async {
    final ref = _invitesRef(academyId).doc(inviteId);
    await db.runTransaction<void>((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data();
      if (!snap.exists || data?['status']?.toString() != 'pending') {
        throw StateError('Apenas convite pendente pode ser revogado.');
      }
      transaction.update(ref, {
        'status': 'revoked',
        'revokedAt': FieldValue.serverTimestamp(),
      });
    });
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
