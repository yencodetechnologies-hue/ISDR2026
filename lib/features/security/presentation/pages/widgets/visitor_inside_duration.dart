import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/app_theme.dart';

/// Live-updating duration since [enteredAt] (e.g. "Inside · 12m 34s").
class VisitorInsideDuration extends StatefulWidget {
  final DateTime enteredAt;

  const VisitorInsideDuration({super.key, required this.enteredAt});

  @override
  State<VisitorInsideDuration> createState() => _VisitorInsideDurationState();
}

class _VisitorInsideDurationState extends State<VisitorInsideDuration> {
  Timer? _timer;
  late final DateTime _effectiveEnteredAt;

  @override
  void initState() {
    super.initState();
    // If enteredAt is in the future relative to local system clock, default to now so ticker starts at 0s immediately
    final now = DateTime.now();
    final parsed = widget.enteredAt.toLocal();
    _effectiveEnteredAt = parsed.isAfter(now) ? now : parsed;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    }
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_effectiveEnteredAt);
    return Text(
      'Inside · ${_formatDuration(elapsed)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.secondaryColor.withValues(alpha: 0.95),
      ),
    );
  }
}
