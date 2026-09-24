import 'package:flutter/material.dart';

import '../domain/technical_taxonomy.dart';

const technicalRetentionColor = Color(0xFF4CC9F0);
const technicalTransitionColor = Color(0xFFE9C46A);
const technicalControlColor = Color(0xFFB026FF);
const technicalAttackColor = Color(0xFF2D6BFF);

Color technicalAxisColor(
  TechnicalRadarAxis axis, {
  required Color unclassifiedColor,
}) {
  return switch (axis) {
    TechnicalRadarAxis.retention => technicalRetentionColor,
    TechnicalRadarAxis.transition => technicalTransitionColor,
    TechnicalRadarAxis.control => technicalControlColor,
    TechnicalRadarAxis.attack => technicalAttackColor,
    TechnicalRadarAxis.unclassified => unclassifiedColor,
  };
}
