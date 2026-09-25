import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin's Banner page: images for the auto-scrolling banner on the
/// participant home, plus an on/off switch for the whole banner.
class ManageBannerPage extends StatefulWidget {
  const ManageBannerPage({super.key});

  @override
  State<ManageBannerPage> createState() => _ManageBannerPageState();
}

class _ManageBannerPageState extends State<ManageBannerPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  bool _enabled = true;
  bool _busy = false; // uploading / switching
  List<Map<String, dynamic>> _images = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Applies a {success, banner} response; returns whether it succeeded.
  bool _apply(Map<String, dynamic> res) {
    if (res['success'] != true || res['banner'] is! Map) return false;
    final banner = Map<String, dynamic>.from(res['banner'] as Map);
    _enabled = banner['enabled'] != false;
    _images = ((banner['images'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return true;
  }

  Future<void> _load() async {
    final res = await _api.getHomeBanner();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = _apply(res)
          ? null
          : res['error']?.toString() ?? 'Could not load the banner';
    });
  }

  Future<void> _toggle(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _busy = true;
    });
    final res = await _api.setHomeBannerEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!_apply(res)) {
        _enabled = previous;
        _toast(res['error']?.toString() ?? 'Could not update');
      }
    });
  }

  Future<void> _addImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final res = await _api.addHomeBannerImage(picked.path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!_apply(res)) _toast(res['error']?.toString() ?? 'Could not add image');
    });
  }

  Future<void> _delete(Map<String, dynamic> image) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text(
          'Delete image?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'It will be removed from the participant home banner.',
          style: TextStyle(color: DarkColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.deleteHomeBannerImage(image['id'].toString());
    if (!mounted) return;
    setState(() {
      if (!_apply(res)) _toast(res['error']?.toString() ?? 'Could not delete');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Banner',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _addImage,
              backgroundColor: DarkColors.accent,
              foregroundColor: Colors.white,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Add Image'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: Text(
                        '$_error\nPull down to try again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: DarkColors.muted),
                      ),
                    )
                  else ...[
                    Container(
                      decoration: darkCardDecoration(),
                      child: SwitchListTile(
                        value: _enabled,
                        onChanged: _busy ? null : _toggle,
                        activeThumbColor: Colors.white,
                        activeTrackColor: DarkColors.accent,
                        title: Text(
                          'Show banner',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          _enabled
                              ? 'On — scrolling on the participant home'
                              : 'Off — hidden from participants',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: DarkColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _images.isEmpty
                          ? 'IMAGES'
                          : 'IMAGES · ${_images.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        color: DarkColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_images.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 44,
                              color: DarkColors.muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No images yet.\nTap "Add Image" to add one.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: DarkColors.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < _images.length; i++)
                        _imageCard(_images[i], i),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _imageCard(Map<String, dynamic> image, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: darkCardDecoration(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: CachedNetworkImage(
              imageUrl: image['url']?.toString() ?? '',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(
                color: DarkColors.field,
                child: Icon(Icons.broken_image_outlined, color: DarkColors.muted),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFF87171),
                ),
                onPressed: () => _delete(image),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
