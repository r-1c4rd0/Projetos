import '../../../model/academy_membership.dart';
import '../../../model/app_user.dart';

class TechnicalScreenContext {
  final String actorUid;
  final String actorRole;
  final String targetUid;
  final String targetAcademyId;
  final String workspaceKey;
  final String membershipState;

  const TechnicalScreenContext({
    required this.actorUid,
    required this.actorRole,
    required this.targetUid,
    required this.targetAcademyId,
    required this.workspaceKey,
    required this.membershipState,
  });

  String get key => [
    actorUid,
    actorRole,
    targetUid,
    targetAcademyId,
    workspaceKey,
    membershipState,
  ].join('|');
}

class CoachEvaluationAuthorization {
  const CoachEvaluationAuthorization._();

  static bool canEvaluate({
    required AppUser? actor,
    required String targetUid,
    required String targetAcademyId,
    required String? activeAcademyId,
    required AcademyMembership? activeMembership,
    required MembershipQuerySnapshot? membershipSnapshot,
  }) {
    if (actor == null || membershipSnapshot == null) return false;
    if (!membershipSnapshot.hasActiveMembership) return false;

    final membership = activeMembership;
    if (membership == null || !membership.isActive) return false;

    final normalizedAcademyId = targetAcademyId.trim();
    final isCurrentAcademy =
        normalizedAcademyId.isNotEmpty &&
        activeAcademyId?.trim() == normalizedAcademyId &&
        membership.academyId.trim() == normalizedAcademyId;
    final isStaff =
        membership.role == UserRole.admin ||
        membership.role == UserRole.professor;
    final isConfirmedMembership = membershipSnapshot.activeMemberships.any(
      (confirmedMembership) =>
          confirmedMembership.academyId.trim() == normalizedAcademyId &&
          confirmedMembership.role == membership.role,
    );
    final isStudentTarget = actor.uid.trim() != targetUid.trim();

    return isCurrentAcademy &&
        isStaff &&
        isConfirmedMembership &&
        isStudentTarget;
  }
}

String coachEvaluationReviewStatusLabel({
  required int evaluationsCount,
  required int needsReviewCount,
}) {
  if (evaluationsCount == 0) return 'Sem avaliação registrada';
  if (needsReviewCount == 0) return 'Sem revisão sinalizada';
  return '$needsReviewCount p/ revisar';
}
