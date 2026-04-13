enum UserRole { admin, professor, athlete }

class AppUser {
  final String uid;
  final String email;
  final String academyId;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.email,
    required this.academyId,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final roleStr = (map['role'] ?? 'athlete') as String;
    final role = UserRole.values.firstWhere(
          (r) => r.name == roleStr,
      orElse: () => UserRole.athlete,
    );
    return AppUser(
      uid: uid,
      email: (map['email'] ?? '') as String,
      academyId: (map['academyId'] ?? 'default') as String,
      role: role,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'academyId': academyId,
    'role': role.name,
  };
}
