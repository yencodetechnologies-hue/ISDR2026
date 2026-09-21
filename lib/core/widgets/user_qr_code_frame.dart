import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Gradient-framed white inset for resident / vehicle / visitor QR codes.
class UserQrCodeFrame extends StatelessWidget {
  final Widget child;
  final double outerRadius;

  const UserQrCodeFrame({
    super.key,
    required this.child,
    this.outerRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final innerRadius = outerRadius > 3 ? outerRadius - 3 : outerRadius;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: AppTheme.brandHeaderGradient,
        borderRadius: BorderRadius.circular(outerRadius + 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacityCompat(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(innerRadius),
        ),
        child: child,
      ),
    );
  }
}
