import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/visitor_model.dart';
import '../models/visitor_type_config.dart';

/// Bottom sheet: grid of subtype options with bundled images under [assets/vendors/&lt;slug&gt;.png].
class VisitorSubtypePickerSheet {
  VisitorSubtypePickerSheet._();

  static IconData _fallbackIcon(VisitorType type) {
    switch (type) {
      case VisitorType.courierDelivery:
        return Icons.delivery_dining_rounded;
      case VisitorType.cabDriver:
        return Icons.local_taxi_rounded;
      case VisitorType.gasDelivery:
        return Icons.local_fire_department_rounded;
      case VisitorType.groceryShop:
        return Icons.shopping_basket_rounded;
      case VisitorType.carpenter:
        return Icons.carpenter_rounded;
      case VisitorType.beautician:
        return Icons.face_retouching_natural_rounded;
      case VisitorType.repairMaintenance:
        return Icons.handyman_rounded;
      case VisitorType.pestControl:
        return Icons.pest_control_rounded;
      case VisitorType.tutor:
        return Icons.menu_book_rounded;
      case VisitorType.otherVendors:
        return Icons.storefront_rounded;
      case VisitorType.guest:
      case VisitorType.other:
        return Icons.apps_rounded;
    }
  }

  /// Returns the selected subtype label (same as [VisitorSubtypeOption.label]) or null if dismissed.
  static Future<String?> show(BuildContext context, VisitorType type) async {
    final options = visitorSubtypeOptions(type);
    if (options.isEmpty) return null;

    final icon = _fallbackIcon(type);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final maxH = MediaQuery.of(ctx).size.height * 0.72;
        final gridWidth = MediaQuery.of(ctx).size.width;
        final crossAxisCount = gridWidth >= 600 ? 4 : 3;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            height: maxH,
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      type.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      'Choose vendor or service',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColor.withOpacity(0.55),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final option = options[i];
                        return Semantics(
                          button: true,
                          label: option.label,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx, option.label),
                              borderRadius: BorderRadius.circular(16),
                              splashColor: AppTheme.primaryColor.withOpacity(0.12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.dividerColor.withOpacity(0.9),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 56,
                                        width: 56,
                                        child: Image.asset(
                                          option.assetPath,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) {
                                            return Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                icon,
                                                size: 30,
                                                color: AppTheme.primaryColor,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        option.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          height: 1.15,
                                          color: AppTheme.textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
