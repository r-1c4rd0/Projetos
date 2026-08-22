import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/jiu_jitsu_taxonomy_item.dart';
import '../service/jiu_jitsu_taxonomy.dart';

class JiuJitsuTaxonomyRepository {
  const JiuJitsuTaxonomyRepository(this.db);

  final FirebaseFirestore db;

  static final JiuJitsuTaxonomyRepository instance =
      JiuJitsuTaxonomyRepository(FirebaseFirestore.instance);

  CollectionReference<Map<String, dynamic>> _collectionRef(String academyId) {
    return db
        .collection('academies')
        .doc(academyId)
        .collection('jiu_jitsu_taxonomy');
  }

  Stream<List<JiuJitsuTaxonomyItem>> watchItems({
    required String academyId,
    required JiuJitsuTaxonomyType type,
  }) {
    return _collectionRef(academyId)
        .where('type', isEqualTo: type.name)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => JiuJitsuTaxonomyItem.fromDoc(doc.id, doc.data()))
              .where((item) => item.academyId == academyId)
              .toList()
            ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            ),
        );
  }

  Future<JiuJitsuTaxonomyItem?> findByNormalizedKey({
    required String academyId,
    required JiuJitsuTaxonomyType type,
    required String normalizedKey,
  }) async {
    final docId = _docId(type: type, normalizedKey: normalizedKey);
    final snap = await _collectionRef(academyId).doc(docId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;

    final item = JiuJitsuTaxonomyItem.fromDoc(snap.id, data);
    if (item.academyId != academyId ||
        item.type != type ||
        item.normalizedKey != normalizedKey ||
        !item.isActive) {
      return null;
    }
    return item;
  }

  Future<JiuJitsuTaxonomyItem> addCustomItem({
    required String academyId,
    required JiuJitsuTaxonomyType type,
    required String label,
    required String createdByUid,
  }) async {
    final cleanLabel = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanLabel.isEmpty) {
      throw ArgumentError('label vazio');
    }

    final normalizedKey = JiuJitsuTaxonomy.normalizedKey(cleanLabel);
    final existing = await findByNormalizedKey(
      academyId: academyId,
      type: type,
      normalizedKey: normalizedKey,
    );
    if (existing != null) return existing;

    final docId = _docId(type: type, normalizedKey: normalizedKey);
    final ref = _collectionRef(academyId).doc(docId);
    final now = DateTime.now();
    final item = JiuJitsuTaxonomyItem(
      id: docId,
      academyId: academyId,
      type: type,
      label: cleanLabel,
      normalizedKey: normalizedKey,
      createdByUid: createdByUid,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );

    await ref.set(item.toMap(), SetOptions(merge: true));
    return item;
  }

  String _docId({
    required JiuJitsuTaxonomyType type,
    required String normalizedKey,
  }) {
    final safeKey = normalizedKey
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${type.name}_${safeKey.isEmpty ? 'item' : safeKey}';
  }
}
