part of '../../screen/master_panel_screen.dart';

class _TeacherAttentionCard extends StatefulWidget {
  final List<_AttentionQueueItem> items;
  final bool showListWhenExpanded;
  final ValueChanged<MasterPanelStudentEntry> onOpen;

  const _TeacherAttentionCard({
    required this.items,
    required this.showListWhenExpanded,
    required this.onOpen,
  });

  @override
  State<_TeacherAttentionCard> createState() => _TeacherAttentionCardState();
}

class _TeacherAttentionCardState extends State<_TeacherAttentionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleItems = widget.items.take(4).toList();
    final hiddenCount = widget.items.length - visibleItems.length;
    final preview = _previewLabel(widget.items);
    final hasItems = widget.items.isNotEmpty;

    return TitansCard(
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter):
                    _toggleExpanded,
                const SingleActivator(LogicalKeyboardKey.space):
                    _toggleExpanded,
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(TitansRadius.md),
                  onTap: _toggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TitansUI.spaceXs,
                      vertical: TitansUI.spaceXs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasItems
                              ? Icons.assignment_late_outlined
                              : Icons.check_circle_outline,
                          color:
                              hasItems
                                  ? TitansUI.actionGold
                                  : TitansUI.successGreen,
                          size: 18,
                        ),
                        const SizedBox(width: TitansUI.spaceXs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Precisa de atenção',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: TitansUI.spaceXs),
                                  _AttentionCounter(count: widget.items.length),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasItems
                                    ? preview
                                    : 'Nenhum cadastro pendente no momento.',
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
                        const SizedBox(width: TitansUI.spaceXs),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: cs.onSurface.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child:
                _expanded
                    ? AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 140),
                      child: Padding(
                        padding: const EdgeInsets.only(top: TitansUI.spaceXs),
                        child:
                            hasItems
                                ? _AttentionExpandedBody(
                                  items: visibleItems,
                                  hiddenCount: hiddenCount,
                                  showList: widget.showListWhenExpanded,
                                  onOpen: widget.onOpen,
                                )
                                : const _AttentionEmptyState(),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _previewLabel(List<_AttentionQueueItem> items) {
    if (items.isEmpty) return '';
    final names = items
        .take(3)
        .map((item) => item.entry.displayStudent.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    final remaining = items.length - 3;
    if (remaining > 0) return '$names +$remaining';
    return names;
  }
}

class _AttentionExpandedBody extends StatelessWidget {
  final List<_AttentionQueueItem> items;
  final int hiddenCount;
  final bool showList;
  final ValueChanged<MasterPanelStudentEntry> onOpen;

  const _AttentionExpandedBody({
    required this.items,
    required this.hiddenCount,
    required this.showList,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!showList) {
      return Text(
        'A lista completa já está aplicada pelo filtro Atenção abaixo.',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.62),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 560;
        final itemWidth =
            twoColumns
                ? (constraints.maxWidth - TitansUI.spaceXs) / 2
                : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: TitansUI.spaceXs,
              runSpacing: TitansUI.spaceXs,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: _AttentionQueueTile(
                      item: item,
                      onOpen: () => onOpen(item.entry),
                    ),
                  ),
              ],
            ),
            if (hiddenCount > 0) ...[
              const SizedBox(height: TitansUI.spaceXs),
              Text(
                '+$hiddenCount cadastros aparecem no filtro Atenção.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AttentionCounter extends StatelessWidget {
  final int count;

  const _AttentionCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = count == 0 ? TitansUI.successGreen : TitansUI.actionGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.pill),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: count == 0 ? color : cs.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AttentionEmptyState extends StatelessWidget {
  const _AttentionEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.md),
        color: TitansUI.successGreen.withValues(alpha: 0.08),
        border: Border.all(
          color: TitansUI.successGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: TitansUI.successGreen,
            size: 18,
          ),
          const SizedBox(width: TitansUI.spaceXs),
          Expanded(
            child: Text(
              'Nenhum cadastro pendente no momento.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionQueueTile extends StatelessWidget {
  final _AttentionQueueItem item;
  final VoidCallback onOpen;

  const _AttentionQueueTile({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final student = item.entry.displayStudent;
    final beltColor = _StudentCard.beltUiColor(student.belt);
    final beltName = _StudentCard.beltName(student.belt);
    final textColor =
        beltColor.computeLuminance() > 0.82 ? cs.onSurface : beltColor;

    return InkWell(
      borderRadius: BorderRadius.circular(TitansRadius.md),
      onTap: onOpen,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(TitansUI.spaceSm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TitansRadius.md),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
          border: Border.all(
            color: TitansUI.actionGold.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: beltColor.withValues(alpha: 0.12),
                border: Border.all(color: beltColor.withValues(alpha: 0.34)),
              ),
              child: Icon(Icons.person_outline, color: textColor, size: 16),
            ),
            const SizedBox(width: TitansUI.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$beltName · Grau ${student.degree}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reasonLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TitansUI.actionGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TitansUI.spaceXs),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterEmptyFilterCard extends StatelessWidget {
  const _RosterEmptyFilterCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      padding: const EdgeInsets.all(TitansUI.spaceMd),
      child: Row(
        children: [
          Icon(Icons.filter_alt_off_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: TitansUI.spaceSm),
          Expanded(
            child: Text(
              'Nenhum aluno encontrado com os filtros atuais.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
