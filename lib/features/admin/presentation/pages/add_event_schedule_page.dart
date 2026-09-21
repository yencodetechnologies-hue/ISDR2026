import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/event_package_sheet.dart' show eventDays;

/// Form to add a schedule (speaker session) to an event.
class AddEventSchedulePage extends StatefulWidget {
  final Map<String, dynamic> event;

  const AddEventSchedulePage({super.key, required this.event});

  @override
  State<AddEventSchedulePage> createState() => _AddEventSchedulePageState();
}

class _AddEventSchedulePageState extends State<AddEventSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _speaker = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();

  File? _photo;
  String? _dateIso; // one of the event's own days (yyyy-MM-dd)
  TimeOfDay? _from;
  TimeOfDay? _to;
  bool _saving = false;

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  @override
  void dispose() {
    _speaker.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isFrom ? _from : _to) ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateIso == null) return _toast('Select the event day');
    if (_from == null || _to == null) return _toast('Select from and to time');
    if (_hhmm(_to!).compareTo(_hhmm(_from!)) <= 0) {
      return _toast('To time must be after from time');
    }
    setState(() => _saving = true);
    final res = await ApiService().createEventSchedule(
      eventId: _eventId,
      speakerName: _speaker.text.trim(),
      scheduleName: _name.text.trim(),
      date: _dateIso!,
      fromTime: _hhmm(_from!),
      toTime: _hhmm(_to!),
      description: _description.text.trim(),
      photoPath: _photo?.path,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _toast(res['error']?.toString() ?? 'Failed to add schedule');
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

  Widget _picker(String label, IconData icon, String? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _dec(label, icon),
        child: Text(
          value ?? 'Select',
          style: TextStyle(
            color: value == null ? Colors.black45 : AppTheme.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// The event's own days — the schedule date can only be one of these.
  Widget _dayChips() {
    final days = eventDays(widget.event);
    return InputDecorator(
      decoration: _dec('Date (event days)', Icons.calendar_month_outlined),
      child: days.isEmpty
          ? const Text('This event has no dates', style: TextStyle(color: Colors.black45))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((d) {
                final selected = _dateIso == d.iso;
                return ChoiceChip(
                  label: Text(d.label),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _dateIso = d.iso),
                );
              }).toList(),
            ),
    );
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
          'Add Schedule',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.09),
                      backgroundImage: _photo != null ? FileImage(_photo!) : null,
                      child: _photo == null
                          ? const Icon(Icons.person_rounded,
                              size: 44, color: AppTheme.primaryColor)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('Speaker photo',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _speaker,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Name of the speaker', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the speaker name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Name of the schedule', Icons.event_note_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the schedule name' : null,
            ),
            const SizedBox(height: 12),
            _dayChips(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _picker('From time', Icons.schedule_rounded,
                      _from?.format(context), () => _pickTime(true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _picker('To time', Icons.schedule_rounded,
                      _to?.format(context), () => _pickTime(false)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Description', Icons.notes_rounded),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Save Schedule',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
