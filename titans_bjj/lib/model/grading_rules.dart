enum BeltColor { white, blue, purple, brown, black }

BeltColor beltColorFromString(
  Object? value, {
  BeltColor fallback = BeltColor.white,
}) {
  final normalized = value.toString().trim().toLowerCase().replaceFirst(
    'beltcolor.',
    '',
  );
  const aliases = {
    'branca': BeltColor.white,
    'azul': BeltColor.blue,
    'roxa': BeltColor.purple,
    'marrom': BeltColor.brown,
    'preta': BeltColor.black,
  };

  final alias = aliases[normalized];
  if (alias != null) return alias;

  return BeltColor.values.firstWhere(
    (belt) => belt.name == normalized,
    orElse: () => fallback,
  );
}

class GradingRules {
  final List<BeltColor> beltOrder;
  final Map<BeltColor, int> sessionsRequiredByBelt;
  final Map<BeltColor, int> maxDegreesByBelt;

  // flags de contagem (mínimo)
  final bool onlyAcademyPlace;

  const GradingRules({
    required this.beltOrder,
    required this.sessionsRequiredByBelt,
    required this.maxDegreesByBelt,
    required this.onlyAcademyPlace,
  });

  int requiredSessions(BeltColor belt) => sessionsRequiredByBelt[belt] ?? 0;
  int maxDegrees(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
      case BeltColor.blue:
      case BeltColor.purple:
      case BeltColor.brown:
        return 4;
      case BeltColor.black:
        return maxDegreesByBelt[belt] ?? 7;
    }
  }

  static int fallbackMaxDegrees(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
      case BeltColor.blue:
      case BeltColor.purple:
      case BeltColor.brown:
        return 4;
      case BeltColor.black:
        return 7;
    }
  }

  static GradingRules defaults() {
    return const GradingRules(
      beltOrder: [
        BeltColor.white,
        BeltColor.blue,
        BeltColor.purple,
        BeltColor.brown,
        BeltColor.black,
      ],
      sessionsRequiredByBelt: {
        BeltColor.white: 200,
        BeltColor.blue: 400,
        BeltColor.purple: 600,
        BeltColor.brown: 800,
        BeltColor.black: 1280,
      },
      maxDegreesByBelt: {
        BeltColor.white: 4,
        BeltColor.blue: 4,
        BeltColor.purple: 4,
        BeltColor.brown: 4,
        BeltColor.black: 7,
      },
      onlyAcademyPlace: false,
    );
  }

  static BeltColor _beltFromString(String s) {
    return beltColorFromString(s);
  }

  static GradingRules fromMap(Map<String, dynamic> map) {
    final orderRaw =
        (map['beltOrder'] as List?) ??
        ['white', 'blue', 'purple', 'brown', 'black'];
    final order = orderRaw.map((e) => _beltFromString(e.toString())).toList();

    final reqRaw = (map['sessionsRequiredByBelt'] as Map?) ?? {};
    final req = <BeltColor, int>{};
    for (final entry in reqRaw.entries) {
      req[_beltFromString(entry.key.toString())] = (entry.value as num).toInt();
    }

    final degRaw = (map['maxDegreesByBelt'] as Map?) ?? {};
    final deg = <BeltColor, int>{};
    for (final entry in degRaw.entries) {
      deg[_beltFromString(entry.key.toString())] = (entry.value as num).toInt();
    }

    final counting = (map['counting'] as Map?) ?? {};
    final onlyAcademyPlace = (counting['onlyAcademyPlace'] ?? false) as bool;

    return GradingRules(
      beltOrder: order,
      sessionsRequiredByBelt: req,
      maxDegreesByBelt: deg,
      onlyAcademyPlace: onlyAcademyPlace,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> beltMap(Map<BeltColor, int> m) => {
      for (final e in m.entries) e.key.name: e.value,
    };

    return {
      'beltOrder': beltOrder.map((b) => b.name).toList(),
      'sessionsRequiredByBelt': beltMap(sessionsRequiredByBelt),
      'maxDegreesByBelt': beltMap(maxDegreesByBelt),
      'counting': {'onlyAcademyPlace': onlyAcademyPlace},
    };
  }
}
