import 'package:flutter/material.dart';

import '../../../core/titans_ui.dart';
import '../../../model/coach_evaluation.dart';
import '../domain/technical_taxonomy.dart';
import 'game_map_explorer_model.dart';
import 'technical_axis_palette.dart';

class GameMapExplorer extends StatefulWidget {
  final GameMapExplorerModel model;
  final String contextKey;
  final TechnicalRadarAxis? initialAxis;
  final bool canEditEvaluation;
  final ValueChanged<GameMapExplorerSelection> onSelectionChanged;
  final ValueChanged<GameMapExplorerRecord> onOpenRecord;
  final ValueChanged<GameMapExplorerTechnique>? onEditEvaluation;

  const GameMapExplorer({
    super.key,
    required this.model,
    required this.contextKey,
    required this.initialAxis,
    required this.canEditEvaluation,
    required this.onSelectionChanged,
    required this.onOpenRecord,
    required this.onEditEvaluation,
  });

  @override
  State<GameMapExplorer> createState() => _GameMapExplorerState();
}

class _GameMapExplorerState extends State<GameMapExplorer> {
  TechnicalRadarAxis? _selectedAxis;
  String? _selectedPositionKey;
  String? _selectedSkillId;

  @override
  void initState() {
    super.initState();
    _selectedAxis = _availableInitialAxis(widget.initialAxis);
  }

  @override
  void didUpdateWidget(covariant GameMapExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contextKey != oldWidget.contextKey) {
      _selectedAxis = _availableInitialAxis(widget.initialAxis);
      _selectedPositionKey = null;
      _selectedSkillId = null;
      return;
    }
    if (widget.initialAxis != oldWidget.initialAxis &&
        widget.initialAxis != _selectedAxis) {
      _selectedAxis = _availableInitialAxis(widget.initialAxis);
      _selectedPositionKey = null;
      _selectedSkillId = null;
    }
  }

  TechnicalRadarAxis? _availableInitialAxis(TechnicalRadarAxis? axis) {
    if (axis == null || widget.model.axisFor(axis) == null) return null;
    return axis;
  }

  GameMapExplorerAxis? get _axis =>
      _selectedAxis == null ? null : widget.model.axisFor(_selectedAxis!);

  GameMapExplorerPosition? get _position {
    final selectedAxis = _axis;
    if (selectedAxis == null || _selectedPositionKey == null) return null;
    for (final position in selectedAxis.positions) {
      if (position.key == _selectedPositionKey) return position;
    }
    return null;
  }

  GameMapExplorerTechnique? get _technique {
    final selectedPosition = _position;
    if (selectedPosition == null || _selectedSkillId == null) return null;
    for (final technique in selectedPosition.techniques) {
      if (technique.skillId == _selectedSkillId) return technique;
    }
    return null;
  }

  GameMapExplorerSelection get _selection => GameMapExplorerSelection(
    axis: _selectedAxis,
    position: _position,
    technique: _technique,
  );

  void _selectAxis(TechnicalRadarAxis? axis) {
    setState(() {
      _selectedAxis = axis;
      _selectedPositionKey = null;
      _selectedSkillId = null;
    });
    widget.onSelectionChanged(_selection);
  }

  void _selectPosition(GameMapExplorerPosition position) {
    setState(() {
      _selectedPositionKey = position.key;
      _selectedSkillId = null;
    });
    widget.onSelectionChanged(_selection);
  }

  void _selectTechnique(GameMapExplorerTechnique technique) {
    setState(() => _selectedSkillId = technique.skillId);
    widget.onSelectionChanged(_selection);
  }

  void _back() {
    setState(() {
      if (_selectedSkillId != null) {
        _selectedSkillId = null;
      } else if (_selectedPositionKey != null) {
        _selectedPositionKey = null;
      } else {
        _selectedAxis = null;
      }
    });
    widget.onSelectionChanged(_selection);
  }

  void _clear() {
    setState(() {
      _selectedAxis = null;
      _selectedPositionKey = null;
      _selectedSkillId = null;
    });
    widget.onSelectionChanged(_selection);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('game-map-explorer'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TitansUI.surfaceColor(context).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(TitansUI.radiusSmall),
        border: Border.all(color: TitansUI.borderColor(context, alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExplorerHeader(hasSelection: _selectedAxis != null, onClear: _clear),
          const SizedBox(height: 12),
          if (widget.model.isEmpty)
            const TitansStateView.empty(
              title: 'Sem registros técnicos realizados',
              message:
                  'O percurso aparece após um treino concluído com técnica registrada.',
              compact: true,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 840;
                if (!desktop) {
                  return _buildMobile(context, cs);
                }
                return _buildDesktop(context, cs);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 330,
          child: _ExplorerNavigation(
            axes: widget.model.axes,
            selectedAxis: _selectedAxis,
            selectedPosition: _position,
            selectedTechnique: _technique,
            onSelectAxis: _selectAxis,
            onSelectPosition: _selectPosition,
            onSelectTechnique: _selectTechnique,
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 440, color: cs.outlineVariant),
        const SizedBox(width: 16),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, ColorScheme cs) {
    final hasSelection = _selectedAxis != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSelection) ...[
          _ExplorerBreadcrumbs(selection: _selection),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('game-map-explorer-back'),
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Voltar'),
          ),
          const SizedBox(height: 4),
        ],
        if (_selectedAxis == null)
          _AxisList(axes: widget.model.axes, onSelect: _selectAxis)
        else if (_selectedPositionKey == null)
          _PositionList(axis: _axis!, onSelect: _selectPosition)
        else if (_selectedSkillId == null)
          _TechniqueList(position: _position!, onSelect: _selectTechnique)
        else
          _buildDetail(),
      ],
    );
  }

  Widget _buildDetail() {
    final technique = _technique;
    if (technique == null) {
      return const _ExplorerDetailPlaceholder();
    }
    return _TechniqueDetail(
      technique: technique,
      position: _position!,
      axis: _axis!,
      canEditEvaluation: widget.canEditEvaluation,
      onOpenRecord: widget.onOpenRecord,
      onEditEvaluation:
          widget.onEditEvaluation == null
              ? null
              : () => widget.onEditEvaluation!(technique),
    );
  }
}

