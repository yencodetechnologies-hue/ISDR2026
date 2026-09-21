/// Hostel room sharing: API `type` strings and display labels. Beds match backend
/// [bedsForHostelRoomType] in blockController.js.
class HostelSharingOption {
  const HostelSharingOption({required this.apiType, required this.label});

  final String apiType;
  final String label;
}

const List<HostelSharingOption> kHostelSharingOptions = [
  HostelSharingOption(apiType: 'single', label: 'Single sharing'),
  HostelSharingOption(apiType: 'double', label: 'Double sharing'),
  HostelSharingOption(apiType: 'triple', label: 'Triple sharing'),
  HostelSharingOption(apiType: 'four', label: 'Four sharing'),
  HostelSharingOption(apiType: 'five', label: 'Five sharing'),
  HostelSharingOption(apiType: 'six', label: 'Six sharing'),
];

/// Returns bed count for a hostel room [type], including legacy `dorm`.
int? bedsForHostelSharing(String type) {
  switch (type) {
    case 'single':
      return 1;
    case 'double':
      return 2;
    case 'triple':
      return 3;
    case 'four':
    case 'dorm':
      return 4;
    case 'five':
      return 5;
    case 'six':
      return 6;
    default:
      return null;
  }
}

String displayLabelForHostelSharing(String type) {
  for (final o in kHostelSharingOptions) {
    if (o.apiType == type) return o.label;
  }
  if (type == 'dorm') return 'Dorm (legacy)';
  return type;
}

/// Maps API type to a value valid for [kHostelSharingOptions] dropdowns (legacy `dorm` → `four`).
String normalizeHostelSharingTypeForUi(String type) {
  if (type == 'dorm') return 'four';
  if (kHostelSharingOptions.any((o) => o.apiType == type)) return type;
  return 'single';
}

/// Max assignees for a room (hostel beds or 1 for apartment units).
int roomBedCapacity({int? beds, required String type}) {
  if (beds != null && beds > 0) return beds;
  final fromType = bedsForHostelSharing(type);
  if (fromType != null) return fromType;
  return 1;
}
