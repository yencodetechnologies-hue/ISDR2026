import 'package:equatable/equatable.dart';

class TenantConversationModel extends Equatable {
  final String id;
  final String userId;
  final String tenantId;
  final String userName;
  final String? userProfilePic;
  final String tenantName;
  final String? tenantProfilePic;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastMessageSenderType;
  final int unreadCountUser;
  final int unreadCountTenant;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantConversationModel({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.userName,
    this.userProfilePic,
    required this.tenantName,
    this.tenantProfilePic,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastMessageSenderType,
    required this.unreadCountUser,
    required this.unreadCountTenant,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TenantConversationModel.fromJson(Map<String, dynamic> json) {
    return TenantConversationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Owner',
      userProfilePic: json['userProfilePic']?.toString(),
      tenantName: json['tenantName']?.toString() ?? 'Tenant',
      tenantProfilePic: json['tenantProfilePic']?.toString(),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageSenderType: json['lastMessageSenderType']?.toString(),
      unreadCountUser: json['unreadCountUser'] is int
          ? json['unreadCountUser']
          : int.tryParse(json['unreadCountUser']?.toString() ?? '0') ?? 0,
      unreadCountTenant: json['unreadCountTenant'] is int
          ? json['unreadCountTenant']
          : int.tryParse(json['unreadCountTenant']?.toString() ?? '0') ?? 0,
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
      'userId': userId,
      'tenantId': tenantId,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'tenantName': tenantName,
      'tenantProfilePic': tenantProfilePic,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessageSenderType': lastMessageSenderType,
      'unreadCountUser': unreadCountUser,
      'unreadCountTenant': unreadCountTenant,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get the display name for the other participant based on user type
  String getDisplayName(String currentUserType) {
    if (currentUserType == 'tenant') {
      return userName;
    }
    return tenantName;
  }

  /// Get the profile picture for the other participant based on user type
  String? getDisplayProfilePic(String currentUserType) {
    if (currentUserType == 'tenant') {
      return userProfilePic;
    }
    return tenantProfilePic;
  }

  /// Get unread count for current user
  int getUnreadCount(String currentUserType) {
    if (currentUserType == 'tenant') {
      return unreadCountTenant;
    }
    return unreadCountUser;
  }

  /// Get the other participant's ID based on current user type
  String getOtherParticipantId(String currentUserType) {
    if (currentUserType == 'tenant') {
      return userId;
    }
    return tenantId;
  }

  TenantConversationModel copyWith({
    String? id,
    String? userId,
    String? tenantId,
    String? userName,
    String? userProfilePic,
    String? tenantName,
    String? tenantProfilePic,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderType,
    int? unreadCountUser,
    int? unreadCountTenant,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantConversationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      tenantName: tenantName ?? this.tenantName,
      tenantProfilePic: tenantProfilePic ?? this.tenantProfilePic,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderType: lastMessageSenderType ?? this.lastMessageSenderType,
      unreadCountUser: unreadCountUser ?? this.unreadCountUser,
      unreadCountTenant: unreadCountTenant ?? this.unreadCountTenant,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        tenantId,
        userName,
        userProfilePic,
        tenantName,
        tenantProfilePic,
        lastMessage,
        lastMessageAt,
        lastMessageSenderType,
        unreadCountUser,
        unreadCountTenant,
        createdAt,
        updatedAt,
      ];
}
