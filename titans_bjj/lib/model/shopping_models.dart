// shopping_models.dart
enum PurchaseStatus { pending, bought }
enum Priority { low, medium, high }

class PurchaseItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;            // ex: un, kg, m, cx
  final Priority priority;
  final DateTime? neededBy;
  final String? supplier;       // opcional
  final String? notes;
  final PurchaseStatus status;

  PurchaseItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.priority = Priority.medium,
    this.neededBy,
    this.supplier,
    this.notes,
    this.status = PurchaseStatus.pending,
  });

  PurchaseItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    Priority? priority,
    DateTime? neededBy,
    String? supplier,
    String? notes,
    PurchaseStatus? status,
  }) {
    return PurchaseItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      priority: priority ?? this.priority,
      neededBy: neededBy ?? this.neededBy,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

abstract class IShoppingRepository {
  Future<List<PurchaseItem>> all();
  Future<void> upsert(PurchaseItem item);
  Future<void> delete(String id);
}

class InMemoryShoppingRepository implements IShoppingRepository {
  final _items = <PurchaseItem>[];

  @override
  Future<List<PurchaseItem>> all() async {
    _items.sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      final ad = a.neededBy?.millisecondsSinceEpoch ?? 1 << 30;
      final bd = b.neededBy?.millisecondsSinceEpoch ?? 1 << 30;
      return ad.compareTo(bd);
    });
    return List.unmodifiable(_items);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((e) => e.id == id);

  @override
  Future<void> upsert(PurchaseItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item;
    } else {
      _items.add(item);
    }
  }
}
