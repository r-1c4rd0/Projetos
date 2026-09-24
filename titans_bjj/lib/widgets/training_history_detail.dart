part of 'training_history_journal.dart';

class _TrainingJournalDetail extends StatelessWidget {
  final TrainingSessionHistoryItem? item;
  final bool canEdit;
  final bool lifecycleSaving;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onMarkMissed;
  final Future<void> Function()? onCancel;

  const _TrainingJournalDetail({
    required this.item,
    required this.canEdit,
    required this.lifecycleSaving,
    required this.onEdit,
    required this.onConfirm,
    required this.onMarkMissed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item;
    if (selected == null) {
      return glassCard(
        context,
        const TitansEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Selecione uma sessão',
          message: 'Escolha um dia e uma sessão para consultar os detalhes.',
          compact: true,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final session = selected.session;
    final status = session.effectiveStatus();
    final awaitingConfirmation = session.isAwaitingConfirmation();
    final primaryNote = primarySessionNote(session);

    return glassCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.dateLabel.toUpperCase(),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected.contextLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Editar treino',
                  onPressed: lifecycleSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _JournalBadge(
                label:
                    awaitingConfirmation
                        ? 'Aguardando confirmação'
                        : TrainingSession.statusLabel(status),
                color: _statusColor(context, session),
              ),
              _JournalBadge(
                label: selected.techniqueCountLabel,
                color: cs.secondary,
              ),
              if (session.intensity != null)
                _JournalBadge(
                  label: 'Intensidade ${session.intensity}/5',
                  color: TitansUI.actionGold,
                ),
              if (session.totalDurationMinutes != null)
                _JournalBadge(
                  label:
                      '${session.totalDurationMinutes} min total'
                      '${session.totalDurationIsEstimated == true ? ' (estimado)' : ''}',
                  color: cs.primary,
                ),
              if (session.combatDurationMinutes != null)
                _JournalBadge(
                  label: '${session.combatDurationMinutes} min de combate',
                  color: TitansUI.technicalBlue,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            selected.summary,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.80),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (session.rolls != null) ...[
            const SizedBox(height: 12),
            Text(
              'Rolas',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${session.rolls!.count} rounds de '
              '${session.rolls!.roundDurationMinutes} min cada',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.82)),
            ),
          ],
          if (session.studiedTechniques.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'TÉCNICAS ESTUDADAS',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final technique in session.studiedTechniques)
                  _JournalBadge(label: technique.label, color: cs.secondary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estudo registrado; não indica aplicação, sucesso ou domínio.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontSize: 11,
              ),
            ),
          ],
          if (canEdit && awaitingConfirmation) ...[
            const SizedBox(height: 14),
            const Text(
              'Você fez este treino?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: lifecycleSaving ? null : onConfirm,
                  icon:
                      lifecycleSaving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.check_circle_outline),
                  label: const Text('Já treinei'),
                ),
                OutlinedButton.icon(
                  onPressed: lifecycleSaving ? null : onEdit,
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Reagendar'),
                ),
                TextButton.icon(
                  onPressed: lifecycleSaving ? null : onMarkMissed,
                  icon: const Icon(Icons.close_outlined),
                  label: const Text('Não fiz'),
                ),
              ],
            ),
          ] else if (canEdit && status == TrainingSessionStatus.planned) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: lifecycleSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: lifecycleSaving ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (selected.techniques.isEmpty)
            Text(
              'Nenhuma técnica informada.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
            )
          else
            for (var i = 0; i < selected.techniques.length; i++) ...[
              _TechniqueDetail(entry: selected.techniques[i]),
              if (i != selected.techniques.length - 1)
                const SizedBox(height: 10),
            ],
          if (primaryNote != null) ...[
            const SizedBox(height: 12),
            Text(
              primaryNote.label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.58),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              primaryNote.text,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.82)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TechniqueDetail extends StatelessWidget {
  final TrainingTechniqueDisplayEntry entry;

  const _TechniqueDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contextLabel = applicationContextLabel(entry.applicationContext);
    final outcomeLabel = techniqueOutcomeLabel(entry.techniqueOutcome);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.technique,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _JournalBadge(
                label: entry.position ?? 'Posição não informada',
                color: cs.primary,
              ),
              if (contextLabel != null)
                _JournalBadge(
                  label: contextLabel,
                  color: TitansUI.technicalBlue,
                ),
              if (outcomeLabel != null)
                _JournalBadge(
                  label: outcomeLabel,
                  color: _outcomeColor(outcomeLabel),
                ),
            ],
          ),
          if (entry.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.notes!,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.78)),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _JournalBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TitansUI.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
