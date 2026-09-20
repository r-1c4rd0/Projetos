import 'package:flutter/material.dart';

import 'home_insight_pages.dart';
import 'home_view_models.dart';

class HomeIntelligenceDeck extends StatefulWidget {
  final ColorScheme cs;
  final HomeDashboardViewModel dashboard;
  final HomeTechnicalRadarViewModel radar;
  final BeltProgress beltProgress;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenTraining;
  final VoidCallback? onRegisterTraining;

  const HomeIntelligenceDeck({
    super.key,
    required this.cs,
    required this.dashboard,
    required this.radar,
    required this.beltProgress,
    required this.onOpenMap,
    required this.onOpenTraining,
    this.onRegisterTraining,
  });

  @override
  State<HomeIntelligenceDeck> createState() => _HomeIntelligenceDeckState();
}

class _HomeIntelligenceDeckState extends State<HomeIntelligenceDeck> {
  int _index = 0;

  static const _pages = [
    _HomeDeckPageMeta(label: 'Radar', icon: Icons.radar_outlined),
    _HomeDeckPageMeta(label: 'Treinos', icon: Icons.show_chart_rounded),
    _HomeDeckPageMeta(
      label: 'Progresso',
      icon: Icons.workspace_premium_outlined,
    ),
    _HomeDeckPageMeta(label: 'Repertório', icon: Icons.account_tree_outlined),
  ];

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index.clamp(0, _pages.length - 1));
  }

  void _next() => _goTo((_index + 1) % _pages.length);

  void _previous() => _goTo((_index - 1 + _pages.length) % _pages.length);

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120) _next();
            if (velocity > 120) _previous();
          },
          child: AnimatedSwitcher(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              if (reduceMotion) return child;
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0.03),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.992, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: _buildPage(context),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _HomeDeckIndicator(
          pages: _pages,
          selectedIndex: _index,
          onSelect: _goTo,
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context) {
    switch (_index) {
      case 0:
        return HomeRadarInsight(
          cs: widget.cs,
          radar: widget.radar,
          onOpenMap: widget.onOpenMap,
          onRegisterTraining: widget.onRegisterTraining,
        );
      case 1:
        return HomeTrainingInsight(
          cs: widget.cs,
          metrics: widget.dashboard.metrics,
          recentSessions: widget.dashboard.recentSessions,
          lastSession:
              widget.dashboard.lastSessions.isEmpty
                  ? null
                  : widget.dashboard.lastSessions.first,
          onOpenTraining: widget.onOpenTraining,
          onRegisterTraining: widget.onRegisterTraining,
        );
      case 2:
        return HomeProgressInsight(
          cs: widget.cs,
          beltProgress: widget.beltProgress,
          metrics: widget.dashboard.metrics,
          frequency: widget.dashboard.frequency,
        );
      default:
        return HomeConsistencyInsight(
          cs: widget.cs,
          frequency: widget.dashboard.frequency,
          gameMap: widget.dashboard.gameMapLite,
          skillMatrix: widget.dashboard.skillMatrix,
          onOpenMap: widget.onOpenMap,
        );
    }
  }
}

class _HomeDeckPageMeta {
  final String label;
  final IconData icon;

  const _HomeDeckPageMeta({required this.label, required this.icon});
}

class _HomeDeckIndicator extends StatelessWidget {
  final List<_HomeDeckPageMeta> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _HomeDeckIndicator({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var i = 0; i < pages.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selectedIndex == i ? 10 : 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    selectedIndex == i
                        ? cs.primary.withValues(alpha: 0.14)
                        : cs.onSurface.withValues(alpha: 0.045),
                border: Border.all(
                  color:
                      selectedIndex == i
                          ? cs.primary.withValues(alpha: 0.34)
                          : cs.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pages[i].icon,
                    size: 13,
                    color:
                        selectedIndex == i
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.58),
                  ),
                  if (selectedIndex == i) ...[
                    const SizedBox(width: 6),
                    Text(
                      pages[i].label,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
