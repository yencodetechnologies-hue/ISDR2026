import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import 'add_event_schedule_page.dart';

/// Schedules (speaker sessions) of one event, with an "Add Schedule" button.
class EventScheduleListPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isReadOnly;

  const EventScheduleListPage({
    super.key,
    required this.event,
    this.isReadOnly = false,
  });

  @override
  State<EventScheduleListPage> createState() => _EventScheduleListPageState();
}

class _EventScheduleListPageState extends State<EventScheduleListPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('EEE, d MMM yyyy');

  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;
  String? _error;
  DateTime _now = DateTime.now();
  Timer? _clock;

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Start/end of a schedule on its calendar day (the date is stored as a UTC day).
  ({DateTime start, DateTime end})? _window(Map<String, dynamic> s) {
    final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
    if (d == null) return null;
    DateTime at(String hhmm) {
      final p = hhmm.split(':');
      return DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0,
          p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
    }
    return (start: at(s['fromTime'].toString()), end: at(s['toTime'].toString()));
  }

  /// Banner for a schedule: live now, upcoming (today), tomorrow, a later date — null once over.
  ({String label, bool live})? _banner(Map<String, dynamic> s) {
    final w = _window(s);
    if (w == null) return null;
    if (!_now.isBefore(w.start) && _now.isBefore(w.end)) {
      return (label: 'LIVE', live: true);
    }
    if (!_now.isBefore(w.end)) return null;
    final today = DateTime(_now.year, _now.month, _now.day);
    final day = DateTime(w.start.year, w.start.month, w.start.day);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return (label: 'Upcoming', live: false);
    if (diff == 1) return (label: 'Tomorrow', live: false);
    return (label: DateFormat('d MMM').format(day), live: false);
  }

  /// Live schedules first, the rest keep their date/time order.
  List<Map<String, dynamic>> get _ordered {
    final live = <Map<String, dynamic>>[];
    final rest = <Map<String, dynamic>>[];
    for (final s in _schedules) {
      (_banner(s)?.live == true ? live : rest).add(s);
    }
    return [...live, ...rest];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _api.listEventSchedules(_eventId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _schedules = List<Map<String, dynamic>>.from(
          (res['schedules'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );
      } else {
        _error = res['error']?.toString() ?? 'Failed to load schedules';
      }
    });
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventSchedulePage(event: widget.event),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this schedule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.deleteEventSchedule(_eventId, s['id'].toString());
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Delete failed')),
      );
    }
  }

  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final t = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    return t.format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          widget.event['title']?.toString() ?? 'Schedules',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          if (!widget.isReadOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Schedule',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 10),
                            OutlinedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _schedules.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text('No schedules added yet',
                                        style: TextStyle(color: Colors.black54)),
                                  ),
                                ],
                              )
                            : Builder(builder: (_) {
                                final items = _ordered;
                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) => _card(items[i]),
                                );
                              }),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final photo = s['speakerPhoto']?.toString() ?? '';
    final utc = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
    final date = utc == null ? null : DateTime(utc.year, utc.month, utc.day);
    final banner = _banner(s);
    final desc = s['description']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.09),
            backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s['scheduleName']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor),
                      ),
                    ),
                    if (banner != null) ...[
                      const SizedBox(width: 8),
                      _StatusBanner(label: banner.label, live: banner.live),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  s['speakerName']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date != null ? _dateFmt.format(date) : ''} · '
                  '${_fmtTime(s['fromTime'].toString())} - ${_fmtTime(s['toTime'].toString())}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 12.5)),
                ],
              ],
            ),
          ),
          if (!widget.isReadOnly)
            IconButton(
              onPressed: () => _delete(s),
              icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
            ),
        ],
      ),
    );
  }
}

/// Small status pill; the live one has a pulsing green dot.
class _StatusBanner extends StatefulWidget {
  final String label;
  final bool live;

  const _StatusBanner({required this.label, required this.live});

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _StatusBanner old) {
    super.didUpdateWidget(old);
    if (widget.live && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.live && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final fg = live ? const Color(0xFF166534) : AppTheme.primaryColor;
    final bg = live ? const Color(0xFFDCFCE7) : AppTheme.primaryColor.withValues(alpha: 0.09);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 6 + 8 * _pulse.value,
                      height: 6 + 8 * _pulse.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E)
                            .withValues(alpha: 0.5 * (1 - _pulse.value)),
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: live ? 0.8 : 0.2,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
