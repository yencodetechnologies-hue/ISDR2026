import 'package:equatable/equatable.dart';

class GuardMessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderType;
  final String? senderName;
  final String recipientId;
  final String recipientType;
  final String message;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const GuardMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    this.senderName,
    required this.recipientId,
    required this.recipientType,
    required this.message,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory GuardMessageModel.fromJson(Map<String, dynamic> json) {
    return GuardMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderType: json['senderType']?.toString() ?? 'user',
      senderName: json['senderName']?.toString(),
      recipientId: json['recipientId']?.toString() ?? '',
      recipientType: json['recipientType']?.toString() ?? 'user',
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'recipientId': recipientId,
      'recipientType': recipientType,
      'message': message,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  GuardMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderType,
    String? senderName,
    String? recipientId,
    String? recipientType,
    String? message,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return GuardMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      recipientType: recipientType ?? this.recipientType,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        senderType,
        senderName,
        recipientId,
        recipientType,
        message,
        isRead,
        readAt,
        createdAt,
      ];
}
