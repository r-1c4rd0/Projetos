part of '../../screen/master_panel_screen.dart';

class MasterPanelStudentRoster extends StatefulWidget {
  final AppUser actor;
  final List<MasterPanelStudentEntry> students;
  final GradingRules rules;
  final VoidCallback onCreate;
  final ValueChanged<MasterPanelStudentEntry> onOpen;
  final ValueChanged<MasterPanelStudentEntry> onEdit;
  final ValueChanged<MasterPanelStudentEntry> onEditGraduation;
  final void Function(MasterPanelStudentInviteAction, MasterPanelStudentEntry)
  onInviteAction;
  final ValueChanged<MasterPanelStudentEntry> onArchive;

  const MasterPanelStudentRoster({
    super.key,
    required this.actor,
    required this.students,
    required this.rules,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onInviteAction,
    required this.onArchive,
  });

  @override
  State<MasterPanelStudentRoster> createState() =>
      _MasterPanelStudentRosterState();
}

class _MasterPanelStudentRosterState extends State<MasterPanelStudentRoster> {
  String _query = '';
  _RosterStatusFilter _statusFilter = _RosterStatusFilter.all;
  BeltColor? _beltFilter;

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        TitansUI.listPadding(context, extra: TitansUI.spaceLg).bottom;
    final summary = _RosterSummary.from(widget.students, widget.rules);
    final attentionUids =
        summary.attentionItems
            .map((item) => item.entry.displayStudent.uid)
            .toSet();
    final filteredStudents = _filteredStudents(widget.students, attentionUids);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hasEnlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.0;
        final ratio =
            width < 390
                ? 2.08
                : width < 900
                ? 2.28
                : hasEnlargedText
                ? 2.2
                : 2.55;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TitansUI.spaceMd,
                TitansUI.spaceMd,
                TitansUI.spaceMd,
                TitansUI.spaceSm,
              ),
              sliver: SliverToBoxAdapter(
                child: _RosterCockpitCard(
                  summary: summary,
                  statusFilter: _statusFilter,
                  beltFilter: _beltFilter,
                  onCreate: widget.onCreate,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onStatusChanged:
                      (value) => setState(() => _statusFilter = value),
                  onBeltChanged: (value) => setState(() => _beltFilter = value),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TitansUI.spaceMd,
                0,
                TitansUI.spaceMd,
                TitansUI.spaceSm,
              ),
              sliver: SliverToBoxAdapter(
                child: _TeacherAttentionCard(
                  items: summary.attentionItems,
                  showListWhenExpanded:
                      _statusFilter != _RosterStatusFilter.needsAttention,
                  onOpen: widget.onOpen,
                ),
              ),
            ),
            if (filteredStudents.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  TitansUI.spaceMd,
                  0,
                  TitansUI.spaceMd,
                  bottomInset,
                ),
                sliver: const SliverToBoxAdapter(
                  child: _RosterEmptyFilterCard(),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  TitansUI.spaceMd,
                  0,
                  TitansUI.spaceMd,
                  bottomInset,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisSpacing: TitansUI.spaceSm,
                    crossAxisSpacing: TitansUI.spaceSm,
                    childAspectRatio: ratio,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = filteredStudents[index];
                    final student = entry.displayStudent;
                    final maxDegree = widget.rules.maxDegrees(student.belt);
                    final degree = student.degree.clamp(0, maxDegree).toInt();

                    final capabilities = _TargetCapabilities.resolve(
                      actor: widget.actor,
                      targetUid: student.uid,
                      targetAcademyId: student.academyId,
                      targetMode: TargetMode.selectedStudent,
                    );

                    return _StudentCard(
                      student: student,
                      degree: degree,
                      maxDegree: maxDegree,
                      capabilities: capabilities,
                      accessStatus: entry.status,
                      onOpen: () => widget.onOpen(entry),
                      onEdit: () => widget.onEdit(entry),
                      onEditGraduation: () => widget.onEditGraduation(entry),
                      onInviteAction:
                          (action) => widget.onInviteAction(action, entry),
                      onArchive: () => widget.onArchive(entry),
                      canCopyInvite: entry.invite != null,
                    );
                  }, childCount: filteredStudents.length),
                ),
              ),
          ],
        );
      },
    );
  }

  List<MasterPanelStudentEntry> _filteredStudents(
    List<MasterPanelStudentEntry> students,
    Set<String> attentionUids,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    return students.where((entry) {
      final student = entry.displayStudent;
      if (normalizedQuery.isNotEmpty &&
          !student.name.toLowerCase().contains(normalizedQuery)) {
        return false;
      }
      if (_beltFilter != null && student.belt != _beltFilter) return false;
      switch (_statusFilter) {
        case _RosterStatusFilter.all:
          return true;
        case _RosterStatusFilter.needsAttention:
          return attentionUids.contains(student.uid);
        case _RosterStatusFilter.active:
          return entry.status == MasterPanelStudentAccessStatus.active;
      }
    }).toList();
  }
}

