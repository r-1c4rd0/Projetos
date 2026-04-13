import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { graduation, specialClass, championship, other }

class EventModel {
  final String id;
  final String title;
  final EventType type;
  final DateTime startAt;
  final DateTime endAt;
  final String? location;
  final String? notes;

  EventModel({
    required this.id,
    required this.title,
    required this.type,
    required this.startAt,
    required this.endAt,
    this.location,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'type': type.name,
    'startAt': Timestamp.fromDate(startAt.toUtc()),
    'endAt': Timestamp.fromDate(endAt.toUtc()),
    'location': location,
    'notes': notes,
  };

  static EventModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final typeStr = (m['type'] ?? 'other') as String;
    final type = EventType.values.firstWhere(
          (e) => e.name == typeStr,
      orElse: () => EventType.other,
    );

    return EventModel(
      id: doc.id,
      title: (m['title'] ?? '') as String,
      type: type,
      startAt: (m['startAt'] as Timestamp).toDate(),
      endAt: (m['endAt'] as Timestamp).toDate(),
      location: m['location'] as String?,
      notes: m['notes'] as String?,
    );
  }
}
