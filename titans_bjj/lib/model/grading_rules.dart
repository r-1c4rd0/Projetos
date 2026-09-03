enum BeltColor {
  white,
  grayWhite,
  gray,
  grayBlack,
  yellowWhite,
  yellow,
  yellowBlack,
  orangeWhite,
  orange,
  orangeBlack,
  greenWhite,
  green,
  greenBlack,
  blue,
  purple,
  brown,
  black,
}

const kidsBeltOrder = <BeltColor>[
  BeltColor.white,
  BeltColor.grayWhite,
  BeltColor.gray,
  BeltColor.grayBlack,
  BeltColor.yellowWhite,
  BeltColor.yellow,
  BeltColor.yellowBlack,
  BeltColor.orangeWhite,
  BeltColor.orange,
  BeltColor.orangeBlack,
  BeltColor.greenWhite,
  BeltColor.green,
  BeltColor.greenBlack,
];

const adultBeltOrder = <BeltColor>[
  BeltColor.white,
  BeltColor.blue,
  BeltColor.purple,
  BeltColor.brown,
  BeltColor.black,
];

const beltSelectionOrder = <BeltColor>[
  ...kidsBeltOrder,
  BeltColor.blue,
  BeltColor.purple,
  BeltColor.brown,
  BeltColor.black,
];

bool isKidsBelt(BeltColor belt) =>
    belt != BeltColor.white &&
    belt != BeltColor.blue &&
    belt != BeltColor.purple &&
    belt != BeltColor.brown &&
    belt != BeltColor.black;

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
    'branco': BeltColor.white,
    'azul': BeltColor.blue,
    'roxo': BeltColor.purple,
    'roxa': BeltColor.purple,
    'marrom': BeltColor.brown,
    'preto': BeltColor.black,
    'preta': BeltColor.black,
    'graywhite': BeltColor.grayWhite,
    'gray_white': BeltColor.grayWhite,
    'cinza_branca': BeltColor.grayWhite,
    'cinza/branca': BeltColor.grayWhite,
    'gray': BeltColor.gray,
    'cinza': BeltColor.gray,
    'grayblack': BeltColor.grayBlack,
    'gray_black': BeltColor.grayBlack,
    'cinza_preta': BeltColor.grayBlack,
    'cinza/preta': BeltColor.grayBlack,
    'yellowwhite': BeltColor.yellowWhite,
    'yellow_white': BeltColor.yellowWhite,
    'amarela_branca': BeltColor.yellowWhite,
    'amarela/branca': BeltColor.yellowWhite,
    'yellow': BeltColor.yellow,
    'amarela': BeltColor.yellow,
    'amarelo': BeltColor.yellow,
    'yellowblack': BeltColor.yellowBlack,
    'yellow_black': BeltColor.yellowBlack,
    'amarela_preta': BeltColor.yellowBlack,
    'amarela/preta': BeltColor.yellowBlack,
    'orangewhite': BeltColor.orangeWhite,
    'orange_white': BeltColor.orangeWhite,
    'laranja_branca': BeltColor.orangeWhite,
    'laranja/branca': BeltColor.orangeWhite,
    'orange': BeltColor.orange,
    'laranja': BeltColor.orange,
    'orangeblack': BeltColor.orangeBlack,
    'orange_black': BeltColor.orangeBlack,
    'laranja_preta': BeltColor.orangeBlack,
    'laranja/preta': BeltColor.orangeBlack,
    'greenwhite': BeltColor.greenWhite,
    'green_white': BeltColor.greenWhite,
    'verde_branca': BeltColor.greenWhite,
    'verde/branca': BeltColor.greenWhite,
    'green': BeltColor.green,
    'verde': BeltColor.green,
    'greenblack': BeltColor.greenBlack,
    'green_black': BeltColor.greenBlack,
    'verde_preta': BeltColor.greenBlack,
    'verde/preta': BeltColor.greenBlack,
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
  bool hasExplicitRule(BeltColor belt) =>
      sessionsRequiredByBelt.containsKey(belt);
  int maxDegrees(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
      case BeltColor.blue:
      case BeltColor.purple:
      case BeltColor.brown:
        return 4;
      case BeltColor.black:
        return maxDegreesByBelt[belt] ?? 7;
      default:
        return maxDegreesByBelt[belt] ?? 4;
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
      default:
        return 4;
    }
  }

  static GradingRules defaults() {
    return const GradingRules(
      beltOrder: adultBeltOrder,
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