class _RosterSummary {
  final int total;
  final int active;
  final int needsAttention;
  final Map<BeltColor, int> beltCounts;
  final List<_AttentionQueueItem> attentionItems;

  const _RosterSummary({
    required this.total,
    required this.active,
    required this.needsAttention,
    required this.beltCounts,
    required this.attentionItems,
  });

  factory _RosterSummary.from(
    List<MasterPanelStudentEntry> students,
    GradingRules rules,
  ) {
    final beltCounts = <BeltColor, int>{};
    final attentionItems = <_AttentionQueueItem>[];
    var active = 0;

    for (final entry in students) {
      final student = entry.displayStudent;
      beltCounts[student.belt] = (beltCounts[student.belt] ?? 0) + 1;
      if (entry.status == MasterPanelStudentAccessStatus.active) {
        active += 1;
      }

      final attentionItem = _AttentionQueueItem.from(entry, rules);
      if (attentionItem != null) attentionItems.add(attentionItem);
    }

    return _RosterSummary(
      total: students.length,
      active: active,
      needsAttention: attentionItems.length,
      beltCounts: beltCounts,
      attentionItems: attentionItems,
    );
  }
}

class _AttentionQueueItem {
  final MasterPanelStudentEntry entry;
  final List<String> reasons;

  const _AttentionQueueItem({required this.entry, required this.reasons});

  String get reasonLabel => reasons.take(2).join(' · ');

  static _AttentionQueueItem? from(
    MasterPanelStudentEntry entry,
    GradingRules rules,
  ) {
    final student = entry.displayStudent;
    final reasons = <String>[];

    switch (entry.status) {
      case MasterPanelStudentAccessStatus.active:
        break;
      case MasterPanelStudentAccessStatus.pending:
        reasons.add('Convite pendente');
        break;
      case MasterPanelStudentAccessStatus.expired:
        reasons.add('Convite expirado');
        break;
      case MasterPanelStudentAccessStatus.revoked:
        reasons.add('Convite revogado');
        break;
      case MasterPanelStudentAccessStatus.noAccess:
        reasons.add('Sem acesso ativo');
        break;
    }

    final name = student.name.trim();
    if (name.isEmpty || name.toLowerCase() == 'aluno') {
      reasons.add('Nome do cadastro precisa revisão');
    }

    final maxDegree = rules.maxDegrees(student.belt);
    if (student.degree > maxDegree) {
      reasons.add('Grau acima da regra da faixa');
    }

    if (reasons.isEmpty) return null;
    return _AttentionQueueItem(entry: entry, reasons: reasons);
  }
}

class _RosterCockpitCard extends StatelessWidget {
  final _RosterSummary summary;
  final _RosterStatusFilter statusFilter;
  final BeltColor? beltFilter;
  final VoidCallback onCreate;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_RosterStatusFilter> onStatusChanged;
  final ValueChanged<BeltColor?> onBeltChanged;

