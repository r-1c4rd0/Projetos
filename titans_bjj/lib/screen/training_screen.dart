import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../model/progress_period.dart';
import '../model/training_session.dart';
import '../repository/training_repository.dart';
import '../service/target_resolver.dart';
import '../widgets/glass_card.dart';
import '../widgets/titans_scaffold.dart';
import 'add_training_session_screen.dart';

class TrainingScreen extends StatefulWidget {
  final String? titleOverride;

  const TrainingScreen({
    super.key,
    this.titleOverride,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  ProgressPeriod _period = ProgressPeriod.month;

  late final TrainingRepository _repo = TrainingRepository.instance;

  @override
  Widget build(BuildContext context) {
    final target = TargetResolver.maybeOf(context);

    final academyId = target?.academyId;
    final uid = target?.uid;

    if (academyId == null || uid == null) {
      return TitansScaffold(
        appBar: AppBar(title: Text(widget.titleOverride ?? 'Treinos')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Não foi possível abrir Treinos.\n\n'
                  'Motivo: não existe sessão (UserScope) e também não foram informados academyId/uid.\n\n'
                  'Solução: quando o mestre abrir esta tela, passe academyIdOverride e uidOverride.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return TitansScaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? 'Treinos'),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'training_fab',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTrainingSessionScreen(
                academyId: academyId,
                uid: uid,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Treino'),
      ),
      body: StreamBuilder<List<TrainingSession>>(
        stream: _repo.watchSessions(
          academyId: academyId,
          uid: uid,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Erro ao carregar treinos:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sessions = List<TrainingSession>.from(
            snap.data ?? const <TrainingSession>[],
          )..sort((a, b) => a.date.compareTo(b.date));

          final series = _buildSeries(sessions, _period);
          final totalInWindow = series.values.fold<int>(0, (a, b) => a + b);

          final bottomPad = MediaQuery.of(context).padding.bottom;
          final extraBottom = 80.0 + bottomPad + 80.0; // Espaço pro FAB e pro Nav

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, extraBottom),
            children: [
              glassCard(
                context,
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleForPeriod(_period),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      height: 240,
                      child: _LineChart(
                        labels: series.labels,
                        values: series.values,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Sem treinos registrados',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                )
              else
                ...sessions.reversed.map((s) {
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _iconForPlace(s.place),
                        color: cs.primary,
                      ),
                      title: Text(_fmtDateTime(s.date)),
                      subtitle: Text(
                        (s.notes ?? '').trim().isEmpty ? '—' : s.notes!.trim(),
                      ),
                      trailing: Text(
                        'Notas: ${s.scores.length}',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  IconData _iconForPlace(TrainingPlace p) {
    switch (p) {
      case TrainingPlace.academy:
        return Icons.sports_mma_outlined;
      case TrainingPlace.home:
        return Icons.home_outlined;
      case TrainingPlace.other:
        return Icons.place_outlined;
    }
  }

  String _titleForPeriod(ProgressPeriod p) {
    switch (p) {
      case ProgressPeriod.day:
        return 'Treinos por dia (últimos 14 dias)';
      case ProgressPeriod.month:
        return 'Treinos por mês (últimos 12 meses)';
      case ProgressPeriod.year:
        return 'Treinos por ano (últimos 5 anos)';
    }
  }

  _Series _buildSeries(List<TrainingSession> sessions, ProgressPeriod period) {
    final now = DateTime.now();
    final labels = <String>[];
    final map = <String, int>{};

    if (period == ProgressPeriod.day) {
      for (int i = 13; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${_fmt2(d.day)}/${_fmt2(d.month)}';
        labels.add(key);
        map[key] = 0;
      }
    } else if (period == ProgressPeriod.month) {
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = '${_fmt2(d.month)}/${d.year}';
        labels.add(key);
        map[key] = 0;
      }
    } else {
      for (int i = 4; i >= 0; i--) {
        final key = (now.year - i).toString();
        labels.add(key);
        map[key] = 0;
      }
    }

    for (final s in sessions) {
      final d = s.date;
      final key = (period == ProgressPeriod.day)
          ? '${_fmt2(d.day)}/${_fmt2(d.month)}'
          : (period == ProgressPeriod.month)
          ? '${_fmt2(d.month)}/${d.year}'
          : '${d.year}';

      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }

    return _Series(
      labels: labels,
      values: labels.map((k) => map[k] ?? 0).toList(),
    );
  }

  static String _fmt2(int n) => n.toString().padLeft(2, '0');

  String _fmtDateTime(DateTime d) {
    return '${_fmt2(d.day)}/${_fmt2(d.month)}/${d.year} ${_fmt2(d.hour)}:${_fmt2(d.minute)}';
  }
}

class _Series {
  final List<String> labels;
  final List<int> values;
  _Series({required this.labels, required this.values});
}

class _LineChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;

  const _LineChart({
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final maxVal = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal < 3) ? 3.0 : (maxVal + 1).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _bottomIntervalFor(values.length),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
                  (i) => FlSpot(i.toDouble(), values[i].toDouble()),
            ),
            isCurved: true,
            barWidth: 3,
            color: cs.primary,
            dotData: FlDotData(show: values.length <= 20),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  double _bottomIntervalFor(int len) {
    if (len <= 5) return 1;
    if (len <= 12) return 2;
    return 3;
  }
}
