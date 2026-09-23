import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../pages/session_file_viewer.dart';

class _Colors {
  static const ink = Color(0xFF0F172A);
  static const primaryBlue = Color(0xFF2563EB);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
  static const green = Color(0xFF16A34A);
}

/// What the speaker added to a session — files to open, polls to vote on and
/// questions to answer. Shown on the session's details page; only participants
/// can vote / answer, and they never see others' votes or answers.
class SessionContentSection extends StatefulWidget {
  final String scheduleId;

  const SessionContentSection({super.key, required this.scheduleId});

  @override
  State<SessionContentSection> createState() => _SessionContentSectionState();
}

class _SessionContentSectionState extends State<SessionContentSection> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  bool _canRespond = false;
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _polls = [];
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(dynamic raw) => ((raw as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _load() async {
    final res = await _api.getSessionContent(widget.scheduleId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _canRespond = res['canRespond'] == true;
        _files = _list(res['files']);
        _polls = _list(res['polls']);
        _questions = _list(res['questions']);
      } else {
        _error = res['error']?.toString() ?? 'Could not load session materials';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          _error!,
          style: GoogleFonts.inter(fontSize: 12.5, color: _Colors.muted),
        ),
      );
    }
    if (_files.isEmpty && _polls.isEmpty && _questions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_files.isNotEmpty)
          _Group(
            title: 'PRESENTATIONS & DOCUMENTS',
            children: [for (final f in _files) _FileRow(file: f)],
          ),
        if (_polls.isNotEmpty)
          _Group(
            title: 'POLLS',
            children: [
              for (var i = 0; i < _polls.length; i++)
                _PollCard(
                  key: ValueKey(_polls[i]['id']),
                  scheduleId: widget.scheduleId,
                  poll: _polls[i],
                  canRespond: _canRespond,
                  onUpdated: (p) => setState(() => _polls[i] = p),
                ),
            ],
          ),
        if (_questions.isNotEmpty)
          _Group(
            title: 'QUESTIONS',
            children: [
              for (var i = 0; i < _questions.length; i++)
                _QuestionCard(
                  key: ValueKey(_questions[i]['id']),
                  scheduleId: widget.scheduleId,
                  question: _questions[i],
                  canRespond: _canRespond,
                  onUpdated: (q) => setState(() => _questions[i] = q),
                ),
            ],
          ),
      ],
    );
  }
}

/// White card with a small uppercase heading, like "ABOUT THIS SESSION".
class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: _Colors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final Map<String, dynamic> file;

  const _FileRow({required this.file});

  @override
  Widget build(BuildContext context) {
    final isPdf = file['kind'] == 'pdf';
    final color = isPdf ? const Color(0xFFE11D48) : const Color(0xFFF97316);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openSessionFile(context, file),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.slideshow_rounded,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['name']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _Colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPdf ? 'PDF · Tap to view' : 'Presentation · Tap to view',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: _Colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _Colors.muted),
          ],
        ),
      ),
    );
  }
}

/// A poll: pick one option and submit. After voting, the chosen option stays
/// highlighted (no results are shown to participants).
class _PollCard extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> poll;
  final bool canRespond;
  final ValueChanged<Map<String, dynamic>> onUpdated;

  const _PollCard({
    super.key,
    required this.scheduleId,
    required this.poll,
    required this.canRespond,
    required this.onUpdated,
  });

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  int? _selected;
  bool _sending = false;

  Future<void> _vote() async {
    final option = _selected;
    if (option == null) return;
    setState(() => _sending = true);
    final res = await ApiService().voteSessionPoll(
      widget.scheduleId,
      widget.poll['id'].toString(),
      option,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true && res['poll'] is Map) {
      widget.onUpdated(Map<String, dynamic>.from(res['poll'] as Map));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not vote')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(
      (widget.poll['options'] as List?) ?? const [],
    );
    final myVote = (widget.poll['myVote'] as num?)?.toInt();
    final voted = myVote != null;
    final canVote = widget.canRespond && !voted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.poll['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _Colors.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < options.length; i++)
            _optionRow(
              options[i],
              chosen: voted ? myVote == i : _selected == i,
              onTap: canVote ? () => setState(() => _selected = i) : null,
            ),
          if (voted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Thanks — your vote is recorded',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _Colors.green,
                ),
              ),
            )
          else if (canVote)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _selected == null || _sending ? null : _vote,
                style: FilledButton.styleFrom(
                  backgroundColor: _Colors.primaryBlue,
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
                    : const Text('Submit vote'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionRow(String label, {required bool chosen, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: chosen
                ? _Colors.primaryBlue.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: chosen ? _Colors.primaryBlue : _Colors.line,
              width: chosen ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                chosen
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: chosen ? _Colors.primaryBlue : _Colors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
                    color: _Colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A question: type an answer and submit once; afterwards it shows "Your answer".
class _QuestionCard extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> question;
  final bool canRespond;
  final ValueChanged<Map<String, dynamic>> onUpdated;

  const _QuestionCard({
    super.key,
    required this.scheduleId,
    required this.question,
    required this.canRespond,
    required this.onUpdated,
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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final res = await ApiService().answerSessionQuestion(
      widget.scheduleId,
      widget.question['id'].toString(),
      text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true && res['question'] is Map) {
      widget.onUpdated(Map<String, dynamic>.from(res['question'] as Map));
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
    final myAnswer = widget.question['myAnswer']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _Colors.ink,
            ),
          ),
          if (myAnswer != null) ...[
            const SizedBox(height: 10),
            Text(
              'YOUR ANSWER',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: _Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              myAnswer,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: _Colors.ink,
                height: 1.45,
              ),
            ),
          ] else if (widget.canRespond) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13.5, color: _Colors.ink),
              decoration: InputDecoration(
                hintText: 'Type your answer',
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _Colors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _Colors.line),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _Colors.primaryBlue,
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
                    : const Text('Submit answer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
