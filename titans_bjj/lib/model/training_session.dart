import 'package:cloud_firestore/cloud_firestore.dart';

enum TrainingPlace { academy, home, other }

class TrainingSession {
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
    );
  }

  Map<String, dynamic> toMap() {
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
    );
  }
}