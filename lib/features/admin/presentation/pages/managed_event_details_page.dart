import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/api_service.dart';
import 'edit_managed_event_page.dart';

class ManagedEventDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String? apartmentId;

  const ManagedEventDetailsPage({
    super.key,
    required this.event,
    this.apartmentId,
  });

  @override
  State<ManagedEventDetailsPage> createState() =>
      _ManagedEventDetailsPageState();
}

class _ManagedEventDetailsPageState extends State<ManagedEventDetailsPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('EEE, d MMM yyyy');
  final _timeFmt = DateFormat('h:mm a');
  final _regSearchController = TextEditingController();

  late Map<String, dynamic> _event;
  List<Map<String, dynamic>> _registrations = [];
  bool _loadingRegs = true;
  bool _busy = false;
  String _regSearchQuery = '';

  String get _eventId =>
      _event['id']?.toString() ?? _event['_id']?.toString() ?? '';

  String get _slug => _event['publicSlug']?.toString() ?? '';

  String get _registerUrl =>
      _slug.isEmpty ? '' : ApiConfig.eventRegisterWebUrl(_slug);

  bool get _isActive =>
      _event['isActive'] != false &&
      _event['status']?.toString() != 'cancelled';

  bool get _canShareRegistration => _isActive && _registerUrl.isNotEmpty;

  List<Map<String, dynamic>> get _filteredRegistrations {
    if (_regSearchQuery.isEmpty) return _registrations;
    final q = _regSearchQuery.toLowerCase();
    return _registrations.where((r) {
      final name = r['name']?.toString().toLowerCase() ?? '';
      final mobile = r['mobileNumber']?.toString().toLowerCase() ?? '';
      final ticket = r['ticketCode']?.toString().toLowerCase() ?? '';
      final status = r['status']?.toString().toLowerCase() ?? '';
      return name.contains(q) ||
          mobile.contains(q) ||
          ticket.contains(q) ||
          status.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _loadRegistrations();
  }

  @override
  void dispose() {
    _regSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegistrations() async {
    if (_eventId.isEmpty) {
      setState(() => _loadingRegs = false);
      return;
    }
    setState(() => _loadingRegs = true);
    final res = await _api.listManagedEventRegistrations(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() {
      _loadingRegs = false;
      _registrations = List<Map<String, dynamic>>.from(
        (res['registrations'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      );
    });
  }

  DateTime? get _eventDate {
    final raw = _event['eventDate'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  Future<void> _shareLink() async {
    if (!_canShareRegistration) return;
    final title = _event['title']?.toString() ?? 'Event';
    await Share.share(
      'Register for $title:\n$_registerUrl',
      subject: 'Register for $title',
    );
  }

  void _showRegisterQr() {
    if (!_canShareRegistration) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
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
              const SizedBox(height: 16),
              const Text(
                'Registration QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Users scan this to open the register form and get their ticket QR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: _registerUrl,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              SelectableText(
                _registerUrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditManagedEventPage(
          event: _event,
          apartmentId: widget.apartmentId,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _event = updated);
  }

  Future<void> _cancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel event?'),
        content: const Text(
          'Registration will close and the event will be marked cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final res = await _api.cancelManagedEvent(
      _eventId,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      final event = Map<String, dynamic>.from(res['event'] as Map? ?? _event);
      Navigator.pop(context, event);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed')),
      );
    }
  }

  String _answersSummary(Map<String, dynamic> r) {
    final answers = r['answers'];
    if (answers is! List || answers.isEmpty) return '';
    return answers.map((a) {
      if (a is! Map) return '';
      final label = a['label']?.toString() ?? '';
      final value = a['value'];
      final display =
          value is List ? value.join(', ') : (value?.toString() ?? '');
      return '$label: $display';
    }).where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final date = _eventDate;
    final isActive = _isActive;
    final qCount = (_event['formQuestions'] is List)
        ? (_event['formQuestions'] as List).length
        : 0;
    final filteredRegs = _filteredRegistrations;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_event['title']?.toString() ?? 'Event'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: _busy ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Registration QR',
            onPressed: _canShareRegistration ? _showRegisterQr : null,
            icon: const Icon(Icons.qr_code_2),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'cancel') _cancelEvent();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRegistrations,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        Text(
                          _event['title']?.toString() ?? 'Event',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    const SizedBox(height: 8),
                    if ((_event['venue']?.toString() ?? '').isNotEmpty)
                      Text(
                        _event['venue'].toString(),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    if (date != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_dateFmt.format(date)} · ${_timeFmt.format(date)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_event['bookedCount'] ?? 0}/${_event['totalSlots'] ?? 0} booked'
                      ' · ${_event['status'] ?? ''}'
                      ' · ${isActive ? 'Active' : 'Inactive'}'
                      '${qCount > 0 ? ' · $qCount questions' : ''}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if ((_event['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_event['description'].toString()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Share registration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive
                          ? 'Users open this link, fill the form, and get a ticket QR for security.'
                          : 'Registration link is disabled while this event is inactive.',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (isActive)
                      SelectableText(
                        _registerUrl.isEmpty ? 'No link yet' : _registerUrl,
                        style: const TextStyle(fontSize: 13),
                      )
                    else
                      const Text(
                        'Link and QR are unavailable until the event is active again.',
                        style: TextStyle(fontSize: 13, color: Colors.black45),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _canShareRegistration ? _shareLink : null,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _canShareRegistration
                                ? _showRegisterQr
                                : null,
                            icon: const Icon(Icons.qr_code_2, size: 18),
                            label: const Text('View QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Registrations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!_loadingRegs && _registrations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _regSearchController,
                  onChanged: (v) => setState(() => _regSearchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, mobile, ticket...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textColor.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.primaryColor.withOpacity(0.7),
                    ),
                    suffixIcon: _regSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _regSearchController.clear();
                              setState(() => _regSearchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            if (_loadingRegs)
              const Center(child: CircularProgressIndicator())
            else if (_registrations.isEmpty)
              const Text(
                'No registrations yet.',
                style: TextStyle(color: Colors.black54),
              )
            else if (filteredRegs.isEmpty)
              const Text(
                'No registrations match your search.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...filteredRegs.map((r) {
                final summary = _answersSummary(r);
                return Card(
                  child: ListTile(
                    title: Text(r['name']?.toString() ?? ''),
                    subtitle: Text(
                      [
                        '${r['mobileNumber'] ?? ''} · ${r['ticketCode'] ?? ''} · ${r['status'] ?? ''}',
                        if (summary.isNotEmpty) summary,
                      ].join('\n'),
                    ),
                    isThreeLine: summary.isNotEmpty,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
