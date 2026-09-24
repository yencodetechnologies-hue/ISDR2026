import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../pages/schedule_detail_page.dart';

/// The participant homepage's live-show card as a self-contained widget:
/// today's live / upcoming sessions across the whole event (every speaker),
/// cycling every few seconds (or on swipe), with page dots. Shows
/// "No Live Program" when nothing is left today.
class LiveShowCard extends StatefulWidget {
  const LiveShowCard({super.key});

  @override
  State<LiveShowCard> createState() => _LiveShowCardState();
}

class _LiveShowCardState extends State<LiveShowCard> {
  final _api = ApiService();
  final List<Map<String, dynamic>> _todayItems = [];
  int _cycleIndex = 0;
  Timer? _refreshTimer;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetch();
    });
    _cycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _todayItems.length < 2) return;
      setState(() => _cycleIndex = (_cycleIndex + 1) % _todayItems.length);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _cycleTimer?.cancel();
    super.dispose();
  }

  /// Today's sessions that haven't ended yet, across every event.
  Future<void> _fetch() async {
    try {
      final eventsRes = await _api.listManagedEvents();
      if (eventsRes['success'] != true) return;
      final events = ((eventsRes['events'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final now = DateTime.now();
      final today = <Map<String, dynamic>>[];
      for (final event in events) {
        final eventId =
            event['id']?.toString() ?? event['_id']?.toString() ?? '';
        if (eventId.isEmpty) continue;
        final res = await _api.listEventSchedules(eventId);
        if (res['success'] != true) continue;
        for (final raw in (res['schedules'] as List?) ?? const []) {
          final s = Map<String, dynamic>.from(raw as Map);
          final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
          if (d == null) continue;
          DateTime at(String? hhmm) {
            final p = (hhmm ?? '').split(':');
            return DateTime(
              d.year,
              d.month,
              d.day,
              int.tryParse(p[0]) ?? 0,
              p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
            );
          }

          final start = at(s['fromTime']?.toString());
          final end = at(s['toTime']?.toString());
          final isToday =
              d.year == now.year && d.month == now.month && d.day == now.day;
          if (isToday && end.isAfter(now)) {
            today.add({
              'schedule': s,
              'event': event,
              'start': start,
              'end': end,
            });
          }
        }
      }
      today.sort(
        (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
      );
      if (!mounted) return;
      setState(() {
        _todayItems
          ..clear()
          ..addAll(today);
        if (_cycleIndex >= _todayItems.length) _cycleIndex = 0;
      });
    } catch (_) {}
  }

  String _fmtTimeStr(String hhmm) {
    final p = hhmm.split(':');
    final t = DateTime(
      2000,
      1,
      1,
      int.tryParse(p[0]) ?? 0,
      p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    );
    return DateFormat('h:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_todayItems.isEmpty) return _noLiveProgram();

    final index = _cycleIndex < _todayItems.length ? _cycleIndex : 0;
    final item = _todayItems[index];
    final schedule = item['schedule'] as Map<String, dynamic>;
    final event = item['event'] as Map<String, dynamic>;
    final start = item['start'] as DateTime;
    final end = item['end'] as DateTime;
    final now = DateTime.now();
    final isLive = !now.isBefore(start) && now.isBefore(end);

    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final speakerName = schedule['speakerName']?.toString() ?? '';
    final speakerPhoto = schedule['speakerPhoto']?.toString() ?? '';
    final fromTime = schedule['fromTime']?.toString() ?? '';
    final toTime = schedule['toTime']?.toString() ?? '';
    final hall = schedule['hall']?.toString() ?? '';
    final metaColor = Colors.white.withValues(alpha: 0.85);
    final metaStyle = GoogleFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      color: metaColor,
    );

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 100 || _todayItems.length < 2) return;
            setState(() {
              _cycleIndex = velocity < 0
                  ? (_cycleIndex + 1) % _todayItems.length
                  : (_cycleIndex - 1 + _todayItems.length) % _todayItems.length;
            });
          },
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Real auditorium/stage photo as the card background.
                Positioned.fill(
                  child: Image.asset(
                    'assets/live banner-clean.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Dark gradient overlay so the text stays readable.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF0A0E1A).withValues(alpha: 0.92),
                          const Color(0xFF0A0E1A).withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleDetailPage(
                          schedule: schedule,
                          event: event,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLive)
                                  const GlowingDot(color: Colors.white)
                                else
                                  const Icon(
                                    Icons.campaign_rounded,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  isLive ? 'LIVE NOW' : 'Next Session',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scheduleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          if (speakerName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // Fixed text height: the bigger photo overflows
                            // it without pushing the other lines apart.
                            SizedBox(
                              height: 16,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    right: speakerPhoto.isNotEmpty ? 52 : 0,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        speakerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: metaColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (speakerPhoto.isNotEmpty)
                                    Positioned(
                                      right: 0,
                                      top: -14,
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Image.network(
                                          speakerPhoto,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 3),
                          if (fromTime.isNotEmpty || hall.isNotEmpty)
                            Row(
                              children: [
                                if (fromTime.isNotEmpty &&
                                    toTime.isNotEmpty) ...[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: metaColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                                    style: metaStyle,
                                  ),
                                ],
                                if (hall.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: metaColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      hall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: metaStyle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Details',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_todayItems.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_todayItems.length, (i) {
              final active = i == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF60A5FA)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  /// Same "No Live Program / OFFLINE" state as the participant homepage.
  Widget _noLiveProgram() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.podcasts_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Live Program',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No live program is currently active',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OFFLINE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small dot with a soft pulsing glow, used for the "LIVE" indicator.
class GlowingDot extends StatefulWidget {
  final Color color;
  const GlowingDot({super.key, required this.color});

  @override
  State<GlowingDot> createState() => _GlowingDotState();
}

class _GlowingDotState extends State<GlowingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 6 + 10 * _pulse.value,
              height: 6 + 10 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.5 * (1 - _pulse.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
