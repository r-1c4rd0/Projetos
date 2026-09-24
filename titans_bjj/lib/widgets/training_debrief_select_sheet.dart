import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../service/jiu_jitsu_taxonomy.dart';

class TrainingDebriefSelection {
  final String label;
  final bool addToAcademy;

  const TrainingDebriefSelection({
    required this.label,
    required this.addToAcademy,
  });
}

enum _TechniqueQuickFilter {
  all,
  submissions,
  passing,
  sweeps,
  takedowns,
  escapesDefense,
  other,
}

class TrainingDebriefSelectSheet extends StatefulWidget {
  final String title;
  final String placeholder;
  final List<String> options;
  final List<String> recentOptions;
  final String currentValue;
  final bool canAddToAcademy;

  const TrainingDebriefSelectSheet({
    super.key,
    required this.title,
    required this.placeholder,
    required this.options,
    required this.recentOptions,
    required this.currentValue,
    required this.canAddToAcademy,
  });

  @override
  State<TrainingDebriefSelectSheet> createState() =>
      _TrainingDebriefSelectSheetState();
}

class _TrainingDebriefSelectSheetState
    extends State<TrainingDebriefSelectSheet> {
  late final TextEditingController _search;
  late String _selected;
  bool _addSelectedToAcademy = false;
  _TechniqueQuickFilter _selectedTechniqueFilter = _TechniqueQuickFilter.all;

  bool get _isTechniqueSheet => widget.title.toLowerCase().contains('cnica');

  bool get _isPositionSheet => widget.title.toLowerCase().contains('posi');

  String get _subtitle {
    if (_isTechniqueSheet) {
      return 'Escolha uma técnica usada neste treino';
    }
    if (_isPositionSheet) {
      return 'Onde essa técnica foi trabalhada?';
    }
    return 'Escolha uma opção para continuar';
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue.trim();
    _search = TextEditingController(text: _selected);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _filteredRecentOptions(String query) {
    final filtered = <String>[];
    final seen = <String>{};

    for (final option in widget.recentOptions) {
      final label = option.trim();
      if (label.isEmpty) continue;
      if (!_matchesSearch(label, query)) continue;
      if (!_matchesTechniqueFilter(label)) continue;

      final key = JiuJitsuTaxonomy.normalizedKey(label);
      if (key.isEmpty || !seen.add(key)) continue;

      filtered.add(label);
      if (filtered.length == 6) break;
    }

    return filtered;
  }

  bool _matchesSearch(String option, String query) {
    final normalizedQuery = query.toLowerCase();
    return normalizedQuery.isEmpty ||
        _searchableTechniqueText(
          option,
        ).toLowerCase().contains(normalizedQuery);
  }

  bool _isHiddenTechniqueAlias(String option) {
    if (!_isTechniqueSheet) return false;
    if (_isPortugueseBowAndArrow(option)) return false;

    final key = JiuJitsuTaxonomy.normalizedKey(option);
    if (key != 'bow and arrow' && key != 'bow and arrow choke') return false;

    return widget.options.any(_isPortugueseBowAndArrow);
  }

  bool _isPortugueseBowAndArrow(String option) {
    final label = option.toLowerCase();
    return label.contains('arco') && label.contains('flecha');
  }

  String _searchableTechniqueText(String option) {
    if (!_isTechniqueSheet) return option;

    final key = JiuJitsuTaxonomy.normalizedKey(option);
    if (key == 'arco e flecha') {
      return '$option bow bow and arrow bow and arrow choke';
    }
    if (key == 'bow and arrow' || key == 'bow and arrow choke') {
      return '$option arco flecha arco e flecha';
    }

    return option;
  }

  Set<String> _techniqueAliasKeys(String option) {
    if (!_isTechniqueSheet) return const <String>{};

    final key = JiuJitsuTaxonomy.normalizedKey(option);
    if (key == 'arco e flecha' ||
        key == 'bow and arrow' ||
        key == 'bow and arrow choke') {
      return const {
        'arco',
        'flecha',
        'arco e flecha',
        'bow',
        'bow and arrow',
        'bow and arrow choke',
      };
    }

    return const <String>{};
  }

  bool _matchesTechniqueFilter(String option) {
    if (!_isTechniqueSheet) return true;
    if (_selectedTechniqueFilter == _TechniqueQuickFilter.all) return true;
    return _techniqueFilterFor(option) == _selectedTechniqueFilter;
  }

  _TechniqueQuickFilter _techniqueFilterFor(String option) {
    final key = JiuJitsuTaxonomy.normalizedKey(option);
    if (key.contains('raspagem') || key.contains('sweep')) {
      return _TechniqueQuickFilter.sweeps;
    }

    final category = JiuJitsuTaxonomy.categoryFor(technique: option);
    switch (category) {
      case JiuJitsuSkillCategory.submissions:
        return _TechniqueQuickFilter.submissions;
      case JiuJitsuSkillCategory.passing:
        return _TechniqueQuickFilter.passing;
      case JiuJitsuSkillCategory.takedowns:
        return _TechniqueQuickFilter.takedowns;
      case JiuJitsuSkillCategory.escapes:
      case JiuJitsuSkillCategory.defense:
        return _TechniqueQuickFilter.escapesDefense;
      case JiuJitsuSkillCategory.guard:
      case JiuJitsuSkillCategory.mount:
      case JiuJitsuSkillCategory.back:
      case JiuJitsuSkillCategory.other:
        return _TechniqueQuickFilter.other;
    }
  }

  String _techniqueFilterLabel(_TechniqueQuickFilter filter) {
    switch (filter) {
      case _TechniqueQuickFilter.all:
        return 'Todas';
      case _TechniqueQuickFilter.submissions:
        return 'Finaliza\u00e7\u00f5es';
      case _TechniqueQuickFilter.passing:
        return 'Passagens';
      case _TechniqueQuickFilter.sweeps:
        return 'Raspagens';
      case _TechniqueQuickFilter.takedowns:
        return 'Quedas';
      case _TechniqueQuickFilter.escapesDefense:
        return 'Defesas';
      case _TechniqueQuickFilter.other:
        return 'Outras';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _search.text.trim();
    final queryKey = JiuJitsuTaxonomy.normalizedKey(query);
    final recentOptions = _filteredRecentOptions(query);
    final recentKeys =
        recentOptions.map(JiuJitsuTaxonomy.normalizedKey).toSet();
    final filtered =
        widget.options
            .where((option) => !_isHiddenTechniqueAlias(option))
            .where((option) => _matchesSearch(option, query))
            .where(_matchesTechniqueFilter)
            .where(
              (option) =>
                  !recentKeys.contains(JiuJitsuTaxonomy.normalizedKey(option)),
            )
            .toList();
    final exactMatch = widget.options.any(
      (option) =>
          JiuJitsuTaxonomy.normalizedKey(option) == queryKey ||
          _techniqueAliasKeys(option).contains(queryKey),
    );
    final showCustom = query.isNotEmpty && !exactMatch;
    final selectedIsVisible =
        _selected.trim().isNotEmpty &&
        ((showCustom && _selected == query) ||
            (_matchesSearch(_selected, query) &&
                _matchesTechniqueFilter(_selected)));
    final valueToConfirm = selectedIsVisible ? _selected : '';
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final availableHeight = math.max(
      220.0,
      media.size.height - bottomInset - media.padding.vertical - 32,
    );
    final compactHeight = availableHeight < 320 || media.size.height < 520;
    final customOptionCount = showCustom ? (widget.canAddToAcademy ? 2 : 1) : 0;
    final showEmptyResults = filtered.isEmpty && !showCustom;
    final resultRowCount =
        customOptionCount + filtered.length + (showEmptyResults ? 1 : 0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: math.min(availableHeight, 680),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compactHeight) ...[
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  isDense: compactHeight,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.34),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                onChanged:
                    (_) => setState(() {
                      _addSelectedToAcademy = false;
                    }),
              ),
              SizedBox(height: compactHeight ? 6 : 10),
              if (_isTechniqueSheet) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useWrap = constraints.maxWidth >= 520;
                    final chips =
                        _TechniqueQuickFilter.values.map((filter) {
                          final selected = _selectedTechniqueFilter == filter;
                          return ChoiceChip(
                            label: Text(_techniqueFilterLabel(filter)),
                            selected: selected,
                            onSelected:
                                (_) => setState(() {
                                  _selectedTechniqueFilter = filter;
                                  _addSelectedToAcademy = false;
                                }),
                            visualDensity: VisualDensity.compact,
                            labelStyle: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w900 : FontWeight.w700,
                            ),
                          );
                        }).toList();

                    if (useWrap) {
                      return Wrap(spacing: 8, runSpacing: 8, children: chips);
                    }

                    return SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsetsDirectional.only(
                          start: 4,
                          end: 20,
                        ),
                        itemCount: chips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => chips[index],
                      ),
                    );
                  },
                ),
                SizedBox(height: compactHeight ? 6 : 10),
              ],
              if (recentOptions.isNotEmpty) ...[
                Text(
                  'Recentes',
                  style: textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: compactHeight ? 4 : 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.only(
                      start: 4,
                      end: 20,
                    ),
                    itemCount: recentOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final option = recentOptions[index];
                      final selected =
                          JiuJitsuTaxonomy.normalizedKey(option) ==
                              JiuJitsuTaxonomy.normalizedKey(_selected) &&
                          !_addSelectedToAcademy;

                      return ChoiceChip(
                        label: Text(option),
                        selected: selected,
                        onSelected:
                            (_) => setState(() {
                              _selected = option;
                              _addSelectedToAcademy = false;
                            }),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: compactHeight ? 6 : 10),
              ],
              SizedBox(
                height: compactHeight ? 8 : 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                    color: cs.surface.withValues(alpha: 0.22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: resultRowCount,
                      itemBuilder: (context, index) {
                        if (showCustom && index == 0) {
                          return _DebriefOptionTile(
                            label: 'Usar "$query"',
                            selected:
                                _selected == query && !_addSelectedToAcademy,
                            accent: true,
                            onTap:
                                () => setState(() {
                                  _selected = query;
                                  _addSelectedToAcademy = false;
                                }),
                          );
                        }
                        if (showCustom &&
                            widget.canAddToAcademy &&
                            index == 1) {
                          return _DebriefOptionTile(
                            label: 'Adicionar "$query" à lista da academia',
                            selected:
                                _selected == query && _addSelectedToAcademy,
                            accent: true,
                            onTap:
                                () => setState(() {
                                  _selected = query;
                                  _addSelectedToAcademy = true;
                                }),
                          );
                        }
                        final optionIndex = index - customOptionCount;
                        if (optionIndex >= 0 && optionIndex < filtered.length) {
                          final option = filtered[optionIndex];
                          return _DebriefOptionTile(
                            label: option,
                            selected:
                                JiuJitsuTaxonomy.normalizedKey(option) ==
                                    JiuJitsuTaxonomy.normalizedKey(_selected) &&
                                !_addSelectedToAcademy,
                            onTap:
                                () => setState(() {
                                  _selected = option;
                                  _addSelectedToAcademy = false;
                                }),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 28,
                          ),
                          child: Text(
                            'Nenhum resultado encontrado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: compactHeight ? 4 : 8),
              Text(
                'Exibindo ${filtered.length + customOptionCount} de ${widget.options.length + customOptionCount} op\u00e7\u00f5es encontradas.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: compactHeight ? 4 : 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        valueToConfirm.trim().isEmpty
                            ? null
                            : () => Navigator.pop(
                              context,
                              TrainingDebriefSelection(
                                label: valueToConfirm.trim(),
                                addToAcademy: _addSelectedToAcademy,
                              ),
                            ),
                    icon: const Icon(Icons.check),
                    label: Text(
                      valueToConfirm.trim().isEmpty
                          ? 'Selecione uma op\u00e7\u00e3o'
                          : (_isTechniqueSheet
                              ? 'Usar t\u00e9cnica'
                              : 'Usar op\u00e7\u00e3o'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebriefOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _DebriefOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color:
          selected
              ? cs.primary.withValues(alpha: 0.16)
              : accent
              ? cs.secondary.withValues(alpha: 0.12)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle
                      : accent
                      ? Icons.add_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color:
                      selected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      color:
                          selected
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.84),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
