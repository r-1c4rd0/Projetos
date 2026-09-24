import 'package:flutter/material.dart';

import '../model/training_session.dart';
import '../service/jiu_jitsu_taxonomy.dart';

class TrainingTechniqueFormEntry {
  final TextEditingController position;
  final TextEditingController technique;
  final TextEditingController notes;
  TrainingTechniqueSide side;
  String? applicationContext;
  String? techniqueOutcome;
  bool expanded;

  TrainingTechniqueFormEntry({
    String? position,
    String? technique,
    String? notes,
    this.side = TrainingTechniqueSide.unknown,
    this.applicationContext,
    this.techniqueOutcome,
    this.expanded = false,
  }) : position = TextEditingController(text: position ?? ''),
       technique = TextEditingController(text: technique ?? ''),
       notes = TextEditingController(text: notes ?? '');

  factory TrainingTechniqueFormEntry.fromEntry(
    TrainingTechniqueEntry entry, {
    required bool expanded,
  }) {
    return TrainingTechniqueFormEntry(
      position: entry.position,
      technique: entry.technique,
      notes: entry.notes,
      side: entry.side,
      applicationContext: entry.applicationContext,
      techniqueOutcome: entry.techniqueOutcome,
      expanded: expanded,
    );
  }

  void clear() {
    position.clear();
    technique.clear();
    notes.clear();
    side = TrainingTechniqueSide.unknown;
    applicationContext = null;
    techniqueOutcome = null;
    expanded = true;
  }

  void dispose() {
    position.dispose();
    technique.dispose();
    notes.dispose();
  }
}

class TrainingTechniqueFormController {
  final List<TrainingTechniqueFormEntry> _entries = [];
  final String? fallbackPosition;
  final String? fallbackTechnique;

  TrainingTechniqueFormController({TrainingSession? session})
    : fallbackPosition = _clean(session?.position),
      fallbackTechnique = _clean(session?.technique) {
    final entries =
        session?.effectiveTechniqueEntries ?? const <TrainingTechniqueEntry>[];
    if (entries.isEmpty) {
      _entries.add(TrainingTechniqueFormEntry(expanded: true));
      return;
    }

    for (var index = 0; index < entries.length; index++) {
      _entries.add(
        TrainingTechniqueFormEntry.fromEntry(
          entries[index],
          expanded: index == 0,
        ),
      );
    }
  }

  List<TrainingTechniqueFormEntry> get entries => List.unmodifiable(_entries);

  void addEntry() {
    for (final entry in _entries) {
      entry.expanded = false;
    }
    _entries.add(TrainingTechniqueFormEntry(expanded: true));
  }

  void removeEntry(TrainingTechniqueFormEntry entry) {
    if (!_entries.contains(entry)) return;
    if (_entries.length == 1) {
      entry.clear();
      return;
    }

    _entries.remove(entry);
    entry.dispose();
  }

  void toggleEntry(TrainingTechniqueFormEntry entry) {
    if (!_entries.contains(entry)) return;
    entry.expanded = !entry.expanded;
  }

  void expandOnly(TrainingTechniqueFormEntry entry) {
    if (!_entries.contains(entry)) return;
    for (final formEntry in _entries) {
      formEntry.expanded = identical(formEntry, entry);
    }
  }

  TrainingTechniqueFormEntry? get firstTechniqueMissingPosition {
    for (final entry in _entries) {
      if (_clean(entry.technique.text) == null) continue;
      if (_clean(entry.position.text) == null) return entry;
    }
    return null;
  }

  List<String> recentTechniques({String? excluding}) {
    return _recentValues(
      _entries.map((entry) => entry.technique.text),
      excluding: excluding,
    );
  }

  List<String> recentPositions({String? excluding}) {
    return _recentValues(
      _entries.map((entry) => entry.position.text),
      excluding: excluding,
    );
  }

  List<TrainingTechniqueEntry> buildEntries() {
    final result = <TrainingTechniqueEntry>[];
    final seen = <String>{};

    for (final formEntry in _entries) {
      final technique = _clean(formEntry.technique.text);
      if (technique == null) continue;

      final position = _clean(formEntry.position.text);
      final key =
          '${JiuJitsuTaxonomy.normalizedKey(position ?? '')}:${JiuJitsuTaxonomy.normalizedKey(technique)}';
      if (!seen.add(key)) continue;

      result.add(
        TrainingTechniqueEntry(
          technique: technique,
          position: position,
          side: formEntry.side,
          applicationContext: formEntry.applicationContext,
          techniqueOutcome: formEntry.techniqueOutcome,
          notes: _clean(formEntry.notes.text),
        ),
      );
    }

    return result;
  }

  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
  }

  static List<String> _recentValues(
    Iterable<String> values, {
    String? excluding,
  }) {
    final recent = <String>[];
    final seen = <String>{};
    final excludingKey = JiuJitsuTaxonomy.normalizedKey(excluding ?? '');

    for (final value in values) {
      final label = value.trim();
      if (label.isEmpty) continue;

      final key = JiuJitsuTaxonomy.normalizedKey(label);
      if (key.isEmpty || key == excludingKey || !seen.add(key)) continue;

      recent.add(label);
      if (recent.length == 6) break;
    }
    return recent;
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
