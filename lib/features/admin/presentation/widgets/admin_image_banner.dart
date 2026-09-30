import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import 'auto_scroll_banner.dart';

/// The admin's image banner (Admin → Banner), the same one the participant
/// home shows: rounded, inside the page margins, scrolling to the next image
/// automatically. Reloads every 30 s so switching it on/off or changing the
/// images shows up without a restart. Hidden when switched off or empty.
class AdminImageBanner extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const AdminImageBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 0),
  });

  @override
  State<AdminImageBanner> createState() => _AdminImageBannerState();
}

class _AdminImageBannerState extends State<AdminImageBanner> {
  final _api = ApiService();
  List<String> _urls = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _api.getHomeBanner();
    if (!mounted || res['success'] != true || res['banner'] is! Map) return;
    final banner = Map<String, dynamic>.from(res['banner'] as Map);
    final urls = banner['enabled'] == false
        ? <String>[]
        : ((banner['images'] as List?) ?? const [])
            .map((i) => (i as Map)['url']?.toString() ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
    if (urls.join() == _urls.join()) return;
    setState(() => _urls = urls);
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AutoScrollBanner(
          key: ValueKey(_urls.join()),
          height: 160,
          items: [for (final url in _urls) BannerItem(imageUrl: url)],
        ),
      ),
    );
  }
}
