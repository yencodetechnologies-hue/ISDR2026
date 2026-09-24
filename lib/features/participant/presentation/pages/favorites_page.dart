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
  static const hot = Color(0xFFF97316);
}

/// The participant's hot-marked schedules (saved on their account), grouped
/// by day. Turning hot off here removes it from the list.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic> _events = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.getMyFavorites();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _schedules = ((res['schedules'] as List?) ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        _events = res['events'] is Map
            ? Map<String, dynamic>.from(res['events'] as Map)
            : {};
      } else {
        _error = res['error']?.toString() ?? 'Could not load favorites';
      }
    });
  }

  Future<void> _unfavorite(Map<String, dynamic> s) async {
    final index = _schedules.indexOf(s);
    setState(() => _schedules.remove(s));
    final res = await _api.toggleFavoriteSchedule(s['id'].toString());
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _schedules.insert(index.clamp(0, _schedules.length), s));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not update')),
      );
    }
  }

  /// Calendar day of a schedule (stored as UTC midnight of that day).
  DateTime? _day(Map<String, dynamic> s) {
    final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  String _fmtTime(String hhmm) {
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
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Favorites',
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
          children: _buildContent(),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    }
    if (_error != null || _schedules.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(
            children: [
              Icon(
                _error != null
                    ? Icons.error_outline_rounded
                    : Icons.local_fire_department_outlined,
                size: 44,
                color: _Colors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No favorites yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _error != null
                    ? 'Pull down to try again.'
                    : 'Tap the 🔥 hot button on a session to add it here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: _Colors.muted),
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final s in _schedules) {
      final day = _day(s);
      if (day != null && day != lastDay) {
        lastDay = day;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 14, bottom: 8),
            child: Text(
              DateFormat('EEEE, d MMM').format(day),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _Colors.muted,
              ),
            ),
          ),
        );
      }
      widgets.add(_row(s));
    }
    return widgets;
  }

  Widget _row(Map<String, dynamic> s) {
    final event = _events[s['eventId']?.toString()];
    final from = s['fromTime']?.toString() ?? '';
    final to = s['toTime']?.toString() ?? '';
    final hall = s['hall']?.toString() ?? '';
    final speaker = s['speakerName']?.toString() ?? '';
    final meta = [
      if (from.isNotEmpty && to.isNotEmpty)
        '${_fmtTime(from)} - ${_fmtTime(to)}',
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
            border: Border.all(color: _Colors.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailPage(
                  schedule: s,
                  event: event is Map
                      ? Map<String, dynamic>.from(event)
                      : const <String, dynamic>{},
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (meta.isNotEmpty)
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
                          s['scheduleName']?.toString() ?? '',
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
                  IconButton(
                    tooltip: 'Remove hot',
                    icon: const Icon(
                      Icons.local_fire_department_rounded,
                      color: _Colors.hot,
                    ),
                    onPressed: () => _unfavorite(s),
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
