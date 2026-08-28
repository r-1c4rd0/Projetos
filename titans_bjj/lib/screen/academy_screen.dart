import 'package:flutter/material.dart';

import '../model/academy_models.dart';
import '../repository/academy_repository.dart';
import '../service/user_session.dart';
import '../widgets/academy_branding.dart';

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Não foi possível carregar a identidade visual da academia.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final profile = snapshot.data ?? AcademyProfile(name: academyId);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AcademyBrandingHeader(profile: profile),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: profile.name,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da academia',
                ),
              ),
              const SizedBox(height: 16),
              _ReadOnlyBrandingField(
                label: 'Logo interna',
                value:
                    profile.branding.logoAssetKey.isEmpty
                        ? 'Padrão Titans'
                        : profile.branding.logoAssetKey,
              ),
              _ReadOnlyBrandingField(
                label: 'Logo por URL',
                value:
                    profile.branding.logoUrl.isEmpty
                        ? 'Não configurada'
                        : profile.branding.logoUrl,
              ),
              _ReadOnlyBrandingField(
                label: 'Fundo do login',
                value:
                    profile.branding.loginBackgroundAssetKey.isEmpty
                        ? 'Padrão Titans'
                        : profile.branding.loginBackgroundAssetKey,
              ),
              _ReadOnlyBrandingField(
                label: 'Fundo do login por URL',
                value:
                    profile.branding.loginBackgroundUrl.isEmpty
                        ? 'Não configurado'
                        : profile.branding.loginBackgroundUrl,
              ),
              _ReadOnlyBrandingField(
                label: 'Cor primária',
                value:
                    profile.branding.primaryColor.isEmpty
                        ? 'Padrão Titans'
                        : profile.branding.primaryColor,
              ),
              _ReadOnlyBrandingField(
                label: 'Cor secundária',
                value:
                    profile.branding.secondaryColor.isEmpty
                        ? 'Padrão Titans'
                        : profile.branding.secondaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                'A logo da academia é usada dentro do app. O ícone instalado do aplicativo continua sendo o ícone do Titans BJJ.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AcademyBrandingHeader extends StatelessWidget {
  final AcademyProfile profile;

  const _AcademyBrandingHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final primary = academyBrandColor(profile.branding.primaryColor);
    final secondary = academyBrandColor(profile.branding.secondaryColor);
    final accent = primary ?? secondary;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor:
                accent?.withValues(alpha: 0.10) ?? colorScheme.surface,
            child: AcademyBrandLogo(branding: profile.branding, size: 56),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            profile.branding.isEmpty
                ? 'Visual padrao Titans'
                : 'Branding carregado da academia ativa',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBrandingField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyBrandingField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
