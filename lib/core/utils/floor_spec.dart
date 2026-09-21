import '../models/block_model.dart';

/// Parses a floor specification string into individual floor labels.
///
/// Supports comma- or space-separated values, e.g.
/// `UF,GF,2,2,3,4,56,78,9`.
List<String> parseFloorSpec(String input) {
  return input
      .split(RegExp(r'[,\s]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(_normalizeFloorLabel)
      .toList();
}

String _normalizeFloorLabel(String label) {
  final trimmed = label.trim();
  if (RegExp(r'^[A-Za-z]+$').hasMatch(trimmed)) {
    return trimmed.toUpperCase();
  }
  return trimmed;
}

/// Returns an error message when [input] is not exactly one floor label.
String? validateSingleFloorLabel(String input) {
  final floors = parseFloorSpec(input);
  if (floors.isEmpty) {
    return 'Please enter a floor number';
  }
  if (floors.length > 1) {
    return 'Enter one floor label at a time';
  }
  return null;
}

/// Returns the normalized floor label when [input] is valid.
String? singleFloorLabelFromInput(String input) {
  final floors = parseFloorSpec(input);
  if (floors.length != 1) return null;
  return floors.first;
}

/// Returns an error message when [input] is invalid, otherwise `null`.
String? validateFloorSpec(String input) {
  final floors = parseFloorSpec(input);
  if (floors.isEmpty) {
    return 'Please enter at least one floor';
  }
  return null;
}

String formatFloorSpec(Iterable<String> floorNumbers) {
  return floorNumbers.join(',');
}

class FloorRename {
  const FloorRename({
    required this.floorId,
    required this.newNumber,
  });

  final String floorId;
  final String newNumber;
}

class FloorSyncPlan {
  const FloorSyncPlan({
    required this.renames,
    required this.floorsToAdd,
    required this.floorsToRemove,
  });

  final List<FloorRename> renames;
  final List<String> floorsToAdd;
  final List<FloorModel> floorsToRemove;

  bool get hasChanges =>
      renames.isNotEmpty || floorsToAdd.isNotEmpty || floorsToRemove.isNotEmpty;
}

/// Plans floor list changes using positional matching so renames keep rooms and assignments.
FloorSyncPlan planFloorListSync(
  List<FloorModel> existingInOrder,
  List<String> desired,
) {
  final renames = <FloorRename>[];
  final toAdd = <String>[];
  final toRemove = <FloorModel>[];

  final overlap = existingInOrder.length < desired.length
      ? existingInOrder.length
      : desired.length;

  for (var i = 0; i < overlap; i++) {
    final existing = existingInOrder[i];
    final target = desired[i];
    if (existing.number != target) {
      renames.add(
        FloorRename(floorId: existing.id, newNumber: target),
      );
    }
  }

  for (var i = overlap; i < desired.length; i++) {
    toAdd.add(desired[i]);
  }

  for (var i = overlap; i < existingInOrder.length; i++) {
    toRemove.add(existingInOrder[i]);
  }

  return FloorSyncPlan(
    renames: renames,
    floorsToAdd: toAdd,
    floorsToRemove: toRemove,
  );
}
