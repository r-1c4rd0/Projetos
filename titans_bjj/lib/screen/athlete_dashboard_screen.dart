import 'dart:async';

import 'package:flutter/material.dart';

import '../model/app_user.dart';
import '../model/grading_rules.dart';
import '../model/training_session.dart';
import '../model/user_progress_profile.dart';
import '../repository/grading_rules_repository.dart';
import '../repository/training_repository.dart';
import '../repository/user_progress_repository.dart';
import '../repository/user_repository.dart';
import '../service/target_resolver.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final String? athleteNameOverride;
  final String? athleteEmailOverride;
  final String? titleOverride;
  final TargetMode targetMode;

  const AthleteDashboardScreen({
    super.key,
    this.athleteNameOverride,
    this.athleteEmailOverride,
    this.titleOverride,
    this.targetMode = TargetMode.self,
  });

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  late final TrainingRepository _trainingRepo = TrainingRepository.instance;
  late final GradingRulesRepository _rulesRepo =
      GradingRulesRepository.instance;
  late final UserProgressRepository _progressRepo =
      UserProgressRepository.instance;
  late final UserRepository _userRepo = UserRepository.instance;

  String? _streamAcademyId;
  String? _streamUid;
  Stream<AppUser?>? _athleteStream;
  Stream<UserProgressProfile?>? _profileStream;
  Stream<GradingRules?>? _rulesStream;
  Stream<List<TrainingSession>>? _sessionsStream;

  void _syncStreams({required String academyId, required String uid}) {
    if (_streamAcademyId == academyId && _streamUid == uid) return;

    _streamAcademyId = academyId;
    _streamUid = uid;
    _athleteStream = _userRepo.watchUser(academyId: academyId, uid: uid);
    _profileStream = _progressRepo.watchProfile(academyId: academyId, uid: uid);
    _rulesStream = _rulesRepo.watch(academyId);
    _sessionsStream = _trainingRepo.watchSessions(
      academyId: academyId,
      uid: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = TargetResolver.maybeOf(context, mode: widget.targetMode);
    final loggedUser = UserScope.maybeOf(context);

    if (target == null) {
      return TitansScaffold(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Inicio')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selecione um aluno no Painel do Mestre para acessar o console do atleta.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _syncStreams(academyId: target.academyId, uid: target.uid);

    final cs = Theme.of(context).colorScheme;

    final academyId = target.academyId;
    final uid = target.uid;

    return TitansScaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Inicio'),
        actions: [
          IconButton(
            tooltip: 'Configuracoes',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: _athleteStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnap.hasError) {
            return _ErrorState(
              title: 'Erro ao carregar usuario',
              message: userSnap.error.toString(),
            );
          }

          final athlete = userSnap.data;
          if (athlete == null) {
            return const _EmptyState(
              title: 'Usuario nao encontrado.',
              subtitle:
                  'Crie academies/{academyId}/users/{uid} com role, belt e degree.',
            );
          }

          final headerName =
              (widget.athleteNameOverride ?? '').trim().isNotEmpty
                  ? widget.athleteNameOverride!.trim()
                  : (athlete.name.trim().isNotEmpty
                      ? athlete.name.trim()
                      : 'Atleta');
          final headerEmail =
              (widget.athleteEmailOverride ?? '').trim().isNotEmpty
                  ? widget.athleteEmailOverride!.trim()
                  : athlete.email;
          final canEditGraduation =
              loggedUser?.role == UserRole.athlete && loggedUser?.uid == uid;

          return StreamBuilder<UserProgressProfile?>(
            stream: _profileStream,
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
              if (profile == null) {
                return const _EmptyState(
                  title: 'Perfil de progresso nao encontrado.',
                  subtitle:
                      'Crie academies/{academyId}/users/{uid}/progress/profile (beltStartAt, estimatedSessionsInBelt).',
                );
              }

              return StreamBuilder<GradingRules?>(
                stream: _rulesStream,
                builder: (context, rulesSnap) {
                  if (rulesSnap.connectionState == ConnectionState.waiting &&
                      !rulesSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rulesSnap.hasError) {
                    return _ErrorState(
                      title: 'Erro ao carregar regras',
                      message: rulesSnap.error.toString(),
                    );
                  }

                  final rules = rulesSnap.data ?? GradingRules.defaults();

                  return StreamBuilder<List<TrainingSession>>(
                    stream: _sessionsStream,
                    builder: (context, trainSnap) {
                      if (trainSnap.connectionState ==
                          ConnectionState.waiting) {
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
                      sessions.sort((a, b) => a.date.compareTo(b.date));

                      final filtered =
                          rules.onlyAcademyPlace
                              ? sessions
                                  .where(
                                    (s) => s.place == TrainingPlace.academy,
                                  )
                                  .toList()
                              : List<TrainingSession>.from(sessions);

                      final beltProgress = _calcBeltProgress(
                        rules: rules,
                        profile: profile,
                        belt: athlete.belt,
                        degree: athlete.degree,
                        sessions: filtered,
                      );
                      final lastSessions = filtered.reversed.take(5).toList();

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final bottomPad =
                              MediaQuery.of(context).padding.bottom;
                          final extraBottom = 80.0 + bottomPad + 32.0;

                          return SafeArea(
                            bottom: false,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                extraBottom,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, c) {
                                        final isWide = c.maxWidth >= 980;
                                        final athleteCard = _AthleteCard(
                                          name: headerName,
                                          email: headerEmail,
                                          uid: uid,
                                          belt: beltProgress.belt,
                                          degree: beltProgress.degree,
                                          percentToNext:
                                              beltProgress.percentToNextBelt,
                                          onEditGraduation:
                                              canEditGraduation
                                                  ? () => _showGraduationDialog(
                                                    academyId: academyId,
                                                    uid: uid,
                                                    athlete: athlete,
                                                    rules: rules,
                                                  )
                                                  : null,
                                        );

                                        if (isWide) {
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 4,
                                                child: athleteCard,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                flex: 6,
                                                child: _NextTrainingCard(
                                                  cs: cs,
                                                  title: 'Sparring de Elite',
                                                  subtitle:
                                                      'Professor: Willian Vox - 20:00 - 21:00',
                                                ),
                                              ),
                                            ],
                                          );
                                        }

                                        return Column(
                                          children: [
                                            athleteCard,
                                            const SizedBox(height: 12),
                                            _NextTrainingCard(
                                              cs: cs,
                                              title: 'Sparring de Elite',
                                              subtitle:
                                                  'Professor: Marco Santos - 19:30 - 21:00',
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
                                          trainingCount: filtered.length,
                                          sparring: _calcSparring(
                                            filtered,
                                            uid,
                                          ),
                                        );
                                        final right = _FeedbackCard(
                                          cs: cs,
                                          feedback:
                                              'Controle de quadril melhorou. Cuidado com a esgrima. Foque em estabilizar antes de transitar.',
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
          );
        },
      ),
    );
  }

  Future<void> _showGraduationDialog({
    required String academyId,
    required String uid,
    required AppUser athlete,
    required GradingRules rules,
  }) async {
    var selectedBelt = athlete.belt;
    var selectedDegree =
        athlete.degree.clamp(0, rules.maxDegrees(selectedBelt)).toInt();
    var saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDegree = rules.maxDegrees(selectedBelt);
            final degreeItems = List.generate(
              maxDegree + 1,
              (index) =>
                  DropdownMenuItem(value: index, child: Text(index.toString())),
            );

            return AlertDialog(
              title: const Text('Solicitar/Editar graduacao'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<BeltColor>(
                    initialValue: selectedBelt,
                    decoration: const InputDecoration(
                      labelText: 'Faixa',
                      prefixIcon: Icon(Icons.horizontal_rule),
                    ),
                    items:
                        BeltColor.values
                            .map(
                              (belt) => DropdownMenuItem(
                                value: belt,
                                child: Text(_beltLabel(belt)),
                              ),
                            )
                            .toList(),
                    onChanged:
                        saving
                            ? null
                            : (belt) {
                              if (belt == null) return;
                              setDialogState(() {
                                selectedBelt = belt;
                                selectedDegree =
                                    selectedDegree
                                        .clamp(0, rules.maxDegrees(belt))
                                        .toInt();
                              });
                            },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('${selectedBelt.name}-$selectedDegree'),
                    initialValue: selectedDegree,
                    decoration: const InputDecoration(
                      labelText: 'Grau',
                      prefixIcon: Icon(Icons.star_outline),
                    ),
                    items: degreeItems,
                    onChanged:
                        saving
                            ? null
                            : (degree) {
                              if (degree == null) return;
                              setDialogState(() => selectedDegree = degree);
                            },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            final navigator = Navigator.of(dialogContext);
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            setDialogState(() {
                              saving = true;
                              errorMessage = null;
                            });
                            try {
                              final clampedDegree =
                                  selectedDegree
                                      .clamp(0, rules.maxDegrees(selectedBelt))
                                      .toInt();
                              await _userRepo.updateBeltDegree(
                                academyId: academyId,
                                uid: uid,
                                belt: selectedBelt,
                                degree: clampedDegree,
                              );
                              if (!mounted) return;
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Graduacao atualizada'),
                                ),
                              );
                            } catch (error) {
                              setDialogState(() {
                                saving = false;
                                errorMessage =
                                    'Nao foi possivel salvar. $error';
                              });
                            }
                          },
                  icon:
                      saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Salvando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _BeltProgress _calcBeltProgress({
    required GradingRules rules,
    required UserProgressProfile profile,
    required BeltColor belt,
    required int degree,
    required List<TrainingSession> sessions,
  }) {
    final maxDeg = rules.maxDegrees(belt).clamp(1, 12).toInt();
    final safeDegree = degree.clamp(0, maxDeg).toInt();

    final sessionsInBelt =
        sessions.where((s) => !s.date.isBefore(profile.beltStartAt)).length;

    final estimated = profile.estimatedSessionsInBelt;
    final requiredByRules = rules.requiredSessions(belt);
    final safeFallback = sessionsInBelt > 0 ? sessionsInBelt : maxDeg;
    final sessionsRequired =
        (estimated != null && estimated > 0)
            ? estimated
            : (requiredByRules > 0 ? requiredByRules : safeFallback)
                .clamp(1, 1 << 30)
                .toInt();

    final perSegment = sessionsRequired / maxDeg;
    final startOfThisSegment = safeDegree * perSegment;
    final doneIntoSegment = sessionsInBelt - startOfThisSegment;
    final pctSegment =
        perSegment <= 0 ? 0.0 : (doneIntoSegment / perSegment).clamp(0.0, 1.0);

    return _BeltProgress(
      belt: belt,
      degree: safeDegree,
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
    final count =
        sessions
            .where(
              (s) => s.date.isAfter(now.subtract(const Duration(days: 14))),
            )
            .length;
    final pct = (count / 12).clamp(0.0, 1.0);
    return (pct * 100).round();
  }

  String _calcSparring(List<TrainingSession> sessions, String uid) {
    final scores =
        sessions
            .map((s) => s.scores[uid])
            .whereType<int>()
            .where((score) => score > 0)
            .toList();
    if (scores.isEmpty) return '-';

    final total = scores.fold<int>(0, (sum, score) => sum + score);
    final avg = total / scores.length;
    return avg.toStringAsFixed(1);
  }

  String _weekKey(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    final diff = d.difference(firstDay).inDays;
    final week = (diff / 7).floor();
    return '${d.year}-$week';
  }
}

// ---------------- UI ----------------

String _beltLabel(BeltColor belt) {
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

class _AthleteCard extends StatelessWidget {
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final double percentToNext;
  final VoidCallback? onEditGraduation;

  const _AthleteCard({
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.percentToNext,
    this.onEditGraduation,
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
                          : '$email - ID: ${uid.substring(0, 6).toUpperCase()}',
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
            'Progresso para o proximo grau',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: percentToNext.clamp(0.0, 1.0),
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
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
          if (onEditGraduation != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onEditGraduation,
                icon: const Icon(Icons.military_tech_outlined),
                label: const Text('Editar graduacao'),
              ),
            ),
          ],
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
        return Colors.black;
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
                ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
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
  final int trainingCount;

  const _StatsCard({
    required this.cs,
    required this.frequency,
    required this.readiness,
    required this.sparring,
    required this.trainingCount,
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
                  title: 'FREQUENCIA',
                  value: '$frequency%',
                  highlight: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatMini(
                  title: 'PRONTIDAO',
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
                  title: 'TREINOS',
                  value: trainingCount.toString(),
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

  const _RecentActivityCard({required this.cs, required this.items});

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
