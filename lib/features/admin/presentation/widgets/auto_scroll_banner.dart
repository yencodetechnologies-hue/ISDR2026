import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// One banner card: a gradient placeholder with a title/subtitle, or a real
/// image when [imagePath] is given.
class BannerItem {
  final String? imagePath;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;

  const BannerItem({
    this.imagePath,
    required this.title,
    required this.subtitle,
    this.gradient = const [Colors.white, Colors.white],
    this.icon = Icons.event_rounded,
  });
}

/// Auto-scrolling banner strip: scrolls right continuously and loops forever.
/// Duplicates the item list so the loop point is invisible.
class AutoScrollBanner extends StatefulWidget {
  final List<BannerItem> items;
  final double height;

  const AutoScrollBanner({
    super.key,
    required this.items,
    this.height = 150,
  });

  @override
  State<AutoScrollBanner> createState() => _AutoScrollBannerState();
}

class _AutoScrollBannerState extends State<AutoScrollBanner> {
  final ScrollController _controller = ScrollController();
  Timer? _ticker;
  double _cardWidth = 260;
  static const double _gap = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (widget.items.isEmpty || !_controller.hasClients) return;
    const step = 0.6; // px per tick — slow, smooth auto-scroll
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_controller.hasClients) return;
      final singleSetExtent = (_cardWidth + _gap) * widget.items.length;
      var next = _controller.offset + step;
      if (next >= singleSetExtent) {
        next -= singleSetExtent;
        _controller.jumpTo(next);
        return;
      }
      _controller.jumpTo(next);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    // Duplicate the list so the loop reset is invisible while scrolling.
    final loopItems = [...widget.items, ...widget.items];
    return LayoutBuilder(
      builder: (context, constraints) {
        _cardWidth = (constraints.maxWidth - _gap) * 0.86;
        return SizedBox(
          height: widget.height,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: loopItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (_, i) => SizedBox(
              width: _cardWidth,
              child: _BannerCard(item: loopItems[i]),
            ),
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem item;
  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        image: item.imagePath != null
            ? DecorationImage(
                image: AssetImage(item.imagePath!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: item.imagePath != null
          ? null
          : const Center(
              child: Text(
                'Image',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

/// Placeholder banner set for the management home page (swap with real
/// [BannerItem.imagePath] values once images are supplied).
const List<BannerItem> defaultManagementBanners = [
  BannerItem(
    title: 'ISDR 2026',
    subtitle: '36th International Conference',
    icon: Icons.event_rounded,
  ),
  BannerItem(
    title: 'Manage Your Events',
    subtitle: 'Packages, participants & schedules',
    icon: Icons.dashboard_customize_rounded,
  ),
  BannerItem(
    title: 'Stay Connected',
    subtitle: 'Notify participants instantly',
    icon: Icons.campaign_rounded,
  ),
];
