import 'package:equatable/equatable.dart';

class TenantMessageModel extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderType;
  final String? senderName;
  final String recipientId;
  final String recipientType;
  final String? message;
  final List<String> attachments;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    this.senderName,
    required this.recipientId,
    required this.recipientType,
    this.message,
    required this.attachments,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantMessageModel.fromJson(Map<String, dynamic> json) {
    List<String> attachmentsList = [];
    if (json['attachments'] != null) {
      if (json['attachments'] is List) {
        attachmentsList = (json['attachments'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    return TenantMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderType: json['senderType']?.toString() ?? 'user',
      senderName: json['senderName']?.toString(),
      recipientId: json['recipientId']?.toString() ?? '',
      recipientType: json['recipientType']?.toString() ?? 'tenant',
      message: json['message']?.toString(),
      attachments: attachmentsList,
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
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
      'attachments': attachments,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TenantMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderType,
    String? senderName,
    String? recipientId,
    String? recipientType,
    String? message,
    List<String>? attachments,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      recipientType: recipientType ?? this.recipientType,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasMessage => message != null && message!.isNotEmpty;

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
        attachments,
        isRead,
        readAt,
        createdAt,
        updatedAt,
      ];
}
