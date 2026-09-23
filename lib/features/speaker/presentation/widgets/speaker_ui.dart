import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark palette shared by the speaker screens.
class SpeakerColors {
  static const bgTop = Color(0xFF0B1F4A);
  static const bg = Color(0xFF061331);
  static const card = Color(0xFF0C1D42);
  static const border = Color(0xFF1C3669);
  static const green = Color(0xFF22C55E);
  static const time = Color(0xFF3EE0B8);
  static const sub = Color(0xFF9FB0CF);
  static const nav = Color(0xFF0A1733);
}

/// The session (schedule row) a speaker sub-page works on.
class SpeakerSessionRef {
  final String id;
  final String name;
  final String when; // e.g. "Wed, 23 Sep · 04:00 PM – 08:00 PM"

  const SpeakerSessionRef({
    required this.id,
    required this.name,
    required this.when,
  });
}

BoxDecoration speakerCardDecoration([double radius = 14]) => BoxDecoration(
  color: SpeakerColors.card.withValues(alpha: 0.85),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: SpeakerColors.border),
);

PreferredSizeWidget speakerAppBar(String title) => AppBar(
  backgroundColor: SpeakerColors.bg,
  elevation: 0,
  foregroundColor: Colors.white,
  title: Text(
    title,
    style: GoogleFonts.outfit(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
);

/// Card at the top of a speaker sub-page naming the session.
class SpeakerSessionHeader extends StatelessWidget {
  final SpeakerSessionRef session;

  const SpeakerSessionHeader({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: speakerCardDecoration(16),
      child: Row(
        children: [
          const Icon(
            Icons.event_note_rounded,
            color: SpeakerColors.green,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session.when,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: SpeakerColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width green button pinned to the bottom of a speaker sub-page.
class SpeakerActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;

  const SpeakerActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: busy ? null : onPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: busy
                    ? [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(busyLabel ?? 'Please wait…', style: textStyle),
                      ]
                    : [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(label, style: textStyle),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered grey message for empty / error states on the speaker pages.
class SpeakerEmptyText extends StatelessWidget {
  final String text;

  const SpeakerEmptyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: SpeakerColors.sub),
        ),
      ),
    );
  }
}

/// "Delete this …?" confirmation; resolves true when confirmed.
Future<bool> confirmSpeakerDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete this $what?'),
      content: const Text('Participants will no longer see it.'),
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
  return ok == true;
}
