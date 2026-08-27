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

enum TechnicalRadarAxis { retention, transition, control, attack, unclassified }

extension TechnicalRadarAxisLabel on TechnicalRadarAxis {
  String get displayLabel {
    switch (this) {
      case TechnicalRadarAxis.retention:
        return 'Reten\u00e7\u00e3o';
      case TechnicalRadarAxis.transition:
        return 'Transi\u00e7\u00e3o';
      case TechnicalRadarAxis.control:
        return 'Controle';
      case TechnicalRadarAxis.attack:
        return 'Ataque';
      case TechnicalRadarAxis.unclassified:
        return 'Sem classifica\u00e7\u00e3o';
    }
  }

  String get label => displayLabel;
}

extension JiuJitsuSkillCategoryLabel on JiuJitsuSkillCategory {
  String get displayLabel {
    switch (this) {
      case JiuJitsuSkillCategory.guard:
        return 'Guarda';
      case JiuJitsuSkillCategory.passing:
        return 'Passagens';
      case JiuJitsuSkillCategory.takedowns:
        return 'Quedas';
      case JiuJitsuSkillCategory.mount:
        return 'Montada';
      case JiuJitsuSkillCategory.back:
        return 'Costas';
      case JiuJitsuSkillCategory.escapes:
        return 'Sa\u00eddas';
      case JiuJitsuSkillCategory.submissions:
        return 'Finaliza\u00e7\u00f5es';
      case JiuJitsuSkillCategory.defense:
        return 'Defesa';
      case JiuJitsuSkillCategory.other:
        return 'N\u00e3o classificado';
    }
  }

  String get label => displayLabel;
}

class JiuJitsuTaxonomy {
  const JiuJitsuTaxonomy._();

  static const positions = <String>[
    'Guarda Fechada',
    'Guarda Aberta',
    'Guarda Aranha',
    'Guarda Aranha Invertida',
    'De La Riva',
    'De La Riva Invertida',
    'Reverse De La Riva',
    'Guarda X',
    'Guarda X Invertida',
    'Reverse X Guard',
    'Guarda Borboleta',
    'Guarda Borboleta Profunda',
    'Meia Guarda',
    'Meia Guarda Profunda',
    'Knee Shield',
    'Guarda Z',
    'Guarda Lasso',
    'Guarda de Lapela',
    '50/50',
    'Guarda Sentada',
    'Guarda Reversa',
    'K-Guard',
    'Rubber Guard',
    '100 Quilos',
    'Controle Lateral',
    'Controle Lateral Invertido',
    'Kesa Gatame',
    'Kesa Gatame Reverso',
    'Norte-Sul',
    'Joelho na Barriga',
    'Montada',
    'Montada Alta',
    'Montada Técnica',
    'Montada S',
    'Costas',
    'Costas com ganchos',
    'Costas com body triangle',
    'Crucifixo',
    'Head and Arm Control',
    '4 Apoios',
    'Turtle / 4 Apoios',
    'Turtle Invertido',
    'Queda',
    'Passagem',
    'Scramble',
    'Posição neutra em pé',
  ];

