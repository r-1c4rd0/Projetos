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
                  'Não foi possível carregar a identidade visual da academia.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profile = snapshot.data ?? AcademyProfile(name: academyId);
          final isDefault = _isDefaultAcademy(profile, academyId);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AcademyBrandingHeader(profile: profile, academyId: academyId),
              const SizedBox(height: 16),
              _AcademyStatusCard(profile: profile, academyId: academyId),
              const SizedBox(height: 16),
              _AcademySection(
                title: 'Identidade',
                children: [
                  _StatusRow(
                    label: 'Nome da academia',
                    value: _displayAcademyName(profile, academyId),
                  ),
                  _StatusRow(
                    label: 'Logo',
                    value:
                        profile.branding.logoAssetKey.isEmpty &&
                                profile.branding.logoUrl.isEmpty
                            ? 'Logo personalizada não configurada'
                            : 'Logo configurada',
                  ),
                  const _StatusRow(
                    label: 'Descrição curta',
                    value: 'Ainda não configurada',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AcademySection(
                title: 'Visual',
                children: [
                  _StatusRow(
                    label: 'Logo interna',
                    value:
                        profile.branding.logoAssetKey.isEmpty
                            ? 'Padrão Titans'
                            : profile.branding.logoAssetKey,
                  ),
                  _StatusRow(
                    label: 'Fundo do login',
                    value:
                        profile.branding.loginBackgroundAssetKey.isEmpty &&
                                profile.branding.loginBackgroundUrl.isEmpty
                            ? 'Não configurado'
                            : 'Configurado',
                  ),
                  _StatusRow(
                    label: 'Cores',
                    value:
                        profile.branding.primaryColor.isEmpty &&
                                profile.branding.secondaryColor.isEmpty
                            ? 'Padrão Titans'
                            : 'Personalizadas',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AcademySection(
                title: 'Operação',
                children: [
                  const _OperationRow(
                    icon: Icons.groups_outlined,
                    title: 'Alunos vinculados',
                    description: 'Gerenciados no Painel do Mestre.',
                    statusLabel: 'Status',
                  ),
                  const _OperationRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Professores e administradores',
                    description: 'Gerenciamento ainda não disponível.',
                    statusLabel: 'Em breve',
                  ),
                  _OperationRow(
                    icon: Icons.fact_check_outlined,
                    title: 'Presença',
                    description:
                        isDefault
                            ? 'Presença requer uma academia configurada.'
                            : 'Gerencie chamadas e check-ins.',
                    actionLabel: isDefault ? null : 'Abrir',
                    statusLabel: isDefault ? 'Indisponível' : null,
                    onPressed: isDefault ? null : _openAttendance,
                  ),
                  const _OperationRow(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Convites',
                    description: 'Fluxo ainda não habilitado.',
                    statusLabel: 'Indisponível',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAttendance() {
    final scope = UserScope.maybeScopeOf(context);
    if (scope == null) {
      _showMessage('Presença requer sessão ativa.');
      return;
    }

    final academyId = scope.activeAcademyId.trim();
    if (academyId.isEmpty || academyId.toLowerCase() == 'default') {
      _showMessage('Presença requer uma academia configurada.');
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

class _AcademyBrandingHeader extends StatelessWidget {
  const _AcademyBrandingHeader({
    required this.profile,
    required this.academyId,
  });

  final AcademyProfile profile;
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final primary = academyBrandColor(profile.branding.primaryColor);
    final secondary = academyBrandColor(profile.branding.secondaryColor);
    final accent = primary ?? secondary;
    final colorScheme = Theme.of(context).colorScheme;
    final isDefault = _isDefaultAcademy(profile, academyId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor:
                  accent?.withValues(alpha: 0.10) ?? colorScheme.surface,
              child: AcademyBrandLogo(branding: profile.branding, size: 46),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academia',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDefault
                        ? 'Ambiente padrão ainda não configurado'
                        : 'Configurações e identidade da academia',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayAcademyName(profile, academyId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademyStatusCard extends StatelessWidget {
  const _AcademyStatusCard({required this.profile, required this.academyId});

  final AcademyProfile profile;
  final String academyId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDefault = _isDefaultAcademy(profile, academyId);
    final chips = <String>[
      if (isDefault) 'Configuração incompleta',
      if (profile.branding.isEmpty) 'Usando visual padrão Titans',
      if (profile.branding.logoAssetKey.isEmpty &&
          profile.branding.logoUrl.isEmpty)
        'Logo personalizada não configurada',
      if (profile.branding.loginBackgroundAssetKey.isEmpty &&
          profile.branding.loginBackgroundUrl.isEmpty)
        'Fundo de login não configurado',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDefault ? 'Configuração incompleta' : 'Status da academia',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  chips
                      .map(
                        (label) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(label),
                          backgroundColor: cs.primary.withValues(alpha: 0.10),
                          side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.20),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademySection extends StatelessWidget {
  const _AcademySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.64)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: cs.onSurface.withValues(alpha: 0.70)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.64)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (actionLabel != null && onPressed != null)
            FilledButton(onPressed: onPressed, child: Text(actionLabel))
          else if (statusLabel != null)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(statusLabel),
              backgroundColor: cs.surfaceContainerHighest,
              side: BorderSide(color: cs.outlineVariant),
            ),
        ],
      ),
    );
  }
}

bool _isDefaultAcademy(AcademyProfile profile, String academyId) {
  return academyId.trim().toLowerCase() == 'default' ||
      profile.name.trim().toLowerCase() == 'default';
}

String _displayAcademyName(AcademyProfile profile, String academyId) {
  return _isDefaultAcademy(profile, academyId)
      ? 'Academia não configurada'
      : profile.name.trim();
}
