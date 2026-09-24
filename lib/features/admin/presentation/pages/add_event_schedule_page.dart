import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../widgets/event_package_sheet.dart' show eventDays;
import 'manage_speakers_page.dart';

/// Form to add a schedule (speaker session) to an event. The speaker is picked
/// from the Speakers list (added on the Speakers page).
class AddEventSchedulePage extends StatefulWidget {
  final Map<String, dynamic> event;

  const AddEventSchedulePage({super.key, required this.event});

  @override
  State<AddEventSchedulePage> createState() => _AddEventSchedulePageState();
}

class _AddEventSchedulePageState extends State<AddEventSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _hall = TextEditingController();
  final _description = TextEditingController();

  List<Map<String, dynamic>> _speakers = [];
  bool _loadingSpeakers = true;
  String? _speakerId;

  final Set<String> _dates = {}; // picked event days (yyyy-MM-dd)
  bool _sameTime = true; // one From/To for every picked date
  TimeOfDay? _from; // used when _sameTime
  TimeOfDay? _to;
  // Used when times differ per date.
  final Map<String, TimeOfDay> _fromByDate = {};
  final Map<String, TimeOfDay> _toByDate = {};
  bool _saving = false;

  /// Separate times per date only makes sense with more than one date picked.
  bool get _perDate => !_sameTime && _dates.length > 1;

  /// Picked event days in calendar order.
  List<({String iso, String label})> get _pickedDays =>
      eventDays(widget.event).where((d) => _dates.contains(d.iso)).toList();

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadSpeakers();
  }

  @override
  void dispose() {
    _name.dispose();
    _hall.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadSpeakers() async {
    final res = await ApiService().listSpeakers();
    if (!mounted) return;
    setState(() {
      _loadingSpeakers = false;
      if (res['success'] == true) {
        _speakers = ((res['speakers'] as List?) ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        if (_speakers.every((s) => s['id'] != _speakerId)) _speakerId = null;
      }
    });
  }

  Future<void> _openSpeakers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageSpeakersPage()),
    );
    // Speakers may have been added there.
    _loadSpeakers();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
    if (_speakerId == null) return _toast('Select a speaker');
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
      speakerId: _speakerId!,
      scheduleName: _name.text.trim(),
      hall: _hall.text.trim(),
      slots: slots,
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _toast(res['error']?.toString() ?? 'Failed to add schedule');
    }
  }

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
        decoration: darkInputDecoration(label, icon),
        child: Text(
          value ?? 'Select',
          style: TextStyle(
            color: value == null ? DarkColors.muted : Colors.white,
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

  /// The speaker dropdown (speakers come from the Speakers page).
  Widget _speakerField() {
    if (_loadingSpeakers) {
      return InputDecorator(
        decoration: darkInputDecoration('Speaker', Icons.person_outline),
        child: const Text(
          'Loading speakers…',
          style: TextStyle(color: DarkColors.muted),
        ),
      );
    }
    if (_speakers.isEmpty) {
      return InkWell(
        onTap: _openSpeakers,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: darkInputDecoration('Speaker', Icons.person_outline),
          child: const Text(
            'No speakers yet — tap to add them on the Speakers page',
            style: TextStyle(color: DarkColors.accentLight),
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _speakerId,
      isExpanded: true,
      dropdownColor: DarkColors.field,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      iconEnabledColor: DarkColors.muted,
      decoration: darkInputDecoration('Speaker', Icons.person_outline),
      hint: const Text(
        'Select speaker',
        style: TextStyle(color: DarkColors.muted),
      ),
      items: [
        for (final s in _speakers)
          DropdownMenuItem(
            value: s['id'].toString(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFF1E3A8A),
                  backgroundImage: (s['photo']?.toString() ?? '').isNotEmpty
                      ? CachedNetworkImageProvider(s['photo'].toString())
                      : null,
                  child: (s['photo']?.toString() ?? '').isEmpty
                      ? Text(
                          (s['name']?.toString() ?? '?').trim().isEmpty
                              ? '?'
                              : s['name'].toString().trim()[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s['name']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (v) => setState(() => _speakerId = v),
      validator: (v) => v == null ? 'Select a speaker' : null,
    );
  }

  /// The event's own days — the speaker can be on any number of these.
  Widget _dayChips() {
    final days = eventDays(widget.event);
    return InputDecorator(
      decoration: darkInputDecoration(
        'Date (event days)',
        Icons.calendar_month_outlined,
      ),
      child: days.isEmpty
          ? const Text(
              'This event has no dates',
              style: TextStyle(color: DarkColors.muted),
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
                  selectedColor: DarkColors.accent,
                  backgroundColor: DarkColors.card,
                  side: const BorderSide(color: DarkColors.line),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : DarkColors.muted,
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
    const fieldStyle = TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Add Schedule',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _speakerField(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              style: fieldStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: darkInputDecoration(
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
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: darkInputDecoration(
                'Hall / venue',
                Icons.meeting_room_outlined,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the hall' : null,
            ),
            const SizedBox(height: 12),
            _dayChips(),
            if (_dates.length > 1)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _sameTime,
                activeThumbColor: DarkColors.accent,
                title: const Text(
                  'Same time for all dates',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
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
                      color: Colors.white,
                    ),
                  ),
                ),
                _timeRow(day.iso),
                const SizedBox(height: 12),
              ]
            else ...[_timeRow(), const SizedBox(height: 12)],
            TextFormField(
              controller: _description,
              style: fieldStyle,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: darkInputDecoration(
                'Description',
                Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarkColors.accent,
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
