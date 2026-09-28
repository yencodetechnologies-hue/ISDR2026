import 'package:flutter/material.dart';

/// Checkbox that is green when ticked and red when not — matches the web `tick-box`.
class TickBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const TickBox({super.key, required this.value, this.onChanged});

  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final color = value ? green : red;
    return SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
        checkColor: Colors.white,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => value ? green : const Color(0x26EF4444),
        ),
        side: BorderSide(color: color, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
