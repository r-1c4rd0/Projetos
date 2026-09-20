import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../model/nutrition_models.dart';
import '../titans_feedback.dart';
import 'dashboard_surfaces.dart';

class NutritionDashboardLiteCard extends StatelessWidget {
  final ColorScheme cs;
  final Stream<UserProfile?>? profileStream;
  final Stream<List<MealEntry>>? mealsStream;
  final bool isStudentView;
  final bool isFallback;
  final bool hasLoadError;
  final bool hideWhenEmpty;
  final VoidCallback onOpenNutrition;

  const NutritionDashboardLiteCard({
    super.key,
    required this.cs,
    required this.profileStream,
    required this.mealsStream,
    required this.isStudentView,
    required this.isFallback,
    required this.hasLoadError,
    this.hideWhenEmpty = false,
    required this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      accent: cs.secondary.withValues(alpha: 0.26),
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
              final recentMeals = _recentMeals(meals);
              final registeredMeals = recentMeals.length;
              final recentKcal = recentMeals.fold<int>(
                0,
                (sum, meal) => sum + (meal.totalKcal() ?? 0),
              );
              if (hideWhenEmpty &&
                  !isLoading &&
                  !hasLoadError &&
                  !isFallback &&
                  profile == null &&
                  meals.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Nutri\u00e7\u00e3o',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenNutrition,
                        child: const Text('Abrir nutri\u00e7\u00e3o'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const TitansSkeletonCard(lines: 2)
                  else ...[
                    if (isStudentView) ...[
                      Text(
                        'Visualiza\u00e7\u00e3o do aluno.',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (hasLoadError || isFallback) ...[
                      Text(
                        'Resumo indispon\u00edvel agora.',
                        style: TextStyle(
                          color: cs.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'N\u00e3o foi poss\u00edvel carregar os dados nutricionais.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _NutritionLiteMetric(
                            label: 'Perfil nutricional',
                            value: profile == null ? 'Pendente' : 'Ativo',
                          ),
                          _NutritionLiteMetric(
                            label: 'Energia estimada',
                            value:
                                profile == null
                                    ? (isStudentView
                                        ? 'Pendente'
                                        : 'Completar perfil')
                                    : '${profile.tdee().toStringAsFixed(0)} kcal/dia',
                          ),
                          _NutritionLiteMetric(
                            label: 'Refei\u00e7\u00f5es',
                            value:
                                registeredMeals == 0
                                    ? 'Sem refei\u00e7\u00f5es registradas'
                                    : '$registeredMeals recentes',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile == null
                            ? (isStudentView
                                ? 'Perfil nutricional ainda n\u00e3o preenchido.'
                                : 'Complete seu perfil para estimar energia de rotina.')
                            : 'Refer\u00eancia de rotina, n\u00e3o prescri\u00e7\u00e3o.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontSize: 12,
                        ),
                      ),
                      if (registeredMeals > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Energia registrada recentemente: $recentKcal kcal.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.68),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<MealEntry> _recentMeals(List<MealEntry> meals) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return meals.where((meal) => !meal.date.isBefore(since)).toList();
  }
}

class _NutritionLiteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _NutritionLiteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: TitansCompactMetricCard(label: label, value: value),
    );
  }
}