class _ExplorerHeader extends StatelessWidget {
  final bool hasSelection;
  final VoidCallback onClear;

  const _ExplorerHeader({required this.hasSelection, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.account_tree_outlined, color: cs.primary),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explorador do jogo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'Eixo → posição → técnica → registros de origem · últimas 100 sessões concluídas e únicas',
              ),
            ],
          ),
        ),
        if (hasSelection)
          IconButton(
            key: const ValueKey('game-map-explorer-clear'),
            tooltip: 'Limpar seleção',
            onPressed: onClear,
            icon: const Icon(Icons.clear_all_rounded),
          ),
      ],
    );
  }
}

class _ExplorerNavigation extends StatelessWidget {
  final List<GameMapExplorerAxis> axes;
  final TechnicalRadarAxis? selectedAxis;
  final GameMapExplorerPosition? selectedPosition;
  final GameMapExplorerTechnique? selectedTechnique;
  final ValueChanged<TechnicalRadarAxis?> onSelectAxis;
  final ValueChanged<GameMapExplorerPosition> onSelectPosition;
  final ValueChanged<GameMapExplorerTechnique> onSelectTechnique;

  const _ExplorerNavigation({
    required this.axes,
    required this.selectedAxis,
    required this.selectedPosition,
    required this.selectedTechnique,
    required this.onSelectAxis,
    required this.onSelectPosition,
    required this.onSelectTechnique,
  });

  @override
  Widget build(BuildContext context) {
    GameMapExplorerAxis? axis;
    for (final item in axes) {
      if (item.axis == selectedAxis) axis = item;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AxisList(
          axes: axes,
          selectedAxis: selectedAxis,
          onSelect: onSelectAxis,
        ),
        if (axis != null) ...[
          const SizedBox(height: 14),
          _PositionList(
            axis: axis,
            selectedKey: selectedPosition?.key,
            onSelect: onSelectPosition,
          ),
        ],
        if (selectedPosition != null) ...[
          const SizedBox(height: 14),
          _TechniqueList(
            position: selectedPosition!,
            selectedSkillId: selectedTechnique?.skillId,
            onSelect: onSelectTechnique,
          ),
        ],
      ],
    );
  }
}

