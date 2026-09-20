import 'package:flutter/material.dart';

import '../../core/titans_ui.dart';
import '../../features/technical_domain/domain/technical_taxonomy.dart';
import '../charts/titans_technical_radar.dart';
import 'dashboard_surfaces.dart';
import 'home_view_models.dart';

class HomeInteractiveTechnicalRadarCard extends StatefulWidget {
  final ColorScheme cs;
  final HomeTechnicalRadarViewModel radar;
  final VoidCallback onOpenMap;
  final VoidCallback? onRegisterTraining;

  const HomeInteractiveTechnicalRadarCard({
    super.key,
    required this.cs,
    required this.radar,
    required this.onOpenMap,
    this.onRegisterTraining,
  });

  @override
  State<HomeInteractiveTechnicalRadarCard> createState() =>
      _HomeInteractiveTechnicalRadarCardState();
}

class _HomeInteractiveTechnicalRadarCardState
    extends State<HomeInteractiveTechnicalRadarCard> {
  late TechnicalRadarAxis _selectedAxis = _initialAxis(widget.radar);

  @override
  void didUpdateWidget(covariant HomeInteractiveTechnicalRadarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.radar.topAxis != oldWidget.radar.topAxis ||
        widget.radar.axisEvidence != oldWidget.radar.axisEvidence) {
      final selectedCount = widget.radar.axisEvidence[_selectedAxis] ?? 0;
      if (selectedCount == 0 && widget.radar.topAxis != null) {
        _selectedAxis = widget.radar.topAxis!;
      }
    }
  }

  TechnicalRadarAxis _initialAxis(HomeTechnicalRadarViewModel radar) {
    final topAxis = radar.topAxis;
    if (topAxis != null) return topAxis;
    for (final entry in radar.axisEvidence.entries) {
      if (entry.value > 0) return entry.key;
    }
    return TechnicalRadarAxis.retention;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final radar = widget.radar;
    final hasEvidence = radar.hasClassifiedEvidence;
    final selectedCount = radar.axisEvidence[_selectedAxis] ?? 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final footerLabel = _footerLabel(radar);

    return DashboardGlassCard(
      accent: cs.secondary.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeRadarHeader(
            cs: cs,
            badgeLabel:
                hasEvidence
                    ? 'Base: ${radar.sessionLabel}'
                    : 'Radar em formação',
            badgeIcon:
                hasEvidence
                    ? Icons.fitness_center_outlined
                    : Icons.radar_outlined,
          ),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: TitansTechnicalRadar(
                variant: TitansTechnicalRadarVariant.homePreview,
                interactive: hasEvidence,
                enableSweep: true,
                enableHolographicMode: true,
                enablePerspectiveControls: false,
                initialPerspective: TitansRadarPerspective.live,
                enableHudDetails: true,
                showDistribution: false,
                showLegend: false,
                showGhostPolygon: false,
                showMetrics: false,
                showSafetyCopy: false,
                contained: false,
                axisEvidence: radar.axisEvidence,
                classifiedEvidenceCount: radar.classifiedEvidenceCount,
                awaitingClassificationCount: radar.awaitingClassificationCount,
                stateLabel:
                    hasEvidence
                        ? 'Radar técnico ativo'
                        : 'Mapa técnico em formação',
                initialFocusedAxis: hasEvidence ? _selectedAxis : null,
                allowFocusClear: false,
                onFocusedAxisChanged: (axis) {
                  if (axis == null || axis == _selectedAxis) return;
                  setState(() => _selectedAxis = axis);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _HomeRadarAxisReading(
              key: ValueKey<String>(
                hasEvidence ? _selectedAxis.name : 'empty-radar',
              ),
              axis: _selectedAxis,
              count: selectedCount,
              dominant: radar.topAxis == _selectedAxis,
              hasEvidence: hasEvidence,
              emptyText: radar.nextStepLabel,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HomeRadarSignalChip(
                label: footerLabel,
                icon: Icons.dataset_outlined,
                color: cs.primary,
              ),
              if (radar.awaitingClassificationCount > 0)
                _HomeRadarSignalChip(
                  label: radar.awaitingEvidenceLabel,
                  icon: Icons.pending_actions_outlined,
                  color: Colors.amber,
                ),
              _HomeRadarFooterButton(
                label:
                    hasEvidence || widget.onRegisterTraining == null
                        ? 'Explorar mapa técnico'
                        : 'Registrar treino',
                icon:
                    hasEvidence || widget.onRegisterTraining == null
                        ? Icons.map_outlined
                        : Icons.add,
                onPressed:
                    hasEvidence || widget.onRegisterTraining == null
                        ? widget.onOpenMap
                        : widget.onRegisterTraining!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _footerLabel(HomeTechnicalRadarViewModel radar) {
    if (!radar.hasClassifiedEvidence) return 'Sem evidências classificadas';
    return '${radar.classifiedEvidenceLabel} · ${radar.sessionLabel}';
  }
}

class _HomeRadarAxisReading extends StatelessWidget {
  final TechnicalRadarAxis axis;
  final int count;
  final bool dominant;
  final bool hasEvidence;
  final String emptyText;

  const _HomeRadarAxisReading({
    super.key,
    required this.axis,
    required this.count,
    required this.dominant,
    required this.hasEvidence,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _homeRadarAxisColor(context, axis);
    final text = _readingText();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.74),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.22,
            ),
          ),
        ),
      ],
    );
  }

  String _readingText() {
    if (!hasEvidence) return 'Radar em formação. $emptyText';
    if (count <= 0) {
      return '${axis.displayLabel} ainda não tem evidências classificadas.';
    }
    final suffix =
        count == 1 ? 'evidência registrada' : 'evidências registradas';
    final marker = dominant ? ' Eixo mais presente no mapa.' : '';
    return '${axis.displayLabel}: $count $suffix.$marker';
  }
}

class _HomeRadarSignalChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _HomeRadarSignalChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 96,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRadarFooterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _HomeRadarFooterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

Color _homeRadarAxisColor(BuildContext context, TechnicalRadarAxis axis) {
  final cs = Theme.of(context).colorScheme;
  return switch (axis) {
    TechnicalRadarAxis.retention => const Color(0xFF4CC9F0),
    TechnicalRadarAxis.transition => TitansUI.actionGold,
    TechnicalRadarAxis.control => cs.tertiary,
    TechnicalRadarAxis.attack => cs.secondary,
    TechnicalRadarAxis.unclassified => cs.onSurface.withValues(alpha: 0.56),
  };
}

class _HomeRadarHeader extends StatelessWidget {
  final ColorScheme cs;
  final String badgeLabel;
  final IconData badgeIcon;

  const _HomeRadarHeader({
    required this.cs,
    required this.badgeLabel,
    required this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardSectionHeaderCompact(title: 'MAPA TÉCNICO'),
            const SizedBox(height: 4),
            Text(
              'Leitura viva do seu jogo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
        final badge = DashboardInsightBadge(
          label: badgeLabel,
          color: cs.primary,
          icon: badgeIcon,
        );

        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 8), badge],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 10),
            badge,
          ],
        );
      },
    );
  }
}
