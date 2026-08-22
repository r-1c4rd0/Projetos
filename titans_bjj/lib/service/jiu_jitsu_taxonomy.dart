enum JiuJitsuSkillCategory {
  guard,
  passing,
  takedowns,
  mount,
  back,
  escapes,
  submissions,
  defense,
  other,
}

extension JiuJitsuSkillCategoryLabel on JiuJitsuSkillCategory {
  String get label {
    switch (this) {
      case JiuJitsuSkillCategory.guard:
        return 'Guard';
      case JiuJitsuSkillCategory.passing:
        return 'Passing';
      case JiuJitsuSkillCategory.takedowns:
        return 'Takedowns';
      case JiuJitsuSkillCategory.mount:
        return 'Mount';
      case JiuJitsuSkillCategory.back:
        return 'Back';
      case JiuJitsuSkillCategory.escapes:
        return 'Escapes';
      case JiuJitsuSkillCategory.submissions:
        return 'Submissions';
      case JiuJitsuSkillCategory.defense:
        return 'Defense';
      case JiuJitsuSkillCategory.other:
        return 'Other';
    }
  }
}

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

  static JiuJitsuSkillCategory categoryFor({
    String? position,
    String? technique,
  }) {
    final positionKey = _nullableNormalizedKey(position);
    final techniqueKey = _nullableNormalizedKey(technique);

    if (_containsAny(techniqueKey, _submissionTerms)) {
      return JiuJitsuSkillCategory.submissions;
    }
    if (_containsAny(techniqueKey, _takedownTerms)) {
      return JiuJitsuSkillCategory.takedowns;
    }
    if (_containsAny(techniqueKey, _passingTerms)) {
      return JiuJitsuSkillCategory.passing;
    }
    if (_containsAny(techniqueKey, _escapeTerms)) {
      return JiuJitsuSkillCategory.escapes;
    }
    if (_containsAny(techniqueKey, _defenseTerms)) {
      return JiuJitsuSkillCategory.defense;
    }
    if (_containsAny(techniqueKey, _backTerms)) {
      return JiuJitsuSkillCategory.back;
    }
    if (_containsAny(techniqueKey, _mountTerms)) {
      return JiuJitsuSkillCategory.mount;
    }
    if (_containsAny(techniqueKey, _guardTerms)) {
      return JiuJitsuSkillCategory.guard;
    }

    if (_containsAny(positionKey, _guardTerms)) {
      return JiuJitsuSkillCategory.guard;
    }
    if (_containsAny(positionKey, _passingTerms)) {
      return JiuJitsuSkillCategory.passing;
    }
    if (_containsAny(positionKey, _takedownTerms)) {
      return JiuJitsuSkillCategory.takedowns;
    }
    if (_containsAny(positionKey, _mountTerms)) {
      return JiuJitsuSkillCategory.mount;
    }
    if (_containsAny(positionKey, _backTerms)) {
      return JiuJitsuSkillCategory.back;
    }
    if (_containsAny(positionKey, _escapeTerms)) {
      return JiuJitsuSkillCategory.escapes;
    }
    if (_containsAny(positionKey, _defenseTerms)) {
      return JiuJitsuSkillCategory.defense;
    }

    return JiuJitsuSkillCategory.other;
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

  static String? _nullableNormalizedKey(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return normalizedKey(clean);
  }

  static bool _containsAny(String? key, List<String> terms) {
    if (key == null || key.isEmpty) return false;
    return terms.any((term) => key == term || key.contains(term));
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

  static const _guardTerms = [
    'guarda',
    'closed guard',
    'open guard',
    'spider guard',
    'de la riva',
    'half guard',
    'worm guard',
  ];
  static const _passingTerms = [
    'passagem',
    'passagem de guarda',
    'knee slice',
    'torreando',
    'leg drag',
    'pass',
  ];
  static const _takedownTerms = [
    'queda',
    'single leg',
    'double leg',
    'baiana',
  ];
  static const _mountTerms = ['montada', 'mount'];
  static const _backTerms = ['costas', 'back', 'mata leao'];
  static const _submissionTerms = [
    'armbar',
    'armlock',
    'omoplata',
    'kimura',
    'americana',
    'triangulo',
    'guilhotina',
    'ezequiel',
    'relogio',
    'anaconda',
    'd arce',
    'darce',
    'peruvian',
    'heel hook',
    'kneebar',
    'toe hold',
    'botinha',
    'chave de pe',
  ];
  static const _escapeTerms = ['escape', 'saida', 'fuga'];
  static const _defenseTerms = ['defesa', 'bloqueio', 'prevencao'];
}
