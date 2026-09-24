import 'package:flutter/material.dart';

import '../features/training/application/training_use_cases.dart';
import '../features/training/domain/training_models.dart';

class TrainingHistoryActiveFilters extends StatelessWidget {
  final String query;
  final TrainingHistoryPeriodFilter period;
  final TrainingHistoryResultFilter result;
  final TrainingHistoryContextFilter contextFilter;
  final String? positionFilter;
  final String? techniqueFilter;
  final VoidCallback onClearSearch;
  final VoidCallback onClearPeriod;
  final VoidCallback onClearResult;
  final VoidCallback onClearContext;
  final VoidCallback onClearPosition;
  final VoidCallback onClearTechnique;

  const TrainingHistoryActiveFilters({
    super.key,
    required this.query,
    required this.period,
    required this.result,
    required this.contextFilter,
    required this.positionFilter,
    required this.techniqueFilter,
    required this.onClearSearch,
    required this.onClearPeriod,
    required this.onClearResult,
    required this.onClearContext,
    required this.onClearPosition,
    required this.onClearTechnique,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (query.isNotEmpty)
        _ActiveHistoryChip(label: 'Busca: $query', onDeleted: onClearSearch),
      if (period != TrainingHistoryPeriodFilter.all)
        _ActiveHistoryChip(label: period.label, onDeleted: onClearPeriod),
      if (result != TrainingHistoryResultFilter.all)
        _ActiveHistoryChip(label: result.label, onDeleted: onClearResult),
      if (contextFilter != TrainingHistoryContextFilter.all)
        _ActiveHistoryChip(
          label: contextFilter.label,
          onDeleted: onClearContext,
        ),
      if (positionFilter != null)
        _ActiveHistoryChip(label: positionFilter!, onDeleted: onClearPosition),
      if (techniqueFilter != null)
        _ActiveHistoryChip(
          label: techniqueFilter!,
          onDeleted: onClearTechnique,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _ActiveHistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveHistoryChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      visualDensity: VisualDensity.compact,
      backgroundColor: cs.primary.withValues(alpha: 0.10),
      side: BorderSide(color: cs.primary.withValues(alpha: 0.22)),
      labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
    );
  }
}

class TrainingHistoryFilterSheet extends StatefulWidget {
  final TrainingHistoryFilters initial;
  final List<String> positions;
  final List<String> techniques;

  const TrainingHistoryFilterSheet({
    super.key,
    required this.initial,
    required this.positions,
    required this.techniques,
  });

