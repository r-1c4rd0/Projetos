import 'package:cloud_firestore/cloud_firestore.dart';

enum TrainingPlace { academy, home, other }

class TrainingSession {
  static const applicationContextDrill = 'drill';
  static const applicationContextPositionalSparring = 'positionalSparring';
  static const applicationContextSparring = 'sparring';
  static const applicationContextCompetition = 'competition';
  static const applicationContextNotApplied = 'notApplied';

  static const techniqueOutcomeWorked = 'worked';
  static const techniqueOutcomeAlmost = 'almost';
  static const techniqueOutcomeFailed = 'failed';
  static const techniqueOutcomeDefended = 'defended';
  static const techniqueOutcomeNotTested = 'notTested';

  static const applicationContextLabels = <String, String>{
    applicationContextDrill: 'Drill',
    applicationContextPositionalSparring: 'Treino posicional',
    applicationContextSparring: 'Rola',
    applicationContextCompetition: 'Competicao',
    applicationContextNotApplied: 'Nao aplicada',
  };

  static const techniqueOutcomeLabels = <String, String>{
    techniqueOutcomeWorked: 'Funcionou',
    techniqueOutcomeAlmost: 'Quase funcionou',
    techniqueOutcomeFailed: 'Falhou',
    techniqueOutcomeDefended: 'Parceiro defendeu',
    techniqueOutcomeNotTested: 'Nao testada',
  };

  static String? applicationContextLabel(String? value) {
    final clean = _optionalString(value);
    if (clean == null) return null;
    return applicationContextLabels[clean] ?? clean;
  }

  static String? techniqueOutcomeLabel(String? value) {
    final clean = _optionalString(value);
    if (clean == null) return null;
    return techniqueOutcomeLabels[clean] ?? clean;
  }

  static bool isApplicationContextMeasured(String? value) {
    return value == applicationContextPositionalSparring ||
        value == applicationContextSparring ||
        value == applicationContextCompetition;
  }

  static bool isTechniqueOutcomeUseful(String? value) {
    final clean = _optionalString(value);
    return clean != null && clean != techniqueOutcomeNotTested;
  }

  static bool isTechniqueOutcomePositive(String? value) {
    return value == techniqueOutcomeWorked || value == techniqueOutcomeAlmost;
  }

  static bool isTechniqueOutcomeNeedsWork(String? value) {
    return value == techniqueOutcomeFailed || value == techniqueOutcomeDefended;
  }

  final String id;
  final DateTime date;
  final TrainingPlace place;
  final String? notes;

  /// Mapa alunoId -> pontuacao 1..5
  final Map<String, int> scores;

  final String? academyId;
  final String? uid;
  final String? source;
  final String? attendanceSessionId;
  final String? attendanceCheckInUid;
  final String? classType;
  final String? instructorUid;
  final String? instructorName;

  final String? position;
  final String? technique;
  final String? successes;
  final String? difficulties;
  final int? intensity;
  final String? debriefNotes;
  final String? applicationContext;
  final String? techniqueOutcome;

  TrainingSession({
    required this.id,
    required this.date,
    required this.place,
    this.notes,
    Map<String, int>? scores,
    this.academyId,
    this.uid,
    this.source,
    this.attendanceSessionId,
    this.attendanceCheckInUid,
    this.classType,
    this.instructorUid,
    this.instructorName,
    this.position,
    this.technique,
    this.successes,
    this.difficulties,
    this.intensity,
    this.debriefNotes,
    this.applicationContext,
    this.techniqueOutcome,
  }) : scores = scores ?? const {};

