class TrainingOperationContext {
  final String actorUid;
  final String academyId;
  final String targetUid;

  const TrainingOperationContext({
    required this.actorUid,
    required this.academyId,
    required this.targetUid,
  });

  bool matches({
    required String? actorUid,
    required String? academyId,
    required String? targetUid,
  }) {
    return this.actorUid == actorUid &&
        this.academyId == academyId &&
        this.targetUid == targetUid;
  }

  String sessionKey(String sessionId) => '$academyId|$targetUid|$sessionId';
}
