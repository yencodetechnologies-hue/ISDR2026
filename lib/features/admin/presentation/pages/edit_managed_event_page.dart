import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/managed_event_form.dart';

class EditManagedEventPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String? apartmentId;
  final bool isEventsProperty;

  const EditManagedEventPage({
    super.key,
    required this.event,
    this.apartmentId,
    this.isEventsProperty = false,
  });

  @override
  State<EditManagedEventPage> createState() => _EditManagedEventPageState();
}

class _EditManagedEventPageState extends State<EditManagedEventPage> {
  final _api = ApiService();
  late final ManagedEventFormData _form;
  bool _busy = false;
  String? _error;

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _form = ManagedEventFormData.fromEvent(widget.event);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final next = await pickManagedEventDateTime(context, _form.eventDate);
    if (next == null || !mounted) return;
    setState(() => _form.eventDate = next);
  }

  Future<void> _pickEndDate() async {
    final next = await pickManagedEventDateTime(context, _form.eventEndDate ?? _form.eventDate);
    if (next == null || !mounted) return;
    setState(() => _form.eventEndDate = next);
  }

  Future<void> _save() async {
    final err = _form.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_eventId.isEmpty) {
      setState(() => _error = 'Missing event id');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.updateManagedEvent(
      eventId: _eventId,
      title: _form.title.text.trim(),
      description: _form.description.text.trim(),
      venue: _form.venue.text.trim(),
      eventDate: _form.eventDate,
      eventEndDate: widget.isEventsProperty ? _form.eventEndDate : null,
      clearEventEndDate: widget.isEventsProperty && _form.eventEndDate == null,
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      final event = Map<String, dynamic>.from(
        res['event'] as Map? ?? widget.event,
      );
      Navigator.pop(context, event);
    } else {
      setState(() => _error = res['error']?.toString() ?? 'Update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Edit event'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 12),
          ],
          ManagedEventFormBody(
            data: _form,
            onChanged: () => setState(() {}),
            onPickDateTime: _pickDate,
            showEndDate: widget.isEventsProperty,
            onPickEndDateTime: _pickEndDate,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
