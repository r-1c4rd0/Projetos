part of '../../screen/skill_detail_screen.dart';

class _SkillHistoryCard extends StatelessWidget {
  final _SkillDetailViewModel vm;
  final ValueChanged<String> onOpenRecord;

  const _SkillHistoryCard({required this.vm, required this.onOpenRecord});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const previewCount = 8;
    final displayHistory = vm.history.take(previewCount).toList();
    final hasMore = vm.history.length > previewCount;

    return TitansCard(
      accent: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DetailEyebrow('HISTÓRICO'),
              const Spacer(),
              if (hasMore)
                TextButton(
                  onPressed: () => _showFullHistory(context, vm.history),
                  child: Text(
                    'Ver completo (${vm.history.length})',
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
          if (vm.history.isEmpty)
            const TitansStateView.empty(
              title: 'Sem evidência registrada',
              message:
                  'Esta técnica ainda não apareceu nos treinos carregados.',
              compact: true,
            )
          else
            Column(
              children: [
                for (var i = 0; i < displayHistory.length; i++) ...[
                  _HistoryRow(
                    item: displayHistory[i],
                    onOpenRecord: onOpenRecord,
                  ),
                  if (i != displayHistory.length - 1)
                    Divider(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      height: 1,
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _showFullHistory(BuildContext context, List<_SkillHistoryItem> history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _FullHistoryBottomSheet(
            history: history,
            onOpenRecord: onOpenRecord,
          ),
    );
  }
}

class _FullHistoryBottomSheet extends StatelessWidget {
  final List<_SkillHistoryItem> history;
  final ValueChanged<String> onOpenRecord;

  const _FullHistoryBottomSheet({
    required this.history,
    required this.onOpenRecord,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                    'Histórico completo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${history.length} registros',
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
                itemCount: history.length,
                separatorBuilder:
                    (_, __) => Divider(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      height: 1,
                    ),
                itemBuilder: (context, index) {
                  return _HistoryRow(
                    item: history[index],
                    onOpenRecord: onOpenRecord,
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
}

class _HistoryRow extends StatelessWidget {
  final _SkillHistoryItem item;
  final ValueChanged<String> onOpenRecord;

  const _HistoryRow({required this.item, required this.onOpenRecord});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[
      if (item.position != null) item.position!,
      if (item.context != null) item.context!,
      if (item.outcome != null) item.outcome!,
    ];

    final sourceId = item.sourceId;

    return InkWell(
      key: ValueKey(
        'skill-history-record:${sourceId ?? item.date.toIso8601String()}',
      ),
      onTap: sourceId == null ? null : () => onOpenRecord(sourceId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                _formatTimelineDate(item.date),
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.isEmpty ? 'Registro técnico' : details.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (item.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
