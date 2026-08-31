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

class TechnicalSkillIdentity {
  final String skillId;
  final String displayName;
  final String normalizedName;
  final List<String> aliases;
  final JiuJitsuSkillCategory category;

  const TechnicalSkillIdentity({
    required this.skillId,
    required this.displayName,
    required this.normalizedName,
    required this.aliases,
    required this.category,
  });
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
    'Retenção de Guarda',
    'Frames',
    'Seatbelt',
    'Crossface',
    'Underhook de Controle',
    'Entrada para Costas',
    'Defesa de Passagem',
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
    final skillIdentity = resolveSkillIdentity(technique);

    if (skillIdentity != null) return skillIdentity.category;

    if (_containsAny(techniqueKey, _retentionTerms)) {
      return JiuJitsuSkillCategory.guard;
    }
    if (_containsAny(techniqueKey, _submissionTerms)) {
      return JiuJitsuSkillCategory.submissions;
    }
    if (_containsAny(techniqueKey, _transitionTerms)) {
      return JiuJitsuSkillCategory.escapes;
    }
    if (_containsAny(techniqueKey, _controlTerms)) {
      return JiuJitsuSkillCategory.mount;
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

    if (_containsAny(positionKey, _retentionTerms)) {
      return JiuJitsuSkillCategory.guard;
    }
    if (_containsAny(positionKey, _transitionTerms)) {
      return JiuJitsuSkillCategory.escapes;
    }
    if (_containsAny(positionKey, _controlTerms)) {
      return JiuJitsuSkillCategory.mount;
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
      case JiuJitsuSkillCategory.guard:
      case JiuJitsuSkillCategory.defense:
        return TechnicalRadarAxis.retention;
      case JiuJitsuSkillCategory.passing:
      case JiuJitsuSkillCategory.takedowns:
      case JiuJitsuSkillCategory.escapes:
        return TechnicalRadarAxis.transition;
      case JiuJitsuSkillCategory.mount:
      case JiuJitsuSkillCategory.back:
        return TechnicalRadarAxis.control;
      case JiuJitsuSkillCategory.submissions:
        return TechnicalRadarAxis.attack;
      case JiuJitsuSkillCategory.other:
        return TechnicalRadarAxis.unclassified;
    }
  }

  static TechnicalSkillIdentity? resolveSkillIdentity(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;

    final rawKey = _baseNormalizedKey(clean);
    return _skillIdentityByAlias[rawKey] ??
        _skillIdentityByAlias[_aliases[rawKey]];
  }

  static String normalizedKey(String value) {
    final normalized = _baseNormalizedKey(value);
    final identity = resolveSkillIdentity(value);
    return identity?.normalizedName ?? _aliases[normalized] ?? normalized;
  }