class _AxisList extends StatelessWidget {
  final List<GameMapExplorerAxis> axes;
  final TechnicalRadarAxis? selectedAxis;
  final ValueChanged<TechnicalRadarAxis?> onSelect;

  const _AxisList({
    required this.axes,
    this.selectedAxis,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _NavigationGroup(
      title: '1. Eixo',
      subtitle: 'Evidências técnicas nas últimas 100 sessões concluídas.',
      children: [
        _NavigationTile(
          key: const ValueKey('game-map-axis-all'),
          label: 'Todos os eixos',
          countLabel:
              '${axes.fold<int>(0, (sum, axis) => sum + axis.recordCount)} evidências',
          selected: selectedAxis == null,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => onSelect(null),
        ),
        for (final axis in axes)
          _NavigationTile(
            key: ValueKey('game-map-axis-${axis.axis.name}'),
            label: axis.label,
            countLabel: '${axis.recordCount} evidências',
            selected: selectedAxis == axis.axis,
            color: technicalAxisColor(
              axis.axis,
              unclassifiedColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => onSelect(axis.axis),
          ),
      ],
    );
  }
}

class _PositionList extends StatelessWidget {
  final GameMapExplorerAxis axis;
  final String? selectedKey;
  final ValueChanged<GameMapExplorerPosition> onSelect;

  const _PositionList({
    required this.axis,
    this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _NavigationGroup(
      title: '2. Posição',
      subtitle: 'Posições registradas para o eixo no mesmo recorte.',
      children: [
        for (final position in axis.positions)
          _NavigationTile(
            key: ValueKey('game-map-position-${position.key}'),
            label: position.label,
            countLabel: '${position.recordCount} evidências',
            selected: selectedKey == position.key,
            color:
                position.hasRecordedPosition
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: () => onSelect(position),
          ),
      ],
    );
  }
}

class _TechniqueList extends StatelessWidget {
  final GameMapExplorerPosition position;
  final String? selectedSkillId;
  final ValueChanged<GameMapExplorerTechnique> onSelect;

  const _TechniqueList({
    required this.position,
    this.selectedSkillId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _NavigationGroup(
      title: '3. Técnica',
      subtitle: 'Técnicas registradas na posição no mesmo recorte.',
      children: [
        for (final technique in position.techniques)
          _NavigationTile(
            key: ValueKey('game-map-technique-${technique.skillId}'),
            label: technique.label,
            countLabel: '${technique.records.length} sessões',
            selected: selectedSkillId == technique.skillId,
            color: Theme.of(context).colorScheme.secondary,
            onTap: () => onSelect(technique),
          ),
      ],
    );
  }
}

class _NavigationGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _NavigationGroup({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final String label;
  final String countLabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavigationTile({
    super.key,
    required this.label,
    required this.countLabel,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.13 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.42 : 0.12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? color : cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  countLabel,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _ExplorerBreadcrumbs extends StatelessWidget {
  final GameMapExplorerSelection selection;

  const _ExplorerBreadcrumbs({required this.selection});

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (selection.axis != null)
        selection.axis == TechnicalRadarAxis.unclassified
            ? 'Sem classificação técnica'
            : selection.axis!.displayLabel,
      if (selection.position != null) selection.position!.label,
      if (selection.technique != null) selection.technique!.label,
    ];
    return Text(
      labels.join(' → '),
      key: const ValueKey('game-map-explorer-breadcrumb'),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ExplorerDetailPlaceholder extends StatelessWidget {
  const _ExplorerDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const TitansStateView.empty(
      title: 'Escolha uma técnica',
      message:
          'Selecione eixo, posição e técnica para consultar os registros de origem.',
      compact: true,
    );
  }
}

class _TechniqueDetail extends StatelessWidget {
  final GameMapExplorerTechnique technique;
  final GameMapExplorerPosition position;
  final GameMapExplorerAxis axis;
  final bool canEditEvaluation;
  final ValueChanged<GameMapExplorerRecord> onOpenRecord;
  final VoidCallback? onEditEvaluation;

  const _TechniqueDetail({
    required this.technique,
    required this.position,
    required this.axis,
    required this.canEditEvaluation,
    required this.onOpenRecord,
    required this.onEditEvaluation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      key: ValueKey('game-map-detail-${technique.skillId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          technique.label,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text('${axis.label} → ${position.label}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DetailBadge(
              label: technique.category.displayLabel,
              color: cs.primary,
            ),
            _DetailBadge(
              label: '${technique.records.length} registros de origem',
              color: cs.secondary,
            ),
            if (!technique.hasCanonicalIdentity)
              _DetailBadge(
                label: 'Sem correspondência canônica',
                color: cs.onSurfaceVariant,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _EvaluationPanel(
          evaluation: technique.evaluation,
          canEdit: canEditEvaluation,
          onEdit: onEditEvaluation,
        ),
        const SizedBox(height: 16),
        const Text(
          '4. Registros de origem',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          'Sessões concluídas que sustentam esta técnica dentro do recorte de 100.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (final record in technique.records)
          _RecordTile(record: record, onOpen: () => onOpenRecord(record)),
      ],
    );
  }
}

class _EvaluationPanel extends StatelessWidget {
  final CoachEvaluation? evaluation;
  final bool canEdit;
  final VoidCallback? onEdit;

  const _EvaluationPanel({
    required this.evaluation,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = evaluation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Avaliação humana',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (canEdit && onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  child: Text(item == null ? 'Registrar' : 'Atualizar'),
                ),
            ],
          ),
          if (item == null)
            Text(
              'Sem avaliação registrada.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.knowledgeLevel != null)
                  _DetailBadge(
                    label:
                        'Conhecimento: ${_evaluationLevel(item.knowledgeLevel!)}',
                    color: cs.primary,
                  ),
                if (item.drillLevel != null)
                  _DetailBadge(
                    label: 'Drill: ${_evaluationLevel(item.drillLevel!)}',
                    color: cs.primary,
                  ),
                if (item.applicationLevel != null)
                  _DetailBadge(
                    label:
                        'Aplicação: ${_evaluationLevel(item.applicationLevel!)}',
                    color: cs.primary,
                  ),
                if (item.consistencyLevel != null)
                  _DetailBadge(
                    label:
                        'Consistência: ${_evaluationLevel(item.consistencyLevel!)}',
                    color: cs.primary,
                  ),
                if (item.needsReview)
                  _DetailBadge(label: 'Revisão sinalizada', color: cs.error),
              ],
            ),
            if (item.note != null) ...[
              const SizedBox(height: 8),
              Text('Observação: ${item.note}'),
            ],
            if (item.recommendation != null) ...[
              const SizedBox(height: 4),
              Text('Recomendação: ${item.recommendation}'),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final GameMapExplorerRecord record;
  final VoidCallback onOpen;

  const _RecordTile({required this.record, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metadata = [
      record.sourceLabel,
      if (record.applicationContext != null) record.applicationContext!,
      if (record.outcome != null) record.outcome!,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
      child: ListTile(
        key: ValueKey('game-map-record-${record.sessionId}-${record.date}'),
        leading: const Icon(Icons.event_note_outlined),
        title: Text(_formatDate(record.date)),
        subtitle: Text(metadata),
        trailing:
            record.canOpen
                ? const Icon(Icons.open_in_new_rounded, size: 18)
                : const Text('ID ausente'),
        onTap: record.canOpen ? onOpen : null,
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _evaluationLevel(CoachEvaluationLevel level) {
  return switch (level) {
    CoachEvaluationLevel.observed => 'Observado',
    CoachEvaluationLevel.needsPractice => 'Precisa praticar',
    CoachEvaluationLevel.progressing => 'Em evolução',
    CoachEvaluationLevel.readyForReview => 'Pronto para revisão',
  };
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
