import 'dart:math';

import 'package:flutter/material.dart';

class AppGradients {
  static const linear = LinearGradient(colors: [
    Color.fromARGB(190, 4, 6, 48),
    Color.fromARGB(219, 6, 8, 106),
  ], stops: [
    0.0,
    0.695
  ], transform: GradientRotation(2.13959913 * pi));
}
