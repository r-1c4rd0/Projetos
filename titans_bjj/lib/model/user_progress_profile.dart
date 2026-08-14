import 'package:cloud_firestore/cloud_firestore.dart';
import 'grading_rules.dart';

class UserProgressProfile {
  final DateTime beltStartAt;

  // TODO migration: currentBelt/currentDegree are legacy cache fields.
  // Canonical graduation lives in academies/{academyId}/users/{uid}.
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
    final normalized = s.trim().toLowerCase().replaceFirst('beltcolor.', '');
    const aliases = {
      'branca': BeltColor.white,
      'azul': BeltColor.blue,
      'roxa': BeltColor.purple,
      'marrom': BeltColor.brown,
      'preta': BeltColor.black,
    };

    final alias = aliases[normalized];
    if (alias != null) return alias;

    return BeltColor.values.firstWhere(
      (b) => b.name == normalized,
      orElse: () => BeltColor.white,
    );
  }

  static DateTime _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static int? _nullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory UserProgressProfile.fromMap(Map<String, dynamic> map) {
    return UserProgressProfile(
      beltStartAt: _dt(map['beltStartAt']),
      currentBelt: _beltFromString((map['currentBelt'] ?? 'white').toString()),
      currentDegree: _int(map['currentDegree'], fallback: 0),
      estimatedSessionsInBelt: _nullableInt(map['estimatedSessionsInBelt']),
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
