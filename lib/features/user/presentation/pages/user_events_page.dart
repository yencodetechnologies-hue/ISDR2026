import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';

/// Events list for a resident/staff login on an Events Management property.
/// Mirrors the web "Events" page (`UserEventTicketsPage.jsx`).
class UserEventsListPage extends StatefulWidget {
  final String? apartmentId;
  const UserEventsListPage({super.key, this.apartmentId});

  @override
  State<UserEventsListPage> createState() => _UserEventsListPageState();
}

class _UserEventsListPageState extends State<UserEventsListPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _api.listManagedEvents(apartmentId: widget.apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _events = List<Map<String, dynamic>>.from(
          (res['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['error']?.toString() ?? 'Failed to load events';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
                      ),
                    ],
                  )
                : _events.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 140),
                          Center(
                            child: Text(
                              'No events created yet for this property.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final ev = _events[index];
                          final id = (ev['id'] ?? ev['_id']).toString();
                          final photoUrl = (ev['photoUrl'] ?? '').toString();
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserEventDetailsPage(
                                      eventId: id,
                                      apartmentId: widget.apartmentId,
                                    ),
                                  ),
                                ).then((_) => _load());
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (photoUrl.isNotEmpty)
                                    Image.network(
                                      photoUrl,
                                      height: 140,
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
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (ev['status'] == 'published') ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                (ev['status'] ?? 'active').toString().toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: (ev['status'] == 'published') ? const Color(0xFF166534) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${ev['bookedCount'] ?? 0} registered',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          (ev['title'] ?? '').toString(),
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                        if ((ev['venue'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text('📍 ${ev['venue']}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(ev['eventDate']?.toString()),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '📅 ${local.day}/${local.month}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Event details with package inclusions — tap an inclusion to scan a
/// participant's ticket QR or enter their 5-character ticket code to
/// claim that benefit for them. Mirrors `UserEventDetailsPage.jsx`.
class UserEventDetailsPage extends StatefulWidget {
  final String eventId;
  final String? apartmentId;
  const UserEventDetailsPage({super.key, required this.eventId, this.apartmentId});

  @override
  State<UserEventDetailsPage> createState() => _UserEventDetailsPageState();
}

class _UserEventDetailsPageState extends State<UserEventDetailsPage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _api.getManagedEvent(widget.eventId, apartmentId: widget.apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _event = Map<String, dynamic>.from(res['event'] as Map);
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['error']?.toString() ?? 'Failed to load event';
        _loading = false;
      });
    }
  }

  void _openClaimSheet(String inclusionName, String packageId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimInclusionScannerPage(
          inclusionName: inclusionName,
          packageId: packageId,
          event: _event ?? const {},
          apartmentId: widget.apartmentId,
          api: _api,
          onClaimed: _loadEvent,
        ),
      ),
    );
  }

  void _openHistorySheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserClaimHistoryPage(
          eventId: widget.eventId,
          apartmentId: widget.apartmentId,
          api: _api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_event?['title']?.toString() ?? 'Event'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan & Claim History',
            onPressed: _openHistorySheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _event == null
              ? Center(child: Text(_error ?? 'Event not found', style: const TextStyle(color: AppTheme.errorColor)))
              : RefreshIndicator(
                  onRefresh: _loadEvent,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildEventHeader(),
                      const SizedBox(height: 18),
                      const Text(
                        'Packages & Inclusions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      if ((_event!['packages'] as List? ?? []).isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                          ),
                          child: const Text('No packages configured for this event.', style: TextStyle(color: Color(0xFF64748B))),
                        )
                      else
                        ...List<Map<String, dynamic>>.from(
                          (_event!['packages'] as List).map((p) => Map<String, dynamic>.from(p as Map)),
                        ).map((pkg) => _buildPackageCard(pkg)),
                    ],
                  ),
                ),
    );
  }

  String _formatScheduleDates(List<String> dates) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sorted = [...dates]..sort();
    return sorted.map((d) {
      final parts = d.split('-');
      if (parts.length != 3) return d;
      final month = int.tryParse(parts[1]);
      if (month == null || month < 1 || month > 12) return d;
      return '${int.tryParse(parts[2]) ?? parts[2]} ${months[month - 1]}';
    }).join(', ');
  }

  String _formatDay(dynamic raw) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildEventHeader() {
    final ev = _event!;
    final venue = (ev['venue'] ?? '').toString();
    final desc = (ev['description'] ?? '').toString();
    final start = _formatDay(ev['eventDate']);
    final end = _formatDay(ev['eventEndDate']);
    final dateText = end.isNotEmpty && end != start ? '$start - $end' : start;
    Widget metaRow(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
            ],
          ),
        );
    final photoUrl = (ev['photoUrl'] ?? '').toString();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (venue.isNotEmpty) metaRow(Icons.location_on_outlined, venue),
                if (dateText.isNotEmpty) metaRow(Icons.calendar_today_outlined, dateText),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rawInclusions = (pkg['inclusions'] as List? ?? []);
    // Every inclusion is listed; ones not scheduled for today are greyed out and explain why when tapped.
    final entries = <Map<String, dynamic>>[];
    for (final e in rawInclusions) {
      final inc = e is Map ? Map<String, dynamic>.from(e) : {'name': e.toString(), 'dates': const []};
      final dates = (inc['dates'] as List? ?? []).map((d) => d.toString()).toList();
      entries.add({'name': inc['name'].toString(), 'dates': dates});
    }
    final rate = pkg['rate'];
    final isFree = rate == null || rate == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pkg['name']?.toString() ?? '',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFree ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFree ? 'Free' : '₹$rate',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isFree ? const Color(0xFF166534) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No inclusions listed.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            )
          else ...[
            const SizedBox(height: 6),
            ...entries.map((inc) {
              final name = inc['name'] as String;
              final dates = inc['dates'] as List<String>;
              final availableToday = dates.isEmpty || dates.contains(today);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: availableToday ? const Color(0xFFF1F6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (availableToday) {
                    _openClaimSheet(name, pkg['id']?.toString() ?? '');
                    return;
                  }
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        content: Text('"$name" is not available today. Scheduled for: ${_formatScheduleDates(dates)}.'),
                      ),
                    );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant_rounded,
                        size: 16,
                        color: availableToday ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            color: availableToday ? const Color(0xFF0F172A) : const Color(0xFFA0AEC0),
                          ),
                        ),
                      ),
                      Icon(
                        availableToday ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                        size: 18,
                        color: availableToday ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Full log of every inclusion claimed for this event, with search +
/// inclusion-type filter. Mirrors the web "📜 Scan & Claim History" modal.
class UserClaimHistoryPage extends StatefulWidget {
  /// When null, claims from every event are combined in time order.
  final String? eventId;
  final String? apartmentId;
  final ApiService? api;

  const UserClaimHistoryPage({
    super.key,
    this.eventId,
    required this.apartmentId,
    this.api,
  });

  @override
  State<UserClaimHistoryPage> createState() => _UserClaimHistoryPageState();
}

class _UserClaimHistoryPageState extends State<UserClaimHistoryPage> {
  late final ApiService _api = widget.api ?? ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _claims = [];
  String _search = '';
  String _inclusionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final events = <Map<String, dynamic>>[];
    if (widget.eventId != null) {
      events.add({'id': widget.eventId, 'title': ''});
    } else {
      final list = await _api.listManagedEvents(apartmentId: widget.apartmentId);
      if (list['success'] == true) {
        for (final e in (list['events'] as List? ?? [])) {
          events.add(Map<String, dynamic>.from(e as Map));
        }
      }
    }
    final claims = <Map<String, dynamic>>[];
    for (final ev in events) {
      final res = await _api.listManagedEventRegistrations(
        (ev['id'] ?? ev['_id']).toString(),
        apartmentId: widget.apartmentId,
      );
      if (res['success'] != true) continue;
      for (final r in (res['registrations'] as List? ?? [])) {
        final reg = Map<String, dynamic>.from(r as Map);
        final claimed = reg['claimedInclusions'];
        if (claimed is List) {
          for (final c in claimed) {
            final claim = Map<String, dynamic>.from(c as Map);
            claims.add({
              'participantName': reg['name'],
              'ticketCode': reg['ticketCode'],
              'packageName': reg['packageName'],
              'institution': reg['institution'],
              'eventTitle': ev['title'],
              'inclusionName': claim['inclusionName'],
              'claimedAt': claim['claimedAt'],
            });
          }
        }
      }
    }
    if (!mounted) return;
    {
      claims.sort((a, b) {
        final da = DateTime.tryParse(a['claimedAt']?.toString() ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['claimedAt']?.toString() ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });
    }
    setState(() {
      _claims = claims;
      _loading = false;
    });
  }

  List<String> get _uniqueInclusions {
    final set = <String>{};
    for (final c in _claims) {
      final name = c['inclusionName']?.toString();
      if (name != null && name.isNotEmpty) set.add(name);
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filtered {
    final term = _search.toLowerCase().trim();
    return _claims.where((c) {
      final matchesSearch = term.isEmpty ||
          (c['participantName']?.toString().toLowerCase().contains(term) ?? false) ||
          (c['ticketCode']?.toString().toLowerCase().contains(term) ?? false) ||
          (c['inclusionName']?.toString().toLowerCase().contains(term) ?? false) ||
          (c['packageName']?.toString().toLowerCase().contains(term) ?? false);
      final matchesFilter = _inclusionFilter == 'ALL' ||
          (c['inclusionName']?.toString().toLowerCase() == _inclusionFilter.toLowerCase());
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Scan & Claim History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search participant, ticket code, inclusion…',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _inclusionFilter,
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                items: [
                                  DropdownMenuItem(value: 'ALL', child: Text('All Inclusions (${_claims.length})')),
                                  ..._uniqueInclusions.map((inc) => DropdownMenuItem(value: inc, child: Text(inc))),
                                ],
                                onChanged: (v) => setState(() => _inclusionFilter = v ?? 'ALL'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📭', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _claims.isEmpty ? 'No inclusions claimed yet' : 'No matching claim history found',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              final claimedAt = DateTime.tryParse(c['claimedAt']?.toString() ?? '');
                              final name = c['participantName']?.toString() ?? '?';
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A), fontSize: 15),
                                      ),
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
                                                  name,
                                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                                child: Text(
                                                  '#${c['ticketCode'] ?? 'SPOT'}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (widget.eventId == null && (c['eventTitle'] ?? '').toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                c['eventTitle'].toString(),
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if ((c['institution'] ?? '').toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                c['institution'].toString(),
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
                                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  '✨ ${c['inclusionName'] ?? ''}',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                                ),
                                              ),
                                              if ((c['packageName'] ?? '').toString().isNotEmpty)
                                                Text(
                                                  c['packageName'].toString(),
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                claimedAt != null
                                                    ? '${claimedAt.toLocal().day}/${claimedAt.toLocal().month}/${claimedAt.toLocal().year} · ${claimedAt.toLocal().hour.toString().padLeft(2, '0')}:${claimedAt.toLocal().minute.toString().padLeft(2, '0')}'
                                                    : '—',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
    );
  }
}

class ClaimInclusionScannerPage extends StatefulWidget {
  final String inclusionName;
  final String packageId;
  final Map<String, dynamic> event;
  final String? apartmentId;
  final ApiService api;
  final VoidCallback onClaimed;

  const ClaimInclusionScannerPage({
    super.key,
    required this.inclusionName,
    required this.packageId,
    required this.event,
    required this.apartmentId,
    required this.api,
    required this.onClaimed,
  });

  @override
  State<ClaimInclusionScannerPage> createState() => _ClaimInclusionScannerPageState();
}

class _ClaimInclusionScannerPageState extends State<ClaimInclusionScannerPage> with SingleTickerProviderStateMixin {
  bool _qrMode = true;
  final TextEditingController _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _submitting = false;
  bool _cameraDenied = false;
  bool _torchOn = false;
  Map<String, dynamic>? _result;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initScanner();
  }

  Future<void> _initScanner() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _scannerController = MobileScannerController(
          formats: const [BarcodeFormat.qrCode],
          detectionSpeed: DetectionSpeed.normal,
          autoStart: true,
        );
      });
    } else {
      setState(() => _cameraDenied = true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_submitting || _result != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final code = barcode.rawValue;
    if (code == null || code.trim().isEmpty) return;

    _submit(qrData: code);
  }

  Future<void> _submit({String? qrData, String? ticketCode}) async {
    if (_result != null) return;
    if (!_submitting) setState(() => _submitting = true);
    final res = await widget.api.claimInclusion(
      inclusionName: widget.inclusionName,
      packageId: widget.packageId,
      qrData: qrData,
      ticketCode: ticketCode,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = res;
    });
    if (res['success'] == true) {
      widget.onClaimed();
    }
  }

  void _resetToScan() {
    setState(() {
      _result = null;
      _qrMode = true;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Claim Benefit',
              style: TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.inclusionName,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (_qrMode && _scannerController != null)
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
              onPressed: () {
                _scannerController?.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScannerTabButton(
                        label: '📷 Scan QR',
                        selected: _qrMode,
                        onTap: () {
                          if (!_qrMode) setState(() => _qrMode = true);
                        },
                      ),
                    ),
                    Expanded(
                      child: _ScannerTabButton(
                        label: '🎟️ Manual Code',
                        selected: !_qrMode,
                        onTap: () {
                          if (_qrMode) setState(() => _qrMode = false);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: _result != null
                  ? _buildResultView()
                  : _qrMode
                      ? _buildScannerView()
                      : _buildManualCodeView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    if (_cameraDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 56, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'Camera Access Denied',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant camera permissions in app settings to scan badges, or switch to Manual Code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_scannerController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Preview with native sharp sensor focus
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),

        // Dark Overlay with Cutout
        CustomPaint(
          size: Size.infinite,
          painter: _ScannerOverlayPainter(),
        ),

        // Google Pay style Animated Scan Line
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            const boxSize = 300.0;
            final topOffset = (_animController.value * (boxSize - 40)) - (boxSize / 2) + 20;
            return Transform.translate(
              offset: Offset(0, topOffset),
              child: Container(
                width: boxSize - 20,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, Color(0xFF38BDF8), Color(0xFF2563EB), Colors.transparent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Corner Frame Markers
        SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            children: [
              // Top-Left
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      left: BorderSide(color: Color(0xFF38BDF8), width: 4),
                    ),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
                  ),
                ),
              ),
              // Top-Right
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      right: BorderSide(color: Color(0xFF38BDF8), width: 4),
                    ),
                    borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
                  ),
                ),
              ),
              // Bottom-Left
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      left: BorderSide(color: Color(0xFF38BDF8), width: 4),
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
                  ),
                ),
              ),
              // Bottom-Right
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      right: BorderSide(color: Color(0xFF38BDF8), width: 4),
                    ),
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom instruction banner
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Align QR code inside frame to claim',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_submitting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            ),
          ),
      ],
    );
  }

  Widget _buildManualCodeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ENTER TICKET CODE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 77F05',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (upper != v) {
                  _codeController.value = _codeController.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_submitting || _codeController.text.trim().isEmpty)
                    ? null
                    : () => _submit(ticketCode: _codeController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _submitting ? 'Verifying...' : 'Verify & Claim ${widget.inclusionName}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildResultBanner(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _resetToScan,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan Next Participant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done & Go Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessGranted(Map<String, dynamic>? registration, {bool used = false, bool denied = false, String? message}) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final reg = registration ?? const <String, dynamic>{};
    Map<String, dynamic>? pkg;
    for (final p in (widget.event['packages'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(p as Map);
      if (m['id']?.toString() == reg['packageId']?.toString() || m['name']?.toString() == reg['packageName']?.toString()) {
        pkg = m;
        break;
      }
    }
    final rate = num.tryParse(pkg?['rate']?.toString() ?? '') ?? 0;
    final packageName = (reg['packageName'] ?? '').toString();
    final packageText = packageName.isEmpty
        ? ''
        : (pkg == null ? packageName : '$packageName — ${rate == 0 ? 'Free' : '₹$rate'}');
    final now = DateTime.now();
    final today = '${now.day} ${months[now.month - 1]} ${now.year}';
    final venue = (widget.event['venue'] ?? '').toString();

    final statusBg = denied
        ? const Color(0xFFFEF2F2)
        : (used ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4));
    final statusBorder = denied
        ? const Color(0xFFFCA5A5)
        : (used ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC));
    final statusText = denied
        ? const Color(0xFF991B1B)
        : (used ? const Color(0xFF92400E) : const Color(0xFF166534));

    Widget line(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusBg,
        border: Border.all(color: statusBorder, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                denied ? Icons.cancel_rounded : (used ? Icons.schedule_rounded : Icons.check_circle_rounded),
                color: statusText,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  denied ? 'ACCESS DENIED' : (used ? 'ALREADY CLAIMED' : 'ACCESS GRANTED'),
                  style: TextStyle(color: statusText, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.black12),
          if ((reg['name'] ?? '').toString().isNotEmpty) ...[
            Text(
              (reg['name'] ?? '').toString(),
              style: TextStyle(color: statusText, fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 8),
          ],
          line('Ticket ID', (reg['ticketCode'] ?? (reg.isEmpty ? '' : 'Spot')).toString()),
          line('Type', reg.isEmpty ? '' : (reg['participantType'] ?? 'Delegate').toString()),
          line('Package', packageText),
          line('Date', today),
          line('Venue', venue),
          line('Benefit', widget.inclusionName),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              denied
                  ? ((message ?? '').isEmpty ? 'This participant is not eligible for this benefit.' : message!)
                  : (used ? 'This entitlement has already been redeemed.' : 'Participant is eligible. Benefit claim registered.'),
              style: TextStyle(color: statusText, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final success = _result?['success'] == true;
    final regMap = _result?['registration'] is Map ? Map<String, dynamic>.from(_result!['registration'] as Map) : null;
    if (success) return _buildAccessGranted(regMap);
    if (_result?['alreadyClaimed'] == true && regMap != null) return _buildAccessGranted(regMap, used: true);
    return _buildAccessGranted(
      regMap,
      denied: true,
      message: (_result?['error'] ?? _result?['message'] ?? '').toString(),
    );
  }
}

class _ScannerTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScannerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxSize = 300.0;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2;
    final rect = Rect.fromLTWH(left, top, boxSize, boxSize);

    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
