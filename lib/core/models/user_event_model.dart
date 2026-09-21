import 'package:equatable/equatable.dart';

class UserEventModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime eventDate;
  final String? venue;
  final String? imageUrl;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String createdById;
  final String? createdByName;
  final String? createdByProfilePic;
  final DateTime createdAt;

  const UserEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    this.venue,
    this.imageUrl,
    this.block,
    this.floor,
    this.roomNumber,
    required this.createdById,
    this.createdByName,
    this.createdByProfilePic,
    required this.createdAt,
  });

  factory UserEventModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    String? name;
    String? profilePic;
    String createdById = '';
    if (createdBy != null && createdBy is Map) {
      name = createdBy['name'] as String?;
      profilePic = createdBy['profilePic'] as String?;
      createdById = createdBy['_id']?.toString() ?? createdBy['id']?.toString() ?? '';
    }
    return UserEventModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventDate: json['eventDate'] != null
          ? DateTime.parse(json['eventDate'] as String).toLocal()
          : DateTime.now(),
      venue: json['venue'] as String?,
      imageUrl: json['imageUrl'] as String?,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
      createdById: createdById,
      createdByName: name,
      createdByProfilePic: profilePic,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        eventDate,
        venue,
        imageUrl,
        block,
        floor,
        roomNumber,
        createdById,
        createdByName,
        createdAt,
      ];
}
