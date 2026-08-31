import '../../../model/event_models.dart';
import '../domain/event_models.dart';

class GetEventsDashboardSummary {
  final GetFilteredEvents getFilteredEvents;
  final GetFeaturedEvent getFeaturedEvent;

  const GetEventsDashboardSummary({
    this.getFilteredEvents = const GetFilteredEvents(),
    this.getFeaturedEvent = const GetFeaturedEvent(),
  });

  EventsDashboardSummary call({
    required List<EventModel> events,
    required EventTimelineFilter timelineFilter,
    EventType? typeFilter,
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final typeFiltered =
        typeFilter == null
            ? List<EventModel>.from(events)
            : events.where((event) => event.type == typeFilter).toList();

    return EventsDashboardSummary(
      typeFilteredEvents: List<EventModel>.unmodifiable(typeFiltered),
      visibleEvents: getFilteredEvents(
        typeFiltered,
        timelineFilter: timelineFilter,
        now: resolvedNow,
      ),
      featuredEvent: getFeaturedEvent(typeFiltered, now: resolvedNow),
      selectedFilter: timelineFilter,
    );
  }
}

class GetFilteredEvents {
  const GetFilteredEvents();

  List<EventModel> call(
    List<EventModel> events, {
    required EventTimelineFilter timelineFilter,
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final filtered =
        events.where((event) {
          switch (timelineFilter) {
            case EventTimelineFilter.all:
              return true;
            case EventTimelineFilter.active:
              return eventTimelineStatus(event, resolvedNow) ==
                  EventTimelineStatus.active;
            case EventTimelineFilter.scheduled:
              return eventTimelineStatus(event, resolvedNow) ==
                  EventTimelineStatus.scheduled;
            case EventTimelineFilter.history:
              return eventTimelineStatus(event, resolvedNow) ==
                      EventTimelineStatus.history ||
                  eventTimelineStatus(event, resolvedNow) ==
                      EventTimelineStatus.cancelled;
          }
        }).toList();

    filtered.sort((a, b) {
      if (timelineFilter == EventTimelineFilter.history) {
        return b.start.compareTo(a.start);
      }
      return a.start.compareTo(b.start);
    });
    return List<EventModel>.unmodifiable(filtered);
  }
}

class GetFeaturedEvent {
  const GetFeaturedEvent();

  EventModel? call(List<EventModel> events, {DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final upcoming =
        events
            .where(
              (event) =>
                  eventTimelineStatus(event, resolvedNow) ==
                  EventTimelineStatus.scheduled,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}

EventTimelineStatus eventTimelineStatus(EventModel event, DateTime now) {
  if (event.status == EventStatus.cancelled) {
    return EventTimelineStatus.cancelled;
  }
  if (event.status == EventStatus.finished || event.end.isBefore(now)) {
    return EventTimelineStatus.history;
  }
  if (!event.start.isAfter(now) && !event.end.isBefore(now)) {
    return EventTimelineStatus.active;
  }
  return EventTimelineStatus.scheduled;
}
