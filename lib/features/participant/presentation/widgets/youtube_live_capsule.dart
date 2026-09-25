import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/api_service.dart';

/// Red "LIVE" capsule for the admin's YouTube link (Admin → YouTube Live).
/// Tapping it opens the video in YouTube. Hidden when no link is set.
class YoutubeLiveCapsule extends StatefulWidget {
  const YoutubeLiveCapsule({super.key});

  @override
  State<YoutubeLiveCapsule> createState() => _YoutubeLiveCapsuleState();
}

class _YoutubeLiveCapsuleState extends State<YoutubeLiveCapsule>
    with SingleTickerProviderStateMixin {
  String _url = '';
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiService().getYoutubeLive();
    if (!mounted || res['success'] != true) return;
    setState(() => _url = res['url']?.toString() ?? '');
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFFF0000), Color(0xFFB91C1C)],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.35),
                blurRadius: 14,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFFFF0000),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FadeTransition(
                    opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: Text(
                      'Watch on YouTube',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
