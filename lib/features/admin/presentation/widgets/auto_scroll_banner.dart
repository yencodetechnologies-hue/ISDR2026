import 'dart:async';
import 'package:flutter/material.dart';

/// One banner slide: just an image — a bundled asset ([imagePath]) or one
/// from the server ([imageUrl]).
class BannerItem {
  final String? imagePath;
  final String? imageUrl;
  final String title;
  final String subtitle;

  const BannerItem({
    this.imagePath,
    this.imageUrl,
    this.title = '',
    this.subtitle = '',
  });
}

/// Full-width image banner carousel — swipeable by the user, with a gentle
/// auto-advance animation between slides (PageView, not a scrolling strip).
class AutoScrollBanner extends StatefulWidget {
  final List<BannerItem> items;
  final double height;

  const AutoScrollBanner({
    super.key,
    required this.items,
    this.height = 170,
  });

  @override
  State<AutoScrollBanner> createState() => _AutoScrollBannerState();
}

class _AutoScrollBannerState extends State<AutoScrollBanner> {
  late final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void didUpdateWidget(covariant AutoScrollBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.items.length) _page = 0;
  }

  void _startAutoAdvance() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients || widget.items.length < 2) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              if (item.imageUrl != null) {
                return Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF14141F)),
                );
              }
              return item.imagePath != null
                  ? Image.asset(item.imagePath!, fit: BoxFit.cover, width: double.infinity)
                  : const ColoredBox(color: Color(0xFFF1F5F9));
            },
          ),
          if (widget.items.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.items.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner set for the management home page and login screen.
const List<BannerItem> defaultManagementBanners = [
  BannerItem(imagePath: 'assets/isdr-slider.webp'),
  BannerItem(imagePath: 'assets/Gemini_Generated_Image_bg38yfbg38yfbg38.png'),
  BannerItem(imagePath: 'assets/Gemini_Generated_Image_avabulavabulavab.png'),
];
