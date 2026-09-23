import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';

/// Create / edit participant sheet with the full profile (same fields as the
/// website "Create participants" form). Pops with the saved registration map.
class EventParticipantSheet extends StatefulWidget {
  final String eventId;
  final String? apartmentId;
  final List<Map<String, dynamic>> packages;
  final Set<String> existingIdNumbers;
  final String? suggestedIdNumber;
  final Map<String, dynamic>? registration;
  final ApiService api;

  const EventParticipantSheet({
    super.key,
    required this.eventId,
    required this.apartmentId,
    required this.packages,
    required this.existingIdNumbers,
    this.suggestedIdNumber,
    required this.api,
    this.registration,
  });

  @override
  State<EventParticipantSheet> createState() => _EventParticipantSheetState();
}

class _EventParticipantSheetState extends State<EventParticipantSheet> {
  static const _titles = ['Dr', 'Mr', 'Ms', 'Prof', 'Baby'];

  final _type = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _designation = TextEditingController();
  final _institution = TextEditingController();
  final _idNumber = TextEditingController();
  final _address = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _utr = TextEditingController();

  String _title = '';
  String _gender = '';
  String _food = '';
  String _paymentMode = '';
  String? _packageId;
  String? _photoPath;
  String _existingPhotoUrl = '';
  String? _error;
  bool _busy = false;

  bool get _editing => widget.registration != null;

  Map<String, dynamic>? get _package {
    for (final p in widget.packages) {
      if (p['id']?.toString() == _packageId) return p;
    }
    return null;
  }

  bool get _free {
    final p = _package;
    return p != null && (num.tryParse(p['rate']?.toString() ?? '') ?? 0) == 0;
  }

  bool get _paid => _package != null && !_free;