  const _RosterCockpitCard({
    required this.summary,
    required this.statusFilter,
    required this.beltFilter,
    required this.onCreate,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onBeltChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansCard(
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final metrics = TitansCompactMetricGrid(
            fourColumnMinWidth: 480,
            children: [
              _RosterMetric(
                label: 'Alunos',
                value: summary.total.toString(),
                color: cs.primary,
              ),
              _RosterMetric(
                label: 'Ativos',
                value: summary.active.toString(),
                color: TitansUI.successGreen,
              ),
              _RosterMetric(
                label: 'Atenção',
                value: summary.needsAttention.toString(),
                color:
                    summary.needsAttention == 0
                        ? cs.onSurface.withValues(alpha: 0.62)
                        : TitansUI.actionGold,
              ),
            ],
          );
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Painel do professor',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cockpit da turma',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Leitura rápida dos alunos vinculados.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Cadastrar atleta'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                titleBlock,
                const SizedBox(height: TitansUI.spaceSm),
                action,
              ] else
                Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: TitansUI.spaceSm),
                    action,
                  ],
                ),
              const SizedBox(height: TitansUI.spaceSm),
              metrics,
              const SizedBox(height: TitansUI.spaceSm),
              TextField(
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Buscar aluno por nome',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(TitansRadius.lg),
                    borderSide: BorderSide(color: TitansUI.navBorder(context)),
                  ),
                ),
              ),
              const SizedBox(height: TitansUI.spaceSm),
              Wrap(
                spacing: TitansUI.spaceXs,
                runSpacing: TitansUI.spaceXs,
                children: [
                  _RosterFilterChip(
                    label: 'Todos',
                    selected: statusFilter == _RosterStatusFilter.all,
                    onTap: () => onStatusChanged(_RosterStatusFilter.all),
                  ),
                  _RosterFilterChip(
                    label: 'Atenção',
                    selected:
                        statusFilter == _RosterStatusFilter.needsAttention,
                    onTap:
                        () =>
                            onStatusChanged(_RosterStatusFilter.needsAttention),
                  ),
                  _RosterFilterChip(
                    label: 'Ativos',
                    selected: statusFilter == _RosterStatusFilter.active,
                    onTap: () => onStatusChanged(_RosterStatusFilter.active),
                  ),
                ],
              ),
              if (summary.beltCounts.isNotEmpty) ...[
                const SizedBox(height: TitansUI.spaceXs),
                Wrap(
                  spacing: TitansUI.spaceXs,
                  runSpacing: TitansUI.spaceXs,
                  children: [
                    _RosterBeltFilterChip(
                      label: 'Todas as faixas',
                      selected: beltFilter == null,
                      color: cs.primary,
                      onTap: () => onBeltChanged(null),
                    ),
                    for (final entry in summary.beltCounts.entries)
                      _RosterBeltFilterChip(
                        label:
                            '${_StudentCard.beltName(entry.key)} (${entry.value})',
                        selected: beltFilter == entry.key,
                        color: _StudentCard.beltUiColor(entry.key),
                        onTap: () => onBeltChanged(entry.key),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RosterMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RosterMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TitansCompactMetricCard(label: label, value: value, color: color);
  }
}

class _RosterFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RosterFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      labelStyle: TextStyle(
        color:
            selected
                ? TitansUI.navSelectedForeground(context)
                : TitansUI.navUnselectedForeground(context),
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
      backgroundColor:
          selected
              ? TitansUI.navSelectedBackground(context)
              : TitansUI.navUnselectedBackground(context),
      side: BorderSide(color: TitansUI.navBorder(context, selected: selected)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RosterBeltFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RosterBeltFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = color.computeLuminance() > 0.82 ? cs.onSurface : color;

    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? textColor : TitansUI.navUnselectedForeground(context),
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
      backgroundColor:
          selected
              ? color.withValues(alpha: 0.14)
              : TitansUI.navUnselectedBackground(context),
      side: BorderSide(
        color:
            selected
                ? color.withValues(alpha: 0.46)
                : TitansUI.navBorder(context),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
