part of '../../screen/master_panel_screen.dart';

class _StudentCard extends StatelessWidget {
  final StudentVm student;
  final int degree;
  final int maxDegree;
  final _TargetCapabilities capabilities;
  final MasterPanelStudentAccessStatus accessStatus;
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;
  final VoidCallback onOpen;
  final ValueChanged<MasterPanelStudentInviteAction> onInviteAction;
  final VoidCallback onArchive;
  final bool canCopyInvite;

  const _StudentCard({
    required this.student,
    required this.degree,
    required this.maxDegree,
    required this.capabilities,
    required this.accessStatus,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onOpen,
    required this.onInviteAction,
    required this.onArchive,
    required this.canCopyInvite,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final beltColor = beltUiColor(student.belt);
    final beltLabel = '${beltName(student.belt)} - Grau $degree/$maxDegree';

    return TitansCard(
      key: ValueKey('master-panel-student-${student.uid}'),
      accent: beltColor,
      padding: const EdgeInsets.all(TitansUI.spaceSm),
      onTap: onOpen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final header = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentProgressRing(
                degree: degree,
                maxDegree: maxDegree,
                color: beltColor,
              ),
              const SizedBox(width: TitansUI.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      beltLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: TitansUI.spaceXs),
                    _AccessStatusBadge(status: accessStatus),
                  ],
                ),
              ),
              if (capabilities.canViewAdminActions)
                _StudentActionsMenu(
                  canEditProfile: capabilities.canEditProfile,
                  canEditGraduation: capabilities.canEditGraduation,
                  canArchiveProfile: capabilities.canArchiveProfile,
                  onEdit: onEdit,
                  onEditGraduation: onEditGraduation,
                  onArchive: onArchive,
                  accessStatus: accessStatus,
                  onInviteAction: onInviteAction,
                  canCopyInvite: canCopyInvite,
                ),
            ],
          );
          final openAction = Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: const Text('Abrir'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(68, 32),
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: TitansUI.spaceXs),
              openAction,
            ],
          );
        },
      ),
    );
  }

  static Color beltUiColor(BeltColor belt) {
    return TitansUI.beltColor(belt.name);
  }

  static String beltName(BeltColor belt) {
    return TitansUI.beltLabel(belt.name);
  }
}

class _StudentProgressRing extends StatelessWidget {
  final int degree;
  final int maxDegree;
  final Color color;

  const _StudentProgressRing({
    required this.degree,
    required this.maxDegree,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeMax = maxDegree.clamp(1, 12).toInt();
    final safeDegree = degree.clamp(0, safeMax).toInt();
    final value = (safeDegree / safeMax).clamp(0.0, 1.0).toDouble();
    final textColor = color.computeLuminance() > 0.82 ? cs.onSurface : color;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 4.5,
              backgroundColor: cs.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$safeDegree',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'grau',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessStatusBadge extends StatelessWidget {
  final MasterPanelStudentAccessStatus status;

  const _AccessStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs);

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitansRadius.pill),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        _label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case MasterPanelStudentAccessStatus.active:
        return 'Ativo';
      case MasterPanelStudentAccessStatus.pending:
        return 'Convite pendente';
      case MasterPanelStudentAccessStatus.expired:
        return 'Expirado';
      case MasterPanelStudentAccessStatus.revoked:
        return 'Revogado';
      case MasterPanelStudentAccessStatus.noAccess:
        return 'Sem acesso';
    }
  }

  Color _color(ColorScheme cs) {
    switch (status) {
      case MasterPanelStudentAccessStatus.active:
        return cs.primary;
      case MasterPanelStudentAccessStatus.pending:
        return TitansUI.neonGold;
      case MasterPanelStudentAccessStatus.expired:
      case MasterPanelStudentAccessStatus.revoked:
        return cs.error;
      case MasterPanelStudentAccessStatus.noAccess:
        return cs.onSurface.withValues(alpha: 0.62);
    }
  }
}

enum MasterPanelStudentInviteAction { send, copy, resend, revoke }

enum _StudentAction {
  edit,
  editGraduation,
  sendInvite,
  copyInvite,
  resendInvite,
  revokeInvite,
  archive,
}

class _StudentActionsMenu extends StatelessWidget {
  final bool canEditProfile;
  final bool canEditGraduation;
  final bool canArchiveProfile;
  final VoidCallback onEdit;
  final VoidCallback onEditGraduation;
  final VoidCallback onArchive;
  final MasterPanelStudentAccessStatus accessStatus;
  final ValueChanged<MasterPanelStudentInviteAction> onInviteAction;
  final bool canCopyInvite;

  const _StudentActionsMenu({
    required this.canEditProfile,
    required this.canEditGraduation,
    required this.canArchiveProfile,
    required this.onEdit,
    required this.onEditGraduation,
    required this.onArchive,
    required this.accessStatus,
    required this.onInviteAction,
    required this.canCopyInvite,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StudentAction>(
      tooltip: 'A\u00e7\u00f5es do atleta',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _StudentAction.edit:
            onEdit();
            break;
          case _StudentAction.editGraduation:
            onEditGraduation();
            break;
          case _StudentAction.sendInvite:
            onInviteAction(MasterPanelStudentInviteAction.send);
            break;
          case _StudentAction.copyInvite:
            onInviteAction(MasterPanelStudentInviteAction.copy);
            break;
          case _StudentAction.resendInvite:
            onInviteAction(MasterPanelStudentInviteAction.resend);
            break;
          case _StudentAction.revokeInvite:
            onInviteAction(MasterPanelStudentInviteAction.revoke);
            break;
          case _StudentAction.archive:
            onArchive();
            break;
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: _StudentAction.edit,
              enabled: canEditProfile,
              child: const _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Editar atleta',
              ),
            ),
            PopupMenuItem(
              value: _StudentAction.editGraduation,
              enabled: canEditGraduation,
              child: const _MenuItem(
                icon: Icons.workspace_premium_outlined,
                label: 'Editar gradua\u00e7\u00e3o',
              ),
            ),
            if (accessStatus == MasterPanelStudentAccessStatus.noAccess)
              PopupMenuItem(
                value: _StudentAction.sendInvite,
                child: const _MenuItem(
                  icon: Icons.outgoing_mail,
                  label: 'Enviar convite',
                ),
              ),
            if (canCopyInvite &&
                (accessStatus == MasterPanelStudentAccessStatus.pending ||
                    accessStatus == MasterPanelStudentAccessStatus.expired))
              PopupMenuItem(
                value: _StudentAction.copyInvite,
                child: const _MenuItem(
                  icon: Icons.copy_outlined,
                  label: 'Copiar convite',
                ),
              ),
            if (accessStatus == MasterPanelStudentAccessStatus.pending ||
                accessStatus == MasterPanelStudentAccessStatus.expired)
              PopupMenuItem(
                value: _StudentAction.resendInvite,
                child: const _MenuItem(
                  icon: Icons.mark_email_unread_outlined,
                  label: 'Reenviar convite',
                ),
              ),
            if (accessStatus == MasterPanelStudentAccessStatus.pending)
              PopupMenuItem(
                value: _StudentAction.revokeInvite,
                child: const _MenuItem(
                  icon: Icons.block_outlined,
                  label: 'Revogar convite',
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _StudentAction.archive,
              enabled: canArchiveProfile,
              child: const _MenuItem(
                icon: Icons.archive_outlined,
                label: 'Arquivar perfil',
              ),
            ),
          ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: TitansUI.spaceSm),
        Flexible(child: Text(label)),
      ],
    );
  }
}
