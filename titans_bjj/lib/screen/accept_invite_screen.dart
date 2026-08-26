import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repository/invite_repository.dart';
import '../widgets/titans_scaffold.dart';

class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({super.key});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _academyCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _repo = InviteRepository.instance;

  bool _submitting = false;

  @override
  void dispose() {
    _academyCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return TitansScaffold(
      scroll: true,
      appBar: AppBar(title: const Text('Aceitar convite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Convite da academia',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user == null
                        ? 'Entre com o e-mail convidado antes de aceitar.'
                        : 'Conta atual: ${user.email ?? user.uid}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _academyCtrl,
                    decoration: const InputDecoration(labelText: 'academyId'),
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'inviteId / codigo',
                    ),
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: user == null || _submitting ? null : _accept,
                    icon:
                        _submitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.verified_user_outlined),
                    label: Text(
                      _submitting ? 'Aceitando...' : 'Aceitar convite',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use o mesmo e-mail informado no convite. Depois de aceitar, reabra o app ou faca login novamente para recarregar a sessao.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final academyId = _academyCtrl.text.trim();
    final inviteId = _inviteCtrl.text.trim();
    if (academyId.isEmpty || inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe academyId e inviteId.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.acceptManualInvite(academyId: academyId, inviteId: inviteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Convite aceito. Reabra o app ou faca login novamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel aceitar convite: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
