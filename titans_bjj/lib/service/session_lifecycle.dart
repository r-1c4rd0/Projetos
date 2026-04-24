import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'selected_student.dart';

class SessionLifecycleService with WidgetsBindingObserver {
  SessionLifecycleService({this.selectedStudentController});

  final SelectedStudentController? selectedStudentController;

  bool _registered = false;
  bool _signingOut = false;
  DateTime? _lastSignOutAt;

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
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }

    if (_signingOut || _isDebounced()) return;

    _signingOut = true;
    _lastSignOutAt = DateTime.now();

    try {
      selectedStudentController?.clear();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Best effort: forced app termination by the OS may not deliver lifecycle
      // callbacks, and sign-out must never crash the app while closing.
    } finally {
      _signingOut = false;
    }
  }

  bool _isDebounced() {
    final lastSignOutAt = _lastSignOutAt;
    if (lastSignOutAt == null) return false;

    return DateTime.now().difference(lastSignOutAt) <
        const Duration(milliseconds: 800);
  }
}