  static const techniques = <String>[
    'Armlock',
    'Omoplata',
    'Kimura',
    'Americana',
    'Mata-Leão',
    'Triângulo',
    'Triângulo Invertido',
    'Guilhotina',
    'Arm-in Guillotine',
    'Marcelotine',
    'Ezequiel',
    'Relógio',
    'Anaconda',
    "D'Arce",
    'Peruvian',
    'Peruvian Necktie',
    'Von Flue',
    'Baseball Bat Choke',
    'Loop Choke',
    'Cross Collar Choke',
    'Arco e Flecha',
    'Bow and Arrow',
    'Paper Cutter',
    'North-South Choke',
    'Japanese Necktie',
    'Viúva Negra',
    'Wristlock',
    'Bicep Slicer',
    'Monoplata',
    'Chave de Pé Aberta',
    'Botinha',
    'Heel Hook',
    'Heel Hook Interno',
    'Heel Hook Externo',
    'Kneebar',
    'Toe Hold',
    'Straight Ankle Lock',
    'Estima Lock',
    'Raspagem',
    'Raspagem Tesoura',
    'Raspagem Pêndulo',
    'Raspagem Elevador',
    'Raspagem Gancho',
    'Butterfly Sweep',
    'Hook Sweep',
    'Balloon Sweep',
    'Raspagem da Meia Guarda',
    'Raspagem Coyote',
    'Berimbolo',
    'Reverse Berimbolo',
    'Passagem de Guarda',
    'Knee Slice',
    'Torreando',
    'Leg Drag',
    'Over Under',
    'Passagem de Pressão',
    'Smash Pass',
    'Long Step',
    'X-Pass',
    'Passagem Meia Guarda',
    'Passagem Guarda Aberta',
    'Passagem Guarda Fechada',
    'Single Leg',
    'Double Leg',
    'Ankle Pick',
    'Tomoe Nage',
    'Uchi Mata',
    'Ippon Seoi Nage',
    'Osoto Gari',
    'Baiana',
    'Saída da Montada',
    'Saída das Costas',
    'Saída do Controle Lateral',
    'Saída do Norte-Sul',
    'Defesa de Triângulo',
    'Defesa de Armlock',
    'Defesa de Guilhotina',
    'Reposição de Guarda',
    'Recuperação de Meia Guarda',
    'Transição para Montada',
    'Transição para Costas',
    'Transição Norte-Sul',
    'Granby Roll',
    'Technical Stand Up',
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

  static TechnicalRadarAxis technicalRadarAxisForCategory(
    JiuJitsuSkillCategory category,
  ) {
    switch (category) {
      case JiuJitsuSkillCategory.submissions:
        return TechnicalRadarAxis.attack;
      case JiuJitsuSkillCategory.escapes:
        return TechnicalRadarAxis.transition;
      case JiuJitsuSkillCategory.guard:
      case JiuJitsuSkillCategory.passing:
      case JiuJitsuSkillCategory.takedowns:
      case JiuJitsuSkillCategory.mount:
      case JiuJitsuSkillCategory.back:
      case JiuJitsuSkillCategory.defense:
      case JiuJitsuSkillCategory.other:
        return TechnicalRadarAxis.unclassified;
    }
  }

  static String normalizedKey(String value) {
    final normalized =
        _removeAccents(value)
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

  static String _removeAccents(String value) => _stripDiacritics(value);

  static String _stripDiacritics(String input) {
    final buffer = StringBuffer();

    for (final rune in input.runes) {
      switch (rune) {
        case 0x00C0:
        case 0x00C1:
        case 0x00C2:
        case 0x00C3:
        case 0x00C4:
        case 0x00C5:
          buffer.write('A');
          break;
        case 0x00E0:
        case 0x00E1:
        case 0x00E2:
        case 0x00E3:
        case 0x00E4:
        case 0x00E5:
          buffer.write('a');
          break;
        case 0x00C8:
        case 0x00C9:
        case 0x00CA:
        case 0x00CB:
          buffer.write('E');
          break;
        case 0x00E8:
        case 0x00E9:
        case 0x00EA:
        case 0x00EB:
          buffer.write('e');
          break;
        case 0x00CC:
        case 0x00CD:
        case 0x00CE:
        case 0x00CF:
          buffer.write('I');
          break;
        case 0x00EC:
        case 0x00ED:
        case 0x00EE:
        case 0x00EF:
          buffer.write('i');
          break;
        case 0x00D2:
        case 0x00D3:
        case 0x00D4:
        case 0x00D5:
        case 0x00D6:
          buffer.write('O');
          break;
        case 0x00F2:
        case 0x00F3:
        case 0x00F4:
        case 0x00F5:
        case 0x00F6:
          buffer.write('o');
          break;
        case 0x00D9:
        case 0x00DA:
        case 0x00DB:
        case 0x00DC:
          buffer.write('U');
          break;
        case 0x00F9:
        case 0x00FA:
        case 0x00FB:
        case 0x00FC:
          buffer.write('u');
          break;
        case 0x00C7:
          buffer.write('C');
          break;
        case 0x00E7:
          buffer.write('c');
          break;
        case 0x00D1:
          buffer.write('N');
          break;
        case 0x00F1:
          buffer.write('n');
          break;
        default:
          buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }

  static const Map<String, String> _aliases = {
    'arm bar': 'armbar',
    'chave de braco': 'armbar',
    'chave de bra\u00e7o': 'armbar',
    'guarda fechada': 'closed guard',
    'closed guard': 'closed guard',
    'meia guarda': 'half guard',
    'half guard': 'half guard',
    'montada': 'mount',
    'mount': 'mount',
    'costas': 'back',
    'back control': 'back',
    'arco e flecha': 'bow and arrow',
    'bow and arrow': 'bow and arrow',
    'bow and arrow choke': 'bow and arrow',
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
  static const _takedownTerms = ['queda', 'single leg', 'double leg', 'baiana'];
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
    'bow and arrow',
    'botinha',
    'chave de pe',
  ];
  static const _escapeTerms = ['escape', 'saida', 'fuga'];
  static const _defenseTerms = ['defesa', 'bloqueio', 'prevencao'];
}
