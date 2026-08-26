import 'package:cloud_firestore/cloud_firestore.dart';
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

class InviteRepository {
  InviteRepository._(this.db);
  InviteRepository(this.db);

  final FirebaseFirestore db;

  static final InviteRepository instance = InviteRepository._(
    FirebaseFirestore.instance,
  );

  String normalizeEmail(String email) => email.trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> _invitesRef(String academyId) {
    return db.collection('academies').doc(academyId).collection('invites');
  }

  DocumentReference<Map<String, dynamic>> _inviteRef({
    required String academyId,
    required String inviteId,
  }) {
    return _invitesRef(academyId).doc(inviteId);
  }

  DocumentReference<Map<String, dynamic>> _userRef({
    required String academyId,
    required String uid,
  }) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid);
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

  Future<bool> acceptInviteForCurrentUser({
    required String academyId,
    required String inviteId,
    required User firebaseUser,
  }) async {
    final authUid = firebaseUser.uid.trim();
    final authEmail = normalizeEmail(firebaseUser.email ?? '');
    if (authUid.isEmpty || authEmail.isEmpty) return false;

    final inviteRef = _inviteRef(academyId: academyId, inviteId: inviteId);
    final inviteSnap = await inviteRef.get();
    final invite = inviteSnap.data();
    if (!inviteSnap.exists || invite == null) return false;

    final status = invite['status']?.toString();
    if (status != 'pending') return false;
    if ((invite['acceptedAuthUid'] ?? '').toString().trim().isNotEmpty) {
      return false;
    }
    if (_isExpired(invite['expiresAt'])) {
      await inviteRef.set({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }

    final inviteEmail = normalizeEmail(
      invite['emailNormalized']?.toString() ?? '',
    );
    if (inviteEmail != authEmail) {
      throw StateError('Convite nao pertence ao e-mail autenticado.');
    }

    final pendingProfileId = invite['pendingProfileId']?.toString().trim();
    if (pendingProfileId == null || pendingProfileId.isEmpty) return false;

    await migratePendingProfileToAuthUid(
      academyId: academyId,
      pendingProfileId: pendingProfileId,
      authUid: authUid,
    );

    return db.runTransaction<bool>((transaction) async {
      final fresh = await transaction.get(inviteRef);
      final data = fresh.data();
      if (!fresh.exists || data == null) return false;
      if (data['status']?.toString() != 'pending') return false;
      if ((data['acceptedAuthUid'] ?? '').toString().trim().isNotEmpty) {
        return false;
      }
      if (_isExpired(data['expiresAt'])) {
        transaction.set(inviteRef, {
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return false;
      }

      final freshEmail = normalizeEmail(
        data['emailNormalized']?.toString() ?? '',
      );
      if (freshEmail != authEmail) {
        throw StateError('Convite nao pertence ao e-mail autenticado.');
      }

      transaction.set(inviteRef, {
        'status': 'accepted',
        'acceptedAuthUid': authUid,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  Future<void> migratePendingProfileToAuthUid({
    required String academyId,
    required String pendingProfileId,
    required String authUid,
  }) async {
    final sourceUid = pendingProfileId.trim();
    final targetUid = authUid.trim();
    if (sourceUid.isEmpty || targetUid.isEmpty || sourceUid == targetUid) {
      return;
    }

    final sourceRef = _userRef(academyId: academyId, uid: sourceUid);
    final targetRef = _userRef(academyId: academyId, uid: targetUid);

    await db.runTransaction<void>((transaction) async {
      final sourceSnap = await transaction.get(sourceRef);
      final targetSnap = await transaction.get(targetRef);
      final sourceData = sourceSnap.data();

      if (!sourceSnap.exists || sourceData == null) {
        throw StateError('Perfil pendente nao encontrado para migracao.');
      }

      if (targetSnap.exists) {
        final targetData = targetSnap.data() ?? const <String, dynamic>{};
        final migratedFrom =
            targetData['migratedFromPendingProfileId']?.toString();
        if (migratedFrom != sourceUid) {
          throw StateError('Usuario Auth ja possui perfil nesta academia.');
        }
        return;
      }

      transaction.set(targetRef, {
        ...sourceData,
        'academyId': academyId,
        'migratedFromPendingProfileId': sourceUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _copyDocument(
      sourceRef.collection('progress').doc('profile'),
      targetRef.collection('progress').doc('profile'),
    );
    await _copyDocument(
      sourceRef.collection('nutrition').doc('profile'),
      targetRef.collection('nutrition').doc('profile'),
    );
    await _copyCollection(
      sourceRef.collection('training_sessions'),
      targetRef.collection('training_sessions'),
    );
    await _copyCollection(
      sourceRef.collection('nutrition').doc('profile').collection('meals'),
      targetRef.collection('nutrition').doc('profile').collection('meals'),
    );
  }

  Future<void> _copyDocument(
    DocumentReference<Map<String, dynamic>> source,
    DocumentReference<Map<String, dynamic>> target,
  ) async {
    final snap = await source.get();
    final data = snap.data();
    if (!snap.exists || data == null) return;
    await target.set(data, SetOptions(merge: true));
  }

  Future<void> _copyCollection(
    CollectionReference<Map<String, dynamic>> source,
    CollectionReference<Map<String, dynamic>> target,
  ) async {
    final snap = await source.get();
    var batch = db.batch();
    var writes = 0;

    for (final doc in snap.docs) {
      batch.set(target.doc(doc.id), doc.data(), SetOptions(merge: true));
      writes++;
      if (writes == 450) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }

    if (writes > 0) await batch.commit();
  }

  bool _isExpired(Object? value) {
    DateTime? expiresAt;
    if (value is Timestamp) expiresAt = value.toDate();
    if (value is DateTime) expiresAt = value;
    if (expiresAt == null) return false;
    return expiresAt.isBefore(DateTime.now());
  }
}
