import 'package:equatable/equatable.dart';

class PropertyDocumentRequirementModel extends Equatable {
  final String id;
  final String name;
  final String documentType;
  final String? apartmentId;
  final DateTime? createdAt;

  const PropertyDocumentRequirementModel({
    required this.id,
    required this.name,
    required this.documentType,
    this.apartmentId,
    this.createdAt,
  });

  bool get isPdf => documentType == 'pdf';
  bool get isImage => documentType == 'image';

  factory PropertyDocumentRequirementModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return PropertyDocumentRequirementModel(
      id: id,
      name: json['name'] as String? ?? '',
      documentType: json['documentType'] as String? ?? 'image',
      apartmentId: json['apartmentId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, documentType, apartmentId, createdAt];
}
