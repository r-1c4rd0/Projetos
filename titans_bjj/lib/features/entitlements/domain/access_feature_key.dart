enum AccessFeatureKey {
  quickLogTraining,
  ownTrainingHistory,
  editOwnTraining,
  homeDynamicSummary,
  homeDeepInsights,
  gameMapFull,
  skillsExpandedDetail,
  progressAdvancedTrends,
  nutritionAdvancedInsights,
  exportReports,
  officialGraduation,
}

class AccessFeatureCatalog {
  final Set<AccessFeatureKey> freeFeatures;
  final Set<AccessFeatureKey> plusFeatures;

  const AccessFeatureCatalog({
    required this.freeFeatures,
    required this.plusFeatures,
  });

  bool isFree(AccessFeatureKey feature) => freeFeatures.contains(feature);

  bool isPlus(AccessFeatureKey feature) => plusFeatures.contains(feature);
}
