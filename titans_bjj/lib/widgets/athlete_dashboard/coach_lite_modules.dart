import 'package:flutter/material.dart';

import '../../features/home/domain/home_dashboard_models.dart';
import '../../features/technical_domain/domain/technical_models.dart';
import '../../model/nutrition_models.dart';
import '../titans_feedback.dart';
import 'dashboard_surfaces.dart';

class CoachActiveLiteModules extends StatelessWidget {
  final ColorScheme cs;
  final HomeTrainingMetrics metrics;
  final int frequency;
  final HomeDebriefInsights insights;
  final List<SkillMatrixCategoryEntry> skillMatrix;
  final List<GameMapEntry> gameMap;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isNutritionFallback;
  final bool hasNutritionLoadError;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenNutrition;

  const CoachActiveLiteModules({
    super.key,
    required this.cs,
    required this.metrics,
    required this.frequency,
    required this.insights,
    required this.skillMatrix,
    required this.gameMap,
    required this.profileStream,
    required this.mealsStream,
    required this.isNutritionFallback,
    required this.hasNutritionLoadError,
    required this.onOpenSkills,
    required this.onOpenGameMap,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cards = <Widget>[
          _CoachLiteModuleCard(
            cs: cs,
            title: 'CONSISTÊNCIA',
            icon: Icons.event_available_outlined,
            accent: cs.primary,
            lines: [
              _CoachLiteLine('Regularidade', '$frequency% em 8 semanas'),
              _CoachLiteLine('Últimos 30 dias', metrics.recent.toString()),
            ],
            note: _consistencyNote(),
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'LEITURA TÉCNICA',
            icon: Icons.visibility_outlined,
            accent: Colors.amber,
            lines: [
              _CoachLiteLine('Foco', insights.technicalFocus ?? '—'),
              _CoachLiteLine('Atenção', insights.attentionPoint ?? '—'),
              _CoachLiteLine('Intensidade', _intensityLabel()),
            ],
            note: 'Leitura baseada nos debriefs recentes.',
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'REPERTÓRIO TÉCNICO',
            icon: Icons.psychology_alt_outlined,
            accent: Colors.lightGreenAccent,
            lines: [
              _CoachLiteLine('Técnicas', _techniquesCount().toString()),
              _CoachLiteLine('Aplicações', _applicationsCount().toString()),
              _CoachLiteLine('Mais presente', _mainTechniqueLabel()),
            ],
            actionLabel: 'Abrir Skills',
            onAction: onOpenSkills,
          ),
          _CoachLiteModuleCard(
            cs: cs,
            title: 'GAME MAP INSIGHT',
            icon: Icons.account_tree_outlined,
            accent: cs.secondary,
            lines: [
              _CoachLiteLine('Posições', gameMap.length.toString()),
              _CoachLiteLine('Mais presente', _mainPositionLabel()),
            ],
            actionLabel: 'Explorar mapa',
            onAction: onOpenGameMap,
          ),
          _CoachNutritionCompactCard(
            cs: cs,
            profileStream: profileStream,
            mealsStream: mealsStream,
            isFallback: isNutritionFallback,
            hasLoadError: hasNutritionLoadError,
            onOpenNutrition: onOpenNutrition,
          ),
        ];

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 10) / 2, child: card),
          ],
        );
      },
    );
  }

  String _consistencyNote() {
    if (metrics.recent <= 0) return 'Sem treinos nos últimos 30 dias.';
    if (frequency <= 0) return 'Regularidade ainda sem sinal recente.';
    return 'Ritmo recente pronto para acompanhamento.';
  }

  String _intensityLabel() {
    final value = insights.averageIntensity;
    if (value == null) return '—';
    return '${value.toStringAsFixed(1)}/5';
  }

  int _techniquesCount() {
    return skillMatrix.fold<int>(
      0,
      (sum, entry) => sum + entry.techniquesCount,
    );
  }

  int _applicationsCount() {
    return skillMatrix.fold<int>(
      0,
      (sum, entry) =>
          sum +
          entry.techniques
              .where((technique) => technique.application == true)
              .length,
    );
  }

  String _mainTechniqueLabel() {
    final techniques = <SkillMatrixTechniqueEntry>[
      for (final entry in skillMatrix) ...entry.techniques,
    ];
    if (techniques.isEmpty) return '—';
    techniques.sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
    final technique = techniques.first;
    final position = technique.position?.trim();
    if (position == null || position.isEmpty) return technique.technique;
    return '${technique.technique} · $position';
  }

  String _mainPositionLabel() {
    if (gameMap.isEmpty) return '—';
    final entries = List<GameMapEntry>.from(gameMap)
      ..sort((a, b) => b.sessionsCount.compareTo(a.sessionsCount));
    return entries.first.position;
  }
}

class _CoachLiteLine {
  final String label;
  final String value;

  const _CoachLiteLine(this.label, this.value);
}

class _CoachLiteModuleCard extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final IconData icon;
  final Color accent;
  final List<_CoachLiteLine> lines;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CoachLiteModuleCard({
    required this.cs,
    required this.title,
    required this.icon,
    required this.accent,
    required this.lines,
    this.note,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      accent: accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: DashboardSectionHeaderCompact(title: title)),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            _CoachLiteDataRow(line: line),
            if (line != lines.last) const SizedBox(height: 7),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachLiteDataRow extends StatelessWidget {
  final _CoachLiteLine line;

  const _CoachLiteDataRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 98,
          child: Text(
            line.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.56),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            line.value.trim().isEmpty ? '—' : line.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachNutritionCompactCard extends StatelessWidget {
  final ColorScheme cs;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isFallback;
  final bool hasLoadError;
  final VoidCallback onOpenNutrition;

  const _CoachNutritionCompactCard({
    required this.cs,
    required this.profileStream,
    required this.mealsStream,
    required this.isFallback,
    required this.hasLoadError,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      accent: cs.tertiary.withValues(alpha: 0.22),
      child: StreamBuilder<UserProfile?>(
        stream: profileStream,
        builder: (context, profileSnap) {
          return StreamBuilder<List<MealEntry>>(
            stream: mealsStream,
            builder: (context, mealsSnap) {
              final isLoading =
                  profileSnap.connectionState == ConnectionState.waiting ||
                  mealsSnap.connectionState == ConnectionState.waiting;
              final profile = profileSnap.data;
              final meals = mealsSnap.data ?? const <MealEntry>[];
              final recentMeals = _recentMealsCount(meals);
              final status =
                  hasLoadError || isFallback
                      ? 'Indisponível'
                      : (profile == null ? 'Pendente' : 'Ativo');
              final summary =
                  hasLoadError || isFallback
                      ? 'Resumo indisponível agora.'
                      : (recentMeals == 0
                          ? 'Sem refeições recentes.'
                          : '$recentMeals refeições recentes.');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        color: cs.tertiary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: DashboardSectionHeaderCompact(title: 'NUTRIÇÃO'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const TitansSkeletonCard(lines: 2)
                  else ...[
                    _CoachLiteDataRow(line: _CoachLiteLine('Perfil', status)),
                    const SizedBox(height: 7),
                    _CoachLiteDataRow(line: _CoachLiteLine('Resumo', summary)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onOpenNutrition,
                        child: const Text('Ver Nutrição'),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  int _recentMealsCount(List<MealEntry> meals) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return meals.where((meal) => !meal.date.isBefore(since)).length;
  }
}
