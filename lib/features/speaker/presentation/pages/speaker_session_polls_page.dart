import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/speaker_ui.dart';

/// Speaker creates polls on one of their sessions and sees the vote counts
/// (only the speaker sees results; participants just vote).
class SpeakerSessionPollsPage extends StatefulWidget {
  final SpeakerSessionRef session;

  const SpeakerSessionPollsPage({super.key, required this.session});

  @override
  State<SpeakerSessionPollsPage> createState() =>
      _SpeakerSessionPollsPageState();
}

class _SpeakerSessionPollsPageState extends State<SpeakerSessionPollsPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _polls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    final res = await _api.getSessionContent(widget.session.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _polls = ((res['polls'] as List?) ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load polls';
      }
    });
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CreatePollPage(scheduleId: widget.session.id),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> poll) async {
    if (!await confirmSpeakerDelete(context, 'poll')) return;
    final res = await _api.deleteSessionPoll(
      widget.session.id,
      poll['id'].toString(),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _polls.removeWhere((p) => p['id'] == poll['id']));
    } else {
      _toast(res['error']?.toString() ?? 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeakerColors.bg,
      appBar: speakerAppBar('Poll'),
      bottomNavigationBar: SpeakerActionButton(
        label: 'Create Poll',
        icon: Icons.add_rounded,
        onPressed: _create,
      ),
      body: RefreshIndicator(
        color: SpeakerColors.green,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            SpeakerSessionHeader(session: widget.session),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: SpeakerColors.green),
                ),
              )
            else if (_error != null)
              SpeakerEmptyText('${_error!}\nPull down to try again.')
            else if (_polls.isEmpty)
              const SpeakerEmptyText(
                'No polls yet.\n'
                'Participants vote on them from this session’s details page.',
              )
            else
              for (final p in _polls) _pollCard(p),
          ],
        ),
      ),
    );
  }

  Widget _pollCard(Map<String, dynamic> p) {
    final options = List<String>.from((p['options'] as List?) ?? const []);
    final counts = ((p['counts'] as List?) ?? const [])
        .map((c) => (c as num).toInt())
        .toList();
    final total = (p['totalVotes'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
      decoration: speakerCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    p['question']?.toString() ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFF87171),
                ),
                onPressed: () => _delete(p),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < options.length; i++)
                  _resultBar(
                    options[i],
                    i < counts.length ? counts[i] : 0,
                    total,
                  ),
                const SizedBox(height: 4),
                Text(
                  total == 1 ? '1 vote' : '$total votes',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: SpeakerColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBar(String option, int count, int total) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '$count  ·  ${(fraction * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SpeakerColors.time,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(SpeakerColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

/// Question + 2–6 options.
class _CreatePollPage extends StatefulWidget {
  final String scheduleId;

  const _CreatePollPage({required this.scheduleId});

  @override
  State<_CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<_CreatePollPage> {
  static const _maxOptions = 6;

  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final question = _question.text.trim();
    final options = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (question.isEmpty) return _toast('Enter the poll question');
    if (options.length < 2) return _toast('Add at least 2 options');
    setState(() => _saving = true);
    final res = await ApiService().createSessionPoll(
      widget.scheduleId,
      question: question,
      options: options,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _toast(res['error']?.toString() ?? 'Could not create the poll');
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13.5, color: SpeakerColors.sub),
    filled: true,
    fillColor: SpeakerColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SpeakerColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SpeakerColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SpeakerColors.green),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fieldStyle = GoogleFonts.inter(fontSize: 14, color: Colors.white);
    final labelStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: SpeakerColors.sub,
    );
    return Scaffold(
      backgroundColor: SpeakerColors.bg,
      appBar: speakerAppBar('Create Poll'),
      bottomNavigationBar: SpeakerActionButton(
        label: 'Save Poll',
        icon: Icons.check_rounded,
        onPressed: _save,
        busy: _saving,
        busyLabel: 'Saving…',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text('QUESTION', style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _question,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: fieldStyle,
            decoration: _dec('e.g. Which technique do you use most?'),
          ),
          const SizedBox(height: 18),
          Text('OPTIONS', style: labelStyle),
          const SizedBox(height: 8),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _options[i],
                      textCapitalization: TextCapitalization.sentences,
                      style: fieldStyle,
                      decoration: _dec('Option ${i + 1}'),
                    ),
                  ),
                  if (_options.length > 2)
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: SpeakerColors.sub,
                      ),
                      onPressed: () {
                        final removed = _options[i];
                        setState(() => _options.removeAt(i));
                        // Its field is still mounted until this rebuild ends.
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => removed.dispose(),
                        );
                      },
                    ),
                ],
              ),
            ),
          if (_options.length < _maxOptions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded, color: SpeakerColors.green),
                label: Text(
                  'Add option',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: SpeakerColors.green,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
