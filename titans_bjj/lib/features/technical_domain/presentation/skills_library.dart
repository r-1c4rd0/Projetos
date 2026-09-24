import 'package:flutter/material.dart';

import '../../../core/titans_ui.dart';
import '../../../model/coach_evaluation.dart';
import '../../../service/training_aggregator.dart';
import 'skills_library_model.dart';

class SkillsLibrary extends StatefulWidget {
  final SkillsLibraryModel model;
  final String contextKey;
  final String? initialPosition;
  final String? initialSkillId;
  final ValueChanged<SkillsLibraryRecord> onOpenRecord;
  final ValueChanged<SkillsLibraryTechnique> onOpenTechniqueDetail;

  const SkillsLibrary({
    super.key,
    required this.model,
    required this.contextKey,
    required this.initialPosition,
    required this.initialSkillId,
    required this.onOpenRecord,
    required this.onOpenTechniqueDetail,
  });

  @override
  State<SkillsLibrary> createState() => _SkillsLibraryState();
}

class _SkillsLibraryState extends State<SkillsLibrary> {
  static const _initialRecordLimit = 5;

  final TextEditingController _searchController = TextEditingController();
  SkillsLibraryMode _mode = SkillsLibraryMode.position;
  String? _selectedGroupKey;
  String? _selectedSkillId;
  String _query = '';
  int _visibleRecords = _initialRecordLimit;
  bool _incomingSelectionMissing = false;

  @override
  void initState() {
    super.initState();
    _applyIncomingSelection();
  }

  @override
  void didUpdateWidget(covariant SkillsLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contextKey != oldWidget.contextKey) {
      _mode = SkillsLibraryMode.position;
      _selectedGroupKey = null;
      _selectedSkillId = null;
      _query = '';
      _searchController.clear();
      _visibleRecords = _initialRecordLimit;
      _applyIncomingSelection();
      return;
    }

    final incomingChanged =
        widget.initialPosition != oldWidget.initialPosition ||
        widget.initialSkillId != oldWidget.initialSkillId;
    if (incomingChanged) {
      _applyIncomingSelection();
      return;
    }
    _discardUnavailableSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SkillsLibraryGroup> get _groups => widget.model.groupsFor(_mode);

  SkillsLibraryGroup? get _selectedGroup =>
      _groupByKey(_groups, _selectedGroupKey);

  SkillsLibraryTechnique? get _selectedTechnique {
    final group = _selectedGroup;
    if (group == null) return null;
    return _techniqueById(group.techniques, _selectedSkillId);
  }

  void _applyIncomingSelection() {
    final skillId = widget.initialSkillId?.trim();
    final position = widget.initialPosition?.trim();
    final normalizedPosition =
        position == null ? null : JiuJitsuTaxonomy.normalizedKey(position);
    SkillsLibraryGroup? positionGroup;

    if (normalizedPosition != null && normalizedPosition.isNotEmpty) {
      for (final group in widget.model.positionGroups) {
        if (JiuJitsuTaxonomy.normalizedKey(group.label) == normalizedPosition) {
          positionGroup = group;
          break;
        }
      }
    }

    final matchingGroup =
        skillId == null || skillId.isEmpty
            ? positionGroup
            : positionGroup != null
            ? (_techniqueById(positionGroup.techniques, skillId) == null
                ? null
                : positionGroup)
            : _groupForSkill(widget.model.positionGroups, skillId);

    _mode = SkillsLibraryMode.position;
    _selectedGroupKey = (matchingGroup ?? positionGroup)?.key;
    _selectedSkillId =
        matchingGroup == null || skillId == null
            ? null
            : _techniqueById(matchingGroup.techniques, skillId)?.skillId;
    _visibleRecords = _initialRecordLimit;
    _incomingSelectionMissing =
        skillId != null && skillId.isNotEmpty && _selectedSkillId == null;
  }

  void _discardUnavailableSelection() {
    final group = _selectedGroup;
    if (group == null) {
      _selectedGroupKey = null;
      _selectedSkillId = null;
      return;
    }
    if (_selectedSkillId != null && _selectedTechnique == null) {
      _selectedSkillId = null;
    }
  }

