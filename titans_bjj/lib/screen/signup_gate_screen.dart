import 'package:flutter/material.dart';

import '../repository/user_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';
import '../model/app_user.dart';
import 'signup_screen.dart';

class SignupGateScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? email;

  const SignupGateScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.email,
  });

  @override
  State<SignupGateScreen> createState() => _SignupGateScreenState();
}

class _SignupGateScreenState extends State<SignupGateScreen> {
  late final UserRepository _repo = UserRepository.instance;
  late final Future<AppUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _repo.getUser(
      academyId: widget.academyId,
      uid: widget.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TitansScaffold(
      scroll: false,
      appBar: AppBar(title: const Text('Verificando cadastro')),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorState(
              title: 'Erro ao verificar cadastro',
              message: snap.error.toString(),
            );
          }

          final user = snap.data;

          if (user == null) {
            // ✅ não existe no firestore -> cadastro
            return SignupScreen(
              academyId: widget.academyId,
              uid: widget.uid,
              email: widget.email,
            );
          }

          // ✅ existe -> injeta UserScope e segue
          return UserScope(
            user: user,
            child: const _AppEntryPoint(),
          );
        },
      ),
    );
  }
}

/// Aqui você aponta para sua home real (tabs, console, etc).
class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------------------
    // Entry Point para Rota Principal
    // Após o registro e inicialização no banco, o usuário segue para a Home.
    // Redirecione para a tela principal real (e.g. HomeShell) via Navigator.
    // ------------------------------------------------------------------------
    return const Center(child: Text('OK! Usuário cadastrado. Entrar no app.'));
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
            ]),
          ),
        ),
      ),
    );
  }
}
