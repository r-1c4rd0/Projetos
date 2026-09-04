import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/startup_performance_trace.dart';
import 'selected_student.dart';
import 'session_lock_controller.dart';

class SessionLifecycleService with WidgetsBindingObserver {
  SessionLifecycleService({this.selectedStudentController});

  final SelectedStudentController? selectedStudentController;

  bool _registered = false;
  DateTime? _backgroundAt;

  void register() {
    if (_registered) return;
    WidgetsBinding.instance.addObserver(this);
    _registered = true;
    StartupPerformanceTrace.mark('SessionLifecycle registered');
  }

  void dispose() {
    if (!_registered) return;
    WidgetsBinding.instance.removeObserver(this);
    _registered = false;
    StartupPerformanceTrace.mark('SessionLifecycle disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    StartupPerformanceTrace.mark('SessionLifecycle lifecycle ${state.name}');
    unawaited(onAppLifecycleStateChanged(state));
  }

  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final backgroundAt = _backgroundAt;
      final backgroundMs =
          backgroundAt == null
              ? null
              : DateTime.now().difference(backgroundAt).inMilliseconds;
      StartupPerformanceTrace.mark(
        backgroundMs == null
            ? 'SessionLifecycle resume foreground'
            : 'SessionLifecycle resume foreground after ${backgroundMs}ms',
      );
      _backgroundAt = null;
      return;
    }

    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }

    _backgroundAt ??= DateTime.now();
    StartupPerformanceTrace.start('SessionLifecycle background lock');
    try {
      SessionLockController.instance.lock();
      StartupPerformanceTrace.end(
        'SessionLifecycle background lock',
        detail: 'state=${state.name}',
      );
    } catch (_) {
      StartupPerformanceTrace.end(
        'SessionLifecycle background lock',
        detail: 'error state=${state.name}',
      );
      // Best effort: lifecycle callbacks must never crash while the app closes.
    }
  }
}
