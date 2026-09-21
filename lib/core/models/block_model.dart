import 'package:equatable/equatable.dart';

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

class BlockModel extends Equatable {
  final String id;
  final String name;
  final String? apartmentId;
  final List<FloorModel> floors;
  final bool isActive;

  const BlockModel({
    required this.id,
    required this.name,
    this.apartmentId,
    required this.floors,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (apartmentId != null) 'apartmentId': apartmentId,
      'floors': floors.map((f) => f.toJson()).toList(),
      'isActive': isActive,
    };
  }

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final floorsRaw = json['floors'];
    final floorsList = floorsRaw is List
        ? floorsRaw
            .where((f) => f is Map)
            .map((f) => FloorModel.fromJson(_jsonMap(f)))
            .toList()
        : <FloorModel>[];
    return BlockModel(
      id: id,
      name: name,
      apartmentId: json['apartmentId']?.toString(),
      floors: floorsList,
      isActive: json['isActive'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, apartmentId, floors, isActive];
}

class FloorModel extends Equatable {
  final String id;
  final String number;
  final List<RoomModel> rooms;

  const FloorModel({
    required this.id,
    required this.number,
    required this.rooms,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'rooms': rooms.map((r) => r.toJson()).toList(),
    };
  }

  factory FloorModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final number = json['number']?.toString() ?? '';
    final roomsRaw = json['rooms'];
    final roomsList = roomsRaw is List
        ? roomsRaw
            .where((r) => r is Map)
            .map((r) => RoomModel.fromJson(_jsonMap(r)))
            .toList()
        : <RoomModel>[];
    return FloorModel(
      id: id,
      number: number,
      rooms: roomsList,
    );
  }

  @override
  List<Object?> get props => [id, number, rooms];
}

class RoomModel extends Equatable {
  final String id;
  final String number;
  final String type;
  final int? beds;
  final bool isOccupied;

  const RoomModel({
    required this.id,
    required this.number,
    required this.type,
    this.beds,
    this.isOccupied = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'type': type,
      if (beds != null) 'beds': beds,
      'occupied': isOccupied,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final number = json['number']?.toString() ?? '';
    final type = json['type']?.toString() ?? '1BHK';
    final beds = json['beds'] != null ? (json['beds'] is int ? json['beds'] as int : int.tryParse(json['beds'].toString())) : null;
    return RoomModel(
      id: id,
      number: number,
      type: type,
      beds: beds,
      isOccupied: json['occupied'] == true,
    );
  }

  RoomModel copyWith({
    String? id,
    String? number,
    String? type,
    int? beds,
    bool? isOccupied,
  }) {
    return RoomModel(
      id: id ?? this.id,
      number: number ?? this.number,
      type: type ?? this.type,
      beds: beds ?? this.beds,
      isOccupied: isOccupied ?? this.isOccupied,
    );
  }

  @override
  List<Object?> get props => [id, number, type, beds, isOccupied];
}

