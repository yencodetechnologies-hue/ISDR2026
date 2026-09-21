import 'package:equatable/equatable.dart';

enum TicketStatus {
  open,
  inProgress,
  closed;

  static TicketStatus fromString(String? value) {
    if (value == null) return TicketStatus.open;
    switch (value) {
      case 'in_progress':
        return TicketStatus.inProgress;
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }

  String get value {
    switch (this) {
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.closed:
        return 'closed';
      default:
        return 'open';
    }
  }
}

class TicketModel extends Equatable {
  final String id;
  final String userId;
  final String issueType;
  final String description;
  final TicketStatus status;
  final DateTime createdAt;
  final String? userName;
  final String? block;
  final String? floor;
  final String? roomNumber;

  const TicketModel({
    required this.id,
    required this.userId,
    required this.issueType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.userName,
    this.block,
    this.floor,
    this.roomNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'issueType': issueType,
      'description': description,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'userName': userName,
      'block': block,
      'floor': floor,
      'roomNumber': roomNumber,
    };
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return TicketModel(
      id: json['id'] as String,
      userId: json['userId']?.toString() ?? '',
      issueType: json['issueType'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: TicketStatus.fromString(json['status'] as String?),
      createdAt: createdAt is DateTime
          ? createdAt
          : DateTime.parse(createdAt.toString()),
      userName: json['userName'] as String?,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        issueType,
        description,
        status,
        createdAt,
        userName,
        block,
        floor,
        roomNumber,
      ];
}