  @override
  void initState() {
    super.initState();
    final r = widget.registration;
    if (r != null) {
      String v(String k) => r[k]?.toString() ?? '';
      _title = v('title');
      _type.text = v('participantType');
      _first.text = v('firstName');
      _middle.text = v('middleName');
      _last.text = v('lastName');
      if (_first.text.isEmpty && _last.text.isEmpty) _first.text = v('name');
      _gender = v('gender');
      _designation.text = v('designation');
      _institution.text = v('institution');
      _idNumber.text = v('idNumber');
      _address.text = v('address');
      _mobile.text = v('mobileNumber');
      _email.text = v('email');
      _food = v('foodPreference');
      _paymentMode = v('paymentMode');
      _utr.text = v('utrNumber');
      _existingPhotoUrl = v('photoUrl');
      final pid = v('packageId');
      if (pid.isNotEmpty && widget.packages.any((p) => p['id']?.toString() == pid)) {
        _packageId = pid;
      } else if (v('packageName').isNotEmpty) {
        for (final p in widget.packages) {
          if (p['name']?.toString() == v('packageName')) _packageId = p['id']?.toString();
        }
      }
    } else {
      _idNumber.text = widget.suggestedIdNumber ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_type, _first, _middle, _last, _designation, _institution, _idNumber, _address, _mobile, _email, _utr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  String? _validate() {
    final checks = <String, String>{
      'Participant type': _type.text,
      'Title': _title,
      'First name': _first.text,
      'Last name': _last.text,
      'Gender': _gender,
      'Designation': _designation.text,
      'Organization': _institution.text,
      'Package': _packageId ?? '',
      'ID no.': _idNumber.text,
      'Mobile number': _mobile.text,
      'Email': _email.text,
      'Food preference': _food,
    };
    for (final e in checks.entries) {
      if (e.value.trim().isEmpty) return '${e.key} is required';
    }
    if (_paid && _paymentMode.isEmpty) return 'Payment mode is required';
    if (!RegExp(r'^\+?\d{10,13}$').hasMatch(_mobile.text.replaceAll(RegExp(r'[\s-]'), ''))) {
      return 'Enter a valid mobile number';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      return 'Enter a valid email address';
    }
    final id = _idNumber.text.trim();
    if (widget.existingIdNumbers.any((e) => e.toLowerCase() == id.toLowerCase())) {
      return 'This ID number is already used for this event.';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final fields = <String, String>{
      'participantType': _type.text.trim(),
      'title': _title,
      'firstName': _first.text.trim(),
      'middleName': _middle.text.trim(),
      'lastName': _last.text.trim(),
      'gender': _gender,
      'designation': _designation.text.trim(),
      'institution': _institution.text.trim(),
      'packageId': _packageId ?? '',
      'idNumber': _idNumber.text.trim(),
      'address': _address.text.trim(),
      'mobileNumber': _mobile.text.trim(),
      'email': _email.text.trim(),
      'foodPreference': _food,
      'paymentMode': _free ? '' : _paymentMode,
      'utrNumber': _utr.text.trim(),
    };
    final res = _editing
        ? await widget.api.updateEventRegistration(
            eventId: widget.eventId,
            registrationId: (widget.registration!['id'] ?? widget.registration!['_id']).toString(),
            fields: fields,
            photoPath: _photoPath,
            apartmentId: widget.apartmentId,
          )
        : await widget.api.createSpotRegistration(
            eventId: widget.eventId,
            fields: fields,
            photoPath: _photoPath,
            apartmentId: widget.apartmentId,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      Navigator.pop(
        context,
        res['registration'] is Map ? Map<String, dynamic>.from(res['registration'] as Map) : <String, dynamic>{},
      );
    } else {
      setState(() => _error = res['error']?.toString() ?? 'Failed to save participant');
    }
  }

  Widget _text(TextEditingController c, String label,
      {bool required = true, TextInputType? type, int maxLines = 1, ValueChanged<String>? onChanged, int? maxLength, TextCapitalization caps = TextCapitalization.none, String? hint, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: type,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: caps,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? '$label *' : '$label (optional)',
          hintText: hint,
          counterText: '',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _drop({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool required = true,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value-$enabled'),
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: required ? '$label *' : '$label (optional)',
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idTaken = _idNumber.text.trim().isNotEmpty &&
        widget.existingIdNumbers.any((e) => e.toLowerCase() == _idNumber.text.trim().toLowerCase());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_editing ? 'Edit participant' : 'Create participants',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                    ],
                    _text(_type, 'Participant type', maxLength: 60, hint: 'e.g. Delegate, Speaker, Organizer'),
                    _drop(
                      label: 'Title',
                      value: _title,
                      items: _titles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _title = v ?? ''),
                    ),
                    _text(_first, 'First name'),
                    _text(_middle, 'Middle name', required: false),
                    _text(_last, 'Last name'),
                    _drop(
                      label: 'Gender',
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? ''),
                    ),
                    _text(_designation, 'Designation'),
                    _text(_institution, 'Organization'),
                    _drop(
                      label: 'Package',
                      value: _packageId ?? '',
                      items: widget.packages
                          .map((p) => DropdownMenuItem(
                                value: p['id'].toString(),
                                child: Text(
                                  '${p['name']} (${(num.tryParse(p['rate']?.toString() ?? '') ?? 0) == 0 ? 'Free' : '₹${p['rate']}'})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _packageId = v;
                        if (_free) {
                          _paymentMode = '';
                        }
                      }),
                    ),
                    _text(
                      _idNumber,
                      'ID no.',
                      hint: 'e.g. ID1001',
                      caps: TextCapitalization.characters,
                      onChanged: (v) {
                        final upper = v.toUpperCase();
                        if (upper != v) {
                          _idNumber.value = _idNumber.value.copyWith(
                            text: upper,
                            selection: TextSelection.collapsed(offset: upper.length),
                          );
                        }
                        setState(() {});
                      },
                    ),
                    if (idTaken)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'This ID number is already used for this event.',
                          style: TextStyle(color: AppTheme.errorColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    _text(_mobile, 'Mobile no.', type: TextInputType.phone),
                    _text(_email, 'Email', type: TextInputType.emailAddress),
                    _drop(
                      label: 'Food preference',
                      value: _food,
                      items: const [
                        DropdownMenuItem(value: 'veg', child: Text('Veg')),
                        DropdownMenuItem(value: 'non-veg', child: Text('Non-veg')),
                      ],
                      onChanged: (v) => setState(() => _food = v ?? ''),
                    ),
                    _drop(
                      label: 'Payment mode',
                      value: _free ? '' : _paymentMode,
                      required: _paid,
                      enabled: !_free,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      ],
                      onChanged: (v) => setState(() => _paymentMode = v ?? ''),
                    ),
                    _text(_utr, 'UTR no.', required: false),
                    _text(_address, 'Address', required: false, maxLines: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: _photoPath != null
                                ? FileImage(File(_photoPath!))
                                : (_existingPhotoUrl.isNotEmpty ? NetworkImage(_existingPhotoUrl) as ImageProvider : null),
                            child: (_photoPath == null && _existingPhotoUrl.isEmpty)
                                ? const Icon(Icons.person, color: Colors.black38)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Photo (optional)'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_busy || idTaken) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_busy ? 'Saving…' : (_editing ? 'Save changes' : 'Create participant & QR')),
                      ),
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
}
