import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin list of pre-conference courses, with add, edit, and delete.
class ManagePreconferencePage extends StatefulWidget {
  const ManagePreconferencePage({super.key});

  @override
  State<ManagePreconferencePage> createState() => _ManagePreconferencePageState();
}

class _ManagePreconferencePageState extends State<ManagePreconferencePage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.listPreconference();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _courses = ((res['courses'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load courses';
      }
    });
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PreconferenceFormPage(existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text('Delete course?', style: TextStyle(color: Colors.white)),
        content: Text(
          'S No ${row['serialNo']} will be removed from the participant list.',
          style: const TextStyle(color: DarkColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.deletePreconference('${row['id']}');
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _courses.removeWhere((c) => c['id'] == row['id']));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not delete')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Preconference',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: DarkColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_error != null || _courses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(
                            _error != null
                                ? Icons.error_outline_rounded
                                : Icons.school_outlined,
                            size: 44,
                            color: DarkColors.muted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error ?? 'No courses yet',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: DarkColors.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final row in _courses) _card(row),
                ],
              ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFA5B4FC), Color(0xFF6366F1)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'S NO  ${row['serialNo'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFC7D2FE),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF93C5FD)),
                        const SizedBox(width: 4),
                        Text(
                          '${row['date'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openForm(row),
                          icon: const Icon(Icons.edit_outlined, color: DarkColors.accentLight),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(row),
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${row['course'] ?? ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: DarkColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFA5B4FC)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${row['venue'] ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreconferenceFormPage extends StatefulWidget {
  const PreconferenceFormPage({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<PreconferenceFormPage> createState() => _PreconferenceFormPageState();
}

class _PreconferenceFormPageState extends State<PreconferenceFormPage> {
  final _api = ApiService();
  late final TextEditingController _serial;
  late final TextEditingController _date;
  late final TextEditingController _course;
  late final TextEditingController _venue;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _serial = TextEditingController(text: e == null ? '' : '${e['serialNo'] ?? ''}');
    _date = TextEditingController(text: e?['date']?.toString() ?? '');
    _course = TextEditingController(text: e?['course']?.toString() ?? '');
    _venue = TextEditingController(text: e?['venue']?.toString() ?? '');
  }

  @override
  void dispose() {
    _serial.dispose();
    _date.dispose();
    _course.dispose();
    _venue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final serialNo = int.tryParse(_serial.text.trim());
    if (serialNo == null || serialNo < 1) {
      _toast('Enter a whole S No starting at 1');
      return;
    }
    if (_date.text.trim().isEmpty) {
      _toast('Enter the date');
      return;
    }
    if (_course.text.trim().isEmpty) {
      _toast('Enter the course');
      return;
    }
    if (_venue.text.trim().isEmpty) {
      _toast('Enter the venue');
      return;
    }
    setState(() => _saving = true);
    final res = _editing
        ? await _api.updatePreconference(
            '${widget.existing!['id']}',
            serialNo: serialNo,
            date: _date.text.trim(),
            course: _course.text.trim(),
            venue: _venue.text.trim(),
          )
        : await _api.createPreconference(
            serialNo: serialNo,
            date: _date.text.trim(),
            course: _course.text.trim(),
            venue: _venue.text.trim(),
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _toast(res['error']?.toString() ?? 'Could not save');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          _editing ? 'Edit course' : 'Add course',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _serial,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration('S No', Icons.numbers),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _date,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration('Date', Icons.event),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _course,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration('Pre Conference Course', Icons.school_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venue,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration('Venue', Icons.location_on_outlined),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: DarkColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_editing ? 'Save changes' : 'Add course'),
            ),
          ),
        ],
      ),
    );
  }
}
