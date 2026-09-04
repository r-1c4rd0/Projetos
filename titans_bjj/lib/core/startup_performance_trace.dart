import 'package:flutter/foundation.dart';

class StartupPerformanceTrace {
  static final Stopwatch _watch = Stopwatch()..start();
  static final Map<String, Stopwatch> _spans = <String, Stopwatch>{};

  const StartupPerformanceTrace._();

  static bool get enabled => kDebugMode || kProfileMode;

  static void mark(String label) {
    if (!enabled) return;
    debugPrint('[STARTUP] ${_watch.elapsedMilliseconds}ms $label');
  }

  static void start(String label) {
    if (!enabled) return;
    _spans[label] = Stopwatch()..start();
    mark('$label start');
  }

  static void end(String label, {String? detail}) {
    if (!enabled) return;
    final span = _spans.remove(label);
    final elapsed = span?.elapsedMilliseconds;
    final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
    if (elapsed == null) {
      mark('$label done$suffix');
      return;
    }
    mark('$label done in ${elapsed}ms$suffix');
  }
}
