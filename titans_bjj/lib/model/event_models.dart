

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
}

abstract class IEventRepository {
  Future<List<EventModel>> list({DateTime? from, DateTime? to});
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
    var data = _items;
    if (from != null) data = data.where((e) => e.end.isAfter(from)).toList();
    if (to != null) data = data.where((e) => e.start.isBefore(to)).toList();
    data.sort((a, b) => a.start.compareTo(b.start));
    return data;
  }

  @override
  Future<void> update(EventModel event) async {
    final i = _items.indexWhere((e) => e.id == event.id);
    if (i >= 0) _items[i] = event;
  }
}
