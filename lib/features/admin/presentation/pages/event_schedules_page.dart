import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import 'event_schedule_list_page.dart';

/// Lists the events of the management account.
class EventSchedulesPage extends StatefulWidget {
  final String? apartmentId;
  final bool isReadOnly;

  const EventSchedulesPage({super.key, this.apartmentId, this.isReadOnly = false});

  @override
  State<EventSchedulesPage> createState() => _EventSchedulesPageState();
}

class _EventSchedulesPageState extends State<EventSchedulesPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('EEE, d MMM yyyy');
  final _timeFmt = DateFormat('h:mm a');

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
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _events = List<Map<String, dynamic>>.from(
          (res['events'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );
      } else {
        _error = res['error']?.toString() ?? 'Failed to load events';
      }
    });
  }

  DateTime? _dateOf(Map<String, dynamic> e, String key) {
    final raw = e[key];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
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
        title: const Text(
          'Event Schedules',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _events.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 160),
                            Center(
                              child: Text('No events yet',
                                  style: TextStyle(color: Colors.black54)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _eventCard(_events[i]),
                        ),
                ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventScheduleListPage(
            event: e,
            isReadOnly: widget.isReadOnly,
          ),
        ),
      ),
      child: _eventCardBody(e),
    );
  }

  Widget _eventCardBody(Map<String, dynamic> e) {
    final start = _dateOf(e, 'eventDate');
    final venue = e['venue']?.toString() ?? '';
    final cancelled = e['status']?.toString() == 'cancelled';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note_rounded,
                color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['title']?.toString() ?? 'Event',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor,
                  ),
                ),
                if (start != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${_dateFmt.format(start)} · ${_timeFmt.format(start)}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(venue,
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: cancelled ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (e['status'] ?? 'Active').toString(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: cancelled ? const Color(0xFF991B1B) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
