import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../widgets/event_package_sheet.dart' show eventDays;

/// Form to add a schedule to an event. It's shown only to participants of the
/// picked packages. The speaker is a name typed on the schedule.
class AddEventSchedulePage extends StatefulWidget {
  final Map<String, dynamic> event;

  /// When given, the page edits this schedule (one date) instead of adding.
  final Map<String, dynamic>? schedule;

  const AddEventSchedulePage({super.key, required this.event, this.schedule});

  @override
  State<AddEventSchedulePage> createState() => _AddEventSchedulePageState();
}

class _AddEventSchedulePageState extends State<AddEventSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _speaker = TextEditingController();
  final _name = TextEditingController();
  final _hall = TextEditingController();
  final _description = TextEditingController();

  final Set<String> _packageIds = {}; // packages whose participants see it
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

  /// Walk-in package. It stays on the event, but is not a schedule audience.
  bool _isSpotRegister(String name) =>
      RegExp(r'^spot register$', caseSensitive: false).hasMatch(name.trim());

  /// Every package on the event, including Spot register.
  List<({String id, String name})> get _eventPackages =>
      ((widget.event['packages'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (p) => (
              id: p['id']?.toString() ?? '',
              name: p['name']?.toString() ?? '',
            ),
          )
          .where((p) => p.id.isNotEmpty)
          .toList();

  /// Packages that can be chosen as who sees this session.
  List<({String id, String name})> get _packages =>
      _eventPackages.where((p) => !_isSpotRegister(p.name)).toList();

  String get _eventId =>
      widget.event['id']?.toString() ?? widget.event['_id']?.toString() ?? '';

  bool get _isEdit => widget.schedule != null;

  /// Packages the schedule was saved with that no longer exist on the event.
  int _removedPackages = 0;

  /// Old schedules saved before packages existed (shown to everyone).
  bool get _hadNoPackages =>
      _isEdit && ((widget.schedule!['packageIds'] as List?) ?? const []).isEmpty;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    if (s != null) {
      _speaker.text = s['speakerName']?.toString() ?? '';
      _name.text = s['scheduleName']?.toString() ?? '';
      _hall.text = s['hall']?.toString() ?? '';
      _description.text = s['description']?.toString() ?? '';
      // Keep selectable packages the event still has. Spot register is hidden
      // from this form, so a saved id for it is dropped and not counted as deleted.
      final saved = ((s['packageIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList();
      final onEvent = _eventPackages.map((p) => p.id).toSet();
      final selectable = _packages.map((p) => p.id).toSet();
      _packageIds.addAll(saved.where(selectable.contains));
      _removedPackages = saved.where((id) => !onEvent.contains(id)).length;
      final utc = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
      if (utc != null) {
        _dates.add(
          '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}',
        );
      }
      TimeOfDay? time(dynamic v) {
        final p = v?.toString().split(':') ?? const [];
        if (p.length < 2) return null;
        final h = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
      }

      _from = time(s['fromTime']);
      _to = time(s['toTime']);
    }
  }

  @override
  void dispose() {
    _speaker.dispose();
    _name.dispose();
    _hall.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Shown to the user: 12-hour with AM/PM.
  String _fmt12(TimeOfDay t) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(t, alwaysUse24HourFormat: false);

  /// Sent to the backend: "HH:mm".
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
      // 12-hour dial with AM/PM even when the phone uses 24-hour time.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
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
    if (_packageIds.isEmpty && !_hadNoPackages) {
      return _toast('Select at least one package');
    }
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
    final res = _isEdit
        ? await ApiService().updateEventSchedule(
            eventId: _eventId,
            scheduleId: widget.schedule!['id'].toString(),
            speakerName: _speaker.text.trim(),
            packageIds: _packageIds.toList(),
            scheduleName: _name.text.trim(),
            hall: _hall.text.trim(),
            slot: slots.first,
            description: _description.text.trim(),
          )
        : await ApiService().createEventSchedule(
            eventId: _eventId,
            speakerName: _speaker.text.trim(),
            packageIds: _packageIds.toList(),
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
      _toast(
        res['error']?.toString() ??
            (_isEdit ? 'Failed to update schedule' : 'Failed to add schedule'),
      );
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
            from == null ? null : _fmt12(from),
            () => _pickTime(true, dateIso),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _picker(
            'To time',
            Icons.schedule_rounded,
            to == null ? null : _fmt12(to),
            () => _pickTime(false, dateIso),
          ),
        ),
      ],
    );
  }

  /// Which packages' participants see this schedule (one or more).
  Widget _packageChips() {
    final packages = _packages;
    return InputDecorator(
      decoration: darkInputDecoration(
        'Packages (who can see it)',
        Icons.card_membership_outlined,
      ),
      child: packages.isEmpty
          ? const Text(
              'This event has no packages. Add packages to the event first.',
              style: TextStyle(color: DarkColors.muted),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: packages.map((p) {
                final selected = _packageIds.contains(p.id);
                return FilterChip(
                  label: Text(p.name),
                  selected: selected,
                  showCheckmark: true,
                  checkmarkColor: Colors.white,
                  selectedColor: DarkColors.accent,
                  backgroundColor: DarkColors.card,
                  side: const BorderSide(color: DarkColors.line),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : DarkColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _packageIds.remove(p.id);
                    } else {
                      _packageIds.add(p.id);
                    }
                  }),
                );
              }).toList(),
            ),
    );
  }

  /// The event's own days — a session can be on any number of these.
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
                    if (_isEdit) {
                      _dates
                        ..clear()
                        ..add(d.iso);
                    } else if (selected) {
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
          _isEdit ? 'Edit Schedule' : 'Add Schedule',
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
            _packageChips(),
            if (_removedPackages > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _removedPackages == 1
                            ? 'The package this schedule was saved with has been deleted from the event. Select its package again.'
                            : '$_removedPackages packages this schedule was saved with have been deleted from the event. Select its packages again.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _speaker,
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: darkInputDecoration(
                'Speaker',
                Icons.person_outline,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a speaker name'
                  : null,
            ),
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
