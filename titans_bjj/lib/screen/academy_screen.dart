import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../model/academy_models.dart';
import '../main.dart';

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  final repo = InMemoryAcademyRepository();
  AcademyProfile? profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    profile = await repo.get();
    setState(() {});
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Salvando cópia local permanente
    final dir = await getApplicationDocumentsDirectory();
    final newPath = '${dir.path}/academy_logo.png';
    await File(picked.path).copy(newPath);

    final updated = profile!.copyWith(logoPath: newPath);
    await repo.save(updated);

    if (mounted) {
      setState(() => profile = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final file = profile!.logoPath != null ? File(profile!.logoPath!) : null;

    return Scaffold(
      appBar: AppBar(
          leading: const AppLogoLeading(),
          title: const Text('Academia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              // AJUSTE 1: Acesso via TitansColors e remoção de const (se necessário)
              backgroundColor: Theme.of(context).colorScheme.surface,
              backgroundImage: file != null && file.existsSync()
                  ? FileImage(file)
                  : null,
              child: file == null
              // AJUSTE 2: Removido 'const' do Icon e acesso via TitansColors
                  ? Icon(Icons.image_outlined, size: 50, color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Trocar Logo'),
              onPressed: _pickLogo,
            ),
          ),
          const SizedBox(height: 30),
          TextFormField(
            initialValue: profile!.name,
            decoration: const InputDecoration(labelText: 'Nome da academia'),
            onChanged: (v) async {
              final updated = profile!.copyWith(name: v);
              await repo.save(updated);
              profile = updated;
            },
          ),
        ],
      ),
    );
  }
}