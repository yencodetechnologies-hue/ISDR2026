import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/apartment_model.dart';
import '../models/block_model.dart';
import '../models/user_model.dart';

String _normalize(String? value) => value?.trim().toLowerCase() ?? '';

String _stripFloorPrefix(String value) {
  return value.replaceFirst(RegExp(r'^floor\s*'), '').trim();
}

bool floorsMatch(String? floorA, String? floorB) {
  if (floorA == null || floorB == null) return false;
  final a = _normalize(floorA);
  final b = _normalize(floorB);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;

  final strippedA = _stripFloorPrefix(a);
  final strippedB = _stripFloorPrefix(b);
  if (strippedA == strippedB) return true;

  final intA = int.tryParse(strippedA);
  final intB = int.tryParse(strippedB);
  if (intA != null && intB != null) return intA == intB;

  return false;
}

bool blocksMatch(String? blockA, String blockB) {
  if (blockA == null || blockA.trim().isEmpty) return false;
  return _normalize(blockA) == _normalize(blockB);
}

String? _roomCandidates(UserModel user, bool isHostel) {
  // Admin approval always writes canonical roomNumber; prefer it over
  // free-text hostelRoom from self-registration.
  final roomNumber = user.roomNumber?.trim();
  if (roomNumber != null && roomNumber.isNotEmpty) return roomNumber;

  if (isHostel) {
    final hostelRoom = user.hostelRoom?.trim();
    if (hostelRoom != null && hostelRoom.isNotEmpty) return hostelRoom;
  }

  final linkedRoom = user.linkedOwner?.roomNumber?.trim();
  if (linkedRoom != null && linkedRoom.isNotEmpty) return linkedRoom;

  if (!isHostel) {
    final hostelRoom = user.hostelRoom?.trim();
    if (hostelRoom != null && hostelRoom.isNotEmpty) return hostelRoom;
  }
  return null;
}

bool userAssignedToRoom(UserModel user, String roomNumber, {bool isHostel = false}) {
  final target = _normalize(roomNumber);
  if (target.isEmpty) return false;

  final candidate = _roomCandidates(user, isHostel);
  if (candidate == null || candidate.isEmpty) return false;

  final normalized = _normalize(candidate);
  if (normalized == target) return true;

  final candidateInt = int.tryParse(normalized);
  final targetInt = int.tryParse(target);
  if (candidateInt != null && targetInt != null && candidateInt == targetInt) {
    return true;
  }
  return false;
}

/// Approved user with block, floor, and room set (Users tab "Assigned").
bool isUserAssigned(UserModel user) {
  return user.status == AccountStatus.approved &&
      user.block != null &&
      user.block!.trim().isNotEmpty &&
      user.floor != null &&
      user.floor!.trim().isNotEmpty &&
      user.roomNumber != null &&
      user.roomNumber!.trim().isNotEmpty;
}

List<UserModel> occupantsForRoom({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
  required RoomModel room,
  bool isHostel = false,
  String? excludeUserId,
}) {
  return users.where((u) {
    if (excludeUserId != null && u.id == excludeUserId) return false;
    if (!isUserAssigned(u)) return false;
    if (!blocksMatch(u.block, blockName)) return false;
    if (!floorsMatch(u.floor, floorNumber)) return false;
    return userAssignedToRoom(u, room.number, isHostel: isHostel);
  }).toList();
}

List<UserModel> assignedUsersForFloor({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
}) {
  return users.where((u) {
    if (!isUserAssigned(u)) return false;
    if (!blocksMatch(u.block, blockName)) return false;
    return floorsMatch(u.floor, floorNumber);
  }).toList();
}

int assignedUserCountForFloor({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
}) {
  return assignedUsersForFloor(
    users: users,
    blockName: blockName,
    floorNumber: floorNumber,
  ).length;
}

int assignedUserCountForBlock({
  required List<UserModel> users,
  required String blockName,
}) {
  return users.where((u) {
    if (!isUserAssigned(u)) return false;
    return blocksMatch(u.block, blockName);
  }).length;
}

int occupiedRoomCountForFloor({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
  required List<RoomModel> rooms,
  bool isHostel = false,
}) {
  return rooms.where((room) {
    return occupantsForRoom(
      users: users,
      blockName: blockName,
      floorNumber: floorNumber,
      room: room,
      isHostel: isHostel,
    ).isNotEmpty;
  }).length;
}

