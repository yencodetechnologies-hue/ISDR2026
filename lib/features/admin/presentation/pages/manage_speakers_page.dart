import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'speaker_questions_page.dart';

/// Management's Speakers page: every speaker of the property. Speakers are
/// added here and then picked from a dropdown when adding a schedule.
class ManageSpeakersPage extends StatefulWidget {
  const ManageSpeakersPage({super.key});

  @override
  State<ManageSpeakersPage> createState() => _ManageSpeakersPageState();
}

class _ManageSpeakersPageState extends State<ManageSpeakersPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _speakers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.listSpeakers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _speakers = ((res['speakers'] as List?) ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load speakers';
      }
    });
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddSpeakerPage()),
    );
    if (added == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> speaker) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddSpeakerPage(speaker: speaker)),
    );
    if (saved == true) _load();
  }

  Future<void> _setAsk(Map<String, dynamic> speaker, bool enabled) async {
    final id = speaker['id'].toString();
    setState(() {
      _speakers = _speakers
          .map((s) => s['id'] == speaker['id'] ? {...s, 'askEnabled': enabled} : s)
          .toList();
    });
    final res = await _api.setSpeakerAskEnabled(id, enabled);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _speakers = _speakers
            .map((s) => s['id'] == speaker['id'] ? {...s, 'askEnabled': !enabled} : s)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not update')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> speaker) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text(
          'Delete speaker?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${speaker['name']} will no longer be able to log in.',
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
    final res = await _api.deleteSpeaker(speaker['id'].toString());
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _speakers.removeWhere((s) => s['id'] == speaker['id']));
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
          'Speakers',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: DarkColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Speaker'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_error != null || _speakers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 44,
                      color: DarkColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'No speakers yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error != null
                          ? 'Pull down to try again.'
                          : 'Add speakers here, then pick them when adding a schedule.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: DarkColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final s in _speakers) _row(s),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final photo = s['photo']?.toString() ?? '';
    final name = s['name']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: darkCardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF1E3A8A),
            backgroundImage: photo.isNotEmpty
                ? CachedNetworkImageProvider(photo)
                : null,
            child: photo.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name.trim()[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpeakerQuestionsPage(
                    speakerId: s['id'].toString(),
                    speakerName: name,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Questions',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: DarkColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: s['askEnabled'] == true,
                activeThumbColor: Colors.white,
                activeTrackColor: DarkColors.accent,
                onChanged: (v) => _setAsk(s, v),
              ),
              Text(
                s['askEnabled'] == true ? 'On' : 'Off',
                style: GoogleFonts.inter(fontSize: 10, color: DarkColors.muted),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF60A5FA)),
            onPressed: () => _edit(s),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFF87171),
            ),
            onPressed: () => _delete(s),
          ),
        ],
      ),
    );
  }
}

/// Name only. Turn the speaker on for questions from the speaker list.
class AddSpeakerPage extends StatefulWidget {
  final Map<String, dynamic>? speaker;

  const AddSpeakerPage({super.key, this.speaker});

  @override
  State<AddSpeakerPage> createState() => _AddSpeakerPageState();
}

class _AddSpeakerPageState extends State<AddSpeakerPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.speaker != null;

  @override
  void initState() {
    super.initState();
    final sp = widget.speaker;
    if (sp != null) _name.text = sp['name']?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final res = _isEdit
        ? await ApiService().updateSpeaker(
            id: widget.speaker!['id'].toString(),
            name: _name.text.trim(),
          )
        : await ApiService().createSpeaker(name: _name.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['error']?.toString() ??
                (_isEdit ? 'Could not save speaker' : 'Could not add speaker'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          _isEdit ? 'Edit Speaker' : 'Add Speaker',
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
            TextFormField(
              controller: _name,
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: darkInputDecoration(
                'Name of the speaker',
                Icons.person_outline,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the speaker name'
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Turn this speaker on from the list when participants should be able to ask them a question.',
              style: GoogleFonts.inter(fontSize: 12.5, color: DarkColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarkColors.accent,
                  foregroundColor: Colors.white,
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
                        'Save Speaker',
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
