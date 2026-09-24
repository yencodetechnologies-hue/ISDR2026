import 'package:cached_network_image/cached_network_image.dart';
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
  static const accent = Color(0xFF60A5FA);
}

/// One session of a speaker, with its start/end resolved to local time.
class _Session {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> event;
  final DateTime start;
  final DateTime end;

  const _Session(this.schedule, this.event, this.start, this.end);
}

/// A speaker and all their sessions (earliest first).
class _Speaker {
  final String name;
  final String photo;
  final List<_Session> sessions;

  _Speaker(this.name, this.photo) : sessions = [];
}

/// Every speaker across the events, ordered by when they first speak.
/// A speaker with several sessions is listed once, with each session below.
class SpeakersPage extends StatefulWidget {
  const SpeakersPage({super.key});

  @override
  State<SpeakersPage> createState() => _SpeakersPageState();
}

class _SpeakersPageState extends State<SpeakersPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<_Speaker> _speakers = [];

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
        _error = eventsRes['error']?.toString() ?? 'Could not load speakers';
      });
      return;
    }
    final events = ((eventsRes['events'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final sessions = <_Session>[];
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
        if (start == null || end == null) continue;
        sessions.add(_Session(s, event, start, end));
      }
    }
    sessions.sort((a, b) => a.start.compareTo(b.start));

    // Group by speaker name; insertion order = order of their first session.
    final byName = <String, _Speaker>{};
    for (final s in sessions) {
      final name = s.schedule['speakerName']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final speaker = byName.putIfAbsent(
        name.toLowerCase(),
        () => _Speaker(name, s.schedule['speakerPhoto']?.toString() ?? ''),
      );
      speaker.sessions.add(s);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
      _speakers = byName.values.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Speakers',
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
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_error != null || _speakers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 44,
                      color: _Colors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'No speakers yet',
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
              )
            else
              for (var i = 0; i < _speakers.length; i++)
                _speakerCard(i + 1, _speakers[i]),
          ],
        ),
      ),
    );
  }

  Widget _speakerCard(int number, _Speaker speaker) {
    final initials = speaker.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w != 'Dr.')
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$number',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _Colors.muted,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF1E3A8A),
                backgroundImage: speaker.photo.isNotEmpty
                    ? CachedNetworkImageProvider(speaker.photo)
                    : null,
                child: speaker.photo.isEmpty
                    ? Text(
                        initials.isEmpty ? '?' : initials,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speaker.name,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      speaker.sessions.length == 1
                          ? '1 session'
                          : '${speaker.sessions.length} sessions',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: _Colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in speaker.sessions) _sessionRow(s),
        ],
      ),
    );
  }

  Widget _sessionRow(_Session s) {
    final hall = s.schedule['hall']?.toString() ?? '';
    final when =
        '${DateFormat('EEE, d MMM').format(s.start)}  ·  '
        '${DateFormat('h:mm a').format(s.start)} - '
        '${DateFormat('h:mm a').format(s.end)}'
        '${hall.isEmpty ? '' : '  ·  $hall'}';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ScheduleDetailPage(schedule: s.schedule, event: s.event),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.schedule['scheduleName']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _Colors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _Colors.muted),
          ],
        ),
      ),
    );
  }
}
