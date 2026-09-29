import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

/// "Get your live photo" button shown below the button grid in all roles
/// (Admin, Participant, Event Staff, Speaker) when a live photo link is configured.
class GetLivePhotoButton extends StatefulWidget {
  const GetLivePhotoButton({super.key});

  /// Globally shared URL notifier so that saving a link in Admin updates all mounted screens immediately.
  static final ValueNotifier<String?> livePhotoUrlNotifier = ValueNotifier<String?>(null);

  /// Trigger an API reload of the live photo link across the app.
  static Future<void> reload() async {
    try {
      final res = await ApiService().getLivePhoto();
      if (res['success'] == true) {
        livePhotoUrlNotifier.value = res['url']?.toString().trim() ?? '';
      }
    } catch (_) {}
  }

  @override
  State<GetLivePhotoButton> createState() => _GetLivePhotoButtonState();
}

class _GetLivePhotoButtonState extends State<GetLivePhotoButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    GetLivePhotoButton.reload();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: GetLivePhotoButton.livePhotoUrlNotifier,
      builder: (context, url, _) {
        if (url == null || url.trim().isEmpty) return const SizedBox.shrink();
        final effectiveUrl = url.trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE11D48),
                    Color(0xFFBE123C),
                    Color(0xFF9333EA),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _open(effectiveUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                FadeTransition(
                                  opacity: _pulse != null
                                      ? Tween(begin: 0.4, end: 1.0).animate(_pulse!)
                                      : const AlwaysStoppedAnimation(1.0),
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE GALLERY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Get your live photos',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