  static String _baseNormalizedKey(String value) {
    return _removeAccents(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  static final Map<String, TechnicalSkillIdentity> _skillIdentityByAlias = {
    for (final skill in _technicalSkillIdentities) ...{
      _baseNormalizedKey(skill.displayName): skill,
      _baseNormalizedKey(skill.normalizedName): skill,
      for (final alias in skill.aliases) _baseNormalizedKey(alias): skill,
    },
  };

  static const List<TechnicalSkillIdentity> _technicalSkillIdentities = [
    TechnicalSkillIdentity(
      skillId: 'submission.armbar',
      displayName: 'Armbar',
      normalizedName: 'armbar',
      aliases: ['Armbar', 'Armlock', 'Chave de braço'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.omoplata',
      displayName: 'Omoplata',
      normalizedName: 'omoplata',
      aliases: ['Omoplata'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.kimura',
      displayName: 'Kimura',
      normalizedName: 'kimura',
      aliases: ['Kimura'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.americana',
      displayName: 'Americana',
      normalizedName: 'americana',
      aliases: ['Americana', 'Keylock'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.rear_naked_choke',
      displayName: 'Mata-Leão',
      normalizedName: 'rear naked choke',
      aliases: ['Mata-Leão', 'Mata Leão', 'Rear Naked Choke', 'RNC'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.triangle_choke',
      displayName: 'Triângulo',
      normalizedName: 'triangle choke',
      aliases: ['Triângulo', 'Triangulo', 'Triangle', 'Triangle Choke'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.guillotine',
      displayName: 'Guilhotina',
      normalizedName: 'guillotine',
      aliases: ['Guilhotina', 'Guillotine', 'Arm-in Guillotine'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.ezekiel',
      displayName: 'Ezequiel',
      normalizedName: 'ezekiel',
      aliases: ['Ezequiel', 'Ezekiel', 'Ezekiel Choke'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.anaconda_choke',
      displayName: 'Anaconda',
      normalizedName: 'anaconda',
      aliases: ['Anaconda', 'Anaconda Choke'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.bow_and_arrow_choke',
      displayName: 'Arco e Flecha',
      normalizedName: 'bow and arrow',
      aliases: ['Arco e Flecha', 'Bow and Arrow', 'Bow and Arrow Choke'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'submission.estima_lock',
      displayName: 'Estima Lock',
      normalizedName: 'estima lock',
      aliases: ['Estima Lock'],
      category: JiuJitsuSkillCategory.submissions,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.side_control',
      displayName: 'Controle Lateral',
      normalizedName: 'side control',
      aliases: ['Controle Lateral', '100 Quilos', 'Cem Quilos', 'Side Control'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.mount',
      displayName: 'Montada',
      normalizedName: 'mount',
      aliases: ['Montada', 'Mount', 'Montada Alta', 'Montada Técnica'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.back_control',
      displayName: 'Costas',
      normalizedName: 'back control',
      aliases: ['Costas', 'Back Control', 'Costas com ganchos'],
      category: JiuJitsuSkillCategory.back,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.north_south',
      displayName: 'Norte-Sul',
      normalizedName: 'north south',
      aliases: ['Norte-Sul', 'Norte Sul', 'North South'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.knee_on_belly',
      displayName: 'Joelho na Barriga',
      normalizedName: 'knee on belly',
      aliases: ['Joelho na Barriga', 'Knee on Belly'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.crucifix',
      displayName: 'Crucifixo',
      normalizedName: 'crucifix',
      aliases: ['Crucifixo', 'Crucifix'],
      category: JiuJitsuSkillCategory.back,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.seatbelt',
      displayName: 'Seatbelt',
      normalizedName: 'seatbelt',
      aliases: ['Seatbelt', 'Cinto de segurança', 'Cinto de seguranca'],
      category: JiuJitsuSkillCategory.back,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.crossface',
      displayName: 'Crossface',
      normalizedName: 'crossface',
      aliases: ['Crossface'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.underhook_control',
      displayName: 'Underhook de Controle',
      normalizedName: 'underhook control',
      aliases: ['Underhook de Controle', 'Underhook Control'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'control.top_pressure',
      displayName: 'Pressão por cima',
      normalizedName: 'top pressure',
      aliases: ['Pressão', 'Pressao', 'Pressão por cima', 'Controle por cima'],
      category: JiuJitsuSkillCategory.mount,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.guard_pass',
      displayName: 'Passagem de Guarda',
      normalizedName: 'guard pass',
      aliases: ['Passagem', 'Passagem de Guarda', 'Guard Pass'],
      category: JiuJitsuSkillCategory.passing,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.knee_slice',
      displayName: 'Knee Slice',
      normalizedName: 'knee slice',
      aliases: ['Knee Slice', 'Corte do joelho'],
      category: JiuJitsuSkillCategory.passing,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.toreando',
      displayName: 'Torreando',
      normalizedName: 'toreando',
      aliases: ['Torreando', 'Toreando'],
      category: JiuJitsuSkillCategory.passing,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.leg_drag',
      displayName: 'Leg Drag',
      normalizedName: 'leg drag',
      aliases: ['Leg Drag'],
      category: JiuJitsuSkillCategory.passing,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.sweep',
      displayName: 'Raspagem',
      normalizedName: 'sweep',
      aliases: ['Raspagem', 'Sweep', 'Raspagem Tesoura', 'Butterfly Sweep'],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.coyote_sweep',
      displayName: 'Raspagem Coyote',
      normalizedName: 'coyote sweep',
      aliases: ['Raspagem Coyote', 'Coyote Sweep'],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.takedown',
      displayName: 'Queda',
      normalizedName: 'takedown',
      aliases: ['Queda', 'Takedown', 'Single Leg', 'Double Leg', 'Baiana'],
      category: JiuJitsuSkillCategory.takedowns,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.technical_stand_up',
      displayName: 'Technical Stand Up',
      normalizedName: 'technical stand up',
      aliases: ['Technical Stand Up', 'Levantada técnica', 'Levantada tecnica'],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.north_south_escape',
      displayName: 'Saída do Norte-Sul',
      normalizedName: 'north south escape',
      aliases: [
        'Saída do Norte-Sul',
        'Saida do Norte-Sul',
        'North South Escape',
      ],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.back_take',
      displayName: 'Entrada para Costas',
      normalizedName: 'back take',
      aliases: ['Entrada para Costas', 'Back Take', 'Transição para Costas'],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'transition.mount_to_back',
      displayName: 'Transição Montada/Costas',
      normalizedName: 'mount to back transition',
      aliases: [
        'Transição Montada/Costas',
        'Transição para Montada',
        'Transição para Costas',
      ],
      category: JiuJitsuSkillCategory.escapes,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.closed_guard',
      displayName: 'Guarda Fechada',
      normalizedName: 'closed guard',
      aliases: ['Guarda Fechada', 'Closed Guard'],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.open_guard',
      displayName: 'Guarda Aberta',
      normalizedName: 'open guard',
      aliases: ['Guarda Aberta', 'Open Guard'],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.half_guard',
      displayName: 'Meia Guarda',
      normalizedName: 'half guard',
      aliases: ['Meia Guarda', 'Half Guard'],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.guard_retention',
      displayName: 'Retenção de Guarda',
      normalizedName: 'guard retention',
      aliases: [
        'Retenção de Guarda',
        'Retencao de Guarda',
        'Manutenção da Guarda',
      ],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.defensive_guard_recovery',
      displayName: 'Reposição de Guarda Defensiva',
      normalizedName: 'defensive guard recovery',
      aliases: [
        'Reposição de Guarda Defensiva',
        'Reposicao de Guarda Defensiva',
      ],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.frames',
      displayName: 'Frames',
      normalizedName: 'frames',
      aliases: ['Frames', 'Frame'],
      category: JiuJitsuSkillCategory.defense,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.knee_shield',
      displayName: 'Knee Shield',
      normalizedName: 'knee shield',
      aliases: ['Knee Shield', 'Guarda Z'],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.granby',
      displayName: 'Granby',
      normalizedName: 'granby',
      aliases: ['Granby', 'Granby Roll'],
      category: JiuJitsuSkillCategory.defense,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.defensive_inversion',
      displayName: 'Inversão Defensiva',
      normalizedName: 'defensive inversion',
      aliases: ['Inversão Defensiva', 'Inversões Defensivas'],
      category: JiuJitsuSkillCategory.defense,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.half_guard_recovery',
      displayName: 'Recuperação de Meia Guarda',
      normalizedName: 'half guard recovery',
      aliases: ['Recuperação de Meia Guarda', 'Recuperacao de Meia Guarda'],
      category: JiuJitsuSkillCategory.guard,
    ),
    TechnicalSkillIdentity(
      skillId: 'retention.pass_defense',
      displayName: 'Defesa de Passagem',
      normalizedName: 'pass defense',
      aliases: ['Defesa de Passagem', 'Pass Defense'],
      category: JiuJitsuSkillCategory.defense,
    ),
  ];
  static const Map<String, String> _aliases = {
    'arm bar': 'armbar',
    'armlock': 'armbar',
    'chave de braco': 'armbar',
    'chave de braço': 'armbar',
    'mata leao': 'rear naked choke',
    'mata-leao': 'rear naked choke',
    'rnc': 'rear naked choke',
    'triangulo': 'triangle choke',
    'triangle': 'triangle choke',
    'guilhotina': 'guillotine',
    'ezequiel': 'ezekiel',
    'guarda fechada': 'closed guard',
    'closed guard': 'closed guard',
    'meia guarda': 'half guard',
    'half guard': 'half guard',
    'guarda aberta': 'open guard',
    'open guard': 'open guard',
    'guarda borboleta': 'butterfly guard',
    'montada': 'mount',
    'mount': 'mount',
    'costas': 'back control',
    'back control': 'back control',
    '100 quilos': 'side control',
    'cem quilos': 'side control',
    'controle lateral': 'side control',
    'norte sul': 'north south',
    'norte-sul': 'north south',
    'joelho na barriga': 'knee on belly',
    'crucifixo': 'crucifix',
    'crucifix': 'crucifix',
    'cinto de seguranca': 'seatbelt',
    'cinto de segurança': 'seatbelt',
    'underhook de controle': 'underhook control',
    'pressao': 'top pressure',
    'pressão': 'top pressure',
    'controle por cima': 'top pressure',
    'arco e flecha': 'bow and arrow',
    'estima lock': 'estima lock',
    'bow and arrow': 'bow and arrow',
    'bow and arrow choke': 'bow and arrow',
    'passagem': 'guard pass',
    'passagem de guarda': 'guard pass',
    'raspagem': 'sweep',
    'raspagem tesoura': 'sweep',
    'raspagem coyote': 'coyote sweep',
    'coyote sweep': 'coyote sweep',
    'butterfly sweep': 'sweep',
    'queda': 'takedown',
    'levantada tecnica': 'technical stand up',
    'levantada técnica': 'technical stand up',
    'saida do norte sul': 'north south escape',
    'saida do norte-sul': 'north south escape',
    'saída do norte-sul': 'north south escape',
    'north south escape': 'north south escape',
    'entrada para costas': 'back take',
    'transicao para costas': 'back take',
    'transição para costas': 'back take',
    'retencao de guarda': 'guard retention',
    'retenção de guarda': 'guard retention',
    'manutencao da guarda': 'guard retention',
    'manutenção da guarda': 'guard retention',
    'reposicao de guarda defensiva': 'defensive guard recovery',
    'reposição de guarda defensiva': 'defensive guard recovery',
    'recuperacao de meia guarda': 'half guard recovery',
    'recuperação de meia guarda': 'half guard recovery',
    'defesa de passagem': 'pass defense',
  };

  static const _retentionTerms = [
    'guard retention',
    'retencao de guarda',
    'manutencao da guarda',
    'defensive guard recovery',
    'reposicao de guarda defensiva',
    'pass defense',
    'defesa de passagem',
    'frames',
    'frame',
    'knee shield',
    'granby',
    'defensive inversion',
    'inversao defensiva',
    'inversoes defensivas',
    'half guard recovery',
    'closed guard',
    'open guard',
    'half guard',
    'recuperacao de meia guarda',
  ];
  static const _controlTerms = [
    'side control',
    '100 quilos',
    'cem quilos',
    'controle lateral',
    'north south',
    'norte sul',
    'knee on belly',
    'joelho na barriga',
    'mount',
    'montada',
    'back control',
    'costas',
    'seatbelt',
    'crossface',
    'underhook control',
    'underhook de controle',
    'top pressure',
    'pressao',
    'controle por cima',
    'crucifix',
    'crucifixo',
  ];
  static const _transitionTerms = [
    'guard pass',
    'passagem',
    'passagem de guarda',
    'sweep',
    'raspagem',
    'takedown',
    'queda',
    'reposicao',
    'reposicao de guarda',
    'technical stand up',
    'levantada tecnica',
    'knee slice',
    'torreando',
    'toreando',
    'leg drag',
    'back take',
    'entrada para costas',
    'transicao para montada',
    'transicao para costas',
    'mount to back transition',
    'coyote sweep',
    'north south escape',
  ];
  static const _guardTerms = [
    'guarda',
    'closed guard',
    'open guard',
    'spider guard',
    'de la riva',
    'half guard',
    'butterfly guard',
    'worm guard',
  ];
  static const _passingTerms = [
    'passagem',
    'passagem de guarda',
    'guard pass',
    'knee slice',
    'torreando',
    'toreando',
    'leg drag',
    'pass',
  ];
  static const _takedownTerms = [
    'queda',
    'takedown',
    'single leg',
    'double leg',
    'ankle pick',
    'baiana',
  ];
  static const _mountTerms = ['montada', 'mount'];
  static const _backTerms = ['costas', 'back', 'back control'];
  static const _submissionTerms = [
    'armbar',
    'armlock',
    'omoplata',
    'kimura',
    'americana',
    'rear naked choke',
    'mata leao',
    'triangulo',
    'triangle choke',
    'guilhotina',
    'guillotine',
    'ezequiel',
    'ezekiel',
    'relogio',
    'anaconda',
    'd arce',
    'darce',
    'peruvian',
    'heel hook',
    'kneebar',
    'toe hold',
    'bow and arrow',
    'estima lock',
    'botinha',
    'chave de pe',
  ];
  static const _escapeTerms = ['escape', 'saida', 'fuga', 'technical stand up'];
  static const _defenseTerms = ['defesa', 'bloqueio', 'prevencao'];
}
