import 'pasal_model.dart';

/// Model for pasal links (relationships between pasal)
class PasalLinkModel {
  final String id;
  final String sourcePasalId;
  final String targetPasalId;
  final String? keterangan;
  final bool isActive;
  final DateTime? createdAt;

  PasalLinkModel({
    required this.id,
    required this.sourcePasalId,
    required this.targetPasalId,
    this.keterangan,
    this.isActive = true,
    this.createdAt,
  });

  factory PasalLinkModel.fromJson(Map<String, dynamic> json) {
    return PasalLinkModel(
      id: json['id'] ?? '',
      sourcePasalId: json['source_pasal_id'] ?? '',
      targetPasalId: json['target_pasal_id'] ?? '',
      keterangan: json['keterangan'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_pasal_id': sourcePasalId,
      'target_pasal_id': targetPasalId,
      'keterangan': keterangan,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Helper class that combines a target pasal with its link keterangan
/// Used for displaying related pasal with context
class PasalLinkWithTarget {
  final PasalModel targetPasal;
  final String? keterangan;

  PasalLinkWithTarget({required this.targetPasal, this.keterangan});
}
