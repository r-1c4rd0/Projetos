import 'package:flutter/material.dart';

import '../model/academy_models.dart';
import '../repository/academy_repository.dart';
import '../service/user_session.dart';
import '../widgets/academy_branding.dart';
import 'attendance_screen.dart';

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  final repo = AcademyRepository.instance;
  Future<AcademyProfile>? _profileFuture;
  String? _academyId;
  bool _showStatusDetails = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = UserScope.scopeOf(context);
    if (_academyId == scope.activeAcademyId && _profileFuture != null) return;
    _academyId = scope.activeAcademyId;
    _profileFuture = repo.getAcademy(scope.activeAcademyId);
  }

  @override
  Widget build(BuildContext context) {
    final academyId = _academyId;
    final profileFuture = _profileFuture;

    if (academyId == null || profileFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Academia')),
      body: FutureBuilder<AcademyProfile>(
        future: profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Nao foi possivel carregar a identidade visual da academia.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profile = snapshot.data ?? AcademyProfile(name: academyId);
          final isDefault = _isDefaultAcademy(profile, academyId);
          final pendingItems = _pendingItems(profile, academyId);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _AcademyCompactHero(
                    profile: profile,
                    academyId: academyId,
                    pendingItems: pendingItems,
                  ),
                  const SizedBox(height: 12),
                  _ConfigurationStatus(
                    pendingItems: pendingItems,
                    expanded: _showStatusDetails,
                    onToggle:
                        pendingItems.isEmpty
                            ? null
                            : () => setState(
                              () => _showStatusDetails = !_showStatusDetails,
                            ),
                  ),
                  const SizedBox(height: 14),
                  _AcademySection(
                    title: 'Identidade',
                    children: [
                      _CompactInfoRow(
                        label: 'Nome',
                        value: _displayAcademyName(profile, academyId),
                      ),
                      _CompactInfoRow(
                        label: 'Logo',
                        value:
                            profile.branding.logoAssetKey.isEmpty &&
                                    profile.branding.logoUrl.isEmpty
                                ? 'Padrao Titans'
                                : 'Configurada',
                      ),
                      const _CompactInfoRow(
                        label: 'Descricao',
                        value: 'Nao adicionada',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AcademySection(
                    title: 'Visual',
                    children: [
                      _CompactInfoRow(
                        label: 'Logo interna',
                        value:
                            profile.branding.logoAssetKey.isEmpty
                                ? 'Padrao Titans'
                                : profile.branding.logoAssetKey,
                      ),
                      _CompactInfoRow(
                        label: 'Fundo do login',
                        value:
                            profile.branding.loginBackgroundAssetKey.isEmpty &&
                                    profile.branding.loginBackgroundUrl.isEmpty
                                ? 'Nao configurado'
                                : 'Configurado',
                      ),
                      _CompactInfoRow(
                        label: 'Cores',
                        value:
                            profile.branding.primaryColor.isEmpty &&
                                    profile.branding.secondaryColor.isEmpty
                                ? 'Padrao Titans'
                                : 'Personalizadas',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AcademySection(
                    title: 'Operacao',
                    priority: true,
                    children: [
                      const _OperationRow(
                        icon: Icons.groups_outlined,
                        title: 'Alunos',
                        description: 'Vinculados no Painel do Mestre',
                        statusLabel: 'Gerenciar',
                      ),
                      _OperationRow(
                        icon: Icons.fact_check_outlined,
                        title: 'Presenca',
                        description:
                            isDefault
                                ? 'Academia nao configurada'
                                : 'Abrir e acompanhar chamadas',
                        actionLabel: isDefault ? null : 'Abrir',
                        statusLabel: isDefault ? 'Indisponivel' : null,
                        onPressed: isDefault ? null : _openAttendance,
                      ),
                      const _OperationRow(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Professores',
                        description: 'Permissoes e equipe',
                        statusLabel: 'Em breve',
                      ),
                      const _OperationRow(
                        icon: Icons.mark_email_unread_outlined,
                        title: 'Convites',
                        description: 'Entrada por convite',
                        statusLabel: 'Indisponivel',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAttendance() {
    final scope = UserScope.maybeScopeOf(context);
    if (scope == null) {
      _showMessage('Presenca requer sessao ativa.');
      return;
    }

    final academyId = scope.activeAcademyId.trim();
    if (academyId.isEmpty || academyId.toLowerCase() == 'default') {
      _showMessage('Presenca requer uma academia configurada.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => UserSession(
              user: scope.user,
              activeAcademyId: scope.activeAcademyId,
              membershipSnapshot: scope.membershipSnapshot,
              memberships: scope.memberships,
              activeMembership: scope.activeMembership,
              child: const AttendanceScreen(),
            ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AcademyCompactHero extends StatelessWidget {
  const _AcademyCompactHero({
    required this.profile,
    required this.academyId,
    required this.pendingItems,
  });

  final AcademyProfile profile;
  final String academyId;
  final List<String> pendingItems;

  @override
  Widget build(BuildContext context) {
    final primary = academyBrandColor(profile.branding.primaryColor);
    final secondary = academyBrandColor(profile.branding.secondaryColor);
    final accent =
        primary ?? secondary ?? Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final isDefault = _isDefaultAcademy(profile, academyId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: AcademyBrandLogo(branding: profile.branding, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academia',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDefault
                        ? 'Ambiente pessoal'
                        : _displayAcademyName(profile, academyId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusDotLabel(
              label: pendingItems.isEmpty ? 'Completa' : 'Incompleta',
              color: pendingItems.isEmpty ? Colors.green : cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationStatus extends StatelessWidget {
  const _ConfigurationStatus({
    required this.pendingItems,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> pendingItems;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final complete = pendingItems.isEmpty;
    final count = pendingItems.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuracao',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            complete
                                ? 'Nenhum item pendente'
                                : '$count ${count == 1 ? 'item pendente' : 'itens pendentes'}',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.66),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusDotLabel(
                      label: complete ? 'Completa' : 'Incompleta',
                      color: complete ? Colors.green : cs.primary,
                    ),
                    if (onToggle != null) ...[
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  expanded
                      ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children:
                              pendingItems
                                  .map(
                                    (item) => _CompactInfoRow(
                                      label: item,
                                      value: 'Pendente',
                                      dense: true,
                                    ),
                                  )
                                  .toList(),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademySection extends StatelessWidget {
  const _AcademySection({
    required this.title,
    required this.children,
    this.priority = false,
  });

  final String title;
  final List<Widget> children;
  final bool priority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            priority
                ? cs.surfaceContainerHighest.withValues(alpha: 0.28)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border:
            priority
                ? Border.all(color: cs.primary.withValues(alpha: 0.18))
                : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(2, priority ? 10 : 0, 2, priority ? 8 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: priority ? 10 : 0),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.64),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.statusLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final String? statusLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionLabel = this.actionLabel;
    final statusLabel = this.statusLabel;
    final actionable = actionLabel != null && onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actionable ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: actionable ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (actionable) ...[
                Text(
                  actionLabel,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: cs.primary),
              ] else if (statusLabel != null)
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDotLabel extends StatelessWidget {
  const _StatusDotLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

List<String> _pendingItems(AcademyProfile profile, String academyId) {
  return <String>[
    if (_isDefaultAcademy(profile, academyId)) 'Academia',
    if (profile.branding.logoAssetKey.isEmpty &&
        profile.branding.logoUrl.isEmpty)
      'Logo',
    if (profile.branding.loginBackgroundAssetKey.isEmpty &&
        profile.branding.loginBackgroundUrl.isEmpty)
      'Fundo do login',
  ];
}

bool _isDefaultAcademy(AcademyProfile profile, String academyId) {
  return academyId.trim().toLowerCase() == 'default' ||
      profile.name.trim().toLowerCase() == 'default';
}

String _displayAcademyName(AcademyProfile profile, String academyId) {
  final name = profile.name.trim();
  return _isDefaultAcademy(profile, academyId) || name.isEmpty
      ? 'Academia nao configurada'
      : name;
}
