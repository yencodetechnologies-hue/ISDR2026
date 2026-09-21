import 'package:equatable/equatable.dart';

enum LeaveRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
  expired,
}

class LeaveRequestModel extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final String? userProfilePic;
  final String apartmentId;
  final DateTime outAt;
  final DateTime expectedInAt;
  final String reason;
  final String parentName;
  final String parentMobile;
  final String hostelRoom;
  final String hostelBed;
  final LeaveRequestStatus status;
  final String rejectionReason;
  final DateTime? approvedAt;
  final DateTime? gatePassExpiresAt;
  final bool hasGatePass;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LeaveRequestModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userProfilePic,
    required this.apartmentId,
    required this.outAt,
    required this.expectedInAt,
    required this.reason,
    required this.parentName,
    required this.parentMobile,
    this.hostelRoom = '',
    this.hostelBed = '',
    required this.status,
    this.rejectionReason = '',
    this.approvedAt,
    this.gatePassExpiresAt,
    this.hasGatePass = false,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActiveGatePass =>
      hasGatePass &&
      status == LeaveRequestStatus.approved &&
      (gatePassExpiresAt == null || gatePassExpiresAt!.isAfter(DateTime.now()));

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] as String?,
      userProfilePic: json['userProfilePic'] as String?,
      apartmentId: json['apartmentId']?.toString() ?? '',
      outAt: DateTime.parse(json['outAt'].toString()),
      expectedInAt: DateTime.parse(json['expectedInAt'].toString()),
      reason: json['reason'] as String? ?? '',
      parentName: json['parentName'] as String? ?? '',
      parentMobile: json['parentMobile'] as String? ?? '',
      hostelRoom: json['hostelRoom'] as String? ?? '',
      hostelBed: json['hostelBed'] as String? ?? '',
      status: LeaveRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      rejectionReason: json['rejectionReason'] as String? ?? '',
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      gatePassExpiresAt: json['gatePassExpiresAt'] != null
          ? DateTime.tryParse(json['gatePassExpiresAt'].toString())
          : null,
      hasGatePass: json['hasGatePass'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        status,
        outAt,
        expectedInAt,
      ];
}

class HostelIdPayload extends Equatable {
  final String userId;
  final String otp;
  final String qrData;
  final String hostelName;
  final String hostelRoom;
  final String hostelBed;
  final DateTime validTill;
  final String name;
  final String? profilePic;

  const HostelIdPayload({
    required this.userId,
    required this.otp,
    required this.qrData,
    required this.hostelName,
    required this.hostelRoom,
    required this.hostelBed,
    required this.validTill,
    required this.name,
    this.profilePic,
  });

  factory HostelIdPayload.fromJson(Map<String, dynamic> json) {
    return HostelIdPayload(
      userId: json['userId']?.toString() ?? '',
      otp: json['otp']?.toString() ?? '',
      qrData: json['qrData']?.toString() ?? '',
      hostelName: json['hostelName'] as String? ?? '',
      hostelRoom: json['hostelRoom'] as String? ?? '',
      hostelBed: json['hostelBed'] as String? ?? '',
      validTill: DateTime.parse(json['validTill'].toString()),
      name: json['name'] as String? ?? '',
      profilePic: json['profilePic'] as String?,
    );
  }

  @override
  List<Object?> get props => [userId, otp, qrData];
}

class LeaveGatePassPayload extends Equatable {
  final LeaveRequestModel leaveRequest;
  final String qrData;
  final String hostelName;
  final DateTime? validTill;

  const LeaveGatePassPayload({
    required this.leaveRequest,
    required this.qrData,
    required this.hostelName,
    this.validTill,
  });

  factory LeaveGatePassPayload.fromJson(Map<String, dynamic> json) {
    final gp = json['gatePass'] as Map<String, dynamic>? ?? json;
    return LeaveGatePassPayload(
      leaveRequest: LeaveRequestModel.fromJson(
        Map<String, dynamic>.from(gp['leaveRequest'] as Map),
      ),
      qrData: gp['qrData']?.toString() ?? '',
      hostelName: gp['hostelName'] as String? ?? '',
      validTill: gp['validTill'] != null
          ? DateTime.tryParse(gp['validTill'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [leaveRequest.id, qrData];
}
