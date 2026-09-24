import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import 'schedule_detail_page.dart';

class _Colors {
  static const bg = Color(0xFF0A0A12);
  static const card = Color(0xFF14141F);
  static const muted = Color(0xFF9CA3AF);
  static const line = Color(0x14FFFFFF);
  static const live = Color(0xFF22C55E);
  static const upcoming = Color(0xFF3B82F6);
}

class _Item {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> event;
  final DateTime start;
  final DateTime end;

  const _Item(this.schedule, this.event, this.start, this.end);
}

/// Every session that hasn't ended yet (live first, then upcoming), in the
/// order they happen, grouped by day.
class UpcomingSchedulesPage extends StatefulWidget {
  const UpcomingSchedulesPage({super.key});

  @override
  State<UpcomingSchedulesPage> createState() => _UpcomingSchedulesPageState();
}

class _UpcomingSchedulesPageState extends State<UpcomingSchedulesPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<_Item> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _at(DateTime day, String? hhmm) {
    final p = (hhmm ?? '').split(':');
    final h = int.tryParse(p[0]);
    if (h == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      h,
      p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    );
  }

  Future<void> _load() async {
    final eventsRes = await _api.listManagedEvents();
    if (!mounted) return;
    if (eventsRes['success'] != true) {
      setState(() {
        _loading = false;
        _error = eventsRes['error']?.toString() ?? 'Could not load schedules';
      });
      return;
    }
    final events = ((eventsRes['events'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final now = DateTime.now();
    final items = <_Item>[];
    for (final event in events) {
      final eventId = event['id']?.toString() ?? event['_id']?.toString() ?? '';
      if (eventId.isEmpty) continue;
      final res = await _api.listEventSchedules(eventId);
      if (res['success'] != true) continue;
      for (final raw in (res['schedules'] as List?) ?? const []) {
        final s = Map<String, dynamic>.from(raw as Map);
        // Stored as UTC midnight of the calendar day; times are local "HH:mm".
        final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
        if (d == null) continue;
        final start = _at(d, s['fromTime']?.toString());
        final end = _at(d, s['toTime']?.toString());
        if (start == null || end == null || !end.isAfter(now)) continue;
        items.add(_Item(s, event, start, end));
      }
    }
    items.sort((a, b) => a.start.compareTo(b.start));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Schedule',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: _content(),
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    }
    if (_error != null || _items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(
            children: [
              const Icon(
                Icons.event_note_rounded,
                size: 44,
                color: _Colors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No upcoming sessions',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Pull down to try again.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: _Colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ];
    }

    final now = DateTime.now();
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final item in _items) {
      final day = DateTime(item.start.year, item.start.month, item.start.day);
      if (day != lastDay) {
        lastDay = day;
        final isToday = DateUtils.isSameDay(day, now);
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 14, bottom: 8),
            child: Text(
              isToday
                  ? 'Today · ${DateFormat('d MMM').format(day)}'
                  : DateFormat('EEEE, d MMM').format(day),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _Colors.muted,
              ),
            ),
          ),
        );
      }
      widgets.add(_row(item, now));
    }
    return widgets;
  }

  Widget _row(_Item item, DateTime now) {
    final isLive = !now.isBefore(item.start);
    final color = isLive ? _Colors.live : _Colors.upcoming;
    final hall = item.schedule['hall']?.toString() ?? '';
    final speaker = item.schedule['speakerName']?.toString() ?? '';
    final meta = [
      '${DateFormat('h:mm a').format(item.start)} - '
          '${DateFormat('h:mm a').format(item.end)}',
      if (hall.isNotEmpty) hall,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: _Colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLive ? color.withValues(alpha: 0.5) : _Colors.line,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailPage(
                  schedule: item.schedule,
                  event: item.event,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _Colors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.schedule['scheduleName']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (speaker.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            speaker,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _Colors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLive ? 'Live' : 'Upcoming',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
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
