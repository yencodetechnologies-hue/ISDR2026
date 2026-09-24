import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/app_theme.dart';
import '../../../../../core/services/api_service.dart';
import '../../bloc/admin_bloc.dart';
import '../create_managed_event_page.dart';
import '../event_management_details_page.dart';
import '../managed_event_details_page.dart';

class ManagedEventsTab extends StatefulWidget {
  final AdminState state;
  final String? selectedApartmentId;
  final bool isEventsProperty;

  const ManagedEventsTab({
    super.key,
    required this.state,
    this.selectedApartmentId,
    this.isEventsProperty = false,
  });

  @override
  State<ManagedEventsTab> createState() => _ManagedEventsTabState();
}

class _ManagedEventsTabState extends State<ManagedEventsTab> {
  final _api = ApiService();
  final _dateFmt = DateFormat('EEE, d MMM yyyy');
  final _timeFmt = DateFormat('h:mm a');
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _message;
  String _searchQuery = '';
  final Set<String> _togglingIds = {};

  String? get _apartmentId {
    final sel =
        widget.selectedApartmentId ??
        (widget.state is AdminLoaded
            ? (widget.state as AdminLoaded).selectedApartmentId
            : null);
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state is AdminLoaded &&
        (widget.state as AdminLoaded).blocks.isNotEmpty) {
      final bApt = (widget.state as AdminLoaded).blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_searchQuery.isEmpty) return _events;
    final q = _searchQuery.toLowerCase();
    return _events.where((e) {
      final title = e['title']?.toString().toLowerCase() ?? '';
      final venue = e['venue']?.toString().toLowerCase() ?? '';
      final status = e['status']?.toString().toLowerCase() ?? '';
      final activeLabel =
          (e['isActive'] != false && e['status']?.toString() != 'cancelled')
          ? 'active'
          : 'inactive';
      return title.contains(q) ||
          venue.contains(q) ||
          status.contains(q) ||
          activeLabel.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final res = await _api.listManagedEvents(apartmentId: _apartmentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _events = List<Map<String, dynamic>>.from(
          (res['events'] as List?)?.map(
                (e) => Map<String, dynamic>.from(e as Map),
              ) ??
              [],
        );
      } else {
        _message = res['error']?.toString() ?? 'Failed to load';
      }
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateManagedEventPage(
          apartmentId: _apartmentId,
          isEventsProperty: widget.isEventsProperty,
        ),
      ),
    );
    if (!mounted) return;
    if (created != null) {
      final slug = created['publicSlug']?.toString() ?? '';
      setState(
        () => _message = slug.isNotEmpty
            ? 'Event created. Register link copied.'
            : 'Event created',
      );
      await _load();
    }
  }

  Future<void> _openDetails(Map<String, dynamic> event) async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isEventsProperty
            ? EventManagementDetailsPage(
                event: event,
                apartmentId: _apartmentId,
              )
            : ManagedEventDetailsPage(event: event, apartmentId: _apartmentId),
      ),
    );
    if (!mounted) return;
    await _load();
    if (updated != null && updated['status'] == 'cancelled') {
      setState(() => _message = 'Event cancelled');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> event, bool active) async {
    final id = event['id']?.toString() ?? event['_id']?.toString() ?? '';
    if (id.isEmpty || _togglingIds.contains(id)) return;

    setState(() {
      _togglingIds.add(id);
      final idx = _events.indexWhere(
        (e) => (e['id']?.toString() ?? e['_id']?.toString()) == id,
      );
      if (idx != -1) {
        _events[idx] = {..._events[idx], 'isActive': active};
      }
    });

    final res = await _api.updateManagedEvent(
      eventId: id,
      isActive: active,
      status: active && event['status'] == 'cancelled' ? 'published' : null,
      apartmentId: _apartmentId,
    );

    if (!mounted) return;
    setState(() => _togglingIds.remove(id));

    if (res['success'] != true) {
      setState(() {
        _message = res['error']?.toString() ?? 'Failed to update status';
      });
      await _load();
      return;
    }
    if (res['event'] is Map) {
      final updated = Map<String, dynamic>.from(res['event'] as Map);
      setState(() {
        final idx = _events.indexWhere(
          (e) => (e['id']?.toString() ?? e['_id']?.toString()) == id,
        );
        if (idx != -1) _events[idx] = updated;
      });
    }
  }

  String _whenLabel(Map<String, dynamic> e) {
    final raw = e['eventDate'];
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString())?.toLocal();
    if (d == null) return '—';
    return '${_dateFmt.format(d)} · ${_timeFmt.format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by title, venue, status...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: const Color(0xFF3B82F6),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E2A),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x14FFFFFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x14FFFFFF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: const Color(0xFF3B82F6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Create event',
                onPressed: _openCreate,
                icon: const Icon(Icons.add_rounded),
                color: const Color(0xFF3B82F6),
                iconSize: 24,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6).withAlpha(15),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x14FFFFFF)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _message!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: const Color(0xFF3B82F6),
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  )
                : _events.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withAlpha(16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 30,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events yet',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Tap + to create an event and share the register link.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF9CA3AF),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _openCreate,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            'Create event',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        'No events match your search.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = filtered[index];
                      final id =
                          e['id']?.toString() ?? e['_id']?.toString() ?? '';
                      final isActive =
                          e['isActive'] != false &&
                          e['status']?.toString() != 'cancelled';
                      final toggling = _togglingIds.contains(id);

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x14FFFFFF)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(6),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _openDetails(e),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child:
                                        (e['photoUrl']?.toString() ?? '')
                                            .isNotEmpty
                                        ? Image.network(
                                            e['photoUrl'].toString(),
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF1E1E2A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0x1AFFFFFF,
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .calendar_month_rounded,
                                                    size: 24,
                                                    color: Color(0xFFE2E8F0),
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E2A),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0x1AFFFFFF),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 24,
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e['title']?.toString() ?? 'Event',
                                          style: GoogleFonts.sora(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _whenLabel(e),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E2A),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                widget.isEventsProperty
                                                    ? '${e['bookedCount'] ?? 0} registered'
                                                    : '${e['bookedCount'] ?? 0}/${e['totalSlots'] ?? 0} booked',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFFCBD5E1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (e['status'] != null &&
                                                e['status']
                                                    .toString()
                                                    .isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '· ${e['status']}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(
                                                    0xFF94A3B8,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: isActive,
                                        activeThumbColor: const Color(
                                          0xFF3B82F6,
                                        ),
                                        onChanged:
                                            toggling ||
                                                e['status']?.toString() ==
                                                    'cancelled'
                                            ? null
                                            : (v) => _toggleActive(e, v),
                                      ),
                                      Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
