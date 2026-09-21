import '../models/apartment_model.dart';
import '../models/user_model.dart';

/// Resolved property (apartment / company / hostel) for the logged-in resident.
class CurrentPropertyContext {
  final ApartmentModel? property;
  final bool isHostel;
  final bool securityEnabled;
  final bool assignPaymentEnabled;
  final bool complaintsEnabled;
  final bool showUserMobile;
  final bool addUserEnabled;
  final bool supportEnabled;
  final bool adsEnabled;

  const CurrentPropertyContext({
    this.property,
    required this.isHostel,
    this.securityEnabled = true,
    this.assignPaymentEnabled = true,
    this.complaintsEnabled = true,
    this.showUserMobile = true,
    this.addUserEnabled = true,
    this.supportEnabled = false,
    this.adsEnabled = true,
  });

  static const defaults = CurrentPropertyContext(
    isHostel: false,
    showUserMobile: true,
    addUserEnabled: true,
    supportEnabled: true,
    adsEnabled: true,
  );

  String get propertyLabel => isHostel ? 'Hostel' : 'Property';
}

ApartmentModel? resolveCurrentProperty(
  UserModel user, {
  String? selectedApartmentId,
}) {
  final apartments = user.apartments;
  if (apartments == null || apartments.isEmpty) return null;
  final selectedId = selectedApartmentId ?? user.apartmentId;
  if (selectedId != null) {
    for (final a in apartments) {
      if (a.id == selectedId) return a;
    }
  }
  return apartments.first;
}

bool userLooksLikeHostelResident(UserModel user) {
  return (user.hostelRoom != null && user.hostelRoom!.isNotEmpty) ||
      (user.hostelBed != null && user.hostelBed!.isNotEmpty);
}

CurrentPropertyContext resolvePropertyContext(
  UserModel user, {
  String? selectedApartmentId,
}) {
  final property = resolveCurrentProperty(
    user,
    selectedApartmentId: selectedApartmentId,
  );
  if (property == null) {
    final fallbackHostel = userLooksLikeHostelResident(user);
    return CurrentPropertyContext(
      isHostel: fallbackHostel,
      securityEnabled: true,
      assignPaymentEnabled: true,
      complaintsEnabled: true,
      showUserMobile: true,
      addUserEnabled: true,
      supportEnabled: !fallbackHostel,
      adsEnabled: true,
    );
  }
  final isHostel =
      false || userLooksLikeHostelResident(user);
  return CurrentPropertyContext(
    property: property,
    isHostel: isHostel,
    securityEnabled: property.securityEnabled,
    assignPaymentEnabled: property.assignPaymentEnabled,
    complaintsEnabled: property.complaintsEnabled,
    showUserMobile: property.showUserMobile,
    addUserEnabled: property.addUserEnabled,
    supportEnabled: isHostel ? property.supportEnabled : true,
    adsEnabled: property.adsEnabled,
  );
}

/// Whether the signed-in viewer should see resident mobile numbers.
///
/// Hostel owners always see numbers. Wardens only see them when
/// [showUserMobileSetting] is enabled. Platform admins always see them.
bool shouldShowUserMobileForViewer({
  required bool showUserMobileSetting,
  String? loginRole,
  bool isHostel = false,
  UserType? viewerUserType,
}) {
  if (viewerUserType == UserType.admin) return true;
  if (loginRole == 'warden') return showUserMobileSetting;
  if (isHostel && loginRole == 'owner') return true;
  return showUserMobileSetting;
}
