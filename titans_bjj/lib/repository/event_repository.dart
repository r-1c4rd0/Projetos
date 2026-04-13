import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/event_model.dart';

class EventRepository {
  EventRepository({required this.academyId});

  final String academyId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('academies')
          .doc(academyId)
          .collection('events');

  Stream<List<EventModel>> watchAll() {
    return _col
        .orderBy('startAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(EventModel.fromDoc).toList());
  }

  Future<void> create(EventModel e) async {
    await _col.add(e.toMap());
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
