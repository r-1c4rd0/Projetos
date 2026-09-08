import 'access_feature_key.dart';
import 'entitlement_models.dart';

enum CommercialAccessReason {
  freeFeature,
  activeSubscription,
  activeCourtesy,
  entitlementsLoading,
  entitlementsUnknownOffline,
  entitlementsPermissionError,
  entitlementsUnavailable,
  differentOwner,
  noActiveGrant,
  featureNotInCatalog,
}

class CommercialAccessDecision {
  final AccessFeatureKey feature;
  final bool isAllowed;
  final CommercialAccessReason reason;
  final EntitlementPlan? requiredPlan;
  final EntitlementGrant? grant;

  const CommercialAccessDecision({
    required this.feature,
    required this.isAllowed,
    required this.reason,
    this.requiredPlan,
    this.grant,
  });
}

class CommercialAccessPolicy {
  final AccessFeatureCatalog catalog;

  const CommercialAccessPolicy({required this.catalog});

  CommercialAccessDecision evaluate({
    required String ownerUid,
    required AccessFeatureKey feature,
    required EntitlementSnapshot snapshot,
    required DateTime now,
  }) {
    if (catalog.isFree(feature)) {
      return CommercialAccessDecision(
        feature: feature,
        isAllowed: true,
        reason: CommercialAccessReason.freeFeature,
      );
    }

    if (!catalog.isPlus(feature)) {
      return CommercialAccessDecision(
        feature: feature,
        isAllowed: false,
        reason: CommercialAccessReason.featureNotInCatalog,
      );
    }

    if (snapshot.ownerUid != ownerUid) {
      return CommercialAccessDecision(
        feature: feature,
        isAllowed: false,
        reason: CommercialAccessReason.differentOwner,
        requiredPlan: EntitlementPlan.titansPlus,
      );
    }

    final indeterminateReason = _indeterminateReason(snapshot.state);
    if (indeterminateReason != null) {
      return CommercialAccessDecision(
        feature: feature,
        isAllowed: false,
        reason: indeterminateReason,
        requiredPlan: EntitlementPlan.titansPlus,
      );
    }

    for (final grant in snapshot.grants) {
      if (!grant.isValidFor(ownerUid: ownerUid, feature: feature, now: now)) {
        continue;
      }
      return CommercialAccessDecision(
        feature: feature,
        isAllowed: true,
        reason: grant.origin == EntitlementGrantOrigin.adminCourtesy
            ? CommercialAccessReason.activeCourtesy
            : CommercialAccessReason.activeSubscription,
        grant: grant,
      );
    }

    return CommercialAccessDecision(
      feature: feature,
      isAllowed: false,
      reason: CommercialAccessReason.noActiveGrant,
      requiredPlan: EntitlementPlan.titansPlus,
    );
  }

  CommercialAccessReason? _indeterminateReason(
    EntitlementSnapshotState state,
  ) {
    switch (state) {
      case EntitlementSnapshotState.loading:
        return CommercialAccessReason.entitlementsLoading;
      case EntitlementSnapshotState.unknownOffline:
        return CommercialAccessReason.entitlementsUnknownOffline;
      case EntitlementSnapshotState.errorPermission:
        return CommercialAccessReason.entitlementsPermissionError;
      case EntitlementSnapshotState.errorUnavailable:
        return CommercialAccessReason.entitlementsUnavailable;
      case EntitlementSnapshotState.confirmedFree:
      case EntitlementSnapshotState.confirmedPlus:
      case EntitlementSnapshotState.revokedOrExpired:
        return null;
    }
  }
}