  void _changeMode(SkillsLibraryMode mode) {
    if (mode == _mode) return;
    final selectedSkillId = _selectedSkillId;
    final groups = widget.model.groupsFor(mode);
    final matchingGroup =
        selectedSkillId == null
            ? null
            : _groupForSkill(groups, selectedSkillId);
    setState(() {
      _mode = mode;
      _selectedGroupKey = matchingGroup?.key;
      _selectedSkillId = matchingGroup == null ? null : selectedSkillId;
      _visibleRecords = _initialRecordLimit;
    });
  }

  void _selectGroup(SkillsLibraryGroup group) {
    setState(() {
      _selectedGroupKey = group.key;
      _selectedSkillId = null;
      _visibleRecords = _initialRecordLimit;
      _incomingSelectionMissing = false;
    });
  }

  void _selectTechnique(
    SkillsLibraryGroup group,
    SkillsLibraryTechnique technique,
  ) {
    setState(() {
      _selectedGroupKey = group.key;
      _selectedSkillId = technique.skillId;
      _visibleRecords = _initialRecordLimit;
      _incomingSelectionMissing = false;
    });
  }

  void _back() {
    setState(() {
      if (_selectedSkillId != null) {
        _selectedSkillId = null;
      } else {
        _selectedGroupKey = null;
      }
      _visibleRecords = _initialRecordLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('skills-library'),
      padding: const EdgeInsets.all(TitansUI.spaceMd),
      decoration: BoxDecoration(
        color: TitansUI.surfaceColor(context).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryHeader(mode: _mode, onModeChanged: _changeMode),
          const SizedBox(height: 12),
          _SearchField(
            controller: _searchController,
            onChanged:
                (value) => setState(
                  () => _query = JiuJitsuTaxonomy.normalizedKey(value),
                ),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          if (_incomingSelectionMissing) ...[
            const SizedBox(height: 10),
            _MissingIncomingSelection(skillId: widget.initialSkillId ?? ''),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 840) return _buildDesktop();
              return _buildMobile();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 340, child: _buildNavigation()),
        const SizedBox(width: 16),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildMobile() {
    final selectedTechnique = _selectedTechnique;
    if (selectedTechnique != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(label: 'Voltar às técnicas', onPressed: _back),
          const SizedBox(height: 8),
          _buildDetail(),
        ],
      );
    }
    if (_selectedGroup != null && _query.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(label: 'Voltar aos grupos', onPressed: _back),
          const SizedBox(height: 8),
          _TechniqueList(
            group: _selectedGroup!,
            selectedSkillId: _selectedSkillId,
            onSelected:
                (technique) => _selectTechnique(_selectedGroup!, technique),
          ),
        ],
      );
    }
    return _buildNavigation();
  }

