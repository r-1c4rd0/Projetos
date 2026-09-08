import '../model/academy_membership.dart';

enum MembershipSessionResolutionKind {
  academySelectionRequired,
  academyContextResolved,
  confirmedNoActiveMembership,
  membershipUnavailable,
  membershipPermissionDenied,
  membershipError,
}

class MembershipSessionResolution {
  final MembershipSessionResolutionKind kind;
  final List<AcademyMembership> memberships;
  final List<AcademyMembership> activeMemberships;
  final AcademyMembership? activeMembership;

  const MembershipSessionResolution({
    required this.kind,
    this.memberships = const <AcademyMembership>[],
    this.activeMemberships = const <AcademyMembership>[],
    this.activeMembership,
  });

  bool get canUseLegacyFallback =>
      kind == MembershipSessionResolutionKind.confirmedNoActiveMembership;

  bool get blocksAcademyContext =>
      kind == MembershipSessionResolutionKind.membershipUnavailable ||
      kind == MembershipSessionResolutionKind.membershipPermissionDenied ||
      kind == MembershipSessionResolutionKind.membershipError;
}

class MembershipSessionAttempt {
  final String uid;
  final String email;
  final int generation;

  const MembershipSessionAttempt({
    required this.uid,
    required this.email,
    required this.generation,
  });

  bool matches({
    required String currentUid,
    required String currentEmail,
    required int currentGeneration,
  }) {
    return uid == currentUid &&
        email == currentEmail &&
        generation == currentGeneration;
  }
}

class MembershipSessionResolver {
  const MembershipSessionResolver();

  MembershipSessionResolution resolve({
    required MembershipQuerySnapshot snapshot,
    String? selectedAcademyId,
  }) {
    switch (snapshot.status) {
      case MembershipQueryStatus.confirmedActive:
        final activeMemberships = snapshot.activeMemberships;
        if (activeMemberships.length > 1 && selectedAcademyId == null) {
          return MembershipSessionResolution(
            kind: MembershipSessionResolutionKind.academySelectionRequired,
            memberships: snapshot.memberships,
            activeMemberships: activeMemberships,
          );
        }

        final activeMembership = _resolveActiveMembership(
          activeMemberships,
          selectedAcademyId,
        );
        if (activeMembership == null) {
          return MembershipSessionResolution(
            kind: MembershipSessionResolutionKind.confirmedNoActiveMembership,
            memberships: snapshot.memberships,
            activeMemberships: activeMemberships,
          );
        }
        return MembershipSessionResolution(
          kind: MembershipSessionResolutionKind.academyContextResolved,
          memberships: snapshot.memberships,
          activeMemberships: activeMemberships,
          activeMembership: activeMembership,
        );
      case MembershipQueryStatus.confirmedEmpty:
        return MembershipSessionResolution(
          kind: MembershipSessionResolutionKind.confirmedNoActiveMembership,
          memberships: snapshot.memberships,
        );
      case MembershipQueryStatus.unavailable:
        return const MembershipSessionResolution(
          kind: MembershipSessionResolutionKind.membershipUnavailable,
        );
      case MembershipQueryStatus.permissionDenied:
        return const MembershipSessionResolution(
          kind: MembershipSessionResolutionKind.membershipPermissionDenied,
        );
      case MembershipQueryStatus.loading:
      case MembershipQueryStatus.error:
        return const MembershipSessionResolution(
          kind: MembershipSessionResolutionKind.membershipError,
        );
    }
  }

  AcademyMembership? _resolveActiveMembership(
    List<AcademyMembership> activeMemberships,
    String? selectedAcademyId,
  ) {
    if (activeMemberships.isEmpty) return null;
    if (selectedAcademyId != null) {
      for (final membership in activeMemberships) {
        if (membership.academyId == selectedAcademyId) return membership;
      }
    }
    return activeMemberships.first;
  }
}
