import 'package:equatable/equatable.dart';

enum ComplaintType {
  plumbing,
  electrical,
  cleaning,
  maintenance,
  security,
  other,
}

enum ComplaintStatus {
  pending,
  approved,
  completed,
  cancelled,
}

class ComplaintModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final ComplaintType type;
  final String description;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? assignedTo;
  final String? remarks;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final DateTime? preferredRepairDateTime;
  final bool isUrgent;

  const ComplaintModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.assignedTo,
    this.remarks,
    this.block,
    this.floor,
    this.roomNumber,
    this.preferredRepairDateTime,
    this.isUrgent = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'description': description,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'assignedTo': assignedTo,
      'remarks': remarks,
      'block': block,
      'floor': floor,
      'roomNumber': roomNumber,
      'preferredRepairDateTime': preferredRepairDateTime?.toIso8601String(),
      'isUrgent': isUrgent,
    };
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String,
      userId: (json['userId'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      type: ComplaintType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ComplaintType.other,
      ),
      description: json['description'] as String,
      status: ComplaintStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ComplaintStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String).toLocal()
          : null,
      assignedTo: json['assignedTo'] as String?,
      remarks: json['remarks'] as String?,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
      preferredRepairDateTime: json['preferredRepairDateTime'] != null
          ? DateTime.parse(json['preferredRepairDateTime'] as String).toLocal()
          : null,
      isUrgent: json['isUrgent'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        type,
        description,
        status,
        createdAt,
        updatedAt,
        assignedTo,
        remarks,
        block,
        floor,
        roomNumber,
        preferredRepairDateTime,
        isUrgent,
      ];
}

