import 'package:equatable/equatable.dart';

class AmenitySlotModel extends Equatable {
  final String slotStart;
  final String slotEnd;
  final int available;
  final int bookedCount;

  const AmenitySlotModel({
    required this.slotStart,
    required this.slotEnd,
    required this.available,
    required this.bookedCount,
  });

  factory AmenitySlotModel.fromJson(Map<String, dynamic> json) {
    return AmenitySlotModel(
      slotStart: json['slotStart'] as String? ?? '',
      slotEnd: json['slotEnd'] as String? ?? '',
      available: (json['available'] as int?) ?? 0,
      bookedCount: (json['bookedCount'] as int?) ?? 0,
    );
  }

  @override
  List<Object?> get props => [slotStart, slotEnd, available, bookedCount];
}
