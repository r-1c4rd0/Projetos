import '../model/training_session.dart';
import 'training_session_composition_fields.dart';

/// Immutable data prepared by the training form before submission.
///
/// This object only assembles sessions and stable recurrence identifiers. The
/// screen remains responsible for validation, user confirmation and writes.
class TrainingSessionFormData {
  final String? notes;
  final String? position;
  final String? technique;
  final List<TrainingTechniqueEntry> techniqueEntries;
  final String? successes;
  final String? difficulties;
  final int? intensity;
  final String? debriefNotes;
  final String? applicationContext;
  final String? techniqueOutcome;
  final TrainingSessionCompositionInput composition;
  final String compositionFingerprint;

  const TrainingSessionFormData({
    required this.notes,
    required this.position,
    required this.technique,
    required this.techniqueEntries,
    required this.successes,
    required this.difficulties,
    required this.intensity,
    required this.debriefNotes,
    required this.applicationContext,
    required this.techniqueOutcome,
    required this.composition,
    required this.compositionFingerprint,
  });

  TrainingSession buildSingleSession({
    required String id,
    required DateTime date,
    required TrainingSessionStatus status,
    required String academyId,
    required String uid,
    required DateTime now,
    TrainingSession? existing,
  }) {
    return TrainingSession(
      id: id,
      date: date,
      place: existing?.place ?? TrainingPlace.academy,
      notes: notes,
      totalDurationMinutes: composition.totalDurationMinutes,
      totalDurationIsEstimated: composition.totalDurationIsEstimated,
      studiedTechniques: composition.studiedTechniques,
      rolls: composition.rolls,
      scores: existing?.scores,
      academyId: existing?.academyId ?? academyId,
      uid: existing?.uid ?? uid,
      source: existing?.source,
      attendanceSessionId: existing?.attendanceSessionId,
      attendanceCheckInUid: existing?.attendanceCheckInUid,
      classType: existing?.classType,
      instructorUid: existing?.instructorUid,
      instructorName: existing?.instructorName,
      status: status,
      plannedFor:
          status == TrainingSessionStatus.planned ? date : existing?.plannedFor,
      effectiveDate:
          status == TrainingSessionStatus.completed
              ? date
              : existing?.effectiveDate,
      confirmedAt:
          status == TrainingSessionStatus.completed
              ? existing?.confirmedAt ?? now
              : existing?.confirmedAt,
      position: position,
      technique: technique,
      techniques: techniqueEntries,
      successes: successes,
      difficulties: difficulties,
      intensity: intensity,
      debriefNotes: debriefNotes,
      applicationContext: applicationContext,
      techniqueOutcome: techniqueOutcome,
    );
  }

  TrainingSession buildRecurringSession({
    required String id,
    required DateTime date,
    required TrainingSessionStatus status,
    required String academyId,
    required String uid,
    required DateTime now,
  }) {
    return TrainingSession(
      id: id,
      date: date,
      place: TrainingPlace.academy,
      academyId: academyId,
      uid: uid,
      status: status,
      plannedFor: status == TrainingSessionStatus.planned ? date : null,
      effectiveDate: status == TrainingSessionStatus.completed ? date : null,
      confirmedAt: status == TrainingSessionStatus.completed ? now : null,
      notes: notes,
      totalDurationMinutes: composition.totalDurationMinutes,
      totalDurationIsEstimated: composition.totalDurationIsEstimated,
      studiedTechniques: composition.studiedTechniques,
      rolls: composition.rolls,
      position: position,
      technique: technique,
      techniques: techniqueEntries,
      successes: successes,
      difficulties: difficulties,
      intensity: intensity,
      debriefNotes: debriefNotes,
      applicationContext: applicationContext,
      techniqueOutcome: techniqueOutcome,
    );
  }

  String recurringSessionId({
    required String academyId,
    required String uid,
    required DateTime occurrenceDate,
    required TrainingSessionStatus status,
  }) {
    final parts = <String>[
      status.name,
      intensity?.toString() ?? '',
      compositionFingerprint,
      notes ?? '',
      successes ?? '',
      difficulties ?? '',
      debriefNotes ?? '',
      applicationContext ?? '',
      techniqueOutcome ?? '',
      for (final entry in techniqueEntries) ...[
        entry.position ?? '',
        entry.technique,
        entry.category ?? '',
        entry.side.name,
        entry.applicationContext ?? '',
        entry.techniqueOutcome ?? '',
        entry.notes ?? '',
      ],
    ];
    final fingerprint = _stableHash(parts.join('|'));
    final timestamp = occurrenceDate.microsecondsSinceEpoch;
    return 'rec_${_docSafe(academyId)}_${_docSafe(uid)}_${status.name}_${timestamp}_$fingerprint';
  }

  static String _stableHash(String value) {
    const fnvOffset = 0x811c9dc5;
    const fnvPrime = 0x01000193;
    var hash = fnvOffset;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _docSafe(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
