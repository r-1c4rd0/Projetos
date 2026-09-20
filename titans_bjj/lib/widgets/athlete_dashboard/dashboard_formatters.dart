import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../model/grading_rules.dart';

String? cleanDebriefText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String? shortDebriefText(String? value, {int maxLength = 72}) {
  final text = cleanDebriefText(value);
  if (text == null) return null;
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3).trimRight()}...';
}

String formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String beltLabel(BeltColor belt) {
  return TitansUI.beltLabel(belt.name);
}

Color beltProgressRingColor(BeltColor belt) {
  return TitansUI.beltColor(belt.name);
}
