import 'package:flutter/material.dart';

import '../features/technical_domain/domain/technical_taxonomy.dart';
import '../model/training_session.dart';
import 'training_session_composition_fields.dart';

enum QuickLogInputField {
  technique,
  position,
  place,
  intensity,
  applicationContext,
  outcome,
  notes,
  duration,
  rolls,
  studiedTechniques,
}

class QuickLogFormController {
  final TextEditingController notes = TextEditingController();
  final TextEditingController customTechnique = TextEditingController();
  final TextEditingController customPosition = TextEditingController();
  final TrainingSessionCompositionController composition =
      TrainingSessionCompositionController();

  final List<String> recentTechniques;
  final List<String> recentPositions;
  final List<TrainingStudiedTechnique> studiedTechniqueCatalog;
  final bool hasRecentSession;

  TrainingPlace? place;
  int? intensity;
  String? applicationContext;
  String? outcome;
  String? technique;
  String? position;

  final Set<QuickLogInputField> _explicitlyProvidedFields = {};

  QuickLogFormController(List<TrainingSession> recentSessions)
    : recentTechniques = _recentTechniques(recentSessions),
      recentPositions = _recentPositions(recentSessions),
      studiedTechniqueCatalog = _studiedTechniques(recentSessions),
      hasRecentSession = recentSessions.isNotEmpty;

  String? validate() {
    final compositionError = composition.validate();
    if (compositionError != null) return compositionError;
    if (place == null) return 'Selecione o local do treino.';
    return null;
  }

  TrainingSession buildSession({
    required String id,
    required String academyId,
    required String uid,
    required DateTime now,
  }) {
    final selectedPlace = place;
    if (selectedPlace == null) {
      throw StateError('O formulário deve ser validado antes da montagem.');
    }

    final selectedTechnique = _clean(technique) ?? _clean(customTechnique.text);
    final selectedPosition = _clean(position) ?? _clean(customPosition.text);
    final observation = _clean(notes.text);
    final compositionValue = composition.value();
    final day = DateTime(now.year, now.month, now.day);
    final techniqueEntries =
        selectedTechnique == null
            ? const <TrainingTechniqueEntry>[]
            : [
              TrainingTechniqueEntry(
                technique: selectedTechnique,
                position: selectedPosition,
                applicationContext: applicationContext,
                techniqueOutcome: outcome,
              ),
            ];

    return TrainingSession(
      id: id,
      date: day,
      place: selectedPlace,
      notes: observation,
      totalDurationMinutes: compositionValue.totalDurationMinutes,
      totalDurationIsEstimated: compositionValue.totalDurationIsEstimated,
      studiedTechniques: compositionValue.studiedTechniques,
      rolls: compositionValue.rolls,
      academyId: academyId,
      uid: uid,
      status: TrainingSessionStatus.completed,
      effectiveDate: day,
      confirmedAt: now,
      position: selectedPosition,
      technique: selectedTechnique,
      techniques: techniqueEntries,
      intensity: intensity,
      debriefNotes: observation,
      applicationContext: applicationContext,
      techniqueOutcome: outcome,
    );
  }

  Set<QuickLogInputField> get explicitlyProvidedFields {
    return {
      ..._explicitlyProvidedFields,
      if (_clean(customTechnique.text) != null) QuickLogInputField.technique,
      if (_clean(customPosition.text) != null) QuickLogInputField.position,
      if (_clean(notes.text) != null) QuickLogInputField.notes,
    };
  }

  void selectTechnique(String value) {
    technique = value;
    _explicitlyProvidedFields.add(QuickLogInputField.technique);
  }

  void selectPosition(String value) {
    position = value;
    _explicitlyProvidedFields.add(QuickLogInputField.position);
  }

  void selectPlace(TrainingPlace value) {
    place = value;
    _explicitlyProvidedFields.add(QuickLogInputField.place);
  }

  void selectIntensity(int value) {
    intensity = value;
    _explicitlyProvidedFields.add(QuickLogInputField.intensity);
  }

  void selectApplicationContext(String value) {
    applicationContext = value;
    _explicitlyProvidedFields.add(QuickLogInputField.applicationContext);
  }

  void selectOutcome(String value) {
    outcome = value;
    _explicitlyProvidedFields.add(QuickLogInputField.outcome);
  }

  void markCompositionChanged() {
    _explicitlyProvidedFields.addAll({
      QuickLogInputField.duration,
      QuickLogInputField.rolls,
      QuickLogInputField.studiedTechniques,
    });
  }

  void dispose() {
    notes.dispose();
    customTechnique.dispose();
    customPosition.dispose();
    composition.dispose();
  }

  static List<String> _recentTechniques(List<TrainingSession> recentSessions) {
    final options = <String>[];
    final seen = <String>{};
    for (final session in recentSessions) {
      for (final entry in session.effectiveTechniqueEntries) {
        final value = _clean(entry.technique);
        if (value == null) continue;
        if (seen.add(value.toLowerCase())) options.add(value);
        if (options.length >= 4) return options;
      }
    }
    return options;
  }

  static List<String> _recentPositions(List<TrainingSession> recentSessions) {
    final options = <String>[];
    final seen = <String>{};
    for (final session in recentSessions) {
      final values = [
        _clean(session.position),
        for (final entry in session.effectiveTechniqueEntries)
          _clean(entry.position),
      ];
      for (final value in values) {
        if (value == null) continue;
        if (seen.add(value.toLowerCase())) options.add(value);
        if (options.length >= 4) return options;
      }
    }
    return options;
  }

  static List<TrainingStudiedTechnique> _studiedTechniques(
    List<TrainingSession> recentSessions,
  ) {
    final byCatalogId = <String, TrainingStudiedTechnique>{};
    for (final session in recentSessions) {
      for (final technique in session.studiedTechniques) {
        byCatalogId.putIfAbsent(technique.catalogId, () => technique);
      }
      for (final entry in session.effectiveTechniqueEntries) {
        final label = _clean(entry.technique);
        if (label == null) continue;
        final catalogId = JiuJitsuTaxonomy.normalizedKey(label);
        byCatalogId.putIfAbsent(
          catalogId,
          () => TrainingStudiedTechnique(catalogId: catalogId, label: label),
        );
      }
    }
    return byCatalogId.values.toList();
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