int vacantRoomCountForFloor({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
  required List<RoomModel> rooms,
  bool isHostel = false,
}) {
  return rooms.length -
      occupiedRoomCountForFloor(
        users: users,
        blockName: blockName,
        floorNumber: floorNumber,
        rooms: rooms,
        isHostel: isHostel,
      );
}

int totalRoomCountForProperty({required List<BlockModel> blocks}) {
  return blocks.fold<int>(
    0,
    (sum, block) =>
        sum +
        block.floors.fold<int>(0, (floorSum, floor) => floorSum + floor.rooms.length),
  );
}

int vacantRoomCountForProperty({
  required List<UserModel> users,
  required List<BlockModel> blocks,
  bool isHostel = false,
}) {
  return vacantRoomsForProperty(
    users: users,
    blocks: blocks,
    isHostel: isHostel,
  ).length;
}

class VacantRoomEntry {
  final String blockName;
  final String floorNumber;
  final RoomModel room;

  const VacantRoomEntry({
    required this.blockName,
    required this.floorNumber,
    required this.room,
  });

  String get assignmentLabel => formatUnitAssignment(
        block: blockName,
        floor: floorNumber,
        roomNumber: room.number,
      );
}

int _compareFloorNumbers(String a, String b) {
  final intA = int.tryParse(_stripFloorPrefix(_normalize(a)));
  final intB = int.tryParse(_stripFloorPrefix(_normalize(b)));
  if (intA != null && intB != null) return intA.compareTo(intB);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

int _compareRoomNumbers(String a, String b) {
  final intA = int.tryParse(a);
  final intB = int.tryParse(b);
  if (intA != null && intB != null) return intA.compareTo(intB);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

List<VacantRoomEntry> vacantRoomsForProperty({
  required List<UserModel> users,
  required List<BlockModel> blocks,
  bool isHostel = false,
}) {
  final entries = <VacantRoomEntry>[];
  for (final block in blocks) {
    for (final floor in block.floors) {
      for (final room in floor.rooms) {
        if (!isRoomOccupiedByAssignment(
          users: users,
          blockName: block.name,
          floorNumber: floor.number,
          room: room,
          isHostel: isHostel,
        )) {
          entries.add(
            VacantRoomEntry(
              blockName: block.name,
              floorNumber: floor.number,
              room: room,
            ),
          );
        }
      }
    }
  }

  entries.sort((a, b) {
    final blockCmp = a.blockName.toLowerCase().compareTo(b.blockName.toLowerCase());
    if (blockCmp != 0) return blockCmp;
    final floorCmp = _compareFloorNumbers(a.floorNumber, b.floorNumber);
    if (floorCmp != 0) return floorCmp;
    return _compareRoomNumbers(a.room.number, b.room.number);
  });

  return entries;
}

bool isRoomOccupiedByAssignment({
  required List<UserModel> users,
  required String blockName,
  required String floorNumber,
  required RoomModel room,
  bool isHostel = false,
}) {
  return occupantsForRoom(
    users: users,
    blockName: blockName,
    floorNumber: floorNumber,
    room: room,
    isHostel: isHostel,
  ).isNotEmpty;
}

class AssignedRoomNode {
  final RoomModel room;
  final List<UserModel> occupants;

  const AssignedRoomNode({
    required this.room,
    required this.occupants,
  });
}

class AssignedFloorNode {
  final FloorModel floor;
  final List<AssignedRoomNode> rooms;

  const AssignedFloorNode({
    required this.floor,
    required this.rooms,
  });

  int get userCount =>
      rooms.fold<int>(0, (sum, node) => sum + node.occupants.length);
}

class AssignedBlockNode {
  final BlockModel block;
  final List<AssignedFloorNode> floors;

  const AssignedBlockNode({
    required this.block,
    required this.floors,
  });

  int get userCount =>
      floors.fold<int>(0, (sum, node) => sum + node.userCount);
}

class AssignedUsersTreeResult {
  final List<AssignedBlockNode> blocks;
  final List<UserModel> unmatchedUsers;

  const AssignedUsersTreeResult({
    required this.blocks,
    required this.unmatchedUsers,
  });

  bool get isEmpty => blocks.isEmpty && unmatchedUsers.isEmpty;
}

int _compareUserNames(UserModel a, UserModel b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

AssignedUsersTreeResult buildAssignedUsersTree({
  required List<UserModel> users,
  required List<BlockModel> blocks,
  required bool isHostel,
}) {
  final matchedIds = <String>{};
  final blockNodes = <AssignedBlockNode>[];

  for (final block in blocks) {
    final floorNodes = <AssignedFloorNode>[];
    for (final floor in block.floors) {
      final roomNodes = <AssignedRoomNode>[];
      for (final room in floor.rooms) {
        final occupants = occupantsForRoom(
          users: users,
          blockName: block.name,
          floorNumber: floor.number,
          room: room,
          isHostel: isHostel,
        );
        if (occupants.isEmpty) continue;
        occupants.sort(_compareUserNames);
        for (final user in occupants) {
          matchedIds.add(user.id);
        }
        roomNodes.add(AssignedRoomNode(room: room, occupants: occupants));
      }
      if (roomNodes.isNotEmpty) {
        floorNodes.add(AssignedFloorNode(floor: floor, rooms: roomNodes));
      }
    }
    if (floorNodes.isNotEmpty) {
      blockNodes.add(AssignedBlockNode(block: block, floors: floorNodes));
    }
  }

  final unmatchedUsers = users
      .where((user) => !matchedIds.contains(user.id))
      .toList()
    ..sort(_compareUserNames);

  return AssignedUsersTreeResult(
    blocks: blockNodes,
    unmatchedUsers: unmatchedUsers,
  );
}

String assignedFloorExpansionKey(String blockId, String floorId) =>
    'floor:$blockId:$floorId';

String assignedRoomExpansionKey(
  String blockId,
  String floorId,
  String roomId,
) =>
    'room:$blockId:$floorId:$roomId';

String assignedBlockExpansionKey(String blockId) => 'block:$blockId';

Set<String> collectAssignedExpansionKeys(AssignedUsersTreeResult tree) {
  final keys = <String>{};
  for (final blockNode in tree.blocks) {
    if (tree.blocks.length > 1) {
      keys.add(assignedBlockExpansionKey(blockNode.block.id));
    }
    for (final floorNode in blockNode.floors) {
      keys.add(
        assignedFloorExpansionKey(blockNode.block.id, floorNode.floor.id),
      );
      for (final roomNode in floorNode.rooms) {
        keys.add(
          assignedRoomExpansionKey(
            blockNode.block.id,
            floorNode.floor.id,
            roomNode.room.id,
          ),
        );
      }
    }
  }
  return keys;
}

/// Formats block, floor, and room compactly (e.g. `yd secondfloor .2b`).
String formatUnitAssignment({
  String? block,
  String? floor,
  String? roomNumber,
}) {
  final b = block?.trim() ?? '';
  final f = floor?.trim() ?? '';
  final r = roomNumber?.trim() ?? '';
  if (b.isEmpty && f.isEmpty && r.isEmpty) return '';

  final parts = <String>[];
  if (b.isNotEmpty) parts.add(b);
  if (f.isNotEmpty) parts.add(f);
  if (r.isNotEmpty) {
    parts.add(r.startsWith('.') ? r : '.$r');
  }
  return parts.join(' ');
}

String formatUserUnitAssignment(UserModel user) => formatUnitAssignment(
      block: user.block,
      floor: user.floor,
      roomNumber: user.roomNumber,
    );

/// Human-readable assignment for list views (e.g. `yd secondfloor .2b`).
String formatUserAssignmentDisplay(
  UserModel user, {
  PropertyType? propertyType,
}) {
  final formatted = formatUserUnitAssignment(user);
  return formatted.isEmpty ? 'Not assigned' : formatted;
}

String occupantDisplayLabel(UserModel user, bool isHostel) {
  final bed = user.hostelBed?.trim();
  if (isHostel && bed != null && bed.isNotEmpty) {
    return '${user.name} (Bed $bed)';
  }
  return user.name;
}

Widget buildAssignedUsersSection({
  required List<UserModel> occupants,
  required bool isHostel,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF13275D).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.people_alt_rounded,
          size: 18,
          color: Color(0xFF13275D),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Occupants',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8C8C90),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (occupants.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1D).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Vacant (No Occupants)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8C8C90),
                  ),
                ),
              )
            else
              Column(
                children: occupants.asMap().entries.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECECEA)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF13275D),
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            occupantDisplayLabel(entry.value, isHostel),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
          ],
        ),
      ),
    ],
  );
}
