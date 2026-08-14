import 'package:cloud_firestore/cloud_firestore.dart';

import 'grading_rules.dart';

enum AttendanceSessionStatus {
  open,
  closed,
  cancelled,
}

enum AttendanceCheckInSource {
  manual,
  qr,
  nfc,
}

class AttendanceSession {
  final String id;
  final String academyId;
  final String title;
  final String classType;
  final String instructorUid;
  final String instructorName;
  final DateTime startsAt;
  final DateTime endsAt;
  final AttendanceSessionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AttendanceSession({
    required this.id,
    required this.academyId,
    required this.title,
    required this.classType,
    required this.instructorUid,
    required this.instructorName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceSession.fromDoc(
    String id,
    Map<String, dynamic> map,
  ) {
    return AttendanceSession(
      id: (map['id'] ?? id).toString(),
      academyId: (map['academyId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      classType: (map['classType'] ?? '').toString(),
      instructorUid: (map['instructorUid'] ?? '').toString(),
      instructorName: (map['instructorName'] ?? '').toString(),
      startsAt: _dateTimeFromValue(map['startsAt']),
      endsAt: _dateTimeFromValue(map['endsAt']),
      status: _sessionStatusFromValue(map['status']),
      createdAt: _nullableDateTimeFromValue(map['createdAt']),
      updatedAt: _nullableDateTimeFromValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'academyId': academyId,
      'title': title,
      'classType': classType,
      'instructorUid': instructorUid,
      'instructorName': instructorName,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'status': status.name,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

class AttendanceCheckIn {
  final String uid;
  final String studentName;
  final BeltColor belt;
  final int degree;
  final AttendanceCheckInSource source;
  final DateTime? checkedInAt;
  final String createdByUid;
  final DateTime? createdAt;

  const AttendanceCheckIn({
    required this.uid,
    required this.studentName,
    required this.belt,
    required this.degree,
    required this.source,
    required this.checkedInAt,
    required this.createdByUid,
    this.createdAt,
  });

  factory AttendanceCheckIn.fromDoc(
    String uid,
    Map<String, dynamic> map,
  ) {
    return AttendanceCheckIn(
      uid: (map['uid'] ?? uid).toString(),
      studentName: (map['studentName'] ?? '').toString(),
      belt: beltColorFromString(map['belt']),
      degree: _degreeFromValue(map['degree']),
      source: _checkInSourceFromValue(map['source']),
      checkedInAt: _nullableDateTimeFromValue(map['checkedInAt']),
      createdByUid: (map['createdByUid'] ?? '').toString(),
      createdAt: _nullableDateTimeFromValue(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'studentName': studentName,
      'belt': belt.name,
      'degree': degree,
      'source': source.name,
      if (checkedInAt != null)
        'checkedInAt': Timestamp.fromDate(checkedInAt!),
      'createdByUid': createdByUid,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}

AttendanceSessionStatus _sessionStatusFromValue(Object? value) {
  final normalized = value.toString().trim().toLowerCase();
  return AttendanceSessionStatus.values.firstWhere(
    (status) => status.name == normalized,
    orElse: () => AttendanceSessionStatus.open,
  );
}

AttendanceCheckInSource _checkInSourceFromValue(Object? value) {
  final normalized = value.toString().trim().toLowerCase();
  return AttendanceCheckInSource.values.firstWhere(
    (source) => source.name == normalized,
    orElse: () => AttendanceCheckInSource.manual,
  );
}

DateTime _dateTimeFromValue(Object? value) {
  return _nullableDateTimeFromValue(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.tryParse(value.toString());
}

int _degreeFromValue(Object? value) {
  if (value is int) return value.clamp(0, 12).toInt();
  if (value is num) return value.toInt().clamp(0, 12).toInt();
  return (int.tryParse(value?.toString() ?? '') ?? 0).clamp(0, 12).toInt();
}
