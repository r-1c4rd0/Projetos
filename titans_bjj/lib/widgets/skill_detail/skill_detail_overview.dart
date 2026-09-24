part of '../../screen/skill_detail_screen.dart';

class _SkillDetailHeader extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _SkillDetailHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPosition =
        vm.positionCounts.isNotEmpty
            ? vm.positionCounts.keys.first
            : vm.preferredPosition;

    return TitansCard(
      accent: cs.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.1),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.psychology_alt_outlined,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vm.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vm.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Evidências registradas nos treinos.',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                if (vm.lastPracticedAt != null || topPosition != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (vm.lastPracticedAt != null)
                        _HeaderMeta(
                          icon: Icons.schedule_outlined,
                          text: 'Última: ${vm.lastPracticedLabel}',
                        ),
                      if (topPosition != null)
                        _HeaderMeta(
                          icon: Icons.account_tree_outlined,
                          text: topPosition,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 3),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EvidenceSummaryCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _EvidenceSummaryCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      accent: cs.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('RESUMO DE EVIDÊNCIAS'),
          const SizedBox(height: 8),
          TitansCompactMetricGrid(
            spacing: 8,
            children: [
              TitansCompactMetricCard(
                label: 'REGISTROS',
                value: vm.evidenceCount.toString(),
                color: cs.primary,
              ),
              TitansCompactMetricCard(
                label: 'SESSÕES',
                value: vm.sessionCount.toString(),
                color: cs.secondary,
              ),
              TitansCompactMetricCard(
                label: 'ÚLTIMA',
                value: vm.lastPracticedLabel,
                color: Colors.lightGreenAccent,
              ),
              TitansCompactMetricCard(
                label: 'CONTEXTOS',
                value: vm.contextCount.toString(),
                color: Colors.amber,
              ),
            ],
          ),
          if (vm.resultLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ChipWrap(labels: vm.resultLabels),
          ],
          if (vm.evidenceCount > 0 && vm.evidenceCount < 3) ...[
            const SizedBox(height: 8),
            Text(
              'Pouca evidência registrada. Mais treinos ajudam a formar uma leitura mais consistente.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.66),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PositionsContextCard extends StatelessWidget {
  final _SkillDetailViewModel vm;

  const _PositionsContextCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = vm.positionCounts.entries.toList();
    final maxCount = entries.isNotEmpty ? entries.first.value : 1;
    final displayEntries = entries.take(3).toList();
    final hasMore = entries.length > 3;

    return TitansCard(
      accent: Colors.lightGreenAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _DetailEyebrow('POSIÇÕES E CONTEXTOS')),
              if (hasMore)
                TextButton(
                  onPressed:
                      () => _showAllPositions(context, entries, maxCount),
                  child: Text(
                    'Ver todas (${entries.length})',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const TitansStateView.empty(
              title: 'Sem posição suficiente',
              message:
                  'Registre posição/contexto nos treinos para refinar esta visão.',
              compact: true,
            )
          else
            Column(
              children: [
                for (var i = 0; i < displayEntries.length; i++) ...[
                  _PositionBar(
                    label: displayEntries[i].key,
                    count: displayEntries[i].value,
                    maxCount: maxCount,
                    color: _positionColor(i),
                  ),
                  if (i != displayEntries.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          if (vm.contextLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ChipWrap(labels: vm.contextLabels),
          ],
        ],
      ),
    );
  }

  Color _positionColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return const Color(0xFFB0BEC5);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return TitansUI.technicalBlue;
    }
  }

  void _showAllPositions(
    BuildContext context,
    List<MapEntry<String, int>> entries,
    int maxCount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              _AllPositionsBottomSheet(entries: entries, maxCount: maxCount),
    );
  }
}

class _PositionBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color color;

  const _PositionBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction =
        maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0).toDouble();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              color: color,
              backgroundColor: cs.onSurface.withValues(alpha: 0.05),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${count}x',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AllPositionsBottomSheet extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int maxCount;

  const _AllPositionsBottomSheet({
    required this.entries,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Posições e contextos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${entries.length} posições',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final color = _positionColor(index);

                  return _PositionBar(
                    label: entry.key,
                    count: entry.value,
                    maxCount: maxCount,
                    color: color,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _positionColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return const Color(0xFFB0BEC5);
      case 2:
        return const Color(0xFFCD7F32);
      default:
        return TitansUI.technicalBlue;
    }
  }
}
