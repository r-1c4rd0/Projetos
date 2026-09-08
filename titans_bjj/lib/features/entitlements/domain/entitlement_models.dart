import 'access_feature_key.dart';

enum EntitlementPlan { titansPlus, futureProduct }

enum EntitlementGrantOrigin { subscription, adminCourtesy }

enum EntitlementGrantStatus {
  active,
  pastDue,
  expired,
  revoked,
  canceled,
  unknown,
}

enum EntitlementSnapshotState {
  loading,
  confirmedFree,
  confirmedPlus,
  unknownOffline,
  errorPermission,
  errorUnavailable,
  revokedOrExpired,
}

class EntitlementGrant {
  final String ownerUid;
  final EntitlementPlan plan;
  final Set<AccessFeatureKey> features;
  final EntitlementGrantOrigin origin;
  final EntitlementGrantStatus status;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final String? grantId;
  final String? sourceRef;

  const EntitlementGrant({
    required this.ownerUid,
    required this.plan,
    this.features = const <AccessFeatureKey>{},
    required this.origin,
    required this.status,
    required this.startsAt,
    this.expiresAt,
    this.grantId,
    this.sourceRef,
  });

  bool isValidFor({
    required String ownerUid,
    required AccessFeatureKey feature,
    required DateTime now,
  }) {
    if (this.ownerUid != ownerUid) return false;
    if (status != EntitlementGrantStatus.active) return false;
    if (startsAt.isAfter(now)) return false;
    if (expiresAt != null && !now.isBefore(expiresAt!)) return false;
    if (origin == EntitlementGrantOrigin.subscription && expiresAt == null) {
      return false;
    }
    if (plan == EntitlementPlan.futureProduct) return false;
    return plan == EntitlementPlan.titansPlus || features.contains(feature);
  }
}

class EntitlementSnapshot {
  final String ownerUid;
  final EntitlementSnapshotState state;
  final List<EntitlementGrant> grants;
  final DateTime? confirmedAt;
  final String? staleReason;

  const EntitlementSnapshot({
    required this.ownerUid,
    required this.state,
    this.grants = const <EntitlementGrant>[],
    this.confirmedAt,
    this.staleReason,
  });

  bool get isConfirmed {
    return state == EntitlementSnapshotState.confirmedFree ||
        state == EntitlementSnapshotState.confirmedPlus ||
        state == EntitlementSnapshotState.revokedOrExpired;
  }
}
