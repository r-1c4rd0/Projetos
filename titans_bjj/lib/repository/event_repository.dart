import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../model/event_models.dart';

class EventRepository implements IEventRepository {
  EventRepository({
    FirebaseFirestore? db,
    required this.academyId,
  }) : db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;
  final String academyId;

  static IEventRepository build({
    required String academyId,
    bool useMocks = AppConfig.useMocks,
  }) {
    if (useMocks || AppConfig.useMocks) return InMemoryEventRepository();
    return EventRepository(academyId: academyId);
  }

  DocumentReference<Map<String, dynamic>> _academyRef(String academyId) {
    return db.collection('academies').doc(academyId);
  }

  CollectionReference<Map<String, dynamic>> _collectionRef(String academyId) {
    return _academyRef(academyId).collection('events');
  }

  DocumentReference<Map<String, dynamic>> _eventRef({
    required String academyId,
    required String eventId,
  }) {
    return _collectionRef(academyId).doc(eventId);
  }

  Map<String, dynamic> _dataForModel(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['start'] ??= normalized['startAt'];
    normalized['end'] ??= normalized['endAt'];
    normalized['description'] ??= normalized['notes'];
    if (normalized['type'] == 'championship') {
      normalized['type'] = 'tournament';
    }
    return normalized;
  }

  Query<Map<String, dynamic>> _query({
    DateTime? from,
    DateTime? to,
  }) {
    Query<Map<String, dynamic>> query = _collectionRef(academyId);

    if (from != null) {
      query = query.where('end', isGreaterThan: Timestamp.fromDate(from.toUtc()));
    }

    if (to != null) {
      query = query.where('start', isLessThan: Timestamp.fromDate(to.toUtc()));
    }

    return query;
  }

  Future<EventModel?> get(String id) async {
    final snap = await _eventRef(academyId: academyId, eventId: id).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return EventModel.fromMap(snap.id, _dataForModel(data));
  }

  @override
  Stream<List<EventModel>> watch({DateTime? from, DateTime? to}) {
    return _query(from: from, to: to).snapshots().map((snap) {
      final events = snap.docs
          .map((doc) => EventModel.fromMap(doc.id, _dataForModel(doc.data())))
          .toList();
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    });
  }

  @override
  Future<List<EventModel>> list({DateTime? from, DateTime? to}) async {
    final snap = await _query(from: from, to: to).get();
    final events = snap.docs
        .map((doc) => EventModel.fromMap(doc.id, _dataForModel(doc.data())))
        .toList();
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  Future<void> upsert(EventModel event) async {
    await _eventRef(academyId: academyId, eventId: event.id).set(
      event.toMap(),
      SetOptions(merge: true),
    );
  }

  @override
  Future<EventModel> create(EventModel event) async {
    await upsert(event);
    return event;
  }

  @override
  Future<void> update(EventModel event) => upsert(event);

  @override
  Future<void> delete(String id) async {
    await _eventRef(academyId: academyId, eventId: id).delete();
  }
}