  @override
  State<TrainingHistoryFilterSheet> createState() =>
      _TrainingHistoryFilterSheetState();
}

class _TrainingHistoryFilterSheetState
    extends State<TrainingHistoryFilterSheet> {
  late TrainingHistoryPeriodFilter _period = widget.initial.period;
  late TrainingHistoryResultFilter _result = widget.initial.result;
  late TrainingHistoryContextFilter _contextFilter = widget.initial.context;
  late String? _positionFilter = widget.initial.position;
  late String? _techniqueFilter = widget.initial.technique;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterGroup(
                title: 'Período',
                children: [
                  for (final option in TrainingHistoryPeriodFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _period == option,
                      onSelected: () => setState(() => _period = option),
                    ),
                ],
              ),
              _FilterGroup(
                title: 'Resultado',
                children: [
                  for (final option in TrainingHistoryResultFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _result == option,
                      onSelected: () => setState(() => _result = option),
                    ),
                ],
              ),
              _FilterGroup(
                title: 'Tipo/contexto',
                children: [
                  for (final option in TrainingHistoryContextFilter.values)
                    _filterChoice(
                      label: option.label,
                      selected: _contextFilter == option,
                      onSelected: () => setState(() => _contextFilter = option),
                    ),
                ],
              ),
              _filterDropdown(
                label: 'Posicao',
                value: _positionFilter,
                values: widget.positions,
                onChanged: (value) => setState(() => _positionFilter = value),
              ),
              const SizedBox(height: 10),
              _filterDropdown(
                label: 'Tecnica',
                value: _techniqueFilter,
                values: widget.techniques,
                onChanged: (value) => setState(() => _techniqueFilter = value),
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _period = TrainingHistoryPeriodFilter.all;
                        _result = TrainingHistoryResultFilter.all;
                        _contextFilter = TrainingHistoryContextFilter.all;
                        _positionFilter = null;
                        _techniqueFilter = null;
                      });
                    },
                    child: const Text('Limpar filtros'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        TrainingHistoryFilters(
                          period: _period,
                          result: _result,
                          context: _contextFilter,
                          position: _positionFilter,
                          technique: _techniqueFilter,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChoice({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        for (final item in values)
          DropdownMenuItem<String?>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FilterGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class TrainingHistoryFilters {
  final TrainingHistoryPeriodFilter period;
  final TrainingHistoryResultFilter result;
  final TrainingHistoryContextFilter context;
  final String? position;
  final String? technique;

  const TrainingHistoryFilters({
    required this.period,
    required this.result,
    required this.context,
    required this.position,
    required this.technique,
  });
}

enum TrainingHistoryPeriodFilter { sevenDays, thirtyDays, threeMonths, all }

enum TrainingHistoryResultFilter { all, worked, partial, review, none }

enum TrainingHistoryContextFilter {
  all,
  academy,
  home,
  sparring,
  drill,
  competition,
}

extension TrainingHistoryPeriodFilterLabel on TrainingHistoryPeriodFilter {
  String get label {
    switch (this) {
      case TrainingHistoryPeriodFilter.sevenDays:
        return '7 dias';
      case TrainingHistoryPeriodFilter.thirtyDays:
        return '30 dias';
      case TrainingHistoryPeriodFilter.threeMonths:
        return '3 meses';
      case TrainingHistoryPeriodFilter.all:
        return 'Todos';
    }
  }
}

extension TrainingHistoryResultFilterLabel on TrainingHistoryResultFilter {
  String get label {
    switch (this) {
      case TrainingHistoryResultFilter.all:
        return 'Todos';
      case TrainingHistoryResultFilter.worked:
        return 'Funcionou';
      case TrainingHistoryResultFilter.partial:
        return 'Parcial';
      case TrainingHistoryResultFilter.review:
        return 'Revisar';
      case TrainingHistoryResultFilter.none:
        return 'Sem resultado';
    }
  }

  TrainingHistoryResultBucket get domainBucket {
    switch (this) {
      case TrainingHistoryResultFilter.all:
        return TrainingHistoryResultBucket.none;
      case TrainingHistoryResultFilter.worked:
        return TrainingHistoryResultBucket.worked;
      case TrainingHistoryResultFilter.partial:
        return TrainingHistoryResultBucket.partial;
      case TrainingHistoryResultFilter.review:
        return TrainingHistoryResultBucket.review;
      case TrainingHistoryResultFilter.none:
        return TrainingHistoryResultBucket.none;
    }
  }
}

extension TrainingHistoryContextFilterLabel on TrainingHistoryContextFilter {
  String get label {
    switch (this) {
      case TrainingHistoryContextFilter.all:
        return 'Todos';
      case TrainingHistoryContextFilter.academy:
        return 'Academia';
      case TrainingHistoryContextFilter.home:
        return 'Casa';
      case TrainingHistoryContextFilter.sparring:
        return 'Rola';
      case TrainingHistoryContextFilter.drill:
        return 'Drill';
      case TrainingHistoryContextFilter.competition:
        return 'Competicao';
    }
  }

  TrainingHistoryContextBucket get domainBucket {
    switch (this) {
      case TrainingHistoryContextFilter.all:
        return TrainingHistoryContextBucket.academy;
      case TrainingHistoryContextFilter.academy:
        return TrainingHistoryContextBucket.academy;
      case TrainingHistoryContextFilter.home:
        return TrainingHistoryContextBucket.home;
      case TrainingHistoryContextFilter.sparring:
        return TrainingHistoryContextBucket.sparring;
      case TrainingHistoryContextFilter.drill:
        return TrainingHistoryContextBucket.drill;
      case TrainingHistoryContextFilter.competition:
        return TrainingHistoryContextBucket.competition;
    }
  }
}

extension TrainingHistoryPeriodFilterDomain on TrainingHistoryPeriodFilter {
  TrainingHistoryPeriod get domainPeriod {
    switch (this) {
      case TrainingHistoryPeriodFilter.sevenDays:
        return TrainingHistoryPeriod.sevenDays;
      case TrainingHistoryPeriodFilter.thirtyDays:
        return TrainingHistoryPeriod.thirtyDays;
      case TrainingHistoryPeriodFilter.threeMonths:
        return TrainingHistoryPeriod.threeMonths;
      case TrainingHistoryPeriodFilter.all:
        return TrainingHistoryPeriod.all;
    }
  }
}

List<String> trainingHistoryFilterValues(Iterable<String> values) {
  final deduped = dedupeTrainingDisplayValues(values);
  return List<String>.from(deduped)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
