import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/speaker_ui.dart';

/// Speaker asks questions on one of their sessions and reads participants'
/// typed answers (only the speaker sees the answers).
class SpeakerSessionQuestionsPage extends StatefulWidget {
  final SpeakerSessionRef session;

  const SpeakerSessionQuestionsPage({super.key, required this.session});

  @override
  State<SpeakerSessionQuestionsPage> createState() =>
      _SpeakerSessionQuestionsPageState();
}

class _SpeakerSessionQuestionsPageState
    extends State<SpeakerSessionQuestionsPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _questions = [];
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
        _questions = ((res['questions'] as List?) ?? [])
            .map((q) => Map<String, dynamic>.from(q as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load questions';
      }
    });
  }

  Future<void> _add() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _AddQuestionDialog(),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final res = await _api.createSessionQuestion(
      widget.session.id,
      text.trim(),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
    } else {
      _toast(res['error']?.toString() ?? 'Could not add the question');
    }
  }

  /// Speaker edits the wording. Existing answers stay attached.
  Future<void> _edit(Map<String, dynamic> q) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _AddQuestionDialog(initialText: q['question']?.toString() ?? ''),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final res = await _api.updateSessionQuestion(
      widget.session.id,
      q['id'].toString(),
      text.trim(),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
    } else {
      _toast(res['error']?.toString() ?? 'Could not update the question');
    }
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    if (!await confirmSpeakerDelete(context, 'question')) return;
    final res = await _api.deleteSessionQuestion(
      widget.session.id,
      q['id'].toString(),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _questions.removeWhere((x) => x['id'] == q['id']));
    } else {
      _toast(res['error']?.toString() ?? 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeakerColors.bg,
      appBar: speakerAppBar('Q&A'),
      bottomNavigationBar: SpeakerActionButton(
        label: 'Add Question',
        icon: Icons.add_rounded,
        onPressed: _add,
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
            else if (_questions.isEmpty)
              const SpeakerEmptyText(
                'No questions yet.\n'
                'Participants answer them from this session’s details page.',
              )
            else
              for (final q in _questions) _questionCard(q),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(Map<String, dynamic> q) {
    final answers = ((q['answers'] as List?) ?? const [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: speakerCardDecoration(),
      child: Theme(
        // No divider lines around the expanded tile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          iconColor: SpeakerColors.sub,
          collapsedIconColor: SpeakerColors.sub,
          title: Text(
            q['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              answers.length == 1 ? '1 answer' : '${answers.length} answers',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: SpeakerColors.time,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Editable only until the first answer comes in.
              if (answers.isEmpty)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: SpeakerColors.sub,
                  ),
                  onPressed: () => _edit(q),
                ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFF87171),
                ),
                onPressed: () => _delete(q),
              ),
              const Icon(Icons.expand_more_rounded, color: SpeakerColors.sub),
            ],
          ),
          children: answers.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No answers yet',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: SpeakerColors.sub,
                      ),
                    ),
                  ),
                ]
              : [for (final a in answers) _answerTile(a)],
        ),
      ),
    );
  }

  Widget _answerTile(Map<String, dynamic> a) {
    final name = a['name']?.toString() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Participant' : name,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: SpeakerColors.green,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            a['text']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its text controller so it's disposed with the dialog. With
/// [initialText] it edits an existing question.
class _AddQuestionDialog extends StatefulWidget {
  final String? initialText;

  const _AddQuestionDialog({this.initialText});

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  bool get _editing => widget.initialText != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit question' : 'Add question'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Type the question participants should answer',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(_editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
