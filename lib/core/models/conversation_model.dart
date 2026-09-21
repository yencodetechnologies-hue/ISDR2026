import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  final String id;
  final String securityId;
  final String userId;
  final String securityName;
  final String? securityProfilePic;
  final String? securityMobile;
  final String userName;
  final String? userProfilePic;
  final String? userBlock;
  final String? userFloor;
  final String? userRoomNumber;
  final String? userMobile;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastMessageSenderType;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.securityId,
    required this.userId,
    required this.securityName,
    this.securityProfilePic,
    this.securityMobile,
    required this.userName,
    this.userProfilePic,
    this.userBlock,
    this.userFloor,
    this.userRoomNumber,
    this.userMobile,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastMessageSenderType,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      securityId: json['securityId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      securityName: json['securityName']?.toString() ?? 'Security Guard',
      securityProfilePic: json['securityProfilePic']?.toString(),
      securityMobile: json['securityMobile']?.toString(),
      userName: json['userName']?.toString() ?? 'Tenant',
      userProfilePic: json['userProfilePic']?.toString(),
      userBlock: json['userBlock']?.toString(),
      userFloor: json['userFloor']?.toString(),
      userRoomNumber: json['userRoomNumber']?.toString(),
      userMobile: json['userMobile']?.toString(),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageSenderType: json['lastMessageSenderType']?.toString(),
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount']
          : int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
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
      'securityId': securityId,
      'userId': userId,
      'securityName': securityName,
      'securityProfilePic': securityProfilePic,
      'securityMobile': securityMobile,
      'userName': userName,
      'userProfilePic': userProfilePic,
      'userBlock': userBlock,
      'userFloor': userFloor,
      'userRoomNumber': userRoomNumber,
      'userMobile': userMobile,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessageSenderType': lastMessageSenderType,
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get the display name for the other participant based on user type
  String getDisplayName(String currentUserType) {
    if (currentUserType == 'security') {
      return userName;
    }
    return securityName;
  }

  /// Get the profile picture for the other participant based on user type
  String? getDisplayProfilePic(String currentUserType) {
    if (currentUserType == 'security') {
      return userProfilePic;
    }
    return securityProfilePic;
  }

  /// Get the subtitle (block/room for tenant, or empty for security)
  String? getDisplaySubtitle(String currentUserType) {
    if (currentUserType == 'security' && userBlock != null && userRoomNumber != null) {
      return '$userBlock - $userRoomNumber';
    }
    return null;
  }

  /// Get the other participant's ID based on current user type
  String getOtherParticipantId(String currentUserType) {
    if (currentUserType == 'security') {
      return userId;
    }
    return securityId;
  }

  ConversationModel copyWith({
    String? id,
    String? securityId,
    String? userId,
    String? securityName,
    String? securityProfilePic,
    String? securityMobile,
    String? userName,
    String? userProfilePic,
    String? userBlock,
    String? userFloor,
    String? userRoomNumber,
    String? userMobile,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderType,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      securityId: securityId ?? this.securityId,
      userId: userId ?? this.userId,
      securityName: securityName ?? this.securityName,
      securityProfilePic: securityProfilePic ?? this.securityProfilePic,
      securityMobile: securityMobile ?? this.securityMobile,
      userName: userName ?? this.userName,
      userProfilePic: userProfilePic ?? this.userProfilePic,
      userBlock: userBlock ?? this.userBlock,
      userFloor: userFloor ?? this.userFloor,
      userRoomNumber: userRoomNumber ?? this.userRoomNumber,
      userMobile: userMobile ?? this.userMobile,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderType: lastMessageSenderType ?? this.lastMessageSenderType,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        securityId,
        userId,
        securityName,
        securityProfilePic,
        securityMobile,
        userName,
        userProfilePic,
        userBlock,
        userFloor,
        userRoomNumber,
        userMobile,
        lastMessage,
        lastMessageAt,
        lastMessageSenderType,
        unreadCount,
        createdAt,
        updatedAt,
      ];
}

/// Model for a participant (security or tenant) when starting a new conversation
class ChatParticipant extends Equatable {
  final String id;
  final String name;
  final String? profilePic;
  final String? mobileNumber;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String userType;

  const ChatParticipant({
    required this.id,
    required this.name,
    this.profilePic,
    this.mobileNumber,
    this.block,
    this.floor,
    this.roomNumber,
    required this.userType,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json, {String userType = 'user'}) {
    return ChatParticipant(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      profilePic: json['profilePic']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      block: json['block']?.toString(),
      floor: json['floor']?.toString(),
      roomNumber: json['roomNumber']?.toString(),
      userType: userType,
    );
  }

  /// Get subtitle for display (block/room for tenant)
  String? get displaySubtitle {
    if (block != null && roomNumber != null) {
      return '$block - $roomNumber';
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        profilePic,
        mobileNumber,
        block,
        floor,
        roomNumber,
        userType,
      ];
}
