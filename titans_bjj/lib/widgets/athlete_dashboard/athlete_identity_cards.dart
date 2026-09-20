import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../model/grading_rules.dart';
import 'belt_progress_ring.dart';
import 'dashboard_formatters.dart';
import 'dashboard_surfaces.dart';

class AthleteCard extends StatelessWidget {
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNext;
  final int sessionsInBelt;
  final int sessionsRequired;
  final bool hasOfficialRule;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditGraduation;

  const AthleteCard({
    super.key,
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNext,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    required this.hasOfficialRule,
    this.onEditProfile,
    this.onEditGraduation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ringColor = beltProgressRingColor(belt);
    final identity = email.isEmpty ? 'ID ${_shortUid(uid)}' : email;
    final sessionLabel =
        hasOfficialRule
            ? '$sessionsInBelt/$sessionsRequired treinos na faixa atual'
            : '$sessionsInBelt treinos registrados nesta faixa';
    final hasActions = onEditProfile != null || onEditGraduation != null;

    return DashboardGlassCard(
      accent: ringColor.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionHeaderCompact(title: 'ALUNO EM ACOMPANHAMENTO'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final info = _StudentSnapshotInfo(
                cs: cs,
                name: name,
                identity: identity,
                belt: belt,
                degree: degree,
                maxDegree: maxDegree,
                sessionsRequired: sessionsRequired,
                hasOfficialRule: hasOfficialRule,
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: BeltProgressRing(
                        colorScheme: cs,
                        value: percentToNext,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    info,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BeltProgressRing(
                    colorScheme: cs,
                    value: percentToNext,
                    color: ringColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: info),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            sessionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasActions) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (onEditProfile != null)
                  OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar perfil'),
                  ),
                if (onEditGraduation != null)
                  OutlinedButton.icon(
                    onPressed: onEditGraduation,
                    icon: const Icon(Icons.military_tech_outlined),
                    label: const Text('Editar gradua\u00e7\u00e3o'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSnapshotInfo extends StatelessWidget {
  final ColorScheme cs;
  final String name;
  final String identity;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final int sessionsRequired;
  final bool hasOfficialRule;

  const _StudentSnapshotInfo({
    required this.cs,
    required this.name,
    required this.identity,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.sessionsRequired,
    required this.hasOfficialRule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          identity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DashboardInsightBadge(
              label: '${beltLabel(belt)} \u00b7 $degree\u00ba grau',
              color: TitansUI.beltColor(belt.name),
              icon: Icons.military_tech_outlined,
            ),
            if (hasOfficialRule)
              DashboardInsightBadge(
                label: 'Ref. $sessionsRequired treinos',
                color: TitansUI.technicalBlue,
                icon: Icons.flag_outlined,
              ),
            _DegreeDots(degree: degree, maxDegree: maxDegree, cs: cs),
          ],
        ),
      ],
    );
  }
}

class AthleteMinimalIdentityCard extends StatelessWidget {
  final ColorScheme cs;
  final String name;
  final String email;
  final String uid;
  final BeltColor belt;
  final int degree;
  final int maxDegree;
  final double percentToNext;
  final int sessionsInBelt;
  final int sessionsRequired;
  final bool hasOfficialRule;

  const AthleteMinimalIdentityCard({
    super.key,
    required this.cs,
    required this.name,
    required this.email,
    required this.uid,
    required this.belt,
    required this.degree,
    required this.maxDegree,
    required this.percentToNext,
    required this.sessionsInBelt,
    required this.sessionsRequired,
    required this.hasOfficialRule,
  });

  @override
  Widget build(BuildContext context) {
    final identity = email.isEmpty ? 'ID ${_shortUid(uid)}' : email;
    final ringColor = beltProgressRingColor(belt);

    return DashboardGlassCard(
      accent: ringColor.withValues(alpha: 0.30),
      child: Row(
        children: [
          BeltProgressRing(
            colorScheme: cs,
            value: percentToNext,
            color: ringColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DashboardInsightBadge(
                      label: '${beltLabel(belt)} · $degreeº grau',
                      color: TitansUI.beltColor(belt.name),
                      icon: Icons.military_tech_outlined,
                    ),
                    _DegreeDots(degree: degree, maxDegree: maxDegree, cs: cs),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasOfficialRule
                      ? '$sessionsInBelt/$sessionsRequired treinos na faixa atual'
                      : '$sessionsInBelt treinos registrados nesta faixa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DegreeDots extends StatelessWidget {
  final int degree;
  final int maxDegree;
  final ColorScheme cs;

  const _DegreeDots({
    required this.degree,
    required this.maxDegree,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final dots = maxDegree <= 0 ? 4 : maxDegree;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < dots; i++) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  i < degree
                      ? Colors.amber
                      : cs.onSurface.withValues(alpha: 0.18),
            ),
          ),
          if (i != dots - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

String _shortUid(String uid) {
  if (uid.length <= 6) return uid.toUpperCase();
  return uid.substring(0, 6).toUpperCase();
}
