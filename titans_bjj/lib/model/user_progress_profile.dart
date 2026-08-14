import 'package:cloud_firestore/cloud_firestore.dart';
import 'grading_rules.dart';

class UserProgressProfile {
  final DateTime beltStartAt;

  // TODO migration: currentBelt/currentDegree are legacy cache fields.
  // Canonical graduation lives in academies/{academyId}/users/{uid}.
  final BeltColor currentBelt;
  final int currentDegree;

  /// Opcional: a academia pode definir uma estimativa propria para essa faixa.
  final int? estimatedSessionsInBelt;

  /// Metricas derivadas de treinos reais. Nao sao fonte de graduacao.
  final int? totalTrainingSessions;
  final int? monthTrainingSessions;
  final int? yearTrainingSessions;
  final int? recentTrainingSessions;
  final double? recentTrainingFrequency;

  const UserProgressProfile({
    required this.beltStartAt,
    required this.currentBelt,
    required this.currentDegree,
    this.estimatedSessionsInBelt,
    this.totalTrainingSessions,
    this.monthTrainingSessions,
    this.yearTrainingSessions,
    this.recentTrainingSessions,
    this.recentTrainingFrequency,
  });

  UserProgressProfile copyWith({
    DateTime? beltStartAt,
    BeltColor? currentBelt,
    int? currentDegree,
    int? estimatedSessionsInBelt,
    int? totalTrainingSessions,
    int? monthTrainingSessions,
    int? yearTrainingSessions,
    int? recentTrainingSessions,
    double? recentTrainingFrequency,
  }) {
    return UserProgressProfile(
      beltStartAt: beltStartAt ?? this.beltStartAt,
      currentBelt: currentBelt ?? this.currentBelt,
      currentDegree: currentDegree ?? this.currentDegree,
      estimatedSessionsInBelt:
          estimatedSessionsInBelt ?? this.estimatedSessionsInBelt,
      totalTrainingSessions:
          totalTrainingSessions ?? this.totalTrainingSessions,
      monthTrainingSessions:
          monthTrainingSessions ?? this.monthTrainingSessions,
      yearTrainingSessions: yearTrainingSessions ?? this.yearTrainingSessions,
      recentTrainingSessions:
          recentTrainingSessions ?? this.recentTrainingSessions,
      recentTrainingFrequency:
          recentTrainingFrequency ?? this.recentTrainingFrequency,
    );
  }

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

  static double? _nullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory UserProgressProfile.fromMap(Map<String, dynamic> map) {
    return UserProgressProfile(
      beltStartAt: _dt(map['beltStartAt']),
      currentBelt: _beltFromString((map['currentBelt'] ?? 'white').toString()),
      currentDegree: _int(map['currentDegree'], fallback: 0),
      estimatedSessionsInBelt: _nullableInt(map['estimatedSessionsInBelt']),
      totalTrainingSessions: _nullableInt(map['totalTrainingSessions']),
      monthTrainingSessions: _nullableInt(map['monthTrainingSessions']),
      yearTrainingSessions: _nullableInt(map['yearTrainingSessions']),
      recentTrainingSessions: _nullableInt(map['recentTrainingSessions']),
      recentTrainingFrequency: _nullableDouble(map['recentTrainingFrequency']),
    );
  }

  Map<String, dynamic> toMap() => {
        'beltStartAt': Timestamp.fromDate(beltStartAt),
        'currentBelt': currentBelt.name,
        'currentDegree': currentDegree,
        if (estimatedSessionsInBelt != null)
          'estimatedSessionsInBelt': estimatedSessionsInBelt,
        if (totalTrainingSessions != null)
          'totalTrainingSessions': totalTrainingSessions,
        if (monthTrainingSessions != null)
          'monthTrainingSessions': monthTrainingSessions,
        if (yearTrainingSessions != null)
          'yearTrainingSessions': yearTrainingSessions,
        if (recentTrainingSessions != null)
          'recentTrainingSessions': recentTrainingSessions,
        if (recentTrainingFrequency != null)
          'recentTrainingFrequency': recentTrainingFrequency,
      };
}