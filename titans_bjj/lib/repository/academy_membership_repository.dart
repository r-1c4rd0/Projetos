import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/academy_membership.dart';

class AcademyMembershipRepository {
  AcademyMembershipRepository._(this.db);
  AcademyMembershipRepository(this.db);

  final FirebaseFirestore db;

  static final AcademyMembershipRepository instance =
      AcademyMembershipRepository._(FirebaseFirestore.instance);

  CollectionReference<Map<String, dynamic>> _membershipCollection(String uid) {
    return db.collection('users').doc(uid).collection('academyMemberships');
  }

  Future<List<AcademyMembership>> listMemberships(String uid) async {
    final snap = await _membershipCollection(uid).get();
    final memberships =
        snap.docs
            .map((doc) => AcademyMembership.fromMap(doc.id, doc.data()))
            .where((membership) => membership.academyId.trim().isNotEmpty)
            .toList();

    memberships.sort((a, b) {
      final nameCompare = a.academyName.compareTo(b.academyName);
      if (nameCompare != 0) return nameCompare;
      return a.academyId.compareTo(b.academyId);
    });

    return memberships;
  }
}
