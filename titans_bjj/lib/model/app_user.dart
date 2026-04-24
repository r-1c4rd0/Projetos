import 'grading_rules.dart';

enum UserRole { admin, professor, athlete }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String academyId;
  final UserRole role;
  final BeltColor belt;
  final int degree;

  const AppUser({
    required this.uid,
    this.name = '',
    required this.email,
    required this.academyId,
    required this.role,
    this.belt = BeltColor.white,
    this.degree = 0,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final roleStr = (map['role'] ?? 'athlete') as String;
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.athlete,
    );
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '') as String,
      academyId: (map['academyId'] ?? 'default') as String,
      role: role,
      belt: beltColorFromString(map['belt']),
      degree: _degreeFromValue(map['degree']),
    );
  }

  Map<String, dynamic> toMap() => {
    if (name.isNotEmpty) 'name': name,
    'email': email,
    'academyId': academyId,
    'role': role.name,
    'belt': belt.name,
    'degree': degree,
  };

  static int _degreeFromValue(Object? value) {
    if (value is int) return value.clamp(0, 12).toInt();
    if (value is num) return value.toInt().clamp(0, 12).toInt();
    return (int.tryParse(value?.toString() ?? '') ?? 0).clamp(0, 12).toInt();
  }
}
