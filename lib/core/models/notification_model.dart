class NotificationModel {
  final String id;
  final String userId;
  final String userType;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final String? apartmentId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.userType,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.read,
    this.apartmentId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userType: json['userType']?.toString() ?? 'user',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      read: json['read'] == true,
      apartmentId: json['apartmentId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userType': userType,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'read': read,
      'apartmentId': apartmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? userType,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? read,
    String? apartmentId,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      read: read ?? this.read,
      apartmentId: apartmentId ?? this.apartmentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
