import 'package:flutter/material.dart';

/// Shared navigation helpers for auth flows and stack resets.
class AppNavigation {
  AppNavigation._();

  /// Replaces the entire route stack with [route].
  static void resetTo(
    BuildContext context,
    String route, {
    Object? arguments,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (_) => false,
      arguments: arguments,
    );
  }
}
