import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../programme.dart';
import 'schedule_detail_page.dart';

/// Every session of the event ("View All" on the home's Today's Schedule),
/// with "All Sessions" and Day 1, Day 2… tabs.
///
/// [items] are the home page's schedule items: {schedule, event, start, end}.
/// [days] are the event's days in order (Day 1 = first day).
class AllSessionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<DateTime> days;
  final DateTime? initialDay;

  const AllSessionsPage({
    super.key,
    this.items = const [],
    this.days = const [],
    this.initialDay,
  });

  @override
  State<AllSessionsPage> createState() => _AllSessionsPageState();
}

class _AllSessionsPageState extends State<AllSessionsPage> {
  DateTime? _day; // null = All Sessions
  List<Map<String, dynamic>> _items = [];
  List<DateTime> _days = [];
  bool _loading = false;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    if (widget.items.isNotEmpty) {
      _items = List.of(widget.items);
      _days = List.of(widget.days);
    } else {
      _fetchSessions();
    }
  }

  Future<void> _fetchSessions() async {
    setState(() => _loading = true);
    try {
      final eventsRes = await _api.listManagedEvents();
      if (eventsRes['success'] == true) {
        final events = List<Map<String, dynamic>>.from(
          (eventsRes['events'] as List?)?.map(
                (e) => Map<String, dynamic>.from(e as Map),
              ) ??
              [],
        );
        final allList = <Map<String, dynamic>>[];
        final eventDays = <DateTime>{};

        for (final event in events) {
          final eventId =
              event['id']?.toString() ?? event['_id']?.toString() ?? '';
          if (eventId.isEmpty) continue;

          final startStr = event['eventDate']?.toString();
          final endStr =
              (event['eventEndDate'] ?? event['eventDate'])?.toString();
          if (startStr != null) {
            final startD = DateTime.tryParse(startStr)?.toUtc();
            final endD =
                (endStr != null ? DateTime.tryParse(endStr)?.toUtc() : null) ??
                startD;
            if (startD != null) {
              var cur = DateTime.utc(startD.year, startD.month, startD.day);
              final endClean = DateTime.utc(endD!.year, endD.month, endD.day);
              while (!cur.isAfter(endClean) && eventDays.length < 60) {
                eventDays.add(DateTime(cur.year, cur.month, cur.day));
                cur = cur.add(const Duration(days: 1));
              }
            }
          }

          final schedRes = await _api.listEventSchedules(eventId);
          if (schedRes['success'] != true) continue;
          final schedules = List<Map<String, dynamic>>.from(
            (schedRes['schedules'] as List?)?.map(
                  (s) => Map<String, dynamic>.from(s as Map),
                ) ??
                [],
          );

          for (final s in schedules) {
            final fromRaw = s['fromTime']?.toString().trim() ?? '';
            final toRaw = s['toTime']?.toString().trim() ?? '';
            final hasTime = fromRaw.isNotEmpty && toRaw.isNotEmpty;
            final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
            if (d == null) {
              allList.add({
                'schedule': s,
                'event': event,
                'hasTime': false,
              });
              continue;
            }
            final fromParts = fromRaw.split(':');
            final toParts = toRaw.split(':');
            final start = DateTime(
              d.year,
              d.month,
              d.day,
              hasTime ? int.tryParse(fromParts[0]) ?? 0 : 0,
              hasTime && fromParts.length > 1
                  ? int.tryParse(fromParts[1]) ?? 0
                  : 0,
            );
            final end = hasTime
                ? DateTime(
                    d.year,
                    d.month,
                    d.day,
                    int.tryParse(toParts[0]) ?? 0,
                    toParts.length > 1 ? int.tryParse(toParts[1]) ?? 0 : 0,
                  )
                : start;
            allList.add({
              'schedule': s,
              'event': event,
              'start': start,
              'end': end,
              'hasTime': hasTime,
            });
            eventDays.add(DateTime(d.year, d.month, d.day));
          }
        }

        if (mounted) {
          setState(() {
            _items = allList;
            _days = eventDays.toList()..sort();
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> get _shown {
    final source = _items.isNotEmpty ? _items : widget.items;
    final list = source.where((i) {
      final start = i['start'];
      if (_day == null) return true;
      return start is DateTime && _sameDay(start, _day!);
    }).toList();
    list.sort((a, b) {
      final as = a['start'];
      final bs = b['start'];
      if (as is! DateTime && bs is! DateTime) return 0;
      if (as is! DateTime) return 1;
      if (bs is! DateTime) return -1;
      return as.compareTo(bs);
    });
    return list;
  }

  List<Widget> _sectioned(List<Map<String, dynamic>> shown) {
    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    final undated = <Map<String, dynamic>>[];
    for (final item in shown) {
      final start = item['start'];
      if (start is! DateTime) {
        undated.add(item);
        continue;
      }
      final day = DateTime(start.year, start.month, start.day);
      byDay.putIfAbsent(day, () => []).add(item);
    }
    final widgets = <Widget>[];
    for (final day in byDay.keys) {
      if (_day == null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 12, bottom: 8),
            child: Text(
              DateFormat('EEEE, d MMM').format(day),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white60,
              ),
            ),
          ),
        );
      }
      final halls = <String, List<Map<String, dynamic>>>{};
      for (final item in byDay[day]!) {
        final schedule = Map<String, dynamic>.from(item['schedule'] as Map);
        final hall = schedule['hall']?.toString().trim() ?? '';
        halls.putIfAbsent(hall.isEmpty ? 'Other' : hall, () => []).add(item);
      }
      final hallNames = halls.keys.toList()
        ..sort((a, b) => programmeHallRank(a).compareTo(programmeHallRank(b)));
      for (final hall in hallNames) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Color(0xFF93C5FD),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hall,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF93C5FD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        for (final item in halls[hall]!) {
          widgets.add(_SessionCard(item: item));
        }
      }
    }
    if (undated.isNotEmpty && _day == null) {
      final halls = <String, List<Map<String, dynamic>>>{};
      for (final item in undated) {
        final schedule = Map<String, dynamic>.from(item['schedule'] as Map);
        final hall = schedule['hall']?.toString().trim() ?? '';
        halls.putIfAbsent(hall.isEmpty ? 'Other' : hall, () => []).add(item);
      }
      final hallNames = halls.keys.toList()
        ..sort((a, b) => programmeHallRank(a).compareTo(programmeHallRank(b)));
      for (final hall in hallNames) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Color(0xFF93C5FD),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hall,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF93C5FD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        for (final item in halls[hall]!) {
          widgets.add(_SessionCard(item: item));
        }
      }
    }
    return widgets;
  }

  String get _eventTitle {
    final source = _items.isNotEmpty ? _items : widget.items;
    for (final i in source) {
      final t = (i['event'] as Map?)?['title']?.toString() ?? '';
      if (t.isNotEmpty) return t;
    }
    return 'All Sessions';
  }

  /// The event is named "ISDR 2026", which the header already shows.
  bool get _titleRepeatsBrand {
    final n = _eventTitle.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return n == 'isdr 2026' || n == 'isdr2026';
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF111A3D),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          Container(
            width: 1,
            height: 58,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFC084FC), Color(0xFF60A5FA)],
                  ).createShader(r),
                  child: Text(
                    'ISDR 2026',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                if (!_titleRepeatsBrand)
                  Text(
                    _eventTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  'Innovate  •  Collaborate  •  Build the Future',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.location_city_rounded,
            size: 46,
            color: const Color(0xFF3B82F6).withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, DateTime? day) {
    final active =
        (day == null && _day == null) ||
        (day != null && _day != null && _sameDay(day, _day!));
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _day = day),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                  )
                : null,
            color: active ? null : const Color(0xFF0E1638),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active
                  ? const Color(0xFFA78BFA)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B1F),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF60A5FA)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shown = _shown;
    final days = _days.isNotEmpty ? _days : widget.days;
    return Scaffold(
      backgroundColor: const Color(0xFF070B1F),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                children: [
                  _tab('All Sessions', Icons.event_note_rounded, null),
                  for (var i = 0; i < days.length; i++)
                    _tab(
                      'Day ${i + 1}  ·  ${DateFormat('d MMM').format(days[i])}',
                      Icons.calendar_today_rounded,
                      days[i],
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions on this day',
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                      children: _sectioned(shown),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SessionCard({required this.item});

  static const _ringColors = [
    [Color(0xFF3B82F6), Color(0xFFA855F7)],
    [Color(0xFFA855F7), Color(0xFF22D3EE)],
    [Color(0xFFF97316), Color(0xFFA855F7)],
    [Color(0xFF22C55E), Color(0xFF22D3EE)],
  ];

  @override
  Widget build(BuildContext context) {
    final s = Map<String, dynamic>.from(item['schedule'] as Map);
    final event = Map<String, dynamic>.from(item['event'] as Map);
    final start = item['start'];
    final end = item['end'];
    final fromRaw = s['fromTime']?.toString().trim() ?? '';
    final toRaw = s['toTime']?.toString().trim() ?? '';
    final hasTime =
        fromRaw.isNotEmpty &&
        toRaw.isNotEmpty &&
        start is DateTime &&
        end is DateTime;
    final now = DateTime.now();
    final live = hasTime && !now.isBefore(start) && now.isBefore(end);
    final done = hasTime && !now.isBefore(end);
    final speakers = splitSpeakerNames(s['speakerName']?.toString());
    final photo = s['speakerPhoto']?.toString() ?? '';
    final hall = s['hall']?.toString() ?? '';
    final ringKey = speakers.isEmpty
        ? (s['scheduleName']?.toString() ?? '')
        : speakers.first;
    final ring = _ringColors[ringKey.hashCode.abs() % _ringColors.length];
    final muted = Colors.white.withValues(alpha: 0.8);

    Widget meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF93C5FD)),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11.5, color: muted)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: live
                  ? const [Color(0xFF0B3B3A), Color(0xFF0C2446)]
                  : const [Color(0xFF0C1640), Color(0xFF0B1230)],
            ),
            border: Border.all(
              color: live
                  ? const Color(0xFF34D399)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.35),
              width: live ? 1.6 : 1.1,
            ),
            boxShadow: live
                ? [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailPage(schedule: s, event: event),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (speakers.isNotEmpty || photo.isNotEmpty) ...[
                    Container(
                      width: 74,
                      height: 74,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: ring),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.5),
                        child: photo.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photo,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                s['scheduleName']?.toString() ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (hasTime && live)
                              _status('LIVE', const Color(0xFF22C55E))
                            else if (hasTime && done)
                              _status('ENDED', const Color(0xFF94A3B8)),
                          ],
                        ),
                        for (final speaker in speakers)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              speaker,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF60A5FA),
                                height: 1.25,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (hasTime)
                              meta(
                                Icons.access_time_rounded,
                                '${DateFormat('h:mm a').format(start)} - '
                                '${DateFormat('h:mm a').format(end)}',
                              ),
                            if (hall.isNotEmpty)
                              meta(Icons.location_on_rounded, hall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1E3A8A),
    child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFFBFDBFE)),
  );

  Widget _status(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
