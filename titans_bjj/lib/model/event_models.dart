import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { graduation, specialClass, tournament, other }
enum EventStatus { scheduled, cancelled, finished }

class EventModel {
  final String id;
  final String title;
  final EventType type;
  final DateTime start;
  final DateTime end;
  final String location;
  final String description;
  final EventStatus status;
  final Set<String> attendees; // emails/ids

  EventModel({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    required this.location,
    required this.description,
    this.status = EventStatus.scheduled,
    Set<String>? attendees,
  }) : attendees = attendees ?? {};

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'start': Timestamp.fromDate(start.toUtc()),
      'end': Timestamp.fromDate(end.toUtc()),
      'location': location,
      'description': description,
      'status': status.name,
      'attendees': attendees.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory EventModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    T parseEnum<T extends Enum>(List<T> values, dynamic value, T fallback) {
      final name = value?.toString();
      return values.firstWhere((item) => item.name == name, orElse: () => fallback);
    }

    return EventModel(
      id: id,
      title: (map['title'] ?? '').toString(),
      type: parseEnum(EventType.values, map['type'], EventType.other),
      start: parseDate(map['start']),
      end: parseDate(map['end']),
      location: (map['location'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      status: parseEnum(EventStatus.values, map['status'], EventStatus.scheduled),
      attendees: {...List<String>.from(map['attendees'] ?? const <String>[])},
    );
  }
}

abstract class IEventRepository {
  Future<List<EventModel>> list({DateTime? from, DateTime? to});
  Stream<List<EventModel>> watch({DateTime? from, DateTime? to});
  Future<EventModel> create(EventModel event);
  Future<void> update(EventModel event);
  Future<void> delete(String id);
}

class InMemoryEventRepository implements IEventRepository {
  final _items = <EventModel>[];

  @override
  Future<EventModel> create(EventModel event) async {
    _items.add(event);
    return event;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<EventModel>> list({DateTime? from, DateTime? to}) async {
    var data = List<EventModel>.from(_items);
    if (from != null) data = data.where((e) => e.end.isAfter(from)).toList();
    if (to != null) data = data.where((e) => e.start.isBefore(to)).toList();
    data.sort((a, b) => a.start.compareTo(b.start));
    return data;
  }

  @override
  Stream<List<EventModel>> watch({DateTime? from, DateTime? to}) async* {
    yield await list(from: from, to: to);
  }

  @override
  Future<void> update(EventModel event) async {
    final i = _items.indexWhere((e) => e.id == event.id);
    if (i >= 0) _items[i] = event;
  }
}
