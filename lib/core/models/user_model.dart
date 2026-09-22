import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'apartment_model.dart';

enum UserType { admin, user, security, apartment, tenant, participant }

enum AccountStatus { pending, approved, rejected }

enum FamilyType { family, bachelor }

enum OccupationCategory { working, student, others }

enum Gender { male, female, other }

class LinkedOwnerModel extends Equatable {
  final String id;
  final String name;
  final String mobileNumber;
  final String? secondaryMobileNumber;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final AccountStatus status;

  const LinkedOwnerModel({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.status,
    this.secondaryMobileNumber,
    this.block,
    this.floor,
    this.roomNumber,
  });

  factory LinkedOwnerModel.fromJson(Map<String, dynamic> json) {
    return LinkedOwnerModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      secondaryMobileNumber: json['secondaryMobileNumber'] as String?,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
      status: AccountStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AccountStatus.approved,
      ),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        mobileNumber,
        secondaryMobileNumber,
        block,
        floor,
        roomNumber,
        status,
      ];
}

class UserModel extends Equatable {
  final String id;
  final String name;
  final String username;
  final String email;
  final String mobileNumber;
  final String? secondaryMobileNumber;
  final Gender? gender;
  final UserType userType;
  final AccountStatus status;
  final String? profilePic;
  final String? address;
  final String? aadhaarCard;
  final String? aadhaarCardFrontImage;
  final String? aadhaarCardBackImage;
  final String? panCard;
  final String? panCardImage;
  final String? idProof;
  final FamilyType? familyType;
  final int? totalOccupants;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String? department;
  final String? employeeId;
  final String? hostelRoom;
  final String? hostelBed;
  final OccupationCategory? occupationCategory;
  final String? occupationDetails;
  final DateTime? dateOfBirth;
  final bool isActive;
  final String? apartmentId;
  final String? apartmentName;
  final List<ApartmentModel>? apartments;
  final bool? subscriptionStatus;
  final DateTime? subscriptionEndsAt;
  final int? daysLeft;
  final bool? isNRI;
  final bool? securityEnabled;
  final bool? assignPaymentEnabled;
  final bool? complaintsEnabled;
  /// Set for apartment (management) accounts from login /auth/me.
  final PropertyType? propertyType;
  final LinkedOwnerModel? linkedOwner;
  final String? loginRole;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.mobileNumber,
    required this.userType,
    required this.status,
    this.secondaryMobileNumber,
    this.gender,
    this.profilePic,
    this.address,
    this.aadhaarCard,
    this.aadhaarCardFrontImage,
    this.aadhaarCardBackImage,
    this.panCard,
    this.panCardImage,
    this.idProof,
    this.familyType,
    this.totalOccupants,
    this.block,
    this.floor,
    this.roomNumber,
    this.department,
    this.employeeId,
    this.hostelRoom,
    this.hostelBed,
    this.occupationCategory,
    this.occupationDetails,
    this.dateOfBirth,
    this.isActive = true,
    this.apartmentId,
    this.apartmentName,
    this.apartments,
    this.subscriptionStatus,
    this.subscriptionEndsAt,
    this.daysLeft,
    this.isNRI,
    this.securityEnabled,
    this.assignPaymentEnabled,
    this.complaintsEnabled,
    this.propertyType,
    this.linkedOwner,
    this.loginRole,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? mobileNumber,
    String? secondaryMobileNumber,
    Gender? gender,
    UserType? userType,
    AccountStatus? status,
    String? profilePic,
    String? address,
    String? aadhaarCard,
    String? aadhaarCardFrontImage,
    String? aadhaarCardBackImage,
    String? panCard,
    String? panCardImage,
    String? idProof,
    FamilyType? familyType,
    int? totalOccupants,
    String? block,
    String? floor,
    String? roomNumber,
    String? department,
    String? employeeId,
    String? hostelRoom,
    String? hostelBed,
    OccupationCategory? occupationCategory,
    String? occupationDetails,
    DateTime? dateOfBirth,
    bool? isActive,
    String? apartmentId,
    List<ApartmentModel>? apartments,
    bool? subscriptionStatus,
    DateTime? subscriptionEndsAt,
    int? daysLeft,
    bool? isNRI,
    bool? securityEnabled,
    bool? assignPaymentEnabled,
    bool? complaintsEnabled,
    PropertyType? propertyType,
    LinkedOwnerModel? linkedOwner,
    String? loginRole,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      secondaryMobileNumber:
          secondaryMobileNumber ?? this.secondaryMobileNumber,
      gender: gender ?? this.gender,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      profilePic: profilePic ?? this.profilePic,
      address: address ?? this.address,
      aadhaarCard: aadhaarCard ?? this.aadhaarCard,
      aadhaarCardFrontImage:
          aadhaarCardFrontImage ?? this.aadhaarCardFrontImage,
      aadhaarCardBackImage: aadhaarCardBackImage ?? this.aadhaarCardBackImage,
      panCard: panCard ?? this.panCard,
      panCardImage: panCardImage ?? this.panCardImage,
      idProof: idProof ?? this.idProof,
      familyType: familyType ?? this.familyType,
      totalOccupants: totalOccupants ?? this.totalOccupants,
      block: block ?? this.block,
      floor: floor ?? this.floor,
      roomNumber: roomNumber ?? this.roomNumber,
      department: department ?? this.department,
      employeeId: employeeId ?? this.employeeId,
      hostelRoom: hostelRoom ?? this.hostelRoom,
      hostelBed: hostelBed ?? this.hostelBed,
      occupationCategory: occupationCategory ?? this.occupationCategory,
      occupationDetails: occupationDetails ?? this.occupationDetails,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isActive: isActive ?? this.isActive,
      apartmentId: apartmentId ?? this.apartmentId,
      apartments: apartments ?? this.apartments,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
      daysLeft: daysLeft ?? this.daysLeft,
      isNRI: isNRI ?? this.isNRI,
      securityEnabled: securityEnabled ?? this.securityEnabled,
      assignPaymentEnabled: assignPaymentEnabled ?? this.assignPaymentEnabled,
      complaintsEnabled: complaintsEnabled ?? this.complaintsEnabled,
      propertyType: propertyType ?? this.propertyType,
      linkedOwner: linkedOwner ?? this.linkedOwner,
      loginRole: loginRole ?? this.loginRole,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'mobileNumber': mobileNumber,
      'secondaryMobileNumber': secondaryMobileNumber,
      'gender': gender?.name,
      'userType': userType.name,
      'status': status.name,
      'profilePic': profilePic,
      'address': address,
      'aadhaarCard': aadhaarCard,
      'aadhaarCardFrontImage': aadhaarCardFrontImage,
      'aadhaarCardBackImage': aadhaarCardBackImage,
      'panCard': panCard,
      'panCardImage': panCardImage,
      'idProof': idProof,
      'familyType': familyType?.name,
      'totalOccupants': totalOccupants,
      'block': block,
      'floor': floor,
      'roomNumber': roomNumber,
      'department': department,
      'employeeId': employeeId,
      'hostelRoom': hostelRoom,
      'hostelBed': hostelBed,
      'occupationCategory': occupationCategory?.name,
      'occupationDetails': occupationDetails,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String().split('T')[0],
      'isActive': isActive,
      if (apartmentId != null) 'apartmentId': apartmentId,
      if (apartments != null) 'apartments': apartments!.map((a) => {'id': a.id, 'name': a.name}).toList(),
      if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus,
      if (subscriptionEndsAt != null) 'subscriptionEndsAt': subscriptionEndsAt?.toIso8601String(),
      if (daysLeft != null) 'daysLeft': daysLeft,
      if (isNRI != null) 'isNRI': isNRI,
      if (securityEnabled != null) 'securityEnabled': securityEnabled,
      if (assignPaymentEnabled != null) 'assignPaymentEnabled': assignPaymentEnabled,
      if (complaintsEnabled != null) 'complaintsEnabled': complaintsEnabled,
      if (propertyType != null) 'propertyType': propertyType!.name,
      if (loginRole != null) 'loginRole': loginRole,
      if (linkedOwner != null)
        'linkedOwner': {
          'id': linkedOwner!.id,
          'name': linkedOwner!.name,
          'mobileNumber': linkedOwner!.mobileNumber,
          if (linkedOwner!.secondaryMobileNumber != null)
            'secondaryMobileNumber': linkedOwner!.secondaryMobileNumber,
          if (linkedOwner!.block != null) 'block': linkedOwner!.block,
          if (linkedOwner!.floor != null) 'floor': linkedOwner!.floor,
          if (linkedOwner!.roomNumber != null) 'roomNumber': linkedOwner!.roomNumber,
          'status': linkedOwner!.status.name,
        },
    };
  }

  static List<ApartmentModel>? _parseApartments(dynamic value) {
    if (value == null || value is! List) return null;
    final list = <ApartmentModel>[];
    for (final e in value) {
      if (e is Map<String, dynamic>) {
        list.add(ApartmentModel.fromJson(e));
      } else if (e is Map) {
        list.add(ApartmentModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return list.isEmpty ? null : list;
  }

  static PropertyType? _parsePropertyType(dynamic value) {
    if (value == null) return null;
    final s = value.toString().toLowerCase();
    if (s == 'events') return PropertyType.events;
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return UserModel(
      id: id,
      name: json['name'] as String,
      username: json['username'] as String? ?? json['name'] as String,
      email: json['email'] as String,
      mobileNumber: json['mobileNumber'] as String,
      secondaryMobileNumber: json['secondaryMobileNumber'] as String?,
      gender: json['gender'] != null
          ? Gender.values.firstWhere(
              (e) => e.name == json['gender'],
              orElse: () => Gender.male,
            )
          : null,
      userType: () {
        final userTypeStr = json['userType']?.toString().toLowerCase().trim();
        debugPrint('=== PARSING USERTYPE ===');
        debugPrint('Raw userType from JSON: ${json['userType']}');
        debugPrint('Normalized userType: "$userTypeStr"');
        debugPrint(
            'Available UserType values: ${UserType.values.map((e) => e.name).toList()}');

        if (userTypeStr == null || userTypeStr.isEmpty) {
          debugPrint(
              'WARNING: userType is null or empty, defaulting to UserType.user');
          return UserType.user;
        }

        try {
          final parsed = UserType.values.firstWhere(
            (e) => e.name.toLowerCase() == userTypeStr,
            orElse: () {
              debugPrint(
                  'WARNING: userType "$userTypeStr" not found in enum, defaulting to UserType.user');
              debugPrint(
                  'Trying to match: "$userTypeStr" against: ${UserType.values.map((e) => e.name).toList()}');
              return UserType.user;
            },
          );
          debugPrint('✓ Successfully parsed UserType: $parsed (${parsed.name})');
          return parsed;
        } catch (e) {
          debugPrint('ERROR parsing userType: $e');
          return UserType.user;
        }
      }(),
      status: AccountStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AccountStatus.approved,
      ),
      profilePic: json['profilePic'] as String?,
      address: json['address'] as String?,
      aadhaarCard: json['aadhaarCard'] as String?,
      aadhaarCardFrontImage: json['aadhaarCardFrontImage'] as String?,
      aadhaarCardBackImage: json['aadhaarCardBackImage'] as String?,
      panCard: json['panCard'] as String?,
      panCardImage: json['panCardImage'] as String?,
      idProof: json['idProof'] as String?,
      familyType: json['familyType'] != null
          ? FamilyType.values.firstWhere(
              (e) => e.name == json['familyType'],
              orElse: () => FamilyType.family,
            )
          : null,
      totalOccupants: json['totalOccupants'] as int?,
      block: json['block']?.toString(),
      floor: json['floor']?.toString(),
      roomNumber: json['roomNumber']?.toString(),
      department: json['department']?.toString(),
      employeeId: json['employeeId']?.toString(),
      hostelRoom: json['hostelRoom']?.toString(),
      hostelBed: json['hostelBed']?.toString(),
      occupationCategory: json['occupationCategory'] != null
          ? OccupationCategory.values.firstWhere(
              (e) => e.name == json['occupationCategory'],
              orElse: () => OccupationCategory.others,
            )
          : null,
      occupationDetails: json['occupationDetails'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      isActive: json['isActive'] as bool? ?? true,
      apartmentId: json['apartmentId']?.toString(),
      apartmentName: json['apartmentName'] as String?,
      apartments: _parseApartments(json['apartments']),
      subscriptionStatus: json['subscriptionStatus'] as bool?,
      subscriptionEndsAt: json['subscriptionEndsAt'] != null
          ? DateTime.tryParse(json['subscriptionEndsAt'].toString())
          : null,
      daysLeft: json['daysLeft'] is int
          ? json['daysLeft'] as int
          : (json['daysLeft'] as num?)?.toInt(),
      isNRI: json['isNRI'] as bool?,
      securityEnabled: json['securityEnabled'] as bool?,
      assignPaymentEnabled: json['assignPaymentEnabled'] as bool?,
      complaintsEnabled: json['complaintsEnabled'] as bool?,
      propertyType: _parsePropertyType(json['propertyType']),
      loginRole: json['loginRole'] as String?,
      linkedOwner: json['linkedOwner'] != null
          ? LinkedOwnerModel.fromJson(
              Map<String, dynamic>.from(json['linkedOwner'] as Map),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        email,
        mobileNumber,
        secondaryMobileNumber,
        gender,
        userType,
        status,
        profilePic,
        address,
        aadhaarCard,
        aadhaarCardFrontImage,
        aadhaarCardBackImage,
        panCard,
        panCardImage,
        idProof,
        familyType,
        totalOccupants,
        block,
        floor,
        roomNumber,
        hostelRoom,
        hostelBed,
        occupationCategory,
        occupationDetails,
        dateOfBirth,
        isActive,
        apartmentId,
        apartments,
        subscriptionStatus,
        subscriptionEndsAt,
        daysLeft,
        isNRI,
        securityEnabled,
        assignPaymentEnabled,
        complaintsEnabled,
        propertyType,
        linkedOwner,
        loginRole,
      ];

  bool get isStaff =>
      loginRole == 'staff' ||
      (employeeId != null && employeeId!.isNotEmpty) ||
      (department != null && department!.isNotEmpty);
}
