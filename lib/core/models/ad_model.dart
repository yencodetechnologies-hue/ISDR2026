import 'package:equatable/equatable.dart';

class AdModel extends Equatable {
  final String id;
  final String imageUrl;
  final int displayOrder;
  final bool isActive;
  final String? apartmentId;
  final DateTime? createdAt;

  const AdModel({
    required this.id,
    required this.imageUrl,
    this.displayOrder = 0,
    this.isActive = true,
    this.apartmentId,
    this.createdAt,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return AdModel(
      id: id,
      imageUrl: json['image'] as String,
      displayOrder: (json['displayOrder'] as int?) ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      apartmentId: json['apartmentId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': imageUrl,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'apartmentId': apartmentId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, imageUrl, displayOrder, isActive, apartmentId, createdAt];
}
