import 'visitor_model.dart';

/// Stable filename slug for [assets/vendors/<slug>.png] (bundled logos).
String slugForSubtypeLabel(String label) {
  var s = label.toLowerCase().trim();
  s = s.replaceAll('&', 'and');
  s = s.replaceAll(RegExp(r'[/]+'), '_');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_');
  if (s.startsWith('_')) s = s.substring(1);
  if (s.endsWith('_')) s = s.substring(0, s.length - 1);
  return s.isEmpty ? 'other' : s;
}

/// One row in the subtype grid (label is sent as `typeDetail` to the API).
class VisitorSubtypeOption {
  final String label;

  const VisitorSubtypeOption({required this.label});

  /// Bundled asset path; may be missing until you add `assets/vendors/<slug>.png`.
  String get assetPath => 'assets/vendors/${slugForSubtypeLabel(label)}.png';
}

/// Rich options for image grid UI; labels match [subOptionsForVisitorType].
List<VisitorSubtypeOption> visitorSubtypeOptions(VisitorType type) {
  return subOptionsForVisitorType(type)
      .map((label) => VisitorSubtypeOption(label: label))
      .toList();
}

/// Sub-labels after picking a primary visitor type (e.g. Swiggy under Courier / Delivery).
List<String> subOptionsForVisitorType(VisitorType type) {
  switch (type) {
    case VisitorType.courierDelivery:
      return [
        'Swiggy',
        'Zomato',
        'Dunzo',
        'Zepto',
        'Blinkit',
        'Amazon',
        'Flipkart',
        'BigBasket',
        'DTDC',
        'Blue Dart',
        'Other',
      ];
    case VisitorType.cabDriver:
      return ['Uber', 'Ola', 'Rapido', 'InDrive', 'Meru', 'Other'];
    case VisitorType.gasDelivery:
      return ['Indane', 'HP Gas', 'Bharat Gas', 'Other'];
    case VisitorType.groceryShop:
      return ['BigBasket', 'JioMart', 'DMart', 'Local kirana', 'Other'];
    case VisitorType.carpenter:
      return ['Furniture', 'Modular kitchen', 'Doors & windows', 'Other'];
    case VisitorType.beautician:
      return ['Salon', 'Spa', 'Home service', 'Other'];
    case VisitorType.repairMaintenance:
      return [
        'AC',
        'Fridge / appliance',
        'TV',
        'Plumbing',
        'Electrical',
        'Other',
      ];
    case VisitorType.pestControl:
      return ['General', 'Termite', 'Cockroach / rodent', 'Other'];
    case VisitorType.tutor:
      return ['Academic', 'Music', 'Sports / fitness', 'Other'];
    case VisitorType.otherVendors:
      return ['Plumber', 'Electrician', 'Maid / helper', 'Official', 'Other'];
    case VisitorType.guest:
    case VisitorType.other:
      return const [];
  }
}

bool visitorTypeRequiresSubtype(VisitorType type) =>
    subOptionsForVisitorType(type).isNotEmpty;
