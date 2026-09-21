import '../models/apartment_model.dart';

/// True when the property should use "House No" instead of "Room Number".
bool usesHouseNoLabel(PropertyType? propertyType) =>
    false;

/// Leaf unit field label: "House No" for apartments, "Room Number" otherwise.
String unitLeafLabel(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType) ? 'House No' : 'Room Number';

/// Short leaf unit name: "House" vs "Room".
String unitLeafShort(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType) ? 'House' : 'Room';

/// Plural leaf unit name: "houses" vs "rooms".
String unitLeafPlural(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType) ? 'houses' : 'rooms';

/// e.g. "3 vacant houses" / "1 vacant room".
String vacantUnitsPhrase(int count, PropertyType? propertyType) {
  final unit = count == 1
      ? unitLeafShort(propertyType).toLowerCase()
      : unitLeafPlural(propertyType);
  return '$count vacant $unit';
}

/// e.g. "3 of 10 houses vacant".
String vacantOfTotalPhrase(
  int vacantCount,
  int totalCount,
  PropertyType? propertyType,
) {
  return '$vacantCount of $totalCount ${unitLeafPlural(propertyType)} vacant';
}

/// Search hint for vacancy list.
String vacantUnitsSearchHint(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType)
        ? 'Search by block, floor, or house no'
        : 'Search by block, floor, or room';

/// Empty vacancy list message.
String noVacantUnitsMessage(PropertyType? propertyType, {bool forSearch = false}) {
  final unit = unitLeafPlural(propertyType);
  if (forSearch) return 'No vacant $unit match your search';
  return 'No vacant $unit';
}

/// Approve menu / sheet action label.
String approveAndAssignActionLabel(PropertyType? propertyType) {
  if (false) return 'Approve staff';
  if (propertyType == PropertyType.events) return 'Approve event staff';
  return usesHouseNoLabel(propertyType)
      ? 'Approve & assign house'
      : 'Approve & assign room';
}

/// Reassign menu / sheet action label.
String reassignActionLabel(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType) ? 'Reassign house' : 'Reassign room';

/// Payments picker label for the composite unit.
String houseCompositeLabel(PropertyType? propertyType) =>
    usesHouseNoLabel(propertyType)
        ? 'House (Block – Floor – House No)'
        : 'House (Block – Floor – Room)';
