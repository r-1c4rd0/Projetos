import 'package:cloud_firestore/cloud_firestore.dart';

enum TrainingPlace { academy, home, other }

class TrainingSession {
  final String id;
  final DateTime date;
  final TrainingPlace place;
  final String? notes;

  /// Mapa alunoId -> pontuação 1..5
  final Map<String, int> scores;

  TrainingSession({
    required this.id,
    required this.date,
    required this.place,
    this.notes,
    Map<String, int>? scores,
  }) : scores = scores ?? const {};

  TrainingSession copyWith({
    DateTime? date,
    TrainingPlace? place,
    String? notes,
    Map<String, int>? scores,
  }) {
    return TrainingSession(
      id: id,
      date: date ?? this.date,
      place: place ?? this.place,
      notes: notes ?? this.notes,
      scores: scores ?? this.scores,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'place': place.name, // 'academy' | 'home' | 'other'
      'notes': notes,
      'scores': scores,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TrainingSession fromDoc(
      String id,
      Map<String, dynamic> data,
      ) {
    final rawDate = data['date'];
    DateTime date;

    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else {
      date = DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    }

    final placeRaw = (data['place'] ?? 'academy').toString();
    final place = TrainingPlace.values.firstWhere(
          (e) => e.name == placeRaw,
      orElse: () => TrainingPlace.academy,
    );

    final notes = data['notes']?.toString();

    final rawScores = (data['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    final scores = <String, int>{};
    rawScores.forEach((k, v) {
      if (v is int) {
        scores[k] = v;
      } else {
        final n = int.tryParse(v.toString());
        if (n != null) scores[k] = n;
      }
    });

    return TrainingSession(
      id: id,
      date: date,
      place: place,
      notes: notes,
      scores: scores,
    );
  }
}
