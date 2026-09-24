import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../model/nutrition_models.dart';
import '../../model/training_session.dart';
import 'athlete_account_menu.dart';
import 'athlete_cockpit_hero.dart';
import 'athlete_identity_cards.dart';
import 'coach_lite_modules.dart';
import 'coach_summary_cards.dart';
import 'dashboard_metrics_cards.dart';
import 'dashboard_primary_action_card.dart';
import 'dashboard_quick_actions_card.dart';
import 'game_map_lite_card.dart';
import 'home_intelligence_deck.dart';
import 'home_view_models.dart';
import 'next_training_card.dart';
import 'nutrition_dashboard_card.dart';
import 'recent_activity_timeline_card.dart';
import 'recommended_focus_card.dart';
import 'skill_matrix_summary_card.dart';

enum AthleteDashboardContentMode {
  athleteSelf,
  coachEmpty,
  coachFoundation,
  coachActive,
  standard,
}

class AthleteDashboardContent extends StatelessWidget {
  final AthleteDashboardContentMode mode;
  final bool embedded;
  final bool isSelfProfile;
  final bool canEditTarget;
  final String athleteName;
  final String athleteEmail;
  final String athleteUid;
  final HomeDashboardViewModel dashboard;
  final BeltProgress beltProgress;
  final Stream<UserProfile?>? nutritionProfileStream;
  final Stream<List<MealEntry>>? nutritionMealsStream;
  final bool nutritionFallbackToMock;
  final bool hasNutritionLoadError;
  final bool cockpitConfirmingPending;
  final bool primaryActionConfirmingPending;
  final VoidCallback onChangeTheme;
  final VoidCallback onSignOut;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditGraduation;
  final Future<void> Function()? onConfirmPending;
  final VoidCallback onQuickLog;
  final VoidCallback onRegisterTraining;
  final VoidCallback onOpenTraining;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenNutrition;
  final ValueChanged<TrainingSession> onOpenTrainingSession;
  final ValueChanged<HomeTechniqueNavigationTarget> onOpenTechnique;

