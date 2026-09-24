part of '../../screen/skill_detail_screen.dart';

class _CoachEvaluationDetailCard extends StatelessWidget {
  final _SkillDetailViewModel vm;
  final bool canEdit;
  final bool isSaving;
  final VoidCallback onEdit;

  const _CoachEvaluationDetailCard({
    required this.vm,
    required this.canEdit,
    required this.isSaving,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final evaluation = vm.evaluation;
    final actionLabel =
        evaluation == null ? 'Registrar avaliação' : 'Editar avaliação';

    return TitansCard(
      accent: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailEyebrow('AVALIAÇÃO DO PROFESSOR'),
          const SizedBox(height: 12),
          if (evaluation == null)
            const TitansStateView.empty(
              title: 'Nenhuma avaliação registrada ainda.',
              message:
                  'A avaliação do professor aparecerá aqui quando existir.',
              compact: true,
            )
          else ...[
            _ChipWrap(labels: vm.evaluationLabels),
            if (_cleanText(evaluation.note) != null) ...[
              const SizedBox(height: 12),
              _TextBlock(label: 'Observação', text: evaluation.note!),
            ],
            if (_cleanText(evaluation.recommendation) != null) ...[
              const SizedBox(height: 12),
              _TextBlock(
                label: 'Recomendação',
                text: evaluation.recommendation!,
              ),
            ],
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onEdit,
                icon: Icon(
                  evaluation == null
                      ? Icons.rate_review_outlined
                      : Icons.edit_note_outlined,
                  size: 18,
                ),
                label: Text(isSaving ? 'Salvando...' : actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachEvaluationDraft {
  final CoachEvaluationLevel? knowledgeLevel;
  final CoachEvaluationLevel? drillLevel;
  final CoachEvaluationLevel? applicationLevel;
  final CoachEvaluationLevel? consistencyLevel;
  final String? note;
  final String? recommendation;
  final bool needsReview;

  const _CoachEvaluationDraft({
    required this.knowledgeLevel,
    required this.drillLevel,
    required this.applicationLevel,
    required this.consistencyLevel,
    required this.note,
    required this.recommendation,
    required this.needsReview,
  });
}

class _CoachEvaluationSheet extends StatefulWidget {
  final String displayName;
  final CoachEvaluation? existing;

  const _CoachEvaluationSheet({
    required this.displayName,
    required this.existing,
  });

  @override
  State<_CoachEvaluationSheet> createState() => _CoachEvaluationSheetState();
}

class _CoachEvaluationSheetState extends State<_CoachEvaluationSheet> {
  CoachEvaluationLevel? _knowledgeLevel;
  CoachEvaluationLevel? _drillLevel;
  CoachEvaluationLevel? _applicationLevel;
  CoachEvaluationLevel? _consistencyLevel;
  bool _needsReview = false;
  final _noteController = TextEditingController();
  final _recommendationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _knowledgeLevel = existing.knowledgeLevel;
    _drillLevel = existing.drillLevel;
    _applicationLevel = existing.applicationLevel;
    _consistencyLevel = existing.consistencyLevel;
    _needsReview = existing.needsReview;
    _noteController.text = existing.note ?? '';
    _recommendationController.text = existing.recommendation ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null
                    ? 'Registrar avaliação'
                    : 'Editar avaliação',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _CoachLevelDropdown(
                label: 'Conhecimento',
                value: _knowledgeLevel,
                onChanged: (value) => setState(() => _knowledgeLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Execução em drill',
                value: _drillLevel,
                onChanged: (value) => setState(() => _drillLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Aplicação',
                value: _applicationLevel,
                onChanged: (value) => setState(() => _applicationLevel = value),
              ),
              const SizedBox(height: 12),
              _CoachLevelDropdown(
                label: 'Recorrência',
                value: _consistencyLevel,
                onChanged: (value) => setState(() => _consistencyLevel = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Observação'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _recommendationController,
                decoration: const InputDecoration(labelText: 'Recomendação'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Precisa revisar'),
                value: _needsReview,
                onChanged: (value) => setState(() => _needsReview = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _CoachEvaluationDraft(
                          knowledgeLevel: _knowledgeLevel,
                          drillLevel: _drillLevel,
                          applicationLevel: _applicationLevel,
                          consistencyLevel: _consistencyLevel,
                          note: _cleanText(_noteController.text),
                          recommendation: _cleanText(
                            _recommendationController.text,
                          ),
                          needsReview: _needsReview,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Salvar avaliação'),
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

class _CoachLevelDropdown extends StatelessWidget {
  final String label;
  final CoachEvaluationLevel? value;
  final ValueChanged<CoachEvaluationLevel?> onChanged;

  const _CoachLevelDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CoachEvaluationLevel>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<CoachEvaluationLevel>(
          value: null,
          child: Text('Não informado'),
        ),
        for (final level in CoachEvaluationLevel.values)
          DropdownMenuItem(value: level, child: Text(_coachLevelLabel(level))),
      ],
      onChanged: onChanged,
    );
  }
}
