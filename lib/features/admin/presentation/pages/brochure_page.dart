import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfx/pdfx.dart';
import '../../../../core/app_theme.dart';

/// Shows the ISDR 36th International Conference brochure.
/// Pre-renders and precaches all pages in memory while displaying a shimmer loader.
/// Only after 100% of pages are fully rendered and GPU-cached is the shimmer dismissed,
/// ensuring 100% smooth, instant, stutter-free scrolling.
class BrochurePage extends StatefulWidget {
  const BrochurePage({super.key});

  static const String _assetPath =
      'assets/ISDR 36th international conference brochure_compressed.pdf';

  @override
  State<BrochurePage> createState() => _BrochurePageState();
}

class _BrochurePageState extends State<BrochurePage> {
  bool _loading = true;
  String? _error;
  List<Uint8List> _pageImages = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _renderedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // Expand Flutter image cache so decoded pages are never evicted during scroll
    PaintingBinding.instance.imageCache.maximumSizeBytes = 350 * 1024 * 1024; // 350MB
    PaintingBinding.instance.imageCache.maximumSize = 200;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preRenderAllPages();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_pageImages.isEmpty || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (maxScroll <= 0) return;
    final pageIndex =
        ((currentScroll / maxScroll) * (_pageImages.length - 1)).round() + 1;
    final clamped = pageIndex.clamp(1, _pageImages.length);
    if (clamped != _currentPage) {
      setState(() => _currentPage = clamped);
    }
  }

  Future<void> _preRenderAllPages() async {
    try {
      final byteData = await rootBundle.load(BrochurePage._assetPath);
      final document =
          await PdfDocument.openData(byteData.buffer.asUint8List());
      final pageCount = document.pagesCount;

      if (!mounted) return;
      setState(() {
        _totalCount = pageCount;
      });

      final rendered = <Uint8List>[];

      for (int i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        // Render at crisp 1.75x ratio for optimal memory + sharpness balance
        final pageImage = await page.render(
          width: page.width * 1.75,
          height: page.height * 1.75,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 85,
        );

        if (pageImage != null) {
          rendered.add(pageImage.bytes);
          // Precache decoded bitmap immediately while still on loading/shimmer screen
          if (mounted) {
            await precacheImage(MemoryImage(pageImage.bytes), context);
          }
        }
        await page.close();

        if (mounted) {
          setState(() {
            _renderedCount = i;
          });
        }
      }
      await document.close();

      if (!mounted) return;
      setState(() {
        _pageImages = rendered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          'Brochure',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _loading
                      ? (_totalCount > 0
                          ? '$_renderedCount / $_totalCount'
                          : 'Loading…')
                      : '$_currentPage / ${_pageImages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? _BrochureFullShimmerScreen(
              renderedCount: _renderedCount,
              totalCount: _totalCount,
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not open the brochure.\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  cacheExtent: 15000,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount: _pageImages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        panEnabled: false,
                        scaleEnabled: true,
                        child: Image.memory(
                          _pageImages[index],
                          fit: BoxFit.fitWidth,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _BrochureFullShimmerScreen extends StatefulWidget {
  final int renderedCount;
  final int totalCount;

  const _BrochureFullShimmerScreen({
    required this.renderedCount,
    required this.totalCount,
  });

  @override
  State<_BrochureFullShimmerScreen> createState() =>
      _BrochureFullShimmerScreenState();
}

class _BrochureFullShimmerScreenState extends State<_BrochureFullShimmerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalCount > 0
        ? (widget.renderedCount / widget.totalCount).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final val = _anim.value;
        return Column(
          children: [
            if (widget.totalCount > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rendering brochure…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.renderedCount} of ${widget.totalCount} pages',
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.secondaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, __) {
                  return AspectRatio(
                    aspectRatio: 1 / 1.414,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment(-1.5 + (val * 3), -0.5),
                          end: Alignment(0.5 + (val * 3), 0.5),
                          colors: const [
                            Color(0xFF1E293B),
                            Color(0xFF334155),
                            Color(0xFF1E293B),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                size: 40, color: Colors.white38),
                            SizedBox(height: 12),
                            Text(
                              'Optimizing & caching high-res pages…',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