  TrainingSession copyWith({
    DateTime? date,
    TrainingPlace? place,
    String? notes,
    Map<String, int>? scores,
    String? academyId,
    String? uid,
    String? source,
    String? attendanceSessionId,
    String? attendanceCheckInUid,
    String? classType,
    String? instructorUid,
    String? instructorName,
    String? position,
    String? technique,
    String? successes,
    String? difficulties,
    int? intensity,
    String? debriefNotes,
    String? applicationContext,
    String? techniqueOutcome,
  }) {
    return TrainingSession(
      id: id,
      date: date ?? this.date,
      place: place ?? this.place,
      notes: notes ?? this.notes,
      scores: scores ?? this.scores,
      academyId: academyId ?? this.academyId,
      uid: uid ?? this.uid,
      source: source ?? this.source,
      attendanceSessionId: attendanceSessionId ?? this.attendanceSessionId,
      attendanceCheckInUid: attendanceCheckInUid ?? this.attendanceCheckInUid,
      classType: classType ?? this.classType,
      instructorUid: instructorUid ?? this.instructorUid,
      instructorName: instructorName ?? this.instructorName,
      position: position ?? this.position,
      technique: technique ?? this.technique,
      successes: successes ?? this.successes,
      difficulties: difficulties ?? this.difficulties,
      intensity: intensity ?? this.intensity,
      debriefNotes: debriefNotes ?? this.debriefNotes,
      applicationContext: applicationContext ?? this.applicationContext,
      techniqueOutcome: techniqueOutcome ?? this.techniqueOutcome,
    );
  }

  Map<String, dynamic> toMap({bool includeApplicationDeletes = false}) {
    return {
      'date': Timestamp.fromDate(date),
      'place': place.name,
      'notes': notes,
      'scores': scores,
      if (academyId != null) 'academyId': academyId,
      if (uid != null) 'uid': uid,
      if (source != null) 'source': source,
      if (attendanceSessionId != null)
        'attendanceSessionId': attendanceSessionId,
      if (attendanceCheckInUid != null)
        'attendanceCheckInUid': attendanceCheckInUid,
      if (classType != null) 'classType': classType,
      if (instructorUid != null) 'instructorUid': instructorUid,
      if (instructorName != null) 'instructorName': instructorName,
      if (position != null) 'position': position,
      if (technique != null) 'technique': technique,
      if (successes != null) 'successes': successes,
      if (difficulties != null) 'difficulties': difficulties,
      if (intensity != null) 'intensity': intensity,
      if (debriefNotes != null) 'debriefNotes': debriefNotes,
      if (applicationContext != null)
        'applicationContext': applicationContext
      else if (includeApplicationDeletes)
        'applicationContext': FieldValue.delete(),
      if (techniqueOutcome != null)
        'techniqueOutcome': techniqueOutcome
      else if (includeApplicationDeletes)
        'techniqueOutcome': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TrainingSession fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['date'];
    DateTime date;

    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else {
      date = DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    }

    final placeRaw = (data['place'] ?? 'academy').toString();
    final place = TrainingPlace.values.firstWhere(
      (e) => e.name == placeRaw,
      orElse: () => TrainingPlace.academy,
    );

    final notes = data['notes']?.toString();

    final rawScores = (data['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    final scores = <String, int>{};
    rawScores.forEach((k, v) {
      if (v is int) {
        scores[k] = v;
      } else {
        final n = int.tryParse(v.toString());
        if (n != null) scores[k] = n;
      }
    });

    return TrainingSession(
      id: id,
      date: date,
      place: place,
      notes: notes,
      scores: scores,
      academyId: data['academyId']?.toString(),
      uid: data['uid']?.toString(),
      source: data['source']?.toString(),
      attendanceSessionId: data['attendanceSessionId']?.toString(),
      attendanceCheckInUid: data['attendanceCheckInUid']?.toString(),
      classType: data['classType']?.toString(),
      instructorUid: data['instructorUid']?.toString(),
      instructorName: data['instructorName']?.toString(),
      position: _optionalString(data['position']),
      technique: _optionalString(data['technique']),
      successes: _optionalString(data['successes']),
      difficulties: _optionalString(data['difficulties']),
      intensity: _intensityFromValue(data['intensity']),
      debriefNotes: _optionalString(data['debriefNotes']),
      applicationContext: _optionalString(data['applicationContext']),
      techniqueOutcome: _optionalString(data['techniqueOutcome']),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _intensityFromValue(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 1 || parsed > 5) return null;
    return parsed;
  }
}
