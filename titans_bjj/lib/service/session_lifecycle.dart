import 'dart:async';

import 'package:flutter/widgets.dart';

import 'selected_student.dart';
import 'session_lock_controller.dart';

class SessionLifecycleService with WidgetsBindingObserver {
  SessionLifecycleService({this.selectedStudentController});

  final SelectedStudentController? selectedStudentController;

  bool _registered = false;

  void register() {
    if (_registered) return;
    WidgetsBinding.instance.addObserver(this);
    _registered = true;
  }

  void dispose() {
    if (!_registered) return;
    WidgetsBinding.instance.removeObserver(this);
    _registered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(onAppLifecycleStateChanged(state));
  }

  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }

    try {
      SessionLockController.instance.lock();
    } catch (_) {
      // Best effort: lifecycle callbacks must never crash while the app closes.
    }
  }
}