import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../admin/presentation/widgets/event_package_sheet.dart'
    show eventDays;

class _Colors {
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
  final bool byAdmin;

  const _DayInclusion(this.name, this.claimedAt, {this.byAdmin = false});
}

/// Inclusions section displayed inside the profile screen or inclusions page.
class InclusionsSection extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool showHeader;

  const InclusionsSection({
    super.key,
    this.padding = EdgeInsets.zero,
    this.showHeader = true,
  });

  @override
  State<InclusionsSection> createState() => InclusionsSectionState();
}

class InclusionsSectionState extends State<InclusionsSection> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _packageName = '';
  List<({String? iso, String? label, List<_DayInclusion> items})> _days = [];

  /// Entry/exit gate scans per event day (yyyy-MM-dd), from the certificate progress.
  Map<String, ({DateTime? entryAt, DateTime? exitAt})> _scans = {};

  /// Re-checks every few seconds so a claim / entry / exit scan shows up right away.
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    load();
    _refresh = Timer.periodic(
      const Duration(seconds: 4),
      (_) => load(silent: true),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  /// Claims are counted per India date on the backend, so compare in IST.
  String _istDay(DateTime d) {
    final ist = d.toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.year}-${ist.month.toString().padLeft(2, '0')}-'
        '${ist.day.toString().padLeft(2, '0')}';
  }

  Future<void> load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await _api.getMyRegistration();
      if (!mounted) return;
      if (res['success'] != true) {
        if (silent) return;
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

      // Entry/exit scans for each day of the participant's package.
      final scans = <String, ({DateTime? entryAt, DateTime? exitAt})>{};
      final certRes = await _api.getMyCertificate();
      if (!mounted) return;
      if (certRes['success'] == true) {
        for (final d in (certRes['days'] as List?) ?? const []) {
          final m = Map<String, dynamic>.from(d as Map);
          DateTime? at(String k) =>
              DateTime.tryParse(m[k]?.toString() ?? '')?.toLocal();
          scans[m['date']?.toString() ?? ''] = (
            entryAt: at('entryAt'),
            exitAt: at('exitAt'),
          );
        }
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
            if (!dates.contains(day.iso)) continue;
            final name = i['name']?.toString() ?? '';
            items.add(claimOn(name, day.iso));
          }
          if (items.isNotEmpty) {
            result.add((iso: day.iso, label: day.label, items: items));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _packageName = reg['packageName']?.toString() ?? '';
        _days = result;
        _scans = scans;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load inclusions';
      });
    }
  }

  String _dayHeading(String iso, DateTime today) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final isToday = DateUtils.isSameDay(d, today);
    return '${DateFormat('EEEE, d MMM').format(d)}${isToday ? '  ·  Today' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _Colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 18,
                    color: _Colors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Package Inclusions',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_packageName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _Colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _Colors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _packageName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _Colors.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _Colors.accent,
          ),
        ),
      );
    }

    final empty = _days.isEmpty || _days.every((d) => d.items.isEmpty);
    if (_error != null || empty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: _Colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Colors.line),
        ),
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              size: 32,
              color: _Colors.muted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'No inclusions in your package',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: load,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: _Colors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to retry',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _Colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _days.length; i++) ...[
          if (_days[i].label != null)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 8),
              child: Text(
                _dayHeading(_days[i].iso!, today),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _Colors.muted,
                ),
              ),
            ),
          if (_days[i].iso != null && _scans[_days[i].iso] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _scanChip('Entry', _scans[_days[i].iso]!.entryAt),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _scanChip('Exit', _scans[_days[i].iso]!.exitAt),
                  ),
                ],
              ),
            ),
          // Two tiles per row, equal width; a row is as tall as its taller tile.
          for (var r = 0; r < _days[i].items.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _tile(_days[i].items[r])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: r + 1 < _days[i].items.length
                          ? _tile(_days[i].items[r + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Gate scan status for one day: scanned (with time) or not scanned.
  Widget _scanChip(String label, DateTime? at) {
    final scanned = at != null;
    final color = scanned ? _Colors.claimed : _Colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scanned ? _Colors.claimed.withValues(alpha: 0.08) : _Colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scanned
              ? _Colors.claimed.withValues(alpha: 0.45)
              : _Colors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            scanned
                ? Icons.check_circle_rounded
                : (label == 'Entry'
                      ? Icons.login_rounded
                      : Icons.logout_rounded),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  scanned
                      ? 'Scanned at ${DateFormat('h:mm a').format(at)}'
                      : 'Not scanned',
                  style: GoogleFonts.inter(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(_DayInclusion item) {
    final claimed = item.claimedAt != null;
    final color = claimed ? _Colors.claimed : _Colors.accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: claimed ? _Colors.claimed.withValues(alpha: 0.08) : _Colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimed
              ? _Colors.claimed.withValues(alpha: 0.45)
              : _Colors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  claimed
                      ? Icons.check_circle_rounded
                      : Icons.card_giftcard_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              // Status tag, pinned to the tile's top-right.
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: claimed
                          ? _Colors.claimed
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: claimed
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                    ),
                    child: Text(
                      claimed
                          ? (item.byAdmin ? 'CLAIMED BY ADMIN' : 'CLAIMED')
                          : 'Available',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: claimed ? 9.5 : 10.5,
                        fontWeight: claimed ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: claimed ? 0.6 : 0,
                        color: claimed ? Colors.white : _Colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            claimed
                ? '${item.byAdmin ? 'By admin' : 'Claimed'} at '
                      '${DateFormat('h:mm a').format(item.claimedAt!)}'
                : 'Not claimed yet',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: claimed ? _Colors.claimed : _Colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
