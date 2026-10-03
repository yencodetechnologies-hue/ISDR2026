import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/delegate_badge.dart';
import '../widgets/event_package_sheet.dart';
import '../widgets/event_participant_sheet.dart';
import '../widgets/tick_box.dart';
import 'edit_managed_event_page.dart';

/// Full management view for an Events Management property's event — mirrors
/// the web `ManagementEventDetailsPage.jsx`: edit/delete event, packages with a
/// per-day inclusion matrix, participants with the full profile form, QR + ID number.
class EventManagementDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String? apartmentId;

  const EventManagementDetailsPage({
    super.key,
    required this.event,
    this.apartmentId,
  });

  @override
  State<EventManagementDetailsPage> createState() =>
      _EventManagementDetailsPageState();
}

class _EventManagementDetailsPageState
    extends State<EventManagementDetailsPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('EEE, d MMM yyyy');
  final _timeFmt = DateFormat('h:mm a');
  final _searchController = TextEditingController();

  late Map<String, dynamic> _event;
  List<Map<String, dynamic>> _registrations = [];
  bool _loadingRegs = true;
  bool _busy = false;
  String? _message;
  String _search = '';
  final Set<String> _expandedRegs = {};

  /// Scanned / not scanned / rejected counts keyed by 'package|inclusion'.
  Map<String, Map<String, dynamic>> _incStats = {};

  String get _eventId =>
      _event['id']?.toString() ?? _event['_id']?.toString() ?? '';

  bool get _isCancelled => _event['status']?.toString() == 'cancelled';

  List<Map<String, dynamic>> get _packages => List<Map<String, dynamic>>.from(
    (_event['packages'] as List? ?? []).map(
      (p) => Map<String, dynamic>.from(p as Map),
    ),
  );

  DateTime? _dateOf(String key) {
    final raw = _event[key];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  List<Map<String, dynamic>> get _filteredRegistrations {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _registrations;
    return _registrations.where((r) {
      return r.values.any(
        (v) =>
            (v is String || v is num) && v.toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _loadAll();
    _refresh = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadRegistrations(silent: true),
    );
  }

  /// Re-checks every few seconds so claims scanned at the counters show up right away.
  Timer? _refresh;

  @override
  void dispose() {
    _refresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadEvent(), _loadRegistrations()]);
    await _loadIncStats();
  }

  Future<void> _loadEvent() async {
    if (_eventId.isEmpty) return;
    final res = await _api.getManagedEvent(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    if (res['success'] == true && res['event'] is Map) {
      setState(() => _event = Map<String, dynamic>.from(res['event'] as Map));
      _loadIncStats();
    }
  }

  Future<void> _loadIncStats() async {
    if (_eventId.isEmpty) return;
    final res = await _api.getClaimSummary(eventId: _eventId, date: 'to-date');
    if (!mounted || res['success'] != true) return;
    final rows = (res['summary']?['inclusions'] as List?) ?? [];
    setState(() {
      _incStats = {
        for (final r in rows)
          '${r['packageName']}|${r['name']}': Map<String, dynamic>.from(
            r as Map,
          ),
      };
    });
  }

  Widget _statPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Future<void> _loadRegistrations({bool silent = false}) async {
    if (_eventId.isEmpty) {
      if (!silent) setState(() => _loadingRegs = false);
      return;
    }
    if (!silent) setState(() => _loadingRegs = true);
    final res = await _api.listManagedEventRegistrations(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    // Keep the list on screen if a background refresh fails.
    if (silent && res['success'] != true) return;
    setState(() {
      _loadingRegs = false;
      _registrations = List<Map<String, dynamic>>.from(
        (res['registrations'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      );
    });
    _loadIncStats();
  }

  void _showMessage(String msg) {
    setState(() => _message = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editEvent() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditManagedEventPage(
          event: _event,
          apartmentId: widget.apartmentId,
          isEventsProperty: true,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _event = {..._event, ...updated});
      _showMessage('Event updated');
      await _loadEvent();
    }
  }

  Future<void> _cancelEvent() async {
    if (!await _confirm('Cancel event?', 'Yes')) return;
    setState(() => _busy = true);
    final res = await _api.cancelManagedEvent(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      if (res['event'] is Map)
        setState(() => _event = Map<String, dynamic>.from(res['event'] as Map));
      _showMessage('Event cancelled');
    } else {
      _showMessage(res['error']?.toString() ?? 'Cancel failed');
    }
  }

  Future<void> _deleteEvent() async {
    if (!await _confirm(
      'Delete "${_event['title']}" and all its participants permanently?',
      'Delete',
    ))
      return;
    setState(() => _busy = true);
    final res = await _api.deleteManagedEventPermanently(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      Navigator.pop(context, {'status': 'deleted'});
    } else {
      _showMessage(res['error']?.toString() ?? 'Delete failed');
    }
  }

  Future<void> _savePackages(
    List<Map<String, dynamic>> next,
    String okMessage,
  ) async {
    setState(() => _busy = true);
    final res = await _api.updateManagedEvent(
      eventId: _eventId,
      packages: next,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      if (res['event'] is Map)
        setState(() => _event = Map<String, dynamic>.from(res['event'] as Map));
      _loadIncStats();
      _showMessage(okMessage);
    } else {
      _showMessage(res['error']?.toString() ?? 'Failed to save package');
    }
  }

  Future<void> _openPackageSheet([Map<String, dynamic>? existing]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventPackageSheet(event: _event, existing: existing),
    );
    if (result == null) return;
    final current = _packages;
    final next = existing == null
        ? [...current, result]
        : current.map((p) => p['id'] == existing['id'] ? result : p).toList();
    await _savePackages(
      next,
      existing == null ? 'Package added' : 'Package updated',
    );
  }

  Future<void> _removePackage(String packageId) async {
    if (!await _confirm('Remove this package?', 'Remove')) return;
    await _savePackages(
      _packages.where((p) => p['id'] != packageId).toList(),
      'Package removed',
    );
  }

  Future<void> _openParticipantSheet([Map<String, dynamic>? reg]) async {
    final selfId = reg == null ? null : (reg['id'] ?? reg['_id']);
    final existingIds = _registrations
        .where((r) => (r['id'] ?? r['_id']) != selfId)
        .map((r) => (r['idNumber'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventParticipantSheet(
        eventId: _eventId,
        apartmentId: widget.apartmentId,
        packages: _packages,
        registration: reg,
        existingIdNumbers: existingIds,
        api: _api,
      ),
    );
    if (saved == null) return;
    await _loadAll();
    if (!mounted) return;
    if (reg == null) {
      if (saved.isNotEmpty) _openQrView(saved);
    } else {
      _showMessage('Participant updated successfully');
    }
  }

  Future<void> _deleteParticipant(Map<String, dynamic> reg) async {
    if (!await _confirm('Delete registration for "${reg['name']}"?', 'Delete'))
      return;
    setState(() => _busy = true);
    final res = await _api.deleteEventRegistration(
      eventId: _eventId,
      registrationId: (reg['id'] ?? reg['_id']).toString(),
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      _showMessage('Participant deleted');
      await _loadAll();
    } else {
      _showMessage(res['error']?.toString() ?? 'Failed to delete participant');
    }
  }

  void _openQrView(Map<String, dynamic> reg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParticipantQrSheet(registration: reg),
    );
  }

  Widget _rateBadge(Map<String, dynamic> p) {
    final rate = num.tryParse(p['rate']?.toString() ?? '') ?? 0;
    final mode = p['paymentMode']?.toString() ?? '';
    final text = rate == 0
        ? 'Free'
        : '₹$rate${mode.isNotEmpty ? ' · ${paymentModeLabel(mode)}' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: rate == 0 ? const Color(0x2622C55E) : const Color(0x263B82F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: rate == 0 ? const Color(0xFF86EFAC) : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _packageCard(Map<String, dynamic> p) {
    final days = eventDays(_event);
    final inclusions = normalizeInclusions(p['inclusions']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _rateBadge(p),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final eeDates = (p['entryExitDates'] as List? ?? [])
                    .map((d) => d.toString())
                    .toList();
                final count = eeDates.isNotEmpty ? eeDates.length : days.length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F22C55E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4D22C55E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        size: 14,
                        color: Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Entry & Exit: $count of ${days.length} ${days.length == 1 ? 'day' : 'days'} authorized',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF86EFAC),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (inclusions.isEmpty)
              const Text(
                'No inclusions added.',
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 12.5,
                ),
              )
            else
              ...inclusions.map((inc) {
                final dates = (inc['dates'] as List)
                    .map((d) => d.toString())
                    .toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              inc['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...[
                        const SizedBox(height: 4),
                        Builder(
                          builder: (_) {
                            final st =
                                _incStats['${p['name']}|${inc['name']}'] ??
                                const <String, dynamic>{};
                            return Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _statPill(
                                  '${st['scanned'] ?? 0} Scanned',
                                  const Color(0xFF16A34A),
                                ),
                                _statPill(
                                  '${st['notScanned'] ?? 0} Not scanned',
                                  const Color(0xFFD97706),
                                ),
                                _statPill(
                                  '${st['rejected'] ?? 0} Rejected',
                                  const Color(0xFFDC2626),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (days.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: days
                              .map(
                                (d) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TickBox(value: dates.contains(d.iso)),
                                    const SizedBox(width: 3),
                                    Text(
                                      d.label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _openPackageSheet(p),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _removePackage(p['id'].toString()),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClaimedInclusions(Map<String, dynamic> r) {
    final name = [
      r['title'],
      r['firstName'],
      r['middleName'],
      r['lastName'],
    ].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join(' ');
    final regId = (r['id'] ?? r['_id']).toString();
    final claims = List<Map<String, dynamic>>.from(
      (r['claimedInclusions'] as List?)?.map(
            (c) => Map<String, dynamic>.from(c as Map),
          ) ??
          [],
    );
    final fmt = DateFormat('d MMM, h:mm a');
    String? busyId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> reclaim(Map<String, dynamic> c) async {
            final claimId = c['id']?.toString();
            if (claimId == null || claimId.isEmpty) return;
            setSheetState(() => busyId = claimId);
            final res = await _api.reclaimInclusion(
              eventId: _eventId,
              regId: regId,
              claimId: claimId,
            );
            if (res['success'] == true) {
              final updated = List<Map<String, dynamic>>.from(
                (res['registration']?['claimedInclusions'] as List?)?.map(
                      (e) => Map<String, dynamic>.from(e as Map),
                    ) ??
                    [],
              );
              setSheetState(() {
                claims
                  ..clear()
                  ..addAll(updated);
                busyId = null;
              });
              _loadRegistrations();
            } else {
              setSheetState(() => busyId = null);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['error']?.toString() ?? 'Failed to reclaim',
                    ),
                  ),
                );
              }
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Claimed Inclusions',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (claims.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No inclusions claimed yet',
                        style: TextStyle(color: const Color(0xFF9CA3AF)),
                      ),
                    )
                  else
                    ...claims.map((c) {
                      final inclName = c['inclusionName']?.toString() ?? '';
                      final claimId = c['id']?.toString() ?? '';
                      final at = DateTime.tryParse(
                        c['claimedAt']?.toString() ?? '',
                      );
                      final isBusy = busyId == claimId;
                      final byAdmin = c['reclaimedByAdmin'] == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          inclName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (byAdmin) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF3B82F6,
                                            ).withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'By Admin',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (at != null)
                                    Text(
                                      fmt.format(at.toLocal()),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: isBusy ? null : () => reclaim(c),
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.replay_rounded, size: 16),
                              label: const Text('Reclaim'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _participantCard(Map<String, dynamic> r) {
    String v(String k) => r[k]?.toString() ?? '';
    final displayName = [
      v('title'),
      v('firstName'),
      v('middleName'),
      v('lastName'),
    ].where((e) => e.isNotEmpty).join(' ');
    final photo = v('photoUrl');
    final claimed = (r['claimedInclusions'] as List? ?? []).length;
    final line = [
      if (v('designation').isNotEmpty) v('designation'),
      if (v('institution').isNotEmpty) v('institution'),
    ].join(' · ');
    Widget info(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: const Color(0xFF9CA3AF)),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
          );
    final regId = (r['id'] ?? r['_id']).toString();
    final expanded = _expandedRegs.contains(regId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          if (!_expandedRegs.remove(regId)) _expandedRegs.add(regId);
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF1E1E2A),
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo)
                        : null,
                    child: photo.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: const Color(0xFF9CA3AF),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? v('name') : displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        if (line.isNotEmpty)
                          Text(
                            line,
                            style: const TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      v('idNumber'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: !expanded
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFF1E1E2A)),
                          const SizedBox(height: 8),
                          info(
                            'Type',
                            RegExp(r'^spot register$', caseSensitive: false).hasMatch(v('packageName'))
                                ? ''
                                : v('participantType'),
                          ),
                          info('Package', v('packageName')),
                          info('Gender', v('gender')),
                          info('Mobile', v('mobileNumber')),
                          info('Email', v('email')),
                          info('ID no.', v('idNumber')),
                          info('Food', v('foodPreference')),
                          info(
                            'Payment',
                            [
                              v('paymentMode'),
                              v('utrNumber'),
                            ].where((e) => e.isNotEmpty).join(' · '),
                          ),
                          info('Address', v('address')),
                          if (claimed > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: OutlinedButton.icon(
                                onPressed: () => _showClaimedInclusions(r),
                                icon: const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'Claimed: $claimed inclusion${claimed == 1 ? '' : 's'}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF16A34A),
                                  side: const BorderSide(
                                    color: Color(0xFF16A34A),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openParticipantSheet(r),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              IconButton(
                                tooltip: 'QR',
                                onPressed: () => _openQrView(r),
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: _busy
                                    ? null
                                    : () => _deleteParticipant(r),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),
                        ],
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
    final start = _dateOf('eventDate');
    final end = _dateOf('eventEndDate');
    final shown = _filteredRegistrations;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        title: Text(_event['title']?.toString() ?? 'Event'),
        backgroundColor: const Color(0xFF0A0A12),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Edit event',
            onPressed: _busy ? null : _editEvent,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (!_isCancelled)
            IconButton(
              tooltip: 'Cancel event',
              onPressed: _busy ? null : _cancelEvent,
              icon: const Icon(Icons.cancel_outlined),
            ),
          IconButton(
            tooltip: 'Delete event',
            onPressed: _busy ? null : _deleteEvent,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message!,
                  style: const TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((_event['photoUrl']?.toString() ?? '').isNotEmpty)
                    Image.network(
                      _event['photoUrl'].toString(),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _event['title']?.toString() ?? 'Event',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _isCancelled
                                    ? const Color(0x26EF4444)
                                    : const Color(0x2622C55E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (_event['status'] ?? 'Active').toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _isCancelled
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFF86EFAC),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((_event['venue']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '📍 ${_event['venue']}',
                            style: const TextStyle(
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                        if (start != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${_dateFmt.format(start)} · ${_timeFmt.format(start)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (end != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'to ${_dateFmt.format(end)} · ${_timeFmt.format(end)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${_event['bookedCount'] ?? 0} registered',
                          style: const TextStyle(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                        if ((_event['description']?.toString() ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_event['description'].toString()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Packages (${_packages.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _openPackageSheet(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Package'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_packages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No packages added yet.',
                  style: TextStyle(color: const Color(0xFF9CA3AF)),
                ),
              )
            else
              ..._packages.map(_packageCard),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _search.isEmpty
                        ? 'Participants (${_registrations.length})'
                        : 'Participants (${shown.length} of ${_registrations.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _openParticipantSheet(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search participants…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1E1E2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingRegs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _registrations.isEmpty
                      ? 'No participants registered for this event yet.'
                      : 'No participants match your search.',
                  style: const TextStyle(color: const Color(0xFF9CA3AF)),
                ),
              )
            else
              ...shown.map(_participantCard),
          ],
        ),
      ),
    );
  }
}

/// Shows a participant's ticket QR + code, with share/save actions —
/// mirrors the web "QR" popup's download action.
class _ParticipantQrSheet extends StatefulWidget {
  final Map<String, dynamic> registration;
  const _ParticipantQrSheet({required this.registration});

  @override
  State<_ParticipantQrSheet> createState() => _ParticipantQrSheetState();
}

class _ParticipantQrSheetState extends State<_ParticipantQrSheet> {
  final GlobalKey _qrKey = GlobalKey();

  Future<Uint8List?> _captureQrCode() async {
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: 1181 / boundary.size.width,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// PNG pHYs so the saved image is 100 mm × 130 mm at 300 dpi.
  Uint8List _stampPngDpi(Uint8List src, int dpi) {
    final ppm = (dpi / 0.0254).round();
    final data = ByteData(9);
    data.setUint32(0, ppm);
    data.setUint32(4, ppm);
    data.setUint8(8, 1);
    final typeAndData = Uint8List(13);
    typeAndData.setAll(0, [0x70, 0x48, 0x59, 0x73]);
    typeAndData.setRange(4, 13, data.buffer.asUint8List());
    var crc = 0xFFFFFFFF;
    for (final b in typeAndData) {
      crc = (crc ^ b) & 0xFFFFFFFF;
      for (var k = 0; k < 8; k++) {
        final mixed = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1);
        crc = mixed & 0xFFFFFFFF;
      }
    }
    crc = (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
    final chunk = BytesBuilder();
    final len = ByteData(4)..setUint32(0, 9);
    chunk.add(len.buffer.asUint8List());
    chunk.add(typeAndData);
    final crcBytes = ByteData(4)..setUint32(0, crc);
    chunk.add(crcBytes.buffer.asUint8List());
    final phys = chunk.toBytes();

    var offset = 8;
    while (offset + 8 <= src.length) {
      final view = ByteData.sublistView(src, offset, offset + 8);
      final chunkLen = view.getUint32(0);
      final type = String.fromCharCodes(src.sublist(offset + 4, offset + 8));
      if (type == 'IDAT' || type == 'IEND' || type == 'pHYs') {
        final out = BytesBuilder();
        out.add(src.sublist(0, offset));
        out.add(phys);
        out.add(src.sublist(type == 'pHYs' ? offset + 12 + chunkLen : offset));
        return out.toBytes();
      }
      offset += 12 + chunkLen;
    }
    return src;
  }

  Future<void> _download() async {
    final bytes = await _captureQrCode();
    if (bytes == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/badge_${widget.registration['idNumber'] ?? 'qr'}.png',
      );
      await file.writeAsBytes(_stampPngDpi(bytes, 300));
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Badge saved to gallery')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving QR code: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = widget.registration;
    final qrData = reg['qrCode']?.toString() ?? '';
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: _qrKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: DelegateBadge(registration: reg),
              ),
            ),
            // Speakers' badges can't be downloaded.
            if (reg['participantType']?.toString().trim().toLowerCase() !=
                'speaker') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: qrData.isEmpty ? null : _download,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download badge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