  const AthleteDashboardContent({
    super.key,
    required this.mode,
    required this.embedded,
    required this.isSelfProfile,
    required this.canEditTarget,
    required this.athleteName,
    required this.athleteEmail,
    required this.athleteUid,
    required this.dashboard,
    required this.beltProgress,
    required this.nutritionProfileStream,
    required this.nutritionMealsStream,
    required this.nutritionFallbackToMock,
    required this.hasNutritionLoadError,
    required this.cockpitConfirmingPending,
    required this.primaryActionConfirmingPending,
    required this.onChangeTheme,
    required this.onSignOut,
    required this.onEditProfile,
    required this.onEditGraduation,
    required this.onConfirmPending,
    required this.onQuickLog,
    required this.onRegisterTraining,
    required this.onOpenTraining,
    required this.onOpenGameMap,
    required this.onOpenSkills,
    required this.onOpenNutrition,
    required this.onOpenTrainingSession,
    required this.onOpenTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (mode == AthleteDashboardContentMode.coachEmpty) {
      return _scrollable(
        context,
        CoachStudentEmptyCard(
          cs: cs,
          studentName: athleteName,
          onRegisterTraining: onRegisterTraining,
        ),
      );
    }

    return _scrollable(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._identitySection(cs),
          const SizedBox(height: 12),
          ..._perspectiveSection(cs),
        ],
      ),
    );
  }

  Widget _scrollable(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SingleChildScrollView(
          padding:
              embedded
                  ? TitansUI.listPadding(context, extra: TitansUI.spaceMd)
                  : TitansUI.listPadding(context, extra: 96),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
        return embedded ? content : SafeArea(bottom: false, child: content);
      },
    );
  }

  List<Widget> _identitySection(ColorScheme cs) {
    if (mode == AthleteDashboardContentMode.athleteSelf) {
      return [
        AthleteMinimalHeader(
          onChangeTheme: onChangeTheme,
          onSignOut: onSignOut,
        ),
        const SizedBox(height: 12),
        AthleteHomeCockpitHero(
          cs: cs,
          focus: dashboard.recommendedFocus,
          nextTraining: dashboard.nextTraining,
          lastSession:
              dashboard.lastSessions.isEmpty
                  ? null
                  : dashboard.lastSessions.first,
          pendingConfirmation: dashboard.pendingConfirmation,
          confirmingPending: cockpitConfirmingPending,
          onConfirmPending: onConfirmPending,
          onRegisterTraining: onQuickLog,
        ),
        const SizedBox(height: 12),
        AthleteMinimalMetricsCard(
          cs: cs,
          frequency: dashboard.frequency,
          metrics: dashboard.metrics,
        ),
        const SizedBox(height: 12),
        AthleteMinimalIdentityCard(
          cs: cs,
          name: athleteName,
          email: athleteEmail,
          uid: athleteUid,
          belt: beltProgress.belt,
          degree: beltProgress.degree,
          maxDegree: beltProgress.maxDegree,
          percentToNext: beltProgress.percentToNextBelt,
          sessionsInBelt: beltProgress.sessionsInBelt,
          sessionsRequired: beltProgress.sessionsRequired,
          hasOfficialRule: beltProgress.hasOfficialRule,
        ),
      ];
    }

    return [
      if (isSelfProfile) ...[
        Align(
          alignment: Alignment.centerRight,
          child: AthleteHomeAccountMenu(
            onChangeTheme: onChangeTheme,
            onSignOut: onSignOut,
          ),
        ),
        const SizedBox(height: 8),
      ],
      AthleteCard(
        name: athleteName,
        email: athleteEmail,
        uid: athleteUid,
        belt: beltProgress.belt,
        degree: beltProgress.degree,
        maxDegree: beltProgress.maxDegree,
        percentToNext: beltProgress.percentToNextBelt,
        sessionsInBelt: beltProgress.sessionsInBelt,
        sessionsRequired: beltProgress.sessionsRequired,
        hasOfficialRule: beltProgress.hasOfficialRule,
        onEditProfile: canEditTarget ? onEditProfile : null,
        onEditGraduation: canEditTarget ? onEditGraduation : null,
      ),
    ];
  }

  List<Widget> _perspectiveSection(ColorScheme cs) {
    return switch (mode) {
      AthleteDashboardContentMode.coachFoundation => _coachFoundation(cs),
      AthleteDashboardContentMode.coachActive => _coachActive(cs),
      AthleteDashboardContentMode.athleteSelf => _athleteSelf(cs),
      AthleteDashboardContentMode.standard => _standard(cs),
      AthleteDashboardContentMode.coachEmpty => const <Widget>[],
    };
  }

  List<Widget> _coachFoundation(ColorScheme cs) {
    final lastSession =
        dashboard.lastSessions.isEmpty ? null : dashboard.lastSessions.first;
    return [
      CoachStudentFoundationCard(
        cs: cs,
        studentName: athleteName,
        belt: beltProgress.belt,
        degree: beltProgress.degree,
        metrics: dashboard.metrics,
        lastSession: lastSession,
        onRegisterTraining: onRegisterTraining,
      ),
      if (dashboard.recommendedFocus.hasRecommendation ||
          dashboard.nextTraining.hasRecommendation) ...[
        const SizedBox(height: 12),
        CoachTechnicalFocusCard(
          cs: cs,
          focus: dashboard.recommendedFocus,
          nextTraining: dashboard.nextTraining,
          compact: true,
          onOpenEvidence: onOpenTraining,
          onOpenSkills: onOpenSkills,
        ),
      ],
      const SizedBox(height: 12),
      _recentActivity(cs),
    ];
  }

  List<Widget> _coachActive(ColorScheme cs) {
    final lastSession =
        dashboard.lastSessions.isEmpty ? null : dashboard.lastSessions.first;
    return [
      CoachStudentActiveSummaryCard(
        cs: cs,
        studentName: athleteName,
        belt: beltProgress.belt,
        degree: beltProgress.degree,
        metrics: dashboard.metrics,
        frequency: dashboard.frequency,
        lastSession: lastSession,
        focus: dashboard.recommendedFocus,
        onOpenEvidence: onOpenTraining,
      ),
      const SizedBox(height: 12),
      CoachTechnicalFocusCard(
        cs: cs,
        focus: dashboard.recommendedFocus,
        nextTraining: dashboard.nextTraining,
        compact: false,
        onOpenEvidence: onOpenTraining,
        onOpenSkills: onOpenSkills,
      ),
      const SizedBox(height: 12),
      _intelligenceDeck(cs),
      const SizedBox(height: 12),
      CoachActiveLiteModules(
        cs: cs,
        metrics: dashboard.metrics,
        frequency: dashboard.frequency,
        insights: dashboard.debriefInsights,
        skillMatrix: dashboard.skillMatrix,
        gameMap: dashboard.gameMapLite,
        profileStream: nutritionProfileStream,
        mealsStream: nutritionMealsStream,
        isNutritionFallback: nutritionFallbackToMock,
        hasNutritionLoadError: hasNutritionLoadError,
        onOpenSkills: onOpenSkills,
        onOpenGameMap: onOpenGameMap,
        onOpenNutrition: onOpenNutrition,
      ),
      const SizedBox(height: 12),
      _recentActivity(cs),
    ];
  }

  List<Widget> _athleteSelf(ColorScheme cs) {
    return [
      _intelligenceDeck(cs),
      if (dashboard.lastSessions.isNotEmpty) ...[
        const SizedBox(height: 12),
        _recentActivity(cs, compact: true),
      ],
    ];
  }

  List<Widget> _standard(ColorScheme cs) {
    return [
      NextTrainingCard(cs: cs, recommendation: dashboard.nextTraining),
      const SizedBox(height: 12),
      DashboardPrimaryActionCard(
        cs: cs,
        nextTraining: dashboard.nextTraining,
        pendingConfirmation: dashboard.pendingConfirmation,
        confirmingPending: primaryActionConfirmingPending,
        onConfirmPending: onConfirmPending,
        onRegisterTraining: onRegisterTraining,
        onOpenTraining: onOpenTraining,
      ),
      const SizedBox(height: 12),
      RecommendedFocusCard(cs: cs, focus: dashboard.recommendedFocus),
      const SizedBox(height: 12),
      DashboardQuickActionsCard(
        cs: cs,
        onOpenGameMap: onOpenGameMap,
        onOpenSkills: onOpenSkills,
      ),
      const SizedBox(height: 12),
      _intelligenceDeck(cs),
      const SizedBox(height: 12),
      _metricsAndInsights(cs),
      const SizedBox(height: 12),
      NutritionDashboardLiteCard(
        cs: cs,
        profileStream: nutritionProfileStream,
        mealsStream: nutritionMealsStream,
        isStudentView: false,
        isFallback: nutritionFallbackToMock,
        hasLoadError: hasNutritionLoadError,
        hideWhenEmpty: false,
        onOpenNutrition: onOpenNutrition,
      ),
      const SizedBox(height: 12),
      SkillMatrixSummaryCard(
        cs: cs,
        entries: dashboard.skillMatrix,
        onOpenSkillMatrix: onOpenGameMap,
      ),
      const SizedBox(height: 12),
      GameMapLiteCard(
        cs: cs,
        entries: dashboard.gameMapLite,
        onOpenFullMap: onOpenGameMap,
      ),
      const SizedBox(height: 12),
      _recentActivity(cs),
    ];
  }

  Widget _intelligenceDeck(ColorScheme cs) {
    return HomeIntelligenceDeck(
      cs: cs,
      dashboard: dashboard,
      radar: dashboard.technicalRadar,
      beltProgress: beltProgress,
      onOpenMap: onOpenGameMap,
      onOpenTraining: onOpenTraining,
      onRegisterTraining: onRegisterTraining,
    );
  }

  Widget _recentActivity(ColorScheme cs, {bool compact = false}) {
    return RecentActivityTimelineCard(
      cs: cs,
      items: dashboard.lastSessions,
      compact: compact,
      onOpenTraining: onOpenTraining,
      onRegisterTraining: onRegisterTraining,
      onOpenTrainingSession: onOpenTrainingSession,
      onOpenTechnique: onOpenTechnique,
    );
  }

  Widget _metricsAndInsights(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final stats = StatsCard(
          cs: cs,
          frequency: dashboard.frequency,
          metrics: dashboard.metrics,
        );
        final insights = DebriefInsightsCard(
          cs: cs,
          insights: dashboard.debriefInsights,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: stats),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: insights),
            ],
          );
        }

        return Column(children: [stats, const SizedBox(height: 12), insights]);
      },
    );
  }
}