  Widget _buildNavigation() {
    if (_groups.isEmpty) {
      return TitansStateView.empty(
        title:
            _mode == SkillsLibraryMode.position
                ? 'Sem posições mapeadas'
                : 'Sem categorias mapeadas',
        message:
            'Registre um treino concluído com técnica para montar a biblioteca.',
        compact: true,
      );
    }

    if (_query.isNotEmpty) {
      final matches =
          <({SkillsLibraryGroup group, SkillsLibraryTechnique technique})>[];
      for (final group in _groups) {
        for (final technique in group.techniques) {
          if (technique.matches(_query)) {
            matches.add((group: group, technique: technique));
          }
        }
      }
      return _SearchResults(matches: matches, onSelected: _selectTechnique);
    }

    final group = _selectedGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupList(
          groups: _groups,
          selectedKey: group?.key,
          onSelected: _selectGroup,
        ),
        if (group != null) ...[
          const SizedBox(height: 12),
          _TechniqueList(
            group: group,
            selectedSkillId: _selectedSkillId,
            onSelected: (technique) => _selectTechnique(group, technique),
          ),
        ],
      ],
    );
  }

  Widget _buildDetail() {
    final technique = _selectedTechnique;
    if (technique == null) {
      return const TitansStateView.empty(
        title: 'Selecione uma técnica',
        message:
            'Escolha um grupo e uma técnica para consultar registros e avaliação.',
        compact: true,
      );
    }

    return _TechniqueDetail(
      technique: technique,
      visibleRecords: _visibleRecords,
      onLoadMore:
          () => setState(
            () =>
                _visibleRecords = (_visibleRecords + _initialRecordLimit).clamp(
                  0,
                  technique.records.length,
                ),
          ),
      onOpenRecord: widget.onOpenRecord,
      onOpenFullDetail: () => widget.onOpenTechniqueDetail(technique),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final SkillsLibraryMode mode;
  final ValueChanged<SkillsLibraryMode> onModeChanged;

  const _LibraryHeader({required this.mode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biblioteca por seleção',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          'Treino registrado é evidência de recorrência, não graduação ou domínio técnico.',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<SkillsLibraryMode>(
          segments: const [
            ButtonSegment(
              value: SkillsLibraryMode.position,
              label: Text('Por posição'),
              icon: Icon(Icons.account_tree_outlined),
            ),
            ButtonSegment(
              value: SkillsLibraryMode.category,
              label: Text('Por categoria'),
              icon: Icon(Icons.grid_view_rounded),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('skills-library-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Buscar técnica',
        hintText: 'Nome, ID, posição ou categoria',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon:
            controller.text.isEmpty
                ? null
                : IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
      ),
    );
  }
}

class _MissingIncomingSelection extends StatelessWidget {
  final String skillId;

  const _MissingIncomingSelection({required this.skillId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('skills-incoming-selection-missing'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(TitansRadius.card),
      ),
      child: Text(
        'A técnica “$skillId” não existe no recorte atual por posição (últimas 20 sessões). Continue explorando ou use a busca; nenhuma alternativa foi selecionada.',
        style: TextStyle(
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  final List<SkillsLibraryGroup> groups;
  final String? selectedKey;
  final ValueChanged<SkillsLibraryGroup> onSelected;

  const _GroupList({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const PageStorageKey('skills-library-groups'),
      children: [
        for (final group in groups)
          _LibraryRow(
            key: ValueKey('skills-group-${group.key}'),
            title: group.label,
            subtitle:
                '${TrainingAggregator.techniqueCountLabel(group.techniques.length)} · ${TrainingAggregator.sessionCountLabel(group.sessionCount)}',
            trailing: _formatDate(group.lastRegisteredAt),
            selected: selectedKey == group.key,
            onTap: () => onSelected(group),
          ),
      ],
    );
  }
}

class _TechniqueList extends StatelessWidget {
  final SkillsLibraryGroup group;
  final String? selectedSkillId;
  final ValueChanged<SkillsLibraryTechnique> onSelected;

  const _TechniqueList({
    required this.group,
    required this.selectedSkillId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('skills-techniques-${group.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(group.scopeLabel, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final technique in group.techniques)
          _LibraryRow(
            key: ValueKey('skills-technique-${group.key}-${technique.skillId}'),
            title: technique.name,
            subtitle:
                '${technique.category.displayLabel} · ${TrainingAggregator.sessionCountLabel(technique.records.length)} · ${technique.scopeLabel}',
            trailing: 'Último ${_formatDate(technique.lastRegisteredAt)}',
            selected: selectedSkillId == technique.skillId,
            onTap: () => onSelected(technique),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<({SkillsLibraryGroup group, SkillsLibraryTechnique technique})>
  matches;
  final void Function(
    SkillsLibraryGroup group,
    SkillsLibraryTechnique technique,
  )
  onSelected;

  const _SearchResults({required this.matches, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const TitansStateView.empty(
        title: 'Nenhuma técnica encontrada',
        message:
            'A busca usa nomes, IDs e classificações existentes no recorte atual.',
        compact: true,
      );
    }
    return Column(
      key: const ValueKey('skills-library-search-results'),
      children: [
        for (final match in matches)
          _LibraryRow(
            title: match.technique.name,
            subtitle:
                '${match.group.label} · ${match.technique.category.displayLabel}',
            trailing: _formatDate(match.technique.lastRegisteredAt),
            selected: false,
            onTap: () => onSelected(match.group, match.technique),
          ),
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color:
            selected
                ? cs.primaryContainer.withValues(alpha: 0.55)
                : cs.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(TitansRadius.card),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TitansRadius.card),
            side: BorderSide(
              color:
                  selected
                      ? cs.primary.withValues(alpha: 0.45)
                      : TitansUI.borderColor(context, alpha: 0.20),
            ),
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88),
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TechniqueDetail extends StatelessWidget {
  final SkillsLibraryTechnique technique;
  final int visibleRecords;
  final VoidCallback onLoadMore;
  final ValueChanged<SkillsLibraryRecord> onOpenRecord;
  final VoidCallback onOpenFullDetail;

  const _TechniqueDetail({
    required this.technique,
    required this.visibleRecords,
    required this.onLoadMore,
    required this.onOpenRecord,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final records = technique.records.take(visibleRecords).toList();
    final hasMore = records.length < technique.records.length;
    final contexts =
        technique.records
            .map((item) => item.context)
            .whereType<String>()
            .toSet();
    final outcomes =
        technique.records
            .map((item) => item.outcome)
            .whereType<String>()
            .toSet();

    return Column(
      key: ValueKey('skills-detail-${technique.skillId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitansCard(
          accent: cs.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                technique.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${technique.category.displayLabel} · ${technique.positions.isEmpty ? 'Sem posição registrada' : technique.positions.join(' · ')}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${TrainingAggregator.sessionCountLabel(technique.records.length)} · último registro ${_formatDate(technique.lastRegisteredAt)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                technique.scopeLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              if (contexts.isNotEmpty || outcomes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in {...contexts, ...outcomes})
                      Chip(label: Text(label)),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenFullDetail,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir detalhes técnicos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _EvaluationCard(
          evaluation: technique.evaluation,
          onOpenFullDetail: onOpenFullDetail,
        ),
        const SizedBox(height: 12),
        TitansCard(
          accent: TitansUI.technicalBlue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registros de origem',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${TrainingAggregator.sessionCountLabel(technique.records.length)} no mesmo recorte da seleção.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final record in records)
                _RecordRow(record: record, onOpen: onOpenRecord),
              if (hasMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('skills-load-more-records'),
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      'Carregar mais (${technique.records.length - records.length})',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final CoachEvaluation? evaluation;
  final VoidCallback onOpenFullDetail;

  const _EvaluationCard({
    required this.evaluation,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    final item = evaluation;
    final labels =
        item == null
            ? const <String>[]
            : <String>[
              if (item.knowledgeLevel != null)
                'Conhecimento: ${_evaluationLevel(item.knowledgeLevel!)}',
              if (item.drillLevel != null)
                'Drill: ${_evaluationLevel(item.drillLevel!)}',
              if (item.applicationLevel != null)
                'Aplicação: ${_evaluationLevel(item.applicationLevel!)}',
              if (item.consistencyLevel != null)
                'Recorrência: ${_evaluationLevel(item.consistencyLevel!)}',
              if (item.needsReview) 'Revisão sinalizada',
            ];

    return TitansCard(
      accent: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avaliação humana',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (item == null)
            const Text('Sem avaliação registrada.')
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final label in labels) Chip(label: Text(label))],
            ),
            if (item.note?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(item.note!),
            ],
            if (item.recommendation?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Recomendação: ${item.recommendation}'),
            ],
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onOpenFullDetail,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(
              item == null
                  ? 'Consultar opções de avaliação'
                  : 'Abrir avaliação',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final SkillsLibraryRecord record;
  final ValueChanged<SkillsLibraryRecord> onOpen;

  const _RecordRow({required this.record, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (record.position != null) record.position!,
      if (record.context != null) record.context!,
      if (record.outcome != null) record.outcome!,
    ];
    return ListTile(
      key: ValueKey('skills-record-${record.sessionId}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_rounded),
      title: Text(_formatDate(record.date)),
      subtitle: Text(
        details.isEmpty ? 'Registro técnico' : details.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: record.canOpen,
      onTap: record.canOpen ? () => onOpen(record) : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BackButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      label: Text(label),
    );
  }
}

SkillsLibraryGroup? _groupByKey(List<SkillsLibraryGroup> groups, String? key) {
  if (key == null) return null;
  for (final group in groups) {
    if (group.key == key) return group;
  }
  return null;
}

SkillsLibraryTechnique? _techniqueById(
  List<SkillsLibraryTechnique> techniques,
  String? skillId,
) {
  if (skillId == null) return null;
  for (final technique in techniques) {
    if (technique.skillId == skillId) return technique;
  }
  return null;
}

SkillsLibraryGroup? _groupForSkill(
  List<SkillsLibraryGroup> groups,
  String skillId,
) {
  for (final group in groups) {
    if (_techniqueById(group.techniques, skillId) != null) return group;
  }
  return null;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

String _evaluationLevel(CoachEvaluationLevel level) => switch (level) {
  CoachEvaluationLevel.observed => 'Observado',
  CoachEvaluationLevel.needsPractice => 'Precisa praticar',
  CoachEvaluationLevel.progressing => 'Em evolução',
  CoachEvaluationLevel.readyForReview => 'Pronto para revisão',
};
