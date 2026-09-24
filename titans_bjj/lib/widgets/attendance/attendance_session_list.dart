part of '../../screen/attendance_screen.dart';

class AttendanceSessionList extends StatelessWidget {
  const AttendanceSessionList({
    super.key,
    required this.sessions,
    required this.isStaff,
    required this.isBusy,
    required this.onOpen,
    required this.onClose,
    required this.onCancel,
  });

  final List<AttendanceSession> sessions;
  final bool isStaff;
  final bool isBusy;
  final ValueChanged<AttendanceSession> onOpen;
  final ValueChanged<AttendanceSession> onClose;
  final ValueChanged<AttendanceSession> onCancel;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return _EmptyState(isStaff: isStaff);

    final openCount =
        sessions
            .where((item) => item.status == AttendanceSessionStatus.open)
            .length;

    return ListView.separated(
      padding: TitansUI.listPadding(context),
      itemCount: sessions.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AttendanceOverviewCard(
            isStaff: isStaff,
            openCount: openCount,
          );
        }

        final session = sessions[index - 1];
        return _AttendanceSessionCard(
          session: session,
          isStaff: isStaff,
          isBusy: isBusy,
          onTap: () => onOpen(session),
          onClose:
              session.status == AttendanceSessionStatus.open
                  ? () => onClose(session)
                  : null,
          onCancel:
              session.status == AttendanceSessionStatus.cancelled
                  ? null
                  : () => onCancel(session),
        );
      },
    );
  }
}

class _AttendanceOverviewCard extends StatelessWidget {
  const _AttendanceOverviewCard({
    required this.isStaff,
    required this.openCount,
  });

  final bool isStaff;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasOpen = openCount > 0;
    final title = hasOpen ? 'Chamada aberta' : 'Sem chamada aberta';
    final message =
        isStaff
            ? 'Abra uma chamada ou acompanhe as aulas recentes.'
            : 'Entre em uma chamada aberta para registrar sua presenca.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              hasOpen ? Icons.fact_check_outlined : Icons.event_busy_outlined,
              color: hasOpen ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CompactStatusPill(
              label: '$openCount aberta${openCount == 1 ? '' : 's'}',
              color: hasOpen ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.session,
    required this.isStaff,
    required this.isBusy,
    required this.onTap,
    required this.onClose,
    required this.onCancel,
  });

  final AttendanceSession session;
  final bool isStaff;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs, session.status);
    final instructor =
        session.instructorName.isEmpty
            ? session.instructorUid
            : session.instructorName;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CompactStatusPill(
                    label: _statusLabel(session.status),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InfoItem(
                    icon: Icons.school_outlined,
                    label: session.classType,
                  ),
                  _InfoItem(
                    icon: Icons.schedule,
                    label:
                        '${_formatDateTime(session.startsAt)} - ${_formatTime(session.endsAt)}',
                  ),
                  _InfoItem(icon: Icons.person_outline, label: instructor),
                ],
              ),
              if (isStaff) ...[
                const SizedBox(height: 8),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 4,
                  overflowSpacing: 4,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Anular'),
                      onPressed: isBusy ? null : onCancel,
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Fechar'),
                      onPressed: isBusy ? null : onClose,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isStaff;

  const _EmptyState({required this.isStaff});

  @override
  Widget build(BuildContext context) {
    return TitansStateView.empty(
      title: 'Nenhuma chamada aberta',
      message:
          isStaff
              ? 'Escolha uma data para iniciar a chamada.'
              : 'Nenhuma chamada aberta no momento.',
    );
  }
}
