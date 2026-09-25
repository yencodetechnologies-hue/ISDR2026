import 'package:equatable/equatable.dart';

enum PropertyType { events }

extension PropertyTypeExt on PropertyType {
  String get displayName {
    switch (this) {
      case PropertyType.events:
        return 'Events Admin';
    }
  }
}

class ApartmentModel extends Equatable {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final bool isActive;
  final bool securityEnabled;
  final bool assignPaymentEnabled;
  final bool complaintsEnabled;
  final bool showUserMobile;
  final bool blockCreationEnabled;
  final bool addUserEnabled;
  final bool wardenFacilityEnabled;
  final bool supportEnabled;
  final bool adsEnabled;
  final PropertyType propertyType;
  final String? hostelType;
  final String? roomType;
  final int? bedCountPerRoom;
  final String ownerName;
  final String wardenName;
  final String wardenContact;
  final String email;
  final String? institutionType;

  const ApartmentModel({
    required this.id,
    required this.name,
    this.address = '',
    this.contactPhone = '',
    this.isActive = true,
    this.securityEnabled = true,
    this.assignPaymentEnabled = true,
    this.complaintsEnabled = true,
    this.showUserMobile = true,
    this.blockCreationEnabled = true,
    this.addUserEnabled = true,
    this.wardenFacilityEnabled = false,
    this.supportEnabled = false,
    this.adsEnabled = true,
    this.propertyType = PropertyType.events,
    this.hostelType,
    this.roomType,
    this.bedCountPerRoom,
    this.ownerName = '',
    this.wardenName = '',
    this.wardenContact = '',
    this.email = '',
    this.institutionType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'contactPhone': contactPhone,
      'isActive': isActive,
      'securityEnabled': securityEnabled,
      'assignPaymentEnabled': assignPaymentEnabled,
      'complaintsEnabled': complaintsEnabled,
      'showUserMobile': showUserMobile,
      'blockCreationEnabled': blockCreationEnabled,
      'addUserEnabled': addUserEnabled,
      'wardenFacilityEnabled': wardenFacilityEnabled,
      'supportEnabled': supportEnabled,
      'adsEnabled': adsEnabled,
      'propertyType': propertyType.name,
      'hostelType': hostelType,
      'roomType': roomType,
      'bedCountPerRoom': bedCountPerRoom,
      'ownerName': ownerName,
      'wardenName': wardenName,
      'wardenContact': wardenContact,
      'email': email,
      'institutionType': institutionType,
    };
  }

  factory ApartmentModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    const pt = PropertyType.events;
    return ApartmentModel(
      id: id,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contactPhone: json['contactPhone'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      securityEnabled: json['securityEnabled'] as bool? ?? true,
      assignPaymentEnabled: json['assignPaymentEnabled'] as bool? ?? true,
      complaintsEnabled: json['complaintsEnabled'] as bool? ?? true,
      showUserMobile: json['showUserMobile'] as bool? ?? true,
      blockCreationEnabled: json['blockCreationEnabled'] as bool? ?? true,
      addUserEnabled: json['addUserEnabled'] as bool? ?? true,
      wardenFacilityEnabled: json['wardenFacilityEnabled'] as bool? ?? false,
      supportEnabled: json['supportEnabled'] as bool? ?? false,
      adsEnabled: json['adsEnabled'] as bool? ?? true,
      propertyType: pt,
      hostelType: json['hostelType'] as String?,
      roomType: json['roomType'] as String?,
      bedCountPerRoom: json['bedCountPerRoom'] as int?,
      ownerName: json['ownerName'] as String? ?? '',
      wardenName: json['wardenName'] as String? ?? '',
      wardenContact: json['wardenContact'] as String? ?? '',
      email: json['email'] as String? ?? '',
      institutionType: json['institutionType'] as String?,
    );
  }

  ApartmentModel copyWith({
    String? id,
    String? name,
    String? address,
    String? contactPhone,
    bool? isActive,
    bool? securityEnabled,
    bool? assignPaymentEnabled,
    bool? complaintsEnabled,
    bool? showUserMobile,
    bool? blockCreationEnabled,
    bool? addUserEnabled,
    bool? wardenFacilityEnabled,
    bool? supportEnabled,
    bool? adsEnabled,
    PropertyType? propertyType,
    String? hostelType,
    String? roomType,
    int? bedCountPerRoom,
    String? ownerName,
    String? wardenName,
    String? wardenContact,
    String? email,
    String? institutionType,
  }) {
    return ApartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      isActive: isActive ?? this.isActive,
      securityEnabled: securityEnabled ?? this.securityEnabled,
      assignPaymentEnabled: assignPaymentEnabled ?? this.assignPaymentEnabled,
      complaintsEnabled: complaintsEnabled ?? this.complaintsEnabled,
      showUserMobile: showUserMobile ?? this.showUserMobile,
      blockCreationEnabled: blockCreationEnabled ?? this.blockCreationEnabled,
      addUserEnabled: addUserEnabled ?? this.addUserEnabled,
      wardenFacilityEnabled: wardenFacilityEnabled ?? this.wardenFacilityEnabled,
      supportEnabled: supportEnabled ?? this.supportEnabled,
      adsEnabled: adsEnabled ?? this.adsEnabled,
      propertyType: propertyType ?? this.propertyType,
      hostelType: hostelType ?? this.hostelType,
      roomType: roomType ?? this.roomType,
      bedCountPerRoom: bedCountPerRoom ?? this.bedCountPerRoom,
      ownerName: ownerName ?? this.ownerName,
      wardenName: wardenName ?? this.wardenName,
      wardenContact: wardenContact ?? this.wardenContact,
      email: email ?? this.email,
      institutionType: institutionType ?? this.institutionType,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        contactPhone,
        isActive,
        securityEnabled,
        assignPaymentEnabled,
        complaintsEnabled,
        showUserMobile,
        blockCreationEnabled,
        addUserEnabled,
        wardenFacilityEnabled,
        supportEnabled,
        adsEnabled,
        propertyType,
        hostelType,
        roomType,
        bedCountPerRoom,
        ownerName,
        wardenName,
        wardenContact,
        email,
        institutionType,
      ];
}
