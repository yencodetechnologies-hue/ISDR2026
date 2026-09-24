import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

List<Map<String, dynamic>> _list(dynamic raw) => ((raw as List?) ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

Text _title(String text) => Text(
  text,
  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
);

Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: DarkColors.muted,
    ),
  ),
);

Widget _emptyState(IconData icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(
    children: [
      Icon(icon, size: 40, color: DarkColors.muted.withValues(alpha: 0.6)),
      const SizedBox(height: 10),
      Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: DarkColors.muted),
      ),
    ],
  ),
);

Widget _avatar(String name, String photo, {double size = 40}) {
  final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  return ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: photo.isNotEmpty
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialCircle(initial, size),
            )
          : _initialCircle(initial, size),
    ),
  );
}

Widget _initialCircle(String initial, double size) => Container(
  color: DarkColors.accent.withValues(alpha: 0.25),
  alignment: Alignment.center,
  child: Text(
    initial,
    style: GoogleFonts.outfit(
      fontSize: size * 0.42,
      fontWeight: FontWeight.w700,
      color: DarkColors.accentLight,
    ),
  ),
);

InputDecoration _boxDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: DarkColors.muted),
  filled: true,
  fillColor: DarkColors.field,
  counterText: '',
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: DarkColors.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: DarkColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: DarkColors.accent),
  ),
);

Widget _spinnerOr(bool busy, String label) => busy
    ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
    : Text(label);

/// Participant Q/A: speakers' session questions to answer, plus
/// "Ask a Speaker" and "My Questions" (the speakers' answers).
class ParticipantQaPage extends StatefulWidget {
  const ParticipantQaPage({super.key});

  @override
  State<ParticipantQaPage> createState() => _ParticipantQaPageState();
}

