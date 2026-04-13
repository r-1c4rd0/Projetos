import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/event_models.dart';


class FirebaseEventRepository implements IEventRepository {
  FirebaseEventRepository(this.academyId);
  final String academyId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('academies')
          .doc(academyId)
          .collection('events');

  @override
  Future<EventModel> create(EventModel e) async {
    await _col.doc(e.id).set({
      'title': e.title,
      'type': e.type.name,
      'start': e.start.toUtc(),
      'end': e.end.toUtc(),
      'location': e.location,
      'description': e.description,
      'status': e.status.name,
      'attendees': e.attendees.toList(),
    });
    return e;
  }

  @override
  Future<void> delete(String id) async => _col.doc(id).delete();

  @override
  Future<List<EventModel>> list({DateTime? from, DateTime? to}) async {
    var q = _col.orderBy('start', descending: false);
    if (from != null) q = q.where('end', isGreaterThan: from.toUtc());
    if (to != null) q = q.where('start', isLessThan: to.toUtc());

    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      return EventModel(
        id: d.id,
        title: m['title'],
        type: EventType.values.firstWhere((x) => x.name == m['type']),
        start: (m['start'] as Timestamp).toDate(),
        end: (m['end'] as Timestamp).toDate(),
        location: m['location'],
        description: m['description'],
        status: EventStatus.values.firstWhere((x) => x.name == m['status']),
        attendees: {...List<String>.from(m['attendees'] ?? [])},
      );
    }).toList();
  }

  @override
  Future<void> update(EventModel e) => create(e);
}
