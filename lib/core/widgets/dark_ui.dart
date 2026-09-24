import 'package:flutter/material.dart';

/// Black theme shared by the participant, speaker, staff and management
/// screens (matches the participant homepage).
class DarkColors {
  static const bg = Color(0xFF0A0A12);
  static const card = Color(0xFF14141F);
  static const field = Color(0xFF1E1E2A);
  static const line = Color(0x14FFFFFF);
  static const text = Colors.white;
  static const muted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF3B82F6);
  static const accentLight = Color(0xFF60A5FA);
}

/// Card decoration for the dark screens.
BoxDecoration darkCardDecoration([double radius = 14]) => BoxDecoration(
  color: DarkColors.card,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: DarkColors.line),
);

/// Text-field decoration for forms on the dark screens.
InputDecoration darkInputDecoration(String label, IconData icon) =>
    InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: DarkColors.muted),
      floatingLabelStyle: const TextStyle(color: DarkColors.accentLight),
      prefixIcon: Icon(icon, color: DarkColors.accentLight, size: 20),
      filled: true,
      fillColor: DarkColors.field,
      counterStyle: const TextStyle(color: DarkColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DarkColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DarkColors.accent),
      ),
    );
