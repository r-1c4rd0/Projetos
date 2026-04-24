import 'package:flutter/material.dart';
import '../model/grading_rules.dart';
import '../repository/user_repository.dart';
import '../service/user_session.dart';
import '../widgets/titans_scaffold.dart';

class SignupScreen extends StatefulWidget {
  final String academyId;
  final String uid;
  final String? email;

  const SignupScreen({
    super.key,
    required this.academyId,
    required this.uid,
    this.email,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  late final UserRepository _repo = UserRepository.instance;

  BeltColor _belt = BeltColor.white;
  int _degree = 0;

  String _role = 'athlete'; // athlete | professor | admin
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TitansScaffold(
      scroll: true,
      appBar: AppBar(title: const Text('Cadastro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete seu cadastro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Academia: ${widget.academyId}',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Informe um nome válido' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email (opcional)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de conta',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'athlete', child: Text('Aluno')),
                          DropdownMenuItem(value: 'professor', child: Text('Mestre')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'athlete'),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<BeltColor>(
                              initialValue: _belt,
                              decoration: const InputDecoration(
                                labelText: 'Faixa',
                                prefixIcon: Icon(Icons.horizontal_rule),
                              ),
                              items: const [
                                DropdownMenuItem(value: BeltColor.white, child: Text('Branca')),
                                DropdownMenuItem(value: BeltColor.blue, child: Text('Azul')),
                                DropdownMenuItem(value: BeltColor.purple, child: Text('Roxa')),
                                DropdownMenuItem(value: BeltColor.brown, child: Text('Marrom')),
                                DropdownMenuItem(value: BeltColor.black, child: Text('Preta')),
                              ],
                              onChanged: (v) => setState(() => _belt = v ?? BeltColor.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _degree,
                              decoration: const InputDecoration(
                                labelText: 'Grau',
                                prefixIcon: Icon(Icons.star_outline),
                              ),
                              items: List.generate(
                                9,
                                    (i) => DropdownMenuItem(value: i, child: Text(i.toString())),
                              ),
                              onChanged: (v) => setState(() => _degree = v ?? 0),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error.toString(),
                            style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _submit,
                              icon: _saving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Icon(Icons.save_outlined),
                              label: Text(_saving ? 'Salvando...' : 'Salvar cadastro'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Isso cria seu usuário dentro da academia e prepara Progresso/Nutrição.',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();

      // 1) upsert user doc (academies/{academyId}/users/{uid})
      await _repo.upsertUser(
        academyId: widget.academyId,
        uid: widget.uid,
        payload: {
          'name': name,
          'email': email,
          'role': _role, // athlete/professor/admin
          'belt': _belt.name,
          'degree': _degree,
        },
      );

      // 2) bootstrap progress + nutrition (ids padrão que suas telas esperam)
      await _repo.ensureBootstrapDocs(
        academyId: widget.academyId,
        uid: widget.uid,
        belt: _belt,
        degree: _degree,
      );

      // 3) ler AppUser e subir UserScope
      final user = await _repo.getUser(academyId: widget.academyId, uid: widget.uid);
      if (!mounted) return;
      if (user == null) {
        throw Exception('Falha ao ler usuário após salvar cadastro.');
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UserScope(
            user: user,
            child: const _AfterSignupEntryPoint(),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Troque para sua home real
class _AfterSignupEntryPoint extends StatelessWidget {
  const _AfterSignupEntryPoint();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Cadastro concluído. Entrar no app.'));
  }
}
