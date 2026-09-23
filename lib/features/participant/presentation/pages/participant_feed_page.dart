import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import 'selfie_camera_page.dart';

class _Colors {
  static const ink = Color(0xFF0F172A);
  static const bg = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
}

/// Every participant's posted selfie, newest first — no restriction on who
/// can see whose photo.
class ParticipantFeedPage extends StatefulWidget {
  const ParticipantFeedPage({super.key});

  @override
  State<ParticipantFeedPage> createState() => _ParticipantFeedPageState();
}

class _ParticipantFeedPageState extends State<ParticipantFeedPage> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.listFeedPosts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _posts = List<Map<String, dynamic>>.from(
          (res['posts'] as List?)?.map((p) => Map<String, dynamic>.from(p as Map)) ?? [],
        );
      }
    });
  }

  Future<void> _openCamera() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SelfieCameraPage()),
    );
    if (posted == true) _load();
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return DateFormat('d MMM, h:mm a').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildBrandGradientAppBar(
        title: Text(
          'Feed',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      Icon(Icons.dynamic_feed_rounded, size: 40, color: _Colors.muted),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'No posts yet',
                          style: GoogleFonts.inter(fontSize: 13, color: _Colors.muted),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _posts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final imageUrl = post['imageUrl']?.toString() ?? '';
                      final name = post['participantName']?.toString() ?? '';
                      final time = _fmtTime(post['createdAt']?.toString());
                      return Container(
                        decoration: BoxDecoration(
                          color: _Colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _Colors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                                  : Container(color: const Color(0xFFF1F5F9)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _Colors.ink,
                                    ),
                                  ),
                                  if (time.isNotEmpty)
                                    Text(
                                      time,
                                      style: GoogleFonts.inter(fontSize: 10, color: _Colors.muted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _SelfieFab(onTap: _openCamera),
    );
  }
}

/// A creative "take a selfie" button — a gradient pill with a
/// camera-and-sparkle icon, instead of a plain camera FAB.
class _SelfieFab extends StatelessWidget {
  final VoidCallback onTap;
  const _SelfieFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF2563EB), Color(0xFFE1306C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 26),
            Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.auto_awesome_rounded, color: Colors.white.withValues(alpha: 0.9), size: 12),
            ),
          ],
        ),
      ),
    );
  }
}
