import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';

/// Ticker text from the admin's lines (one message per line), separated by
/// dots the same way as [kConferenceTickerText].
String tickerTextFromLines(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return lines.isEmpty ? '' : '${lines.join('  •  ')}  •  ';
}

/// The conference message shown before an admin sets their own text.
const String kConferenceTickerText =
    'Welcome to ISDR 2026 — 36th International Conference  •  IADR Indian Division  •  Register your sessions and claim your inclusions on time  •  ';

/// A blue strap with continuously scrolling marquee text, like a news ticker —
/// loops forever, never stops.
class NewsTickerStrap extends StatefulWidget {
  final String text;
  const NewsTickerStrap({super.key, this.text = kConferenceTickerText});

  @override
  State<NewsTickerStrap> createState() => _NewsTickerStrapState();
}

class _NewsTickerStrapState extends State<NewsTickerStrap> {
  final ScrollController _controller = ScrollController();
  Timer? _ticker;
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  void _measureAndStart() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _textStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _textWidth = painter.width + 40; // matches the SizedBox gap below
    _start();
  }

  void _start() {
    if (_textWidth <= 0) return;
    const step = 0.8; // px per tick — smooth, continuous scroll
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          !_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      var next = _controller.offset + step;
      if (next >= _textWidth) next -= _textWidth;
      _controller.jumpTo(next);
    });
  }

  static final TextStyle _textStyle = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 34,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ListView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(3, (_) {
            return Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Center(
                child: Text(widget.text, maxLines: 1, style: _textStyle),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// The news ticker as the admin set it (Admin → News Ticker): loads the text
/// and on/off switch, re-checks every minute, and hides when switched off.
class AdminNewsTicker extends StatefulWidget {
  const AdminNewsTicker({super.key});

  @override
  State<AdminNewsTicker> createState() => _AdminNewsTickerState();
}

class _AdminNewsTickerState extends State<AdminNewsTicker> {
  String? _text; // null = off (or not loaded yet)
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiService().getNewsTicker();
    if (!mounted || res['success'] != true || res['ticker'] is! Map) return;
    final ticker = Map<String, dynamic>.from(res['ticker'] as Map);
    final text = ticker['enabled'] == false
        ? null
        : tickerTextFromLines(ticker['text']?.toString() ?? '');
    final next = (text == null || text.isEmpty) ? null : text;
    if (next != _text) setState(() => _text = next);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    // A new key restarts the scroll with the new text.
    return NewsTickerStrap(key: ValueKey(text), text: text);
  }
}
