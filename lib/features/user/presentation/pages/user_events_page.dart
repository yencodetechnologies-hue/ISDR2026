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
                                                    return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                              child: Padding(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClaimInclusionSheet(
        inclusionName: inclusionName,
        packageId: packageId,
        event: _event ?? const {},
        apartmentId: widget.apartmentId,
        api: _api,
        onClaimed: _loadEvent,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
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

class _ClaimInclusionSheet extends StatefulWidget {
  final String inclusionName;
  final String packageId;
  final Map<String, dynamic> event;
  final String? apartmentId;
  final ApiService api;
  final VoidCallback onClaimed;

  const _ClaimInclusionSheet({
    required this.inclusionName,
    required this.packageId,
    required this.event,
    required this.apartmentId,
    required this.api,
    required this.onClaimed,
  });

  @override
  State<_ClaimInclusionSheet> createState() => _ClaimInclusionSheetState();
}

class _ClaimInclusionSheetState extends State<_ClaimInclusionSheet> {
  bool _qrMode = true;
  final TextEditingController _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _submitting = false;
  bool _cameraDenied = false;
  Map<String, dynamic>? _result; // {success, alreadyClaimed, message, registration}

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _scannerController = MobileScannerController(formats: [BarcodeFormat.qrCode]);
      });
    } else {
      setState(() => _cameraDenied = true);
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit({String? qrData, String? ticketCode}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(
                'Claim Event Benefit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB), letterSpacing: 0.5),
              ),
              Text(
                '✨ ${widget.inclusionName}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              if (_result == null) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: '📷 Scan QR',
                          selected: _qrMode,
                          onTap: () => setState(() => _qrMode = true),
                        ),
                      ),
                      Expanded(
                        child: _ModeTab(
                          label: '🎟️ Ticket Code',
                          selected: !_qrMode,
                          onTap: () => setState(() => _qrMode = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_qrMode) ...[
                  if (_cameraDenied)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14)),
                      child: const Text(
                        'Camera permission denied. Use "Ticket Code" instead, or grant camera access in app settings.',
                        style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (_scannerController == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 260,
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
                            if (code != null && !_submitting) {
                              _submit(qrData: code);
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Point camera at the participant\'s ticket QR code to claim ${widget.inclusionName}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ] else ...[
                  Text(
                    'ENTER 5-CHARACTER TICKET CODE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 10,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3),
                    decoration: InputDecoration(
                      hintText: 'e.g. ABC12',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_submitting || _codeController.text.trim().isEmpty)
                          ? null
                          : () => _submit(ticketCode: _codeController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_submitting ? 'Processing…' : 'Verify & Claim ${widget.inclusionName}'),
                    ),
                  ),
                ],
              ] else ...[
                _buildResultBanner(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _resetToScan,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('🔄 Scan / Claim Another Ticket'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
    final green = denied ? const Color(0xFF991B1B) : (used ? const Color(0xFF92400E) : const Color(0xFF166534));
    const grey = Color(0xFF475569);
    Widget line(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Text('$label: $value', style: const TextStyle(color: grey, fontSize: 14, height: 1.5));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(denied ? '✕ FOOD ACCESS DENIED' : (used ? '◷ ALREADY USED' : '✓ FOOD ACCESS GRANTED'),
              style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          if ((reg['name'] ?? '').toString().isNotEmpty)
            Text((reg['name'] ?? '').toString(),
              style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 14, height: 1.5)),
          line('Participant ID', (reg['ticketCode'] ?? (reg.isEmpty ? '' : 'Spot')).toString()),
          line('Type', reg.isEmpty ? '' : (reg['participantType'] ?? 'Delegate').toString()),
          line('Package', packageText),
          line('Date', today),
          line('Venue', venue),
          line('Meal', widget.inclusionName),
          Text(
              denied
                  ? ((message ?? '').isEmpty ? 'This participant is not allowed this meal.' : message!)
                  : (used ? 'This meal entitlement has already been redeemed.' : 'Participant is eligible. Food access granted.'),
              style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 14, height: 1.5)),
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

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? [const BoxShadow(color: Colors.black12, blurRadius: 6)] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
