import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_repository.dart';

class FirebaseEventRepository extends EventRepository {
  FirebaseEventRepository(
    String academyId, {
    FirebaseFirestore? db,
  }) : super(db: db, academyId: academyId);
}
