import '../../../model/event_models.dart';

enum EventTimelineFilter { all, active, scheduled, history }

enum EventTimelineStatus { active, scheduled, history, cancelled }

class EventsDashboardSummary {
  final List<EventModel> typeFilteredEvents;
  final List<EventModel> visibleEvents;
  final EventModel? featuredEvent;
  final EventTimelineFilter selectedFilter;

  const EventsDashboardSummary({
    required this.typeFilteredEvents,
    required this.visibleEvents,
    required this.featuredEvent,
    required this.selectedFilter,
  });

  bool get hasEventsForType => typeFilteredEvents.isNotEmpty;
}
