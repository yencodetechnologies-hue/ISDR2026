import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/event_package_sheet.dart' show normalizeInclusions;

/// Manager form: pick an event (required), optionally a package and an inclusion,
/// write the content and send it to that event's participants.
class SendNotificationPage extends StatefulWidget {
  final String? apartmentId;

  const SendNotificationPage({super.key, this.apartmentId});

  @override
  State<SendNotificationPage> createState() => _SendNotificationPageState();
}

class _SendNotificationPageState extends State<SendNotificationPage> {
  final _api = ApiService();
  final _content = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  Map<String, dynamic>? _event;
  String? _packageId; // null = all packages
  String? _inclusion; // null = all inclusions

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
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
        _loadError = res['error']?.toString() ?? 'Failed to load events';
      }
    });
  }

  String _idOf(Map<String, dynamic> e) =>
      e['id']?.toString() ?? e['_id']?.toString() ?? '';

  List<Map<String, dynamic>> get _packages {
    final raw = _event?['packages'] as List? ?? [];
    return raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  /// Inclusion names for the chosen package, or for every package when none is chosen.
  List<String> get _inclusionNames {
    final source = _packageId == null
        ? _packages
        : _packages.where((p) => p['id']?.toString() == _packageId).toList();
    final names = <String>{};
    for (final p in source) {
      for (final inc in normalizeInclusions(p['inclusions'])) {
        names.add(inc['name'].toString());
      }
    }
    return names.toList();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _send() async {
    if (_event == null) return _toast('Select an event');
    if (_content.text.trim().isEmpty) return _toast('Write the notification content');
    setState(() => _sending = true);
    final res = await _api.sendEventNotification(
      eventId: _idOf(_event!),
      message: _content.text.trim(),
      packageId: _packageId,
      inclusionName: _inclusion,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      final n = res['recipientCount'] ?? 0;
      _content.clear();
      _toast('Notification sent to $n participant${n == 1 ? '' : 's'}');
    } else {
      _toast(res['error']?.toString() ?? 'Failed to send notification');
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      );

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
          'Send Notification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      value: _event == null ? null : _idOf(_event!),
                      isExpanded: true,
                      decoration: _dec('Event *', Icons.event_rounded),
                      hint: const Text('Select event'),
                      items: _events
                          .map((e) => DropdownMenuItem(
                                value: _idOf(e),
                                child: Text(e['title']?.toString() ?? 'Event',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (id) => setState(() {
                        _event = _events.firstWhere((e) => _idOf(e) == id);
                        _packageId = null;
                        _inclusion = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _packageId,
                      isExpanded: true,
                      decoration: _dec('Package (optional)', Icons.inventory_2_outlined),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('All packages')),
                        ..._packages.map((p) => DropdownMenuItem<String?>(
                              value: p['id']?.toString(),
                              child: Text(p['name']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: _event == null
                          ? null
                          : (v) => setState(() {
                                _packageId = v;
                                _inclusion = null;
                              }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _inclusion,
                      isExpanded: true,
                      decoration: _dec('Inclusion (optional)', Icons.checklist_rounded),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('All inclusions')),
                        ..._inclusionNames.map((n) => DropdownMenuItem<String?>(
                              value: n,
                              child: Text(n, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged:
                          _event == null ? null : (v) => setState(() => _inclusion = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _content,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec('Notification content *', Icons.notes_rounded),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send Notification',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
