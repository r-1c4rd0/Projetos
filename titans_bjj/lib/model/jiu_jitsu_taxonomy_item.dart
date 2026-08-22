import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/jiu_jitsu_taxonomy.dart';

enum JiuJitsuTaxonomyType { position, technique }

class JiuJitsuTaxonomyItem {
  final String id;
  final String academyId;
  final JiuJitsuTaxonomyType type;
  final String label;
  final String normalizedKey;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const JiuJitsuTaxonomyItem({
    required this.id,
    required this.academyId,
    required this.type,
    required this.label,
    required this.normalizedKey,
    required this.createdByUid,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory JiuJitsuTaxonomyItem.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return JiuJitsuTaxonomyItem(
      id: id,
      academyId: (data['academyId'] ?? '').toString(),
      type: taxonomyTypeFromString(data['type']),
      label: (data['label'] ?? '').toString(),
      normalizedKey: (data['normalizedKey'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
      isActive: data['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'academyId': academyId,
      'type': type.name,
      'label': label,
      'normalizedKey': normalizedKey,
      'createdByUid': createdByUid,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isActive': isActive,
    };
  }

  static DateTime? _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

JiuJitsuTaxonomyType taxonomyTypeFromString(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  return JiuJitsuTaxonomyType.values.firstWhere(
    (type) => type.name == normalized,
    orElse: () => JiuJitsuTaxonomyType.position,
  );
}

extension JiuJitsuTaxonomyTypeLabels on JiuJitsuTaxonomyType {
  List<String> get staticOptions {
    switch (this) {
      case JiuJitsuTaxonomyType.position:
        return JiuJitsuTaxonomy.positions;
      case JiuJitsuTaxonomyType.technique:
        return JiuJitsuTaxonomy.techniques;
    }
  }
}
