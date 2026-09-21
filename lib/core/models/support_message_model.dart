import 'package:equatable/equatable.dart';

class SupportMessageModel extends Equatable {
  final String id;
  final String senderType; // 'user' | 'admin'
  final String? message;
  final String? imageUrl;
  final DateTime createdAt;

  const SupportMessageModel({
    required this.id,
    required this.senderType,
    this.message,
    this.imageUrl,
    required this.createdAt,
  });

  bool get isUser => senderType == 'user';
  bool get isAdmin => senderType == 'admin';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderType': senderType,
      'message': message,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return SupportMessageModel(
      id: json['id'] as String,
      senderType: json['senderType'] as String? ?? 'user',
      message: json['message'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: createdAt is DateTime
          ? createdAt
          : DateTime.parse(createdAt.toString()),
    );
  }

  @override
  List<Object?> get props => [id, senderType, message, imageUrl, createdAt];
}
