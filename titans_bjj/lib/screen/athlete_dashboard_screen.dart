import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/grading_rules.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../widgets/titans_scaffold.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final String? athleteNameOverride;
  final String? athleteEmailOverride;

  final String? titleOverride;

  const AthleteDashboardScreen({
    super.key,
    this.athleteNameOverride,
    this.athleteEmailOverride,
    this.titleOverride,
  });

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  late final TrainingRepository _trainingRepo =
  TrainingRepository(FirebaseFirestore.instance);

  late final GradingRulesRepository _rulesRepo =
  GradingRulesRepository(FirebaseFirestore.instance);

  Stream<UserProgressProfile?> _watchProfile({
    required String academyId,
    required String uid,
  }) {
    return FirebaseFirestore.instance
        .collection('academies')
        .doc(academyId)
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('profile')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return UserProgressProfile.fromMap(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = TargetResolver.of(context);
    final cs = Theme.of(context).colorScheme;

    final academyId = target.academyId;
    final uid = target.uid;

    final headerName = (widget.athleteNameOverride ?? '').trim().isNotEmpty
        ? widget.athleteNameOverride!.trim()
        : 'Atleta';

    final headerEmail = (widget.athleteEmailOverride ?? '').trim().isNotEmpty
        ? widget.athleteEmailOverride!.trim()
        : '';

    return TitansScaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Início'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: StreamBuilder<UserProgressProfile?>(
        stream: _watchProfile(academyId: academyId, uid: uid),
        builder: (context, profileSnap) {
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnap.hasError) {
            return _ErrorState(
              title: 'Erro ao carregar perfil',
              message: profileSnap.error.toString(),
            );
          }

          final profile = profileSnap.data;

          return StreamBuilder<GradingRules?>(
            stream: _rulesRepo.watch(academyId),
            builder: (context, rulesSnap) {
              if (rulesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (rulesSnap.hasError) {
                return _ErrorState(
                  title: 'Erro ao carregar regras',
                  message: rulesSnap.error.toString(),
                );
              }

              final rules = rulesSnap.data;

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
                  )..sort((a, b) => a.date.compareTo(b.date));

                  final filtered = (rules?.onlyAcademyPlace ?? false)
                      ? sessions
                      .where((s) => s.place == TrainingPlace.academy)
                      .toList()
                      : sessions;

                  final beltProgress = _calcBeltProgress(
                    rules: rules,
                    profile: profile,
                    sessions: filtered,
                  );

                  final lastSessions = filtered.reversed.take(5).toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bottomPad = MediaQuery.of(context).padding.bottom;
                      // ~80 do nav bar + safe area bottom + margem visual
                      final extraBottom = 80.0 + bottomPad + 32.0;

                      return SafeArea(
                        bottom: false,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, extraBottom),
                          child: ConstrainedBox(
                            constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final isWide = c.maxWidth >= 980;
                                    if (isWide) {
                                      return Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: _AthleteCard(
                                              name: headerName,
                                              email: headerEmail,
                                              uid: uid,
                                              belt: beltProgress.belt,
                                              degree: beltProgress.degree,
                                              percentToNext:
                                              beltProgress.percentToNextBelt,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 6,
                                            child: _NextTrainingCard(
                                              cs: cs,
                                              title: 'Sparring de Elite',
                                              subtitle:
                                              'Professor: Willian Vox • 20:00 - 21:00',
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        _AthleteCard(
                                          name: headerName,
                                          email: headerEmail,
                                          uid: uid,
                                          belt: beltProgress.belt,
                                          degree: beltProgress.degree,
                                          percentToNext:
                                          beltProgress.percentToNextBelt,
                                        ),
                                        const SizedBox(height: 12),
                                        _NextTrainingCard(
                                          cs: cs,
                                          title: 'Sparring de Elite',
                                          subtitle:
                                          'Professor: Marco Santos • 19:30 - 21:00',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final isWide = c.maxWidth >= 980;

                                    final left = _StatsCard(
                                      cs: cs,
                                      frequency: _calcFrequency(filtered),
                                      readiness: _calcReadiness(filtered),
                                      ranking: '#04',
                                      sparring: 'S+',
                                    );

                                    final right = _FeedbackCard(
                                      cs: cs,
                                      feedback:
                                      '“Controle de quadril melhorou. Cuidado com a esgrima. Foque em estabilizar antes de transitar.”',
                                      task: 'Tarefa: 30 drills',
                                    );

                                    if (isWide) {
                                      return Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 4, child: left),
                                          const SizedBox(width: 12),
                                          Expanded(flex: 6, child: right),
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        left,
                                        const SizedBox(height: 12),
                                        right,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _RecentActivityCard(
                                  cs: cs,
                                  items: lastSessions,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
    required GradingRules? rules,
    required UserProgressProfile? profile,
    required List<TrainingSession> sessions,
  }) {
    if (profile == null) {
      return const _BeltProgress(
        belt: BeltColor.white,
        degree: 0,
        maxDegree: 4,
        percentToNextBelt: 0,
      );
    }

    final belt = profile.currentBelt;
    final maxDeg = (rules == null) ? 4 : rules.maxDegrees(belt);
    final degree = profile.currentDegree.clamp(0, maxDeg);

    final estimatedTotal = profile.estimatedSessionsInBelt ??
        ((rules == null) ? 0 : rules.requiredSessions(belt));

    if (estimatedTotal <= 0) {
      final denom = (maxDeg + 1);
      final pct = denom <= 0 ? 0.0 : (degree / denom).clamp(0.0, 1.0);
      return _BeltProgress(
        belt: belt,
        degree: degree,
        maxDegree: maxDeg,
        percentToNextBelt: pct,
      );
    }

    final sessionsInBelt =
        sessions.where((s) => !s.date.isBefore(profile.beltStartAt)).length;

    final segments = maxDeg + 1;
    final perSegment = (estimatedTotal / segments);

    final startOfThisSegment = (degree * perSegment);
    final doneIntoSegment = (sessionsInBelt - startOfThisSegment);

    final pctSegment = perSegment <= 0
        ? 0.0
        : (doneIntoSegment / perSegment).clamp(0.0, 1.0);

    return _BeltProgress(
      belt: belt,
      degree: degree,
      maxDegree: maxDeg,
      percentToNextBelt: pctSegment,
    );
  }

  int _calcFrequency(List<TrainingSession> sessions) {
    final now = DateTime.now();
    final weeks = <String, bool>{};
    for (int i = 0; i < 8; i++) {
      final d = now.subtract(Duration(days: i * 7));
      weeks[_weekKey(d)] = false;
    }
    for (final s in sessions) {
      final k = _weekKey(s.date);
      if (weeks.containsKey(k)) weeks[k] = true;
    }
    final total = weeks.length;
    final hit = weeks.values.where((v) => v).length;
    if (total == 0) return 0;
    return ((hit / total) * 100).round();
  }

  int _calcReadiness(List<TrainingSession> sessions) {
    final now = DateTime.now();
    final count = sessions
        .where((s) => s.date.isAfter(now.subtract(const Duration(days: 14))))
        .length;
    final pct = (count / 12).clamp(0.0, 1.0);
    return (pct * 100).round();
  }

  String _weekKey(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    final diff = d.difference(firstDay).inDays;
    final week = (diff / 7).floor();
    return '${d.year}-$week';
  }
}

// ---------------- UI ----------------

class _AthleteCard extends StatelessWidget {
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final double percentToNext;

  const _AthleteCard({
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.percentToNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = _beltUiColor(belt, cs);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email.isEmpty
                          ? 'ID: ${uid.substring(0, 6).toUpperCase()}'
                          : '$email • ID: ${uid.substring(0, 6).toUpperCase()}',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _BeltPill(belt: belt, color: beltColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Progresso para o próximo grau',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65), fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: percentToNext.clamp(0.0, 1.0),
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(beltColor),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(percentToNext * 100).round()}%',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grau atual: $degree',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _beltUiColor(BeltColor belt, ColorScheme cs) {
    switch (belt) {
      case BeltColor.white:
        return Colors.white.withValues(alpha: 0.95);
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
}

class _BeltPill extends StatelessWidget {
  final BeltColor belt;
  final Color color;
  const _BeltPill({required this.belt, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (belt) {
      BeltColor.white => 'FAIXA WHITE',
      BeltColor.blue => 'FAIXA BLUE',
      BeltColor.purple => 'FAIXA PURPLE',
      BeltColor.brown => 'FAIXA BROWN',
      BeltColor.black => 'FAIXA BLACK',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NextTrainingCard extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final String subtitle;

  const _NextTrainingCard({
    required this.cs,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.error.withValues(alpha: 0.55),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 520;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('CHECK-IN AGORA'),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75))),
                ]),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {},
                child: const Text('CHECK-IN AGORA'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ColorScheme cs;
  final int frequency;
  final int readiness;
  final String sparring;
  final String ranking;

  const _StatsCard({
    required this.cs,
    required this.frequency,
    required this.readiness,
    required this.sparring,
    required this.ranking,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: 'FREQUÊNCIA',
                  value: '$frequency%',
                  highlight: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'PRONTIDÃO',
                  value: '$readiness%',
                  highlight: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatMini(
                  title: 'SPARRING',
                  value: sparring,
                  highlight: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'RANKING',
                  value: ranking,
                  highlight: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String title;
  final String value;
  final Color highlight;

  const _StatMini({
    required this.title,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: highlight,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final ColorScheme cs;
  final String feedback;
  final String task;

  const _FeedbackCard({
    required this.cs,
    required this.feedback,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accent: cs.error.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEEDBACK DO MESTRE',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            feedback,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () {},
              child: Text(task.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final ColorScheme cs;
  final List items;

  const _RecentActivityCard({
    required this.cs,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOG DE ATIVIDADES RECENTES',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'Sem atividades.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            )
          else
            Text(
              'TODO: renderizar lista de treinos aqui (mantido do seu original).',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
            ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _GlassCard({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (accent != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent!.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _BeltProgress {
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNextBelt;

  const _BeltProgress({
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNextBelt,
  });
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