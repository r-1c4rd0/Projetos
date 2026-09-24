part of 'training_history_journal.dart';

class _TrainingHistoryListPane extends StatelessWidget {
  final List<TrainingSessionHistoryItem> allItems;
  final List<TrainingSessionHistoryItem> filteredItems;
  final List<TrainingSessionHistoryItem> visibleItems;
  final String? selectedSessionId;
  final TextEditingController searchController;
  final Widget activeFilters;
  final bool canEdit;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onLoadMore;
  final ValueChanged<TrainingSessionHistoryItem> onSessionSelected;
  final Future<void> Function()? onAddTraining;

  const _TrainingHistoryListPane({
    required this.allItems,
    required this.filteredItems,
    required this.visibleItems,
    required this.selectedSessionId,
    required this.searchController,
    required this.activeFilters,
    required this.canEdit,
    required this.onOpenFilters,
    required this.onClearSearch,
    required this.onLoadMore,
    required this.onSessionSelected,
    required this.onAddTraining,
  });

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();
    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar treino',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon:
                        query.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: onClearSearch,
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filtros',
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          activeFilters,
          const SizedBox(height: 8),
          Text(
            '${filteredItems.length} resultados no histórico completo',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.60),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (allItems.isEmpty)
            TitansEmptyState(
              icon: Icons.fitness_center_outlined,
              title: 'Sem treinos registrados',
              message: 'Adicione uma sessão para iniciar o histórico.',
              compact: true,
              action:
                  canEdit
                      ? FilledButton.icon(
                        onPressed: onAddTraining,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar treino'),
                      )
                      : null,
            )
          else if (filteredItems.isEmpty)
            const TitansEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Nenhum treino encontrado com esses filtros.',
              message: 'Ajuste a busca ou remova algum filtro ativo.',
              compact: true,
            )
          else ...[
            for (final item in visibleItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CompactSessionRow(
                  item: item,
                  selected: selectedSessionId == item.id,
                  onPressed: () => onSessionSelected(item),
                ),
              ),
            if (filteredItems.length > visibleItems.length)
              Center(
                child: OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(
                    'Carregar mais '
                    '(${filteredItems.length - visibleItems.length})',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactSessionRow extends StatelessWidget {
  final TrainingSessionHistoryItem item;
  final bool selected;
  final VoidCallback onPressed;

  const _CompactSessionRow({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color:
          selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: _statusColor(context, item.session),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.dateLabel} · ${item.summary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.62),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.chevron_right,
                color:
                    selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.46),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
