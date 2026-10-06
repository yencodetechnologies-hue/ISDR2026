import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../../../core/services/api_service.dart';

/// Preconference PDF loaded from Cloudinary.
class PreconferencePdfPage extends StatefulWidget {
  const PreconferencePdfPage({super.key});

  @override
  State<PreconferencePdfPage> createState() => _PreconferencePdfPageState();
}

class _PreconferencePdfPageState extends State<PreconferencePdfPage> {
  final _api = ApiService();
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
    PaintingBinding.instance.imageCache.maximumSizeBytes = 350 * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSize = 200;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preRenderAllPages();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      final bytes = await _api.downloadPreconferencePdf();
      final document = await PdfDocument.openData(bytes);
      final pageCount = document.pagesCount;
      if (!mounted) return;
      setState(() => _totalCount = pageCount);

      final rendered = <Uint8List>[];
      for (int i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 1.75,
          height: page.height * 1.75,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 85,
        );
        await page.close();
        if (pageImage == null) continue;
        rendered.add(pageImage.bytes);
        if (!mounted) return;
        setState(() => _renderedCount = rendered.length);
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
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Preconference',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          ? _PreconferenceShimmer(renderedCount: _renderedCount, totalCount: _totalCount)
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not open the preconference PDF.\n$_error',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

class _PreconferenceShimmer extends StatefulWidget {
  final int renderedCount;
  final int totalCount;

  const _PreconferenceShimmer({required this.renderedCount, required this.totalCount});

  @override
  State<_PreconferenceShimmer> createState() => _PreconferenceShimmerState();
}

class _PreconferenceShimmerState extends State<_PreconferenceShimmer>
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rendering preconference PDF…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.renderedCount} of ${widget.totalCount} pages',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
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
                          Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded, size: 40, color: Colors.white38),
                            SizedBox(height: 12),
                            Text(
                              'Loading the preconference PDF…',
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
