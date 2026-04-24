import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/grading_rules.dart';
import '../repository/athlete_registration_repository.dart';
import '../widgets/titans_scaffold.dart';

class AthleteRegistrationScreen extends StatelessWidget {
  final String academyId;

  const AthleteRegistrationScreen({super.key, required this.academyId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => AthleteRegistrationViewModel(
            repository: AthleteRegistrationRepository.instance,
          ),
      child: _AthleteRegistrationForm(academyId: academyId),
    );
  }
}

class _AthleteRegistrationForm extends StatefulWidget {
  final String academyId;

  const _AthleteRegistrationForm({required this.academyId});

  @override
  State<_AthleteRegistrationForm> createState() =>
      _AthleteRegistrationFormState();
}

class _AthleteRegistrationFormState extends State<_AthleteRegistrationForm> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickBirthDate(AthleteRegistrationViewModel vm) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 10, now.month, now.day),
    );

    if (picked != null) {
      vm.updateBirthDate(picked);
    }
  }

  Future<void> _submit() async {
    final vm = context.read<AthleteRegistrationViewModel>();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await vm.register(academyId: widget.academyId);
    if (!success || !mounted) return;
    _formKey.currentState?.reset();
    vm.resetInputs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atleta cadastrado com sucesso')),
    );
  }

  String _formatBirthDate(DateTime? date) {
    if (date == null) return 'Selecione a data';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AthleteRegistrationViewModel>();
    final cs = Theme.of(context).colorScheme;

    return TitansScaffold(
      scroll: true,
      appBar: AppBar(title: const Text('Cadastro de atleta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dados básicos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: vm.nameController,
                      enabled: !vm.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator:
                          (value) =>
                              (value?.trim().length ?? 0) < 3
                                  ? 'Informe o nome completo'
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: vm.emailController,
                      enabled: !vm.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: vm.phoneController,
                      enabled: !vm.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Telefone / WhatsApp',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BeltColor>(
                            initialValue: vm.belt,
                            decoration: const InputDecoration(
                              labelText: 'Faixa',
                              prefixIcon: Icon(Icons.horizontal_rule),
                            ),
                            items:
                                BeltColor.values
                                    .map(
                                      (belt) => DropdownMenuItem(
                                        value: belt,
                                        child: Text(_beltLabel(belt)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: vm.isLoading ? null : vm.updateBelt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('${vm.belt.name}-${vm.degree}'),
                            initialValue: vm.degree,
                            decoration: const InputDecoration(
                              labelText: 'Grau',
                              prefixIcon: Icon(Icons.star_outline),
                            ),
                            items: List.generate(
                              vm.maxDegree + 1,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(index.toString()),
                              ),
                            ),
                            onChanged: vm.isLoading ? null : vm.updateDegree,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: vm.sex,
                      decoration: const InputDecoration(
                        labelText: 'Sexo',
                        prefixIcon: Icon(Icons.transgender_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'male',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Feminino'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Outro')),
                      ],
                      onChanged: vm.isLoading ? null : vm.updateSex,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Medidas corporais',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: vm.weightController,
                            enabled: !vm.isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: vm.heightController,
                            enabled: !vm.isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Altura (cm)',
                              prefixIcon: Icon(Icons.height),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Informações adicionais',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data de nascimento',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: const OutlineInputBorder(),
                        enabled: !vm.isLoading,
                      ),
                      child: InkWell(
                        onTap: vm.isLoading ? null : () => _pickBirthDate(vm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatBirthDate(vm.birthDate),
                                style: TextStyle(
                                  color:
                                      vm.birthDate == null
                                          ? cs.onSurface.withValues(alpha: 0.6)
                                          : cs.onSurface,
                                ),
                              ),
                              Icon(
                                Icons.calendar_month_outlined,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: vm.notesController,
                      enabled: !vm.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Notas internas',
                        prefixIcon: Icon(Icons.note_outlined),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (vm.successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          vm.successMessage!,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: vm.isLoading ? null : _submit,
                      icon:
                          vm.isLoading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.save_outlined),
                      label: Text(
                        vm.isLoading ? 'Cadastrando...' : 'Cadastrar atleta',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O cadastro cria o documento de usuário, progresso e nutrição que as telas do atleta esperam.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _beltLabel(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return 'Branca';
      case BeltColor.blue:
        return 'Azul';
      case BeltColor.purple:
        return 'Roxa';
      case BeltColor.brown:
        return 'Marrom';
      case BeltColor.black:
        return 'Preta';
    }
  }
}

class AthleteRegistrationViewModel extends ChangeNotifier {
  AthleteRegistrationViewModel({required this.repository});

  final AthleteRegistrationRepository repository;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final notesController = TextEditingController();

  BeltColor belt = BeltColor.white;
  int degree = 0;
  int get maxDegree => GradingRules.fallbackMaxDegrees(belt);
  String sex = 'male';
  DateTime? birthDate;

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  void updateBelt(BeltColor? value) {
    if (value == null || belt == value) return;
    belt = value;
    degree = degree.clamp(0, maxDegree).toInt();
    notifyListeners();
  }

  void updateDegree(int? value) {
    if (value == null) return;
    final nextDegree = value.clamp(0, maxDegree).toInt();
    if (degree == nextDegree) return;
    degree = nextDegree;
    notifyListeners();
  }

  void updateSex(String? value) {
    if (value == null || sex == value) return;
    sex = value;
    notifyListeners();
  }

  void updateBirthDate(DateTime? date) {
    birthDate = date;
    notifyListeners();
  }

  Future<bool> register({required String academyId}) async {
    final athleteName = nameController.text.trim();
    if (athleteName.length < 3) {
      errorMessage = 'Nome precisa conter pelo menos 3 caracteres.';
      successMessage = null;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await repository.registerAthlete(
        academyId: academyId,
        name: athleteName,
        email: _optionalText(emailController),
        phone: _optionalText(phoneController),
        belt: belt,
        degree: degree.clamp(0, maxDegree).toInt(),
        weightKg: _parseDouble(weightController),
        heightCm: _parseDouble(heightController),
        sex: sex,
        birthDate: birthDate,
        notes: _optionalText(notesController),
      );
      successMessage = 'Atleta cadastrado com sucesso.';
      return true;
    } catch (e) {
      errorMessage = 'Não foi possível cadastrar o atleta. ${e.toString()}';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetInputs() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    weightController.clear();
    heightController.clear();
    notesController.clear();
    belt = BeltColor.white;
    degree = 0;
    sex = 'male';
    birthDate = null;
    notifyListeners();
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _parseDouble(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    weightController.dispose();
    heightController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
