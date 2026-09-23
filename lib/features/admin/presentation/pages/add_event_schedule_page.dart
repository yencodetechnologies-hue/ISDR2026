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
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _hall = TextEditingController();
  final _description = TextEditingController();

  File? _photo;
  final Set<String> _dates = {}; // picked event days (yyyy-MM-dd)
  bool _sameTime = true; // one From/To for every picked date
  TimeOfDay? _from; // used when _sameTime
  TimeOfDay? _to;
  // Used when times differ per date.
  final Map<String, TimeOfDay> _fromByDate = {};
  final Map<String, TimeOfDay> _toByDate = {};
  bool _saving = false;
  bool _showPassword = false;

  /// Separate times per date only makes sense with more than one date picked.
  bool get _perDate => !_sameTime && _dates.length > 1;

  /// Picked event days in calendar order.
  List<({String iso, String label})> get _pickedDays =>
      eventDays(widget.event).where((d) => _dates.contains(d.iso)).toList();

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  @override
  void dispose() {
    _speaker.dispose();
    _mobile.dispose();
    _password.dispose();
    _name.dispose();
    _hall.dispose();
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

  /// Picks the shared From/To time, or the one for [dateIso] when given.
  Future<void> _pickTime(bool isFrom, [String? dateIso]) async {
    final current = dateIso == null
        ? (isFrom ? _from : _to)
        : (isFrom ? _fromByDate : _toByDate)[dateIso];
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (dateIso == null) {
        isFrom ? _from = picked : _to = picked;
      } else {
        (isFrom ? _fromByDate : _toByDate)[dateIso] = picked;
      }
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dates.isEmpty) return _toast('Select at least one event day');
    final slots = <Map<String, String>>[];
    for (final day in _pickedDays) {
      final from = _perDate ? _fromByDate[day.iso] : _from;
      final to = _perDate ? _toByDate[day.iso] : _to;
      final forDay = _perDate ? ' for ${day.label}' : '';
      if (from == null || to == null) {
        return _toast('Select from and to time$forDay');
      }
      if (_hhmm(to).compareTo(_hhmm(from)) <= 0) {
        return _toast('To time must be after from time$forDay');
      }
      slots.add({
        'date': day.iso,
        'fromTime': _hhmm(from),
        'toTime': _hhmm(to),
      });
    }
    setState(() => _saving = true);
    final res = await ApiService().createEventSchedule(
      eventId: _eventId,
      speakerName: _speaker.text.trim(),
      speakerMobile: _mobile.text.trim(),
      speakerPassword: _password.text,
      scheduleName: _name.text.trim(),
      hall: _hall.text.trim(),
      slots: slots,
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

  Widget _picker(
    String label,
    IconData icon,
    String? value,
    VoidCallback onTap,
  ) {
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

  /// From/To pickers — the shared pair, or the pair for [dateIso] when given.
  Widget _timeRow([String? dateIso]) {
    final from = dateIso == null ? _from : _fromByDate[dateIso];
    final to = dateIso == null ? _to : _toByDate[dateIso];
    return Row(
      children: [
        Expanded(
          child: _picker(
            'From time',
            Icons.schedule_rounded,
            from?.format(context),
            () => _pickTime(true, dateIso),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _picker(
            'To time',
            Icons.schedule_rounded,
            to?.format(context),
            () => _pickTime(false, dateIso),
          ),
        ),
      ],
    );
  }

  /// The event's own days — the speaker can be on any number of these.
  Widget _dayChips() {
    final days = eventDays(widget.event);
    return InputDecorator(
      decoration: _dec('Date (event days)', Icons.calendar_month_outlined),
      child: days.isEmpty
          ? const Text(
              'This event has no dates',
              style: TextStyle(color: Colors.black45),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((d) {
                final selected = _dates.contains(d.iso);
                return ChoiceChip(
                  label: Text(d.label),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _dates.remove(d.iso);
                    } else {
                      _dates.add(d.iso);
                    }
                  }),
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
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.09,
                      ),
                      backgroundImage: _photo != null
                          ? FileImage(_photo!)
                          : null,
                      child: _photo == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 44,
                              color: AppTheme.primaryColor,
                            )
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
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Speaker photo',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _speaker,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Name of the speaker', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the speaker name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: _dec(
                'Speaker mobile number',
                Icons.phone_outlined,
              ).copyWith(counterText: ''),
              validator: (v) => RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid 10-digit mobile number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: _dec('Speaker password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(
                'Name of the schedule',
                Icons.event_note_outlined,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the schedule name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hall,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Hall / venue', Icons.meeting_room_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the hall' : null,
            ),
            const SizedBox(height: 12),
            _dayChips(),
            if (_dates.length > 1)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _sameTime,
                activeThumbColor: AppTheme.primaryColor,
                title: const Text(
                  'Same time for all dates',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onChanged: (v) => setState(() => _sameTime = v),
              )
            else
              const SizedBox(height: 12),
            if (_perDate)
              for (final day in _pickedDays) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    day.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
                _timeRow(day.iso),
                const SizedBox(height: 12),
              ]
            else ...[_timeRow(), const SizedBox(height: 12)],
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
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
