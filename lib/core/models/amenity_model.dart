import 'package:equatable/equatable.dart';

class AmenityModel extends Equatable {
  final String id;
  final String name;
  final bool isEnabled;
  final int displayOrder;
  final String? openingTime;
  final String? closingTime;
  final int slotDurationMinutes;
  final int capacityPerSlot;

  const AmenityModel({
    required this.id,
    required this.name,
    this.isEnabled = true,
    this.displayOrder = 0,
    this.openingTime,
    this.closingTime,
    this.slotDurationMinutes = 60,
    this.capacityPerSlot = 1,
  });

  bool get isBookable =>
      (openingTime != null &&
          openingTime!.isNotEmpty &&
          closingTime != null &&
          closingTime!.isNotEmpty &&
          capacityPerSlot > 0);

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return AmenityModel(
      id: id,
      name: json['name'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as int?) ?? 0,
      openingTime: json['openingTime'] as String?,
      closingTime: json['closingTime'] as String?,
      slotDurationMinutes: (json['slotDurationMinutes'] as int?) ?? 60,
      capacityPerSlot: (json['capacityPerSlot'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isEnabled': isEnabled,
      'displayOrder': displayOrder,
      if (openingTime != null) 'openingTime': openingTime,
      if (closingTime != null) 'closingTime': closingTime,
      'slotDurationMinutes': slotDurationMinutes,
      'capacityPerSlot': capacityPerSlot,
    };
  }

  AmenityModel copyWith({
    String? id,
    String? name,
    bool? isEnabled,
    int? displayOrder,
    String? openingTime,
    String? closingTime,
    int? slotDurationMinutes,
    int? capacityPerSlot,
  }) {
    return AmenityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      displayOrder: displayOrder ?? this.displayOrder,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      capacityPerSlot: capacityPerSlot ?? this.capacityPerSlot,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, isEnabled, displayOrder, openingTime, closingTime, slotDurationMinutes, capacityPerSlot];
}
