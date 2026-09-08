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
      academyId:
          mappedAcademyId == null || mappedAcademyId.isEmpty
              ? academyId
              : mappedAcademyId,
      academyName: (map['academyName'] ?? map['name'] ?? '').toString().trim(),
      role: role,
      isActive: map['isActive'] != false,
    );
  }
}

enum MembershipQueryStatus {
  loading,
  confirmedEmpty,
  confirmedActive,
  unavailable,
  permissionDenied,
  error,
}

class MembershipQuerySnapshot {
  final MembershipQueryStatus status;
  final List<AcademyMembership> memberships;
  final Object? error;
  final StackTrace? stackTrace;

  const MembershipQuerySnapshot({
    required this.status,
    this.memberships = const <AcademyMembership>[],
    this.error,
    this.stackTrace,
  });

  factory MembershipQuerySnapshot.confirmed(
    List<AcademyMembership> memberships,
  ) {
    final copiedMemberships = List<AcademyMembership>.unmodifiable(memberships);
    final hasActiveMembership = copiedMemberships.any(
      (membership) => membership.isActive,
    );

    return MembershipQuerySnapshot(
      status:
          hasActiveMembership
              ? MembershipQueryStatus.confirmedActive
              : MembershipQueryStatus.confirmedEmpty,
      memberships: copiedMemberships,
    );
  }

  factory MembershipQuerySnapshot.unavailable(Object error) {
    return MembershipQuerySnapshot(
      status: MembershipQueryStatus.unavailable,
      error: error,
    );
  }

  factory MembershipQuerySnapshot.permissionDenied(Object error) {
    return MembershipQuerySnapshot(
      status: MembershipQueryStatus.permissionDenied,
      error: error,
    );
  }

  factory MembershipQuerySnapshot.failed(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    return MembershipQuerySnapshot(
      status: MembershipQueryStatus.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  List<AcademyMembership> get activeMemberships =>
      memberships.where((membership) => membership.isActive).toList();

  bool get isConfirmed =>
      status == MembershipQueryStatus.confirmedEmpty ||
      status == MembershipQueryStatus.confirmedActive;

  bool get hasActiveMembership =>
      status == MembershipQueryStatus.confirmedActive &&
      activeMemberships.isNotEmpty;

  bool get isIndeterminate =>
      status == MembershipQueryStatus.loading ||
      status == MembershipQueryStatus.unavailable ||
      status == MembershipQueryStatus.permissionDenied ||
      status == MembershipQueryStatus.error;
}
