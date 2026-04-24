// shopping_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/shopping_models.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final IShoppingRepository repo = InMemoryShoppingRepository();

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    await repo.upsert(PurchaseItem(
      id: const Uuid().v4(),
      name: 'Fita Kinesio',
      quantity: 5,
      unit: 'un',
      priority: Priority.high,
      neededBy: DateTime.now().add(const Duration(days: 3)),
      notes: 'Para atletas lesionados',
    ));
    await repo.upsert(PurchaseItem(
      id: const Uuid().v4(),
      name: 'Produto de limpeza',
      quantity: 2,
      unit: 'cx',
      priority: Priority.medium,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'shopping_fab',
        onPressed: _addItem,
        child: const Icon(Icons.add_shopping_cart),
      ),
      body: FutureBuilder<List<PurchaseItem>>(
        future: repo.all(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return  Center(child: Text('Lista vazia', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              return Card(
                child: ListTile(
                  leading: Checkbox(
                    value: it.status == PurchaseStatus.bought,
                    onChanged: (v) async {
                      await repo.upsert(it.copyWith(
                        status: v == true ? PurchaseStatus.bought : PurchaseStatus.pending,
                      ));
                      if (mounted) setState(() {});
                    },
                  ),
                  title: Text('${it.name} • ${it.quantity.toStringAsFixed(0)} ${it.unit}'),
                  subtitle: Text(_subtitle(it)),
                  trailing: _priorityChip(it.priority),
                  onTap: () => _editItem(it),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _subtitle(PurchaseItem it) {
    final parts = <String>[];
    if (it.neededBy != null) {
      parts.add('precisa até ${it.neededBy!.day.toString().padLeft(2, '0')}/${it.neededBy!.month.toString().padLeft(2, '0')}');
    }
    if ((it.supplier ?? '').isNotEmpty) parts.add('fornecedor: ${it.supplier}');
    if ((it.notes ?? '').isNotEmpty) parts.add(it.notes!);
    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  Widget _priorityChip(Priority p) {
    final label = switch (p) { Priority.high => 'Alta', Priority.medium => 'Média', Priority.low => 'Baixa' };
    final color = switch (p) { Priority.high => Colors.red, Priority.medium => Colors.orange, Priority.low => Colors.green };
    return Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.15), side: BorderSide(color: color));
  }

  Future<void> _addItem() async {
    final created = await showDialog<PurchaseItem>(
      context: context,
      builder: (_) => _ShoppingDialog(),
    );
    if (created != null) {
      await repo.upsert(created);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editItem(PurchaseItem it) async {
    final updated = await showDialog<PurchaseItem>(
      context: context,
      builder: (_) => _ShoppingDialog(existing: it),
    );
    if (updated != null) {
      await repo.upsert(updated);
      if (mounted) setState(() {});
    }
  }
}

class _ShoppingDialog extends StatefulWidget {
  final PurchaseItem? existing;
  const _ShoppingDialog({this.existing});
  @override
  State<_ShoppingDialog> createState() => _ShoppingDialogState();
}

class _ShoppingDialogState extends State<_ShoppingDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'un');
  final _supplier = TextEditingController();
  final _notes = TextEditingController();
  Priority _priority = Priority.medium;
  DateTime? _neededBy;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _qty.text = e.quantity.toString();
      _unit.text = e.unit;
      _supplier.text = e.supplier ?? '';
      _notes.text = e.notes ?? '';
      _priority = e.priority;
      _neededBy = e.neededBy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Novo item' : 'Editar item'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _qty,
                  decoration: const InputDecoration(labelText: 'Qtd'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<Priority>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: Priority.high, child: Text('Alta')),
                DropdownMenuItem(value: Priority.medium, child: Text('Média')),
                DropdownMenuItem(value: Priority.low, child: Text('Baixa')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? Priority.medium),
              decoration: const InputDecoration(labelText: 'Prioridade'),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _neededBy ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (!mounted) return;
                if (picked != null) setState(() => _neededBy = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Precisa até'),
                child: Text(_neededBy == null
                    ? '—'
                    : '${_neededBy!.day.toString().padLeft(2, '0')}/${_neededBy!.month.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _supplier, decoration: const InputDecoration(labelText: 'Fornecedor')),
            const SizedBox(height: 8),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Observações'), maxLines: 2),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final id = widget.existing?.id ?? const Uuid().v4();
            final qty = double.tryParse(_qty.text.replaceAll(',', '.')) ?? 1.0;
            final item = PurchaseItem(
              id: id,
              name: _name.text.trim(),
              quantity: qty,
              unit: _unit.text.trim().isEmpty ? 'un' : _unit.text.trim(),
              priority: _priority,
              neededBy: _neededBy,
              supplier: _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              status: widget.existing?.status ?? PurchaseStatus.pending,
            );
            Navigator.pop(context, item);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
