import '../model/progress_period.dart';
import '../model/training_session.dart';

class TrainingMetrics {
  final int total;
  final int month;
  final int year;
  final int recent;
  final double recentFrequency;

  const TrainingMetrics({
    required this.total,
    required this.month,
    required this.year,
    required this.recent,
    required this.recentFrequency,
  });
}

class GameMapEntry {
  final String position;
  final List<GameMapTechniqueSummary> techniques;

  const GameMapEntry({
    required this.position,
    required this.techniques,
  });

  int get sessionsCount => techniques.fold<int>(
        0,
        (sum, technique) => sum + technique.sessionsCount,
      );

  DateTime get lastTrainedAt {
    return techniques
        .map((technique) => technique.lastTrainedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

class GameMapTechniqueSummary {
  final String technique;
  final int sessionsCount;
  final DateTime lastTrainedAt;
  final double? averageIntensity;
  final String? recentSuccess;
  final String? recentDifficulty;

  const GameMapTechniqueSummary({
    required this.technique,
    required this.sessionsCount,
    required this.lastTrainedAt,
    required this.averageIntensity,
    required this.recentSuccess,
    required this.recentDifficulty,
  });
}

class TrainingAggregator {
  static const int recentWindowDays = 30;
  static const String undefinedPositionLabel = 'Sem posicao definida';

  static const Map<String, String> _gameMapAliases = {
    'arm bar': 'armbar',
    'chave de braco': 'armbar',
    'chave de braÃ§o': 'armbar',
    'guarda fechada': 'closed guard',
    'closed guard': 'closed guard',
    'meia guarda': 'half guard',
    'half guard': 'half guard',
    'montada': 'mount',
    'mount': 'mount',
    'costas': 'back',
    'back control': 'back',
  };

  static List<TrainingSession> uniqueSessions(List<TrainingSession> sessions) {
    final byKey = <String, TrainingSession>{};

    for (final session in sessions) {
      byKey[_dedupeKey(session)] = session;
    }

    final unique = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return unique;
  }

  static TrainingMetrics metrics(
    List<TrainingSession> sessions, {
    DateTime? now,
  }) {
    final unique = uniqueSessions(sessions);
    final resolvedNow = now ?? DateTime.now();
    final monthStart = DateTime(resolvedNow.year, resolvedNow.month, 1);
    final yearStart = DateTime(resolvedNow.year, 1, 1);
    final recentStart = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    ).subtract(const Duration(days: recentWindowDays - 1));

    final month = unique.where((s) => !s.date.isBefore(monthStart)).length;
    final year = unique.where((s) => !s.date.isBefore(yearStart)).length;
    final recent = unique.where((s) => !s.date.isBefore(recentStart)).length;

    return TrainingMetrics(
      total: unique.length,
      month: month,
      year: year,
      recent: recent,
      recentFrequency: recent / recentWindowDays,
    );
  }

  static List<GameMapEntry> buildGameMap(
    List<TrainingSession> sessions, {
    int limit = 20,
  }) {
    final ordered = List<TrainingSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final byPosition = <String, _GameMapPositionDraft>{};

    for (final session in ordered.take(limit)) {
      final techniqueLabel = _cleanText(session.technique);
      if (techniqueLabel == null) continue;

      final positionLabel = _cleanText(session.position);
      final positionKey = positionLabel == null
          ? '__undefined_position'
          : _normalizeGameMapText(positionLabel);
      final techniqueKey = _normalizeGameMapText(techniqueLabel);
      if (techniqueKey.isEmpty) continue;

      final positionDraft = byPosition.putIfAbsent(
        positionKey,
        () => _GameMapPositionDraft(),
      );
      positionDraft.addLabel(
        positionLabel ?? undefinedPositionLabel,
        session.date,
      );

      final techniqueDraft = positionDraft.techniques.putIfAbsent(
        techniqueKey,
        () => _GameMapTechniqueDraft(),
      );
      techniqueDraft.addSession(
        session: session,
        techniqueLabel: techniqueLabel,
      );
    }

    final entries = byPosition.values.map((draft) {
      final techniques = draft.techniques.values
          .map((technique) => technique.toSummary())
          .toList()
        ..sort(_compareTechniqueSummary);

      return GameMapEntry(
        position: draft.displayLabel,
        techniques: techniques,
      );
    }).where((entry) => entry.techniques.isNotEmpty).toList()
      ..sort(_compareGameMapEntry);

    return entries;
  }

  /// Retorna uma lista de pontos ja agregados.
  static List<int> aggregate({
    required List<TrainingSession> sessions,
    required ProgressPeriod period,
  }) {
    final now = DateTime.now();
    final unique = uniqueSessions(sessions);

    switch (period) {
      case ProgressPeriod.day:
        return _byDay(unique, now);
      case ProgressPeriod.month:
        return _byMonth(unique, now);
      case ProgressPeriod.year:
        return _byYear(unique, now);
    }
  }

  static String _dedupeKey(TrainingSession session) {
    final attendanceSessionId = session.attendanceSessionId;
    final attendanceCheckInUid = session.attendanceCheckInUid ?? session.uid;

    if (attendanceSessionId != null &&
        attendanceSessionId.trim().isNotEmpty &&
        attendanceCheckInUid != null &&
        attendanceCheckInUid.trim().isNotEmpty) {
      return 'attendance:${attendanceSessionId.trim()}:${attendanceCheckInUid.trim()}';
    }

    return 'training:${session.id}';
  }

  static int _compareGameMapEntry(GameMapEntry a, GameMapEntry b) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.position.toLowerCase().compareTo(b.position.toLowerCase());
  }

  static int _compareTechniqueSummary(
    GameMapTechniqueSummary a,
    GameMapTechniqueSummary b,
  ) {
    final dateCompare = b.lastTrainedAt.compareTo(a.lastTrainedAt);
    if (dateCompare != 0) return dateCompare;
    final countCompare = b.sessionsCount.compareTo(a.sessionsCount);
    if (countCompare != 0) return countCompare;
    return a.technique.toLowerCase().compareTo(b.technique.toLowerCase());
  }

  static String? _cleanText(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeGameMapText(String value) {
    final normalized = _removeAccents(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _gameMapAliases[normalized] ?? normalized;
  }

  static String _removeAccents(String value) {
    const accents = {
      'Ã¡': 'a',
      'Ã ': 'a',
      'Ã¢': 'a',
      'Ã£': 'a',
      'Ã¤': 'a',
      'Ã': 'A',
      'Ã€': 'A',
      'Ã‚': 'A',
      'Ãƒ': 'A',
      'Ã„': 'A',
      'Ã©': 'e',
      'Ã¨': 'e',
      'Ãª': 'e',
      'Ã«': 'e',
      'Ã‰': 'E',
      'Ãˆ': 'E',
      'ÃŠ': 'E',
      'Ã‹': 'E',
      'Ã­': 'i',
      'Ã¬': 'i',
      'Ã®': 'i',
      'Ã¯': 'i',
      'Ã': 'I',
      'ÃŒ': 'I',
      'ÃŽ': 'I',
      'Ã': 'I',
      'Ã³': 'o',
      'Ã²': 'o',
      'Ã´': 'o',
      'Ãµ': 'o',
      'Ã¶': 'o',
      'Ã“': 'O',
      'Ã’': 'O',
      'Ã”': 'O',
      'Ã•': 'O',
      'Ã–': 'O',
      'Ãº': 'u',
      'Ã¹': 'u',
      'Ã»': 'u',
      'Ã¼': 'u',
      'Ãš': 'U',
      'Ã™': 'U',
      'Ã›': 'U',
      'Ãœ': 'U',
      'Ã§': 'c',
      'Ã‡': 'C',
    };

    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString();
  }

  static List<int> _byDay(List<TrainingSession> sessions, DateTime now) {
    return List.generate(14, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 13 - i));

      return sessions
          .where((e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .length;
    });
  }

  static List<int> _byMonth(List<TrainingSession> sessions, DateTime now) {
    return List.generate(12, (i) {
      final month = DateTime(now.year, now.month - (11 - i), 1);

      return sessions
          .where((e) => e.date.year == month.year && e.date.month == month.month)
          .length;
    });
  }

  static List<int> _byYear(List<TrainingSession> sessions, DateTime now) {
    return List.generate(5, (i) {
      final year = now.year - (4 - i);

      return sessions.where((e) => e.date.year == year).length;
    });
  }
}

class _GameMapPositionDraft {
  final labels = <String, _GameMapLabelScore>{};
  final techniques = <String, _GameMapTechniqueDraft>{};

  void addLabel(String label, DateTime date) {
    final score = labels.putIfAbsent(label, () => _GameMapLabelScore(label));
    score.add(date);
  }

  String get displayLabel => _bestLabel(labels);
}

class _GameMapTechniqueDraft {
  final labels = <String, _GameMapLabelScore>{};
  int sessionsCount = 0;
  DateTime? lastTrainedAt;
  final List<int> intensities = [];
  String? recentSuccess;
  String? recentDifficulty;

  void addSession({
    required TrainingSession session,
    required String techniqueLabel,
  }) {
    sessionsCount += 1;
    labels.putIfAbsent(
      techniqueLabel,
      () => _GameMapLabelScore(techniqueLabel),
    ).add(session.date);

    if (lastTrainedAt == null || session.date.isAfter(lastTrainedAt!)) {
      lastTrainedAt = session.date;
    }

    final intensity = session.intensity;
    if (intensity != null && intensity >= 1 && intensity <= 5) {
      intensities.add(intensity);
    }

    final success = TrainingAggregator._cleanText(session.successes);
    if (success != null && recentSuccess == null) {
      recentSuccess = success;
    }

    final difficulty = TrainingAggregator._cleanText(session.difficulties);
    if (difficulty != null && recentDifficulty == null) {
      recentDifficulty = difficulty;
    }
  }

  GameMapTechniqueSummary toSummary() {
    final averageIntensity = intensities.isEmpty
        ? null
        : intensities.fold<int>(0, (sum, value) => sum + value) /
            intensities.length;

    return GameMapTechniqueSummary(
      technique: _bestLabel(labels),
      sessionsCount: sessionsCount,
      lastTrainedAt: lastTrainedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      averageIntensity: averageIntensity,
      recentSuccess: recentSuccess,
      recentDifficulty: recentDifficulty,
    );
  }
}

class _GameMapLabelScore {
  final String label;
  int count = 0;
  DateTime? latestAt;

  _GameMapLabelScore(this.label);

  void add(DateTime date) {
    count += 1;
    if (latestAt == null || date.isAfter(latestAt!)) {
      latestAt = date;
    }
  }
}

String _bestLabel(Map<String, _GameMapLabelScore> labels) {
  _GameMapLabelScore? best;
  for (final score in labels.values) {
    if (best == null ||
        score.count > best.count ||
        (score.count == best.count &&
            score.latestAt != null &&
            (best.latestAt == null || score.latestAt!.isAfter(best.latestAt!)))) {
      best = score;
    }
  }
  return best?.label ?? TrainingAggregator.undefinedPositionLabel;
}
