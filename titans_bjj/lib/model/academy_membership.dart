import 'app_user.dart';

class AcademyMembership {
  final String academyId;
  final String academyName;
  final UserRole role;
  final bool isActive;

  const AcademyMembership({
    required this.academyId,
    this.academyName = '',
    required this.role,
    this.isActive = true,
  });

  factory AcademyMembership.fromMap(
    String academyId,
    Map<String, dynamic> map,
  ) {
    final mappedAcademyId = map['academyId']?.toString().trim();
    final roleName = map['role']?.toString().trim();
    final role = UserRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => UserRole.athlete,
    );

    return AcademyMembership(
      academyId: mappedAcademyId == null || mappedAcademyId.isEmpty
          ? academyId
          : mappedAcademyId,
      academyName: (map['academyName'] ?? map['name'] ?? '').toString().trim(),
      role: role,
      isActive: map['isActive'] != false,
    );
  }
}