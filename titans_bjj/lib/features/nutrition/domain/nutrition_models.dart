import '../../../model/nutrition_models.dart';

class NutritionProfileStatus {
  final bool hasProfile;
  final double? estimatedDailyKcal;
  final String profileStatusLabel;
  final String energyStatusLabel;
  final String profileEmptyMessage;
  final String mealEmptyMessage;
  final String chartEmptyMessage;

  const NutritionProfileStatus({
    required this.hasProfile,
    required this.estimatedDailyKcal,
    required this.profileStatusLabel,
    required this.energyStatusLabel,
    required this.profileEmptyMessage,
    required this.mealEmptyMessage,
    required this.chartEmptyMessage,
  });
}

class NutritionMealLogItem {
  final MealEntry meal;
  final DateTime date;
  final String mealType;
  final String itemsLabel;
  final int totalKcal;

  const NutritionMealLogItem({
    required this.meal,
    required this.date,
    required this.mealType,
    required this.itemsLabel,
    required this.totalKcal,
  });
}

class NutritionChartPoint {
  final DateTime date;
  final int totalKcal;

  const NutritionChartPoint({required this.date, required this.totalKcal});
}

class MealLogSummary {
  final List<NutritionMealLogItem> items;

  const MealLogSummary({required this.items});

  bool get isEmpty => items.isEmpty;
}

class NutritionDashboardSummary {
  final UserProfile? profile;
  final List<MealEntry> meals;
  final NutritionProfileStatus profileStatus;
  final MealLogSummary mealLog;
  final List<NutritionChartPoint> weeklyCalories;

  const NutritionDashboardSummary({
    required this.profile,
    required this.meals,
    required this.profileStatus,
    required this.mealLog,
    required this.weeklyCalories,
  });
}
