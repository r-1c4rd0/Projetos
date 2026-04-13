import 'package:cloud_firestore/cloud_firestore.dart';
import 'grading_rules.dart';

class UserProgressProfile {
  final DateTime beltStartAt;
  final BeltColor currentBelt;
  final int currentDegree;

  /// opcional: a academia pode definir uma estimativa própria para essa faixa
  final int? estimatedSessionsInBelt;

  const UserProgressProfile({
    required this.beltStartAt,
    required this.currentBelt,
    required this.currentDegree,
    this.estimatedSessionsInBelt,
  });

  static BeltColor _beltFromString(String s) {
    return BeltColor.values.firstWhere(
          (b) => b.name == s,
      orElse: () => BeltColor.white,
    );
  }

  static DateTime _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  factory UserProgressProfile.fromMap(Map<String, dynamic> map) {
    return UserProgressProfile(
      beltStartAt: _dt(map['beltStartAt']),
      currentBelt: _beltFromString((map['currentBelt'] ?? 'white').toString()),
      currentDegree: _int(map['currentDegree'], fallback: 0),
      estimatedSessionsInBelt: map.containsKey('estimatedSessionsInBelt')
          ? _int(map['estimatedSessionsInBelt'], fallback: 0)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'beltStartAt': Timestamp.fromDate(beltStartAt),
    'currentBelt': currentBelt.name,
    'currentDegree': currentDegree,
    if (estimatedSessionsInBelt != null)
      'estimatedSessionsInBelt': estimatedSessionsInBelt,
  };
}