class _ParticipantQaPageState extends State<ParticipantQaPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.getAllSessionQuestions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _questions = _list(res['questions']);
      } else {
        _error = res['error']?.toString() ?? 'Could not load questions';
      }
    });
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final pending = _questions.where((q) => q['myAnswer'] == null).length;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(title: _title('Q/A')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.record_voice_over_rounded,
                    color: const Color(0xFF3B82F6),
                    title: 'Ask a Speaker',
                    subtitle: 'Send your question',
                    onTap: () => _open(const AskSpeakerPage()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.mark_chat_read_rounded,
                    color: const Color(0xFF22C55E),
                    title: 'My Questions',
                    subtitle: "Speakers' answers",
                    onTap: () => _open(const MyQuestionsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionLabel(
              pending > 0
                  ? 'QUESTIONS FOR YOU · $pending TO ANSWER'
                  : 'QUESTIONS FOR YOU',
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _emptyState(Icons.error_outline_rounded, _error!)
            else if (_questions.isEmpty)
              _emptyState(
                Icons.quiz_outlined,
                'No questions from speakers yet',
              )
            else
              for (var i = 0; i < _questions.length; i++)
                _SessionQuestionCard(
                  key: ValueKey(_questions[i]['id']),
                  question: _questions[i],
                  onAnswered: (text) =>
                      setState(() => _questions[i]['myAnswer'] = text),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DarkColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DarkColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: DarkColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A speaker's session question: type one answer, or see the one you gave.
class _SessionQuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final ValueChanged<String> onAnswered;

  const _SessionQuestionCard({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<_SessionQuestionCard> createState() => _SessionQuestionCardState();
}

class _SessionQuestionCardState extends State<_SessionQuestionCard> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final q = widget.question;
    final res = await ApiService().answerSessionQuestion(
      q['scheduleId'].toString(),
      q['id'].toString(),
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      widget.onAnswered(text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not send answer'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final myAnswer = q['myAnswer']?.toString();
    final date = DateTime.tryParse(q['date']?.toString() ?? '')?.toLocal();
    final meta = [
      q['speakerName']?.toString() ?? '',
      if (date != null) DateFormat('d MMM').format(date),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q['sessionName']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: DarkColors.accentLight,
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: GoogleFonts.inter(fontSize: 11, color: DarkColors.muted),
            ),
          const SizedBox(height: 8),
          Text(
            q['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (myAnswer != null) ...[
            Text(
              'YOUR ANSWER',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              myAnswer,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: Colors.white,
                height: 1.45,
              ),
            ),
          ] else ...[
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
              decoration: _boxDecoration('Type your answer'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: DarkColors.accent,
                ),
                child: _spinnerOr(_sending, 'Submit answer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pick a speaker, then type a question to them.
class AskSpeakerPage extends StatefulWidget {
  const AskSpeakerPage({super.key});

  @override
  State<AskSpeakerPage> createState() => _AskSpeakerPageState();
}

class _AskSpeakerPageState extends State<AskSpeakerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _speakers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().listAskableSpeakers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _speakers = _list(res['speakers']);
      } else {
        _error = res['error']?.toString() ?? 'Could not load speakers';
      }
    });
  }

  Future<void> _ask(Map<String, dynamic> speaker) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DarkColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AskSheet(speaker: speaker),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question sent'),
          action: SnackBarAction(
            label: 'My Questions',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyQuestionsPage()),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(title: _title('Ask a Speaker')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _emptyState(Icons.error_outline_rounded, _error!)
          : _speakers.isEmpty
          ? _emptyState(Icons.groups_outlined, 'No speakers yet')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _speakers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = _speakers[i];
                final name = s['name']?.toString() ?? '';
                return Material(
                  color: DarkColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: DarkColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _ask(s),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _avatar(name, s['photo']?.toString() ?? '', size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: DarkColors.accentLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Bottom sheet: the question box for one speaker.
class _AskSheet extends StatefulWidget {
  final Map<String, dynamic> speaker;

  const _AskSheet({required this.speaker});

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final res = await ApiService().askSpeakerQuestion(
      widget.speaker['id'].toString(),
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not send question'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.speaker['name']?.toString() ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(name, widget.speaker['photo']?.toString() ?? ''),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ask $name',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: _boxDecoration('Type your question'),
          ),
          const SizedBox(height: 6),
          Text(
            'Only you and the speaker will see this question and the answer.',
            style: GoogleFonts.inter(fontSize: 11, color: DarkColors.muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: DarkColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _spinnerOr(_sending, 'Send question'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The participant's questions to speakers and the speakers' answers.
class MyQuestionsPage extends StatefulWidget {
  const MyQuestionsPage({super.key});

  @override
  State<MyQuestionsPage> createState() => _MyQuestionsPageState();
}

class _MyQuestionsPageState extends State<MyQuestionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().getMySpeakerQuestions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _questions = _list(res['questions']);
      } else {
        _error = res['error']?.toString() ?? 'Could not load your questions';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(title: _title('My Questions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _emptyState(Icons.error_outline_rounded, _error!)
                  else if (_questions.isEmpty)
                    _emptyState(
                      Icons.forum_outlined,
                      "You haven't asked any speaker yet",
                    )
                  else
                    for (final q in _questions) _MyQuestionCard(question: q),
                ],
              ),
      ),
    );
  }
}

class _MyQuestionCard extends StatelessWidget {
  final Map<String, dynamic> question;

  const _MyQuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final q = question;
    final answered = q['answered'] == true;
    final name = q['speakerName']?.toString() ?? 'Speaker';
    final asked = DateTime.tryParse(q['createdAt']?.toString() ?? '')?.toLocal();
    final statusColor = answered
        ? const Color(0xFF22C55E)
        : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(name, q['speakerPhoto']?.toString() ?? '', size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (asked != null)
                      Text(
                        'Asked ${DateFormat('d MMM, h:mm a').format(asked)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: DarkColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  answered ? 'Answered' : 'Awaiting answer',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (answered) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: DarkColors.field,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: statusColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SPEAKER'S ANSWER",
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .5,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                q['answer']?.toString() ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: Colors.white,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
