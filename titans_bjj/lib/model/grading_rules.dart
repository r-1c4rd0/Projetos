enum BeltColor { white, blue, purple, brown, black }

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
  int maxDegrees(BeltColor belt) => maxDegreesByBelt[belt] ?? 0;

  static BeltColor _beltFromString(String s) {
    return BeltColor.values.firstWhere(
          (b) => b.name == s,
      orElse: () => BeltColor.white,
    );
  }

  static GradingRules fromMap(Map<String, dynamic> map) {
    final orderRaw = (map['beltOrder'] as List?) ?? ['white','blue','purple','brown','black'];
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
    Map<String, dynamic> beltMap(Map<BeltColor, int> m) =>
        {for (final e in m.entries) e.key.name: e.value};

    return {
      'beltOrder': beltOrder.map((b) => b.name).toList(),
      'sessionsRequiredByBelt': beltMap(sessionsRequiredByBelt),
      'maxDegreesByBelt': beltMap(maxDegreesByBelt),
      'counting': {
        'onlyAcademyPlace': onlyAcademyPlace,
      }
    };
  }
}
