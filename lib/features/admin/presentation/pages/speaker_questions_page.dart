import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Questions participants asked one speaker. Search by name or question, then answer and publish.
class SpeakerQuestionsPage extends StatefulWidget {
  final String speakerId;
  final String speakerName;

  const SpeakerQuestionsPage({
    super.key,
    required this.speakerId,
    required this.speakerName,
  });

  @override
  State<SpeakerQuestionsPage> createState() => _SpeakerQuestionsPageState();
}

class _SpeakerQuestionsPageState extends State<SpeakerQuestionsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().getSpeakerQuestionsForManagement();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _questions = ((res['questions'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((q) => q['speakerId']?.toString() == widget.speakerId)
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load questions';
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> get _groups {
    final term = _query.trim().toLowerCase();
    final shown = _questions.where((q) {
      if (term.isEmpty) return true;
      final name = (q['participantName']?.toString() ?? '').toLowerCase();
      final text = (q['question']?.toString() ?? '').toLowerCase();
      return name.contains(term) || text.contains(term);
    });
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final q in shown) {
      final name = (q['participantName']?.toString() ?? '').trim();
      final key = name.isEmpty ? 'Participant' : name;
      groups.putIfAbsent(key, () => []).add(q);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          widget.speakerName,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: DarkColors.muted)),
                )
              : _questions.isEmpty
                  ? const Center(
                      child: Text(
                        'No questions for this speaker yet',
                        style: TextStyle(color: DarkColors.muted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(color: Colors.white),
                          decoration: darkInputDecoration('Search participant or question', Icons.search),
                        ),
                        const SizedBox(height: 16),
                        if (groups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text('No matching questions', style: TextStyle(color: DarkColors.muted)),
                            ),
                          )
                        else
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                entry.key,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            for (final q in entry.value)
                              _QuestionCard(item: q, onChanged: _load),
                          ],
                      ],
                    ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;

  const _QuestionCard({required this.item, required this.onChanged});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final TextEditingController _answer;
  bool _saving = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(text: widget.item['answer']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.item['answer']?.toString() ?? '';
    if (next != oldWidget.item['answer']?.toString() && next != _answer.text) {
      _answer.text = next;
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    final res = await ApiService().answerSpeakerQuestionAsAdmin(widget.item['id'].toString(), text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not save the answer')),
      );
    }
  }

  Future<void> _setPublic(bool isPublic) async {
    setState(() => _publishing = true);
    final res = await ApiService().setSpeakerQuestionPublic(widget.item['id'].toString(), isPublic);
    if (!mounted) return;
    setState(() => _publishing = false);
    if (res['success'] == true) {
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not update')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final answered = item['answered'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['question']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _answer,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Type the answer',
              hintStyle: TextStyle(color: DarkColors.muted),
              filled: true,
              fillColor: DarkColors.field,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: DarkColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(answered ? 'Update answer' : 'Save answer'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: item['isPublic'] == true,
                activeThumbColor: Colors.white,
                activeTrackColor: DarkColors.accent,
                onChanged: _publishing ? null : _setPublic,
              ),
              const Expanded(
                child: Text(
                  'Show to all participants',
                  style: TextStyle(fontSize: 12, color: DarkColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
