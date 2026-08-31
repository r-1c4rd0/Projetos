import '../../../model/nutrition_models.dart';
import '../domain/nutrition_models.dart';

class GetNutritionDashboardSummary {
  final GetNutritionProfileStatus getProfileStatus;
  final PrepareNutritionMeals prepareMeals;
  final GetMealLogSummary getMealLogSummary;
  final GetNutritionWeeklyCalories getWeeklyCalories;

  const GetNutritionDashboardSummary({
    this.getProfileStatus = const GetNutritionProfileStatus(),
    this.prepareMeals = const PrepareNutritionMeals(),
    this.getMealLogSummary = const GetMealLogSummary(),
    this.getWeeklyCalories = const GetNutritionWeeklyCalories(),
  });

  NutritionDashboardSummary call({
    required UserProfile? profile,
    required List<MealEntry> meals,
    DateTime? now,
  }) {
    final preparedMeals = prepareMeals(meals);
    return NutritionDashboardSummary(
      profile: profile,
      meals: List<MealEntry>.unmodifiable(meals),
      profileStatus: getProfileStatus(profile),
      mealLog: getMealLogSummary(preparedMeals),
      weeklyCalories: getWeeklyCalories(meals, now: now),
    );
  }
}

class GetNutritionProfileStatus {
  const GetNutritionProfileStatus();

  NutritionProfileStatus call(UserProfile? profile) {
    return NutritionProfileStatus(
      hasProfile: profile != null,
      estimatedDailyKcal: profile?.tdee(),
      profileStatusLabel: profile == null ? 'Perfil pendente' : 'Perfil ativo',
      energyStatusLabel:
          profile == null ? 'Energia pendente' : 'Energia estimada',
      profileEmptyMessage:
          profile == null
              ? 'Perfil nutricional ainda n\u00e3o preenchido.'
              : 'Dados usados para estimar energia de rotina.',
      mealEmptyMessage:
          'Nenhuma refei\u00e7\u00e3o foi registrada para este usu\u00e1rio.',
      chartEmptyMessage:
          'O gr\u00e1fico semanal aparece quando houver registros alimentares.',
    );
  }
}

class PrepareNutritionMeals {
  const PrepareNutritionMeals();

  List<NutritionMealLogItem> call(List<MealEntry> meals) {
    final orderedMeals = List<MealEntry>.from(meals.reversed);
    return List<NutritionMealLogItem>.unmodifiable(
      orderedMeals.map(
        (meal) => NutritionMealLogItem(
          meal: meal,
          date: meal.date,
          mealType: meal.mealType,
          itemsLabel: meal.items.map((item) => item.name).join(', '),
          totalKcal: meal.totalKcal(),
        ),
      ),
    );
  }
}

class GetMealLogSummary {
  const GetMealLogSummary();

  MealLogSummary call(List<NutritionMealLogItem> meals) {
    return MealLogSummary(items: meals);
  }
}

class GetNutritionWeeklyCalories {
  const GetNutritionWeeklyCalories();

  List<NutritionChartPoint> call(List<MealEntry> meals, {DateTime? now}) {
    final resolvedNow = now ?? DateTime.now();
    final start = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    ).subtract(const Duration(days: 6));
    final map = <DateTime, int>{};

    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      map[date] = 0;
    }

    for (final meal in meals) {
      final day = DateTime(meal.date.year, meal.date.month, meal.date.day);
      if (day.isBefore(start) ||
          day.isAfter(start.add(const Duration(days: 6)))) {
        continue;
      }
      map.update(
        day,
        (value) => value + meal.totalKcal(),
        ifAbsent: meal.totalKcal,
      );
    }

    final keys = map.keys.toList()..sort();
    return List<NutritionChartPoint>.unmodifiable(
      keys.map(
        (date) => NutritionChartPoint(date: date, totalKcal: map[date] ?? 0),
      ),
    );
  }
}
