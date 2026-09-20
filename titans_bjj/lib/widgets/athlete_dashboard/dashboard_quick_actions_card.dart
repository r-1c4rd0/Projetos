import 'package:flutter/material.dart';

import 'dashboard_surfaces.dart';

class DashboardQuickActionsCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onOpenGameMap;
  final VoidCallback onOpenSkills;

  const DashboardQuickActionsCard({
    super.key,
    required this.cs,
    required this.onOpenGameMap,
    required this.onOpenSkills,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      accent: cs.tertiary.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeaderCompact(title: 'ATALHO ÚTIL'),
                const SizedBox(height: 5),
                Text(
                  'Game Map e repertório técnico em atalhos internos.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _QuickActionButton(
                    icon: Icons.map_outlined,
                    label: 'Game Map',
                    onPressed: onOpenGameMap,
                  ),
                  _QuickActionButton(
                    icon: Icons.psychology_alt_outlined,
                    label: 'Skills',
                    onPressed: onOpenSkills,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
