import 'package:equatable/equatable.dart';

class AmenityBookingModel extends Equatable {
  final String id;
  final String amenityId;
  final String amenityName;
  final String date;
  final String slotStart;
  final String slotEnd;
  final String status;

  const AmenityBookingModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.date,
    required this.slotStart,
    required this.slotEnd,
    required this.status,
  });

  factory AmenityBookingModel.fromJson(Map<String, dynamic> json) {
    final amenity = json['amenityId'];
    final amenityName = amenity is Map
        ? (amenity['name'] as String? ?? '')
        : (json['amenityName'] as String? ?? '');
    return AmenityBookingModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      amenityId: amenity is Map
          ? (amenity['_id']?.toString() ?? amenity['id']?.toString() ?? '')
          : (json['amenityId']?.toString() ?? ''),
      amenityName: amenityName,
      date: json['date'] as String? ?? '',
      slotStart: json['slotStart'] as String? ?? '',
      slotEnd: json['slotEnd'] as String? ?? '',
      status: json['status'] as String? ?? 'booked',
    );
  }

  @override
  List<Object?> get props => [id, amenityId, amenityName, date, slotStart, slotEnd, status];
}
