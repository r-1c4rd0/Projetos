import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../model/grading_rules.dart';
import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../widgets/titans_scaffold.dart';

class ProgressScreen extends StatefulWidget {
  final String? titleOverride;

  const ProgressScreen({
    super.key,
    this.titleOverride,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressPeriod _period = ProgressPeriod.month;

  late final TrainingRepository _trainingRepo =
  TrainingRepository(FirebaseFirestore.instance);

  late final GradingRulesRepository _rulesRepo =
  GradingRulesRepository(FirebaseFirestore.instance);

  late final UserProgressRepository _progressRepo =
  UserProgressRepository(FirebaseFirestore.instance);

  bool _ensuringRules = false;
  Object? _ensureError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_ensuringRules) return;

    final target = TargetResolver.maybeOf(context);
    final academyId = target?.academyId;

    if (academyId == null) return;

    _ensuringRules = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _rulesRepo.ensureDefault(academyId);
        _ensureError = null;
      } catch (e) {
        _ensureError = e;
      } finally {
        if (mounted) setState(() => _ensuringRules = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = TargetResolver.maybeOf(context);

    final academyId = target?.academyId;
    final uid = target?.uid;

    if (academyId == null || uid == null) {
      return TitansScaffold(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Progresso')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Não foi possível abrir Progresso.\n\n'
                  'Motivo: não existe sessão (UserScope) e também não foram informados academyId/uid.\n\n'
                  'Solução: quando o mestre abrir esta tela, passe academyIdOverride e uidOverride.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return TitansScaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Progresso'),
        actions: [
          PopupMenuButton<ProgressPeriod>(
            initialValue: _period,
            onSelected: (p) => setState(() => _period = p),
            itemBuilder: (_) => const [
              PopupMenuItem(value: ProgressPeriod.day, child: Text('Dia')),
              PopupMenuItem(value: ProgressPeriod.month, child: Text('Mês')),
              PopupMenuItem(value: ProgressPeriod.year, child: Text('Ano')),
            ],
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: _ensureError != null
          ? _ErrorState(
        title: 'Erro ao configurar regras',
        message: _ensureError.toString(),
      )
          : StreamBuilder<GradingRules?>(
        stream: _rulesRepo.watch(academyId),
        builder: (context, rulesSnap) {
          if (_ensuringRules &&
              rulesSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (rulesSnap.hasError) {
            return _ErrorState(
              title: 'Erro ao carregar regras',
              message: rulesSnap.error.toString(),
            );
          }

          final rules = rulesSnap.data;
          if (rules == null) {
            return const _EmptyState(
              title: 'Regras da academia não configuradas.',
              subtitle:
              'Não foi possível ler academies/{academyId}/grading_rules/default.',
            );
          }

          return StreamBuilder<UserProgressProfile?>(
            stream: _progressRepo.watchProfile(
              academyId: academyId,
              uid: uid,
            ),
            builder: (context, profileSnap) {
              if (profileSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (profileSnap.hasError) {
                return _ErrorState(
                  title: 'Erro ao carregar perfil de progresso',
                  message: profileSnap.error.toString(),
                );
              }

              final profile = profileSnap.data;
              if (profile == null) {
                return const _EmptyState(
                  title: 'Perfil de progresso não encontrado.',
                  subtitle:
                  'Crie academies/{academyId}/users/{uid}/progress/profile (beltStartAt, currentBelt, currentDegree).',
                );
              }

              return StreamBuilder<List<TrainingSession>>(
                stream: _trainingRepo.watchSessions(
                  academyId: academyId,
                  uid: uid,
                ),
                builder: (context, trainSnap) {
                  if (trainSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (trainSnap.hasError) {
                    return _ErrorState(
                      title: 'Erro ao carregar treinos',
                      message: trainSnap.error.toString(),
                    );
                  }

                  final sessions = List<TrainingSession>.from(
                    trainSnap.data ?? const <TrainingSession>[],
                  );

                  final filtered = rules.onlyAcademyPlace
                      ? sessions
                      .where((s) => s.place == TrainingPlace.academy)
                      .toList()
                      : List<TrainingSession>.from(sessions);

                  filtered.sort((a, b) => a.date.compareTo(b.date));

                  final beltProgress = _calcBeltProgress(
                    rules: rules,
                    profile: profile,
                    sessions: filtered,
                  );

                  final series = _buildSeries(filtered, _period);
                  final totalInWindow =
                  series.values.fold<int>(0, (a, b) => a + b);

                  final bottomPad = MediaQuery.of(context).padding.bottom;
                  final extraBottom = 80.0 + bottomPad + 32.0;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, extraBottom),
                    children: [
                      _BeltProgressCard(progress: beltProgress),
                      const SizedBox(height: 12),
                      _ConsistencyChartCard(
                        title: _titleForPeriod(_period),
                        totalInWindow: totalInWindow,
                        labels: series.labels,
                        values: series.values,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  _BeltProgress _calcBeltProgress({
    required GradingRules rules,
    required UserProgressProfile profile,
    required List<TrainingSession> sessions,
  }) {
    final belt = profile.currentBelt;
    final maxDeg = rules.maxDegrees(belt).clamp(1, 12);

    final beltStart = profile.beltStartAt;
    final sessionsInBelt =
        sessions.where((s) => !s.date.isBefore(beltStart)).length;

    final degree = profile.currentDegree.clamp(0, maxDeg);

    final fallbackRules = rules.requiredSessions(belt);
    int estimatedTotal = profile.estimatedSessionsInBelt ??
        (degree > 0 ? ((sessionsInBelt * maxDeg) / degree).ceil() : fallbackRules);

    if (estimatedTotal <= 0) estimatedTotal = fallbackRules;
    if (estimatedTotal <= 0) estimatedTotal = (maxDeg * 40);

    final percent = maxDeg <= 0 ? 0.0 : (degree / maxDeg).clamp(0.0, 1.0);

    return _BeltProgress(
      belt: belt,
      degree: degree,
      maxDegree: maxDeg,
      percentToNextBelt: percent,
      sessionsInCurrentBelt: sessionsInBelt,
      sessionsRequiredCurrentBelt: estimatedTotal,
    );
  }

  _Series _buildSeries(List<TrainingSession> sessions, ProgressPeriod period) {
    final now = DateTime.now();
    final map = <String, int>{};
    final labels = <String>[];

    if (period == ProgressPeriod.day) {
      for (int i = 13; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final label =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        labels.add(label);
        map[label] = 0;
      }
    } else if (period == ProgressPeriod.month) {
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final label = '${d.month.toString().padLeft(2, '0')}/${d.year}';
        labels.add(label);
        map[label] = 0;
      }
    } else {
      for (int i = 4; i >= 0; i--) {
        final label = (now.year - i).toString();
        labels.add(label);
        map[label] = 0;
      }
    }

    for (final s in sessions) {
      final d = s.date;

      final key = switch (period) {
        ProgressPeriod.day =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
        ProgressPeriod.month =>
        '${d.month.toString().padLeft(2, '0')}/${d.year}',
        ProgressPeriod.year => d.year.toString(),
      };

      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    return _Series(
      labels: labels,
      values: labels.map((l) => map[l] ?? 0).toList(),
    );
  }

  String _titleForPeriod(ProgressPeriod p) {
    switch (p) {
      case ProgressPeriod.day:
        return 'Consistência (14 dias)';
      case ProgressPeriod.month:
        return 'Consistência (12 meses)';
      case ProgressPeriod.year:
        return 'Consistência (5 anos)';
    }
  }
}

class UserProgressRepository {
  final FirebaseFirestore db;
  const UserProgressRepository(this.db);

  DocumentReference<Map<String, dynamic>> _ref({
    required String academyId,
    required String uid,
  }) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('profile');
  }

  Stream<UserProgressProfile?> watchProfile({
    required String academyId,
    required String uid,
  }) {
    return _ref(academyId: academyId, uid: uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return UserProgressProfile.fromMap(data);
    });
  }

  Future<void> upsertProfile({
    required String academyId,
    required String uid,
    required UserProgressProfile profile,
  }) async {
    await _ref(academyId: academyId, uid: uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }
}

class _BeltProgressCard extends StatelessWidget {
  final _BeltProgress progress;
  const _BeltProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = _beltUiColor(progress.belt, context);

    final pctText = '${(progress.percentToNextBelt * 100).toStringAsFixed(0)}%';
    final subtitle =
        '${progress.sessionsInCurrentBelt}/${progress.sessionsRequiredCurrentBelt} treinos (estimativa)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Faixa atual',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _beltName(progress.belt),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: beltColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LinearProgressIndicator(
              minHeight: 16,
              value: progress.percentToNextBelt,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(beltColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Graus: ${progress.degree}/${progress.maxDegree}',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                pctText,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
          ),
        ]),
      ),
    );
  }

  static Color _beltUiColor(BeltColor belt, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (belt) {
      case BeltColor.white:
        return Colors.white.withValues(alpha: 0.90);
      case BeltColor.blue:
        return Colors.blueAccent;
      case BeltColor.purple:
        return Colors.purpleAccent;
      case BeltColor.brown:
        return const Color(0xFF8D6E63);
      case BeltColor.black:
        return cs.onSurface;
    }
  }

  static String _beltName(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return 'Branca';
      case BeltColor.blue:
        return 'Azul';
      case BeltColor.purple:
        return 'Roxa';
      case BeltColor.brown:
        return 'Marrom';
      case BeltColor.black:
        return 'Preta';
    }
  }
}

class _ConsistencyChartCard extends StatelessWidget {
  final String title;
  final int totalInWindow;
  final List<String> labels;
  final List<int> values;

  const _ConsistencyChartCard({
    required this.title,
    required this.totalInWindow,
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxY = values.isEmpty
        ? 4.0
        : (values.reduce((a, b) => a > b ? a : b)).toDouble() + 1;

    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Total: $totalInWindow',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY < 4 ? 4 : maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: _bottomInterval(labels.length),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final text = labels[idx];
                        final rotate = text.length >= 6; // ex 02/2026

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Transform.rotate(
                            angle: rotate ? -0.6 : 0,
                            child: Text(
                              text,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.65),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3.5,
                    color: cs.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cs.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static double _bottomInterval(int len) {
    if (len <= 7) return 1;
    if (len <= 14) return 2;
    return 3;
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Series {
  final List<String> labels;
  final List<int> values;
  _Series({required this.labels, required this.values});
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;
  final int sessionsInCurrentBelt;
  final int sessionsRequiredCurrentBelt;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
    required this.sessionsInCurrentBelt,
    required this.sessionsRequiredCurrentBelt,
  });
}