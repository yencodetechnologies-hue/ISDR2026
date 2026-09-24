import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/api_service.dart';
import 'selfie_camera_page.dart';

// Same dark theme as the participant homepage.
class _Colors {
  static const ink = Colors.white;
  static const bg = Color(0xFF0A0A12);
  static const card = Color(0xFF14141F);
  static const muted = Color(0xFF9CA3AF);
  static const line = Color(0x14FFFFFF); // white at 8%
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

  /// Flips the heart right away, then syncs with the server's count
  /// (and flips back if the request fails).
  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post['liked'] == true;
    final count = (post['likeCount'] as num?)?.toInt() ?? 0;
    setState(() {
      post['liked'] = !wasLiked;
      post['likeCount'] = count + (wasLiked ? -1 : 1);
    });
    final res = await _api.toggleFeedPostLike(post['id'].toString());
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        post['liked'] = res['liked'] == true;
        post['likeCount'] = (res['likeCount'] as num?)?.toInt() ?? 0;
      } else {
        post['liked'] = wasLiked;
        post['likeCount'] = count;
      }
    });
  }

  String? _sharingId; // post whose photo is being downloaded to share

  /// Downloads the post's photo and opens the phone's share sheet with it.
  Future<void> _share(Map<String, dynamic> post) async {
    final id = post['id'].toString();
    final url = post['imageUrl']?.toString() ?? '';
    if (url.isEmpty || _sharingId != null) return;
    setState(() => _sharingId = id);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/isdr_feed_$id.jpg');
      await Dio().download(url, file.path);
      final name = post['participantName']?.toString() ?? '';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/jpeg')],
        text: name.isEmpty ? 'From the ISDR 2026 feed' : '$name at ISDR 2026',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share this photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingId = null);
    }
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
      appBar: AppBar(
        backgroundColor: _Colors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
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
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final imageUrl = post['imageUrl']?.toString() ?? '';
                      final name = post['participantName']?.toString() ?? '';
                      final time = _fmtTime(post['createdAt']?.toString());
                      final liked = post['liked'] == true;
                      final likeCount = (post['likeCount'] as num?)?.toInt() ?? 0;
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
                            // Square, like the 1:1 selfie camera.
                            AspectRatio(
                              aspectRatio: 1,
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                                  : Container(color: const Color(0xFF1E1E2A)),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                              child: Row(
                                children: [
                                  Expanded(
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
                                  _LikeButton(
                                    liked: liked,
                                    count: likeCount,
                                    onTap: () => _toggleLike(index),
                                  ),
                                  IconButton(
                                    tooltip: 'Share',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _share(post),
                                    icon: _sharingId == post['id'].toString()
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(
                                            Icons.share_rounded,
                                            size: 21,
                                            color: _Colors.muted,
                                          ),
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

/// Heart + like count on a feed card.
class _LikeButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;

  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 22,
              color: liked ? const Color(0xFFEF4444) : _Colors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: liked ? const Color(0xFFEF4444) : _Colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A creative "take a selfie" button â€” a gradient pill with a
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
