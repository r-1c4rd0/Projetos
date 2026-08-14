import 'package:flutter/material.dart';

import 'selected_student.dart';

class SelectedStudentScope extends InheritedNotifier<SelectedStudentController> {
  const SelectedStudentScope({
    super.key,
    required SelectedStudentController controller,
    required super.child,
  }) : super(notifier: controller);

  static SelectedStudentController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'SelectedStudentScope nao encontrado no widget tree.');
    return controller!;
  }

  static SelectedStudentController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SelectedStudentScope>()
        ?.notifier;
  }
}
