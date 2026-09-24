import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Questions participants asked this speaker directly. Each can be answered
/// once; only the asking participant sees the answer.
class SpeakerParticipantQuestionsPage extends StatefulWidget {
  const SpeakerParticipantQuestionsPage({super.key});

  @override
  State<SpeakerParticipantQuestionsPage> createState() =>
      _SpeakerParticipantQuestionsPageState();
}

class _SpeakerParticipantQuestionsPageState
    extends State<SpeakerParticipantQuestionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().getSpeakerInbox();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _questions = ((res['questions'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load questions';
      }
    });
  }

  void _replace(Map<String, dynamic> updated) {
    setState(() {
      final i = _questions.indexWhere((q) => q['id'] == updated['id']);
      if (i >= 0) _questions[i] = updated;
    });
  }

  Widget _list(List<Map<String, dynamic>> items, String emptyText) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            _empty(Icons.error_outline_rounded, _error!)
          else if (items.isEmpty)
            _empty(Icons.forum_outlined, emptyText)
          else
            for (final q in items)
              _QuestionCard(
                key: ValueKey(q['id']),
                question: q,
                onAnswered: _replace,
              ),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
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

  @override
  Widget build(BuildContext context) {
    final unanswered = _questions.where((q) => q['answered'] != true).toList();
    final answered = _questions.where((q) => q['answered'] == true).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: DarkColors.bg,
        appBar: buildDarkAppBar(
          title: Text(
            'Participant Questions',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            indicatorColor: DarkColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: DarkColors.muted,
            labelStyle: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: 'Unanswered (${unanswered.length})'),
              Tab(text: 'Answered (${answered.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _list(unanswered, 'No new questions'),
                  _list(answered, 'No answered questions yet'),
                ],
              ),
      ),
    );
  }
}

/// One participant question: their name, the question and the answer box
/// (or the answer already sent).
class _QuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final ValueChanged<Map<String, dynamic>> onAnswered;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
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
    final res = await ApiService().answerParticipantQuestion(
      widget.question['id'].toString(),
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true && res['question'] is Map) {
      widget.onAnswered(Map<String, dynamic>.from(res['question'] as Map));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer sent')),
      );
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
    final answered = q['answered'] == true;
    final name = (q['participantName']?.toString() ?? '').trim();
    final asked = DateTime.tryParse(q['createdAt']?.toString() ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 16,
                color: DarkColors.accentLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Participant' : name,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DarkColors.accentLight,
                  ),
                ),
              ),
              if (asked != null)
                Text(
                  DateFormat('d MMM, h:mm a').format(asked),
                  style: GoogleFonts.inter(fontSize: 11, color: DarkColors.muted),
                ),
            ],
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
          const SizedBox(height: 12),
          if (answered) ...[
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
              q['answer']?.toString() ?? '',
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
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your answer',
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
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "An answer can't be changed once sent.",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: DarkColors.muted,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: DarkColors.accent,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send answer'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
