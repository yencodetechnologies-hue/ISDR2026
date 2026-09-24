import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../admin/presentation/widgets/event_package_sheet.dart'
    show eventDays;

class _Colors {
  static const bg = Color(0xFF0A0A12);
  static const card = Color(0xFF14141F);
  static const muted = Color(0xFF9CA3AF);
  static const line = Color(0x14FFFFFF);
  static const accent = Color(0xFF60A5FA);
  static const claimed = Color(0xFF22C55E);
}

/// One inclusion on one event day, and the claim for that day (if any).
class _DayInclusion {
  final String name;
  final DateTime? claimedAt;

  /// Management re-registered this claim (e.g. after a mis-scan).
  final bool byAdmin;

  const _DayInclusion(this.name, this.claimedAt, {this.byAdmin = false});
}

/// Every inclusion in the participant's package, day by day. An inclusion can
/// be claimed once per day, so each day shows its own "Claimed" banner.
class InclusionsPage extends StatefulWidget {
  const InclusionsPage({super.key});

  @override
  State<InclusionsPage> createState() => _InclusionsPageState();
}

class _InclusionsPageState extends State<InclusionsPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _packageName = '';
  // (day label, iso date) → that day's inclusions. A null day means the event
  // has no dates, so inclusions are shown once without a day.
  List<({String? iso, String? label, List<_DayInclusion> items})> _days = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Claims are counted per India date on the backend, so compare in IST.
  String _istDay(DateTime d) {
    final ist = d.toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.year}-${ist.month.toString().padLeft(2, '0')}-'
        '${ist.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final res = await _api.getMyRegistration();
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['error']?.toString() ?? 'Failed to load inclusions';
      });
      return;
    }
    final reg = Map<String, dynamic>.from(res['registration'] as Map? ?? {});
    final inclusions = ((res['availableInclusions'] as List?) ?? const [])
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList();
    final claims = ((reg['claimedInclusions'] as List?) ?? const [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    // The event's days come from the event itself.
    final eventRes = await _api.getManagedEvent(
      reg['eventId']?.toString() ?? '',
    );
    if (!mounted) return;
    final event = eventRes['success'] == true && eventRes['event'] is Map
        ? Map<String, dynamic>.from(eventRes['event'] as Map)
        : <String, dynamic>{};

    String key(String? s) => (s ?? '').trim().toLowerCase();

    /// [name] on [iso] (or on any day when [iso] is null), with its claim if any.
    _DayInclusion claimOn(String name, String? iso) {
      for (final c in claims) {
        if (key(c['inclusionName']?.toString()) != key(name)) continue;
        final at = DateTime.tryParse(c['claimedAt']?.toString() ?? '');
        if (at == null) continue;
        if (iso == null || _istDay(at) == iso) {
          return _DayInclusion(
            name,
            at.toLocal(),
            byAdmin: c['reclaimedByAdmin'] == true,
          );
        }
      }
      return _DayInclusion(name, null);
    }

    final days = eventDays(event);
    final result =
        <({String? iso, String? label, List<_DayInclusion> items})>[];
    if (days.isEmpty) {
      result.add((
        iso: null,
        label: null,
        items: [
          for (final i in inclusions)
            claimOn(i['name']?.toString() ?? '', null),
        ],
      ));
    } else {
      for (final day in days) {
        final items = <_DayInclusion>[];
        for (final i in inclusions) {
          final dates = ((i['dates'] as List?) ?? const [])
              .map((d) => d.toString())
              .toList();
          // No dates = offered on every day of the event.
          if (dates.isNotEmpty && !dates.contains(day.iso)) continue;
          final name = i['name']?.toString() ?? '';
          items.add(claimOn(name, day.iso));
        }
        if (items.isNotEmpty) {
          result.add((iso: day.iso, label: day.label, items: items));
        }
      }
    }

    setState(() {
      _loading = false;
      _error = null;
      _packageName = reg['packageName']?.toString() ?? '';
      _days = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Inclusions',
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
    final empty = _days.every((d) => d.items.isEmpty);
    if (_error != null || empty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: 44,
                color: _Colors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No inclusions in your package',
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

    final today = DateUtils.dateOnly(DateTime.now());
    return [
      if (_packageName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Package: $_packageName',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _Colors.accent,
            ),
          ),
        ),
      for (var i = 0; i < _days.length; i++) ...[
        if (_days[i].label != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _dayHeading(_days[i].iso!, today),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _Colors.muted,
              ),
            ),
          ),
        for (final item in _days[i].items) _row(item),
      ],
    ];
  }

  String _dayHeading(String iso, DateTime today) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final isToday = DateUtils.isSameDay(d, today);
    return '${DateFormat('EEEE, d MMM').format(d)}${isToday ? '  ·  Today' : ''}';
  }

  Widget _row(_DayInclusion item) {
    final claimed = item.claimedAt != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: claimed ? _Colors.claimed.withValues(alpha: 0.08) : _Colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimed
              ? _Colors.claimed.withValues(alpha: 0.45)
              : _Colors.line,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (claimed ? _Colors.claimed : _Colors.accent).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                claimed
                    ? Icons.check_circle_rounded
                    : Icons.card_giftcard_rounded,
                size: 20,
                color: claimed ? _Colors.claimed : _Colors.accent,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  claimed
                      ? '${item.byAdmin ? 'Claimed by admin' : 'Claimed'} at '
                            '${DateFormat('h:mm a').format(item.claimedAt!)}'
                      : 'Not claimed yet',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: claimed ? _Colors.claimed : _Colors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (claimed)
            // "Claimed" banner on the card's right edge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
              color: _Colors.claimed,
              child: Text(
                item.byAdmin ? 'CLAIMED\nBY ADMIN' : 'CLAIMED',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
