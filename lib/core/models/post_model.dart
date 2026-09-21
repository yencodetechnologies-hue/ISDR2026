import 'package:equatable/equatable.dart';

class PostModel extends Equatable {
  final String id;
  final String description;
  final String? imageUrl;
  final String? link;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String createdById;
  final String? createdByName;
  final String? createdByProfilePic;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.description,
    this.imageUrl,
    this.link,
    this.block,
    this.floor,
    this.roomNumber,
    required this.createdById,
    this.createdByName,
    this.createdByProfilePic,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    String? name;
    String? profilePic;
    String createdById = '';
    if (createdBy != null) {
      if (createdBy is Map) {
        name = createdBy['name'] as String?;
        profilePic = createdBy['profilePic'] as String?;
        createdById = createdBy['_id']?.toString() ?? createdBy['id']?.toString() ?? '';
      }
    }
    return PostModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      link: json['link'] as String?,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
      createdById: createdById,
      createdByName: name,
      createdByProfilePic: profilePic,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        imageUrl,
        link,
        block,
        floor,
        roomNumber,
        createdById,
        createdByName,
        createdAt,
      ];
}
