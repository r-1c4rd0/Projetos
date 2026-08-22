class JiuJitsuTaxonomy {
  const JiuJitsuTaxonomy._();

  static const positions = <String>[
    'Guarda Fechada',
    'Guarda Aberta',
    'Guarda Aranha',
    'De La Riva',
    'Meia Guarda',
    'Meia Guarda Profunda',
    '100 Quilos',
    'Montada',
    'Costas',
    'Norte-Sul',
    'Joelho na Barriga',
    '4 Apoios',
    'Queda',
    'Passagem',
    'Controle Lateral',
  ];

  static const techniques = <String>[
    'Armlock',
    'Omoplata',
    'Kimura',
    'Americana',
    'Mata-Leão',
    'Triângulo',
    'Guilhotina',
    'Ezequiel',
    'Relógio',
    'Anaconda',
    "D'Arce",
    'Peruvian',
    'Viúva Negra',
    'Chave de Pé Aberta',
    'Botinha',
    'Heel Hook',
    'Kneebar',
    'Toe Hold',
    'Raspagem',
    'Passagem de Guarda',
    'Knee Slice',
    'Torreando',
    'Leg Drag',
    'Berimbolo',
    'Single Leg',
    'Double Leg',
    'Baiana',
  ];

  static List<String> mergeStaticAndCustom({
    required List<String> staticItems,
    required Iterable<String> customItems,
  }) {
    final byKey = <String, String>{};

    for (final label in staticItems.followedBy(customItems)) {
      final cleanLabel = _cleanLabel(label);
      if (cleanLabel == null) continue;
      byKey.putIfAbsent(normalizedKey(cleanLabel), () => cleanLabel);
    }

    return byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static String normalizedKey(String value) {
    final normalized = _removeAccents(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _aliases[normalized] ?? normalized;
  }

  static String? _cleanLabel(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return null;
    return text;
  }

  static String _removeAccents(String value) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ç': 'c',
      'Ç': 'C',
    };

    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString();
  }

  static const Map<String, String> _aliases = {
    'arm bar': 'armbar',
    'chave de braco': 'armbar',
    'chave de braço': 'armbar',
    'guarda fechada': 'closed guard',
    'closed guard': 'closed guard',
    'meia guarda': 'half guard',
    'half guard': 'half guard',
    'montada': 'mount',
    'mount': 'mount',
    'costas': 'back',
    'back control': 'back',
  };
}
