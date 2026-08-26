import 'package:cloud_functions/cloud_functions.dart';
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
                        ? 'Entre com o mesmo e-mail do convite antes de aceitar.'
                        : 'Conta atual: ${user.email ?? user.uid}. Confirme que é o mesmo e-mail do convite.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'O professor fornece o ID da academia e o código do convite.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _academyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID da academia (academyId)',
                    ),
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código do convite (inviteId)',
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
                    'Use o mesmo e-mail informado no convite. Depois do aceite, volte e atualize a sessão; se necessário, entre novamente.',
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
            'Convite aceito. Volte e atualize a sessão; se os dados não aparecerem, entre novamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_inviteErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _inviteErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Este convite pertence a outro e-mail. Entre com o mesmo e-mail informado pelo professor.';
        case 'deadline-exceeded':
          return 'Este convite expirou. Peça ao professor para reenviá-lo.';
        case 'not-found':
          return 'Convite não encontrado. Confira o ID da academia e o código enviados pelo professor.';
        case 'invalid-argument':
          return 'Código inválido. Confira o ID da academia e o código do convite.';
        case 'unauthenticated':
          return 'Sua sessão não está ativa. Entre novamente antes de aceitar o convite.';
        case 'already-exists':
          return 'Este convite ou esta conta já possui um vínculo com a academia.';
        case 'failed-precondition':
          return 'Este convite não pode mais ser aceito. Peça ao professor para verificar ou reenviar o convite.';
      }
    }
    return 'Não foi possível aceitar o convite. Confira os dados e tente novamente.';
  }
}
