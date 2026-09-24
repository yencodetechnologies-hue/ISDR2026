import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Near-black app bar for the participant screens (matches the participant
/// homepage's dark theme). Same parameters as [buildBrandGradientAppBar].
AppBar buildDarkAppBar({
  Key? key,
  required Widget title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  double? leadingWidth,
  bool centerTitle = true,
}) {
  return AppBar(
    key: key,
    backgroundColor: const Color(0xFF0A0A12),
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    title: DefaultTextStyle.merge(
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      child: title,
    ),
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    leadingWidth: leadingWidth,
    actions: actions,
    bottom: bottom,
  );
}

/// App bar with [AppTheme.brandHeaderGradient] (same pattern as Security dashboard).
AppBar buildBrandGradientAppBar({
  Key? key,
  required Widget title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  double? leadingWidth,
  bool centerTitle = true,
}) {
  return AppBar(
    key: key,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    title: DefaultTextStyle.merge(
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      child: title,
    ),
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    leadingWidth: leadingWidth,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: AppTheme.brandHeaderGradient,
      ),
    ),
    actions: actions,
    bottom: bottom,
  );
}
