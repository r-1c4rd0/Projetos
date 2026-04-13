import 'package:flutter/material.dart';

import 'training_session.dart';

enum PeriodScale { day, month, year }

class Athlete {
  final String id;
  final String name;
  Athlete({required this.id, required this.name});
}

abstract class ITrainingRepository {
  Future<List<TrainingSession>> listAll();
  Future<void> upsert(TrainingSession s);
  Future<void> upsertMany(List<TrainingSession> sessions);
  Future<void> delete(String id);
  Future<List<Athlete>> listAthletes();
}

class InMemoryTrainingRepository implements ITrainingRepository {
  final _sessions = <TrainingSession>[];
  final _athletes = <Athlete>[
    Athlete(id: 'a1', name: 'João'),
    Athlete(id: 'a2', name: 'Maria'),
    Athlete(id: 'a3', name: 'Pedro'),
  ];

  @override
  Future<void> delete(String id) async {
    _sessions.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<TrainingSession>> listAll() async {
    final copy = List<TrainingSession>.from(_sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(copy);
  }

  @override
  Future<void> upsert(TrainingSession s) async {
    final i = _sessions.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      _sessions[i] = s;
    } else {
      _sessions.add(s);
    }
  }

  @override
  Future<void> upsertMany(List<TrainingSession> sessions) async {
    for (final s in sessions) {
      await upsert(s);
    }
  }

  @override
  Future<List<Athlete>> listAthletes() async => List.unmodifiable(_athletes);
}

IconData placeIcon(TrainingPlace p) {
  switch (p) {
    case TrainingPlace.academy:
      return Icons.sports_mma_outlined;
    case TrainingPlace.home:
      return Icons.home_outlined;
    case TrainingPlace.other:
      return Icons.place_outlined;
  }
}
