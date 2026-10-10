import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin editor for the conference feedback questions participants must answer.
class FeedbackQuestionsPage extends StatefulWidget {
  const FeedbackQuestionsPage({super.key});

  @override
  State<FeedbackQuestionsPage> createState() => _FeedbackQuestionsPageState();
}

class _FeedbackQuestionsPageState extends State<FeedbackQuestionsPage> {
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
    final res = await _api.listFeedbackQuestions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _questions = (res['questions'] as List? ?? [])
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();
        _error = null;
      } else {
        _error = res['error']?.toString() ?? 'Could not load questions';
      }
    });
  }

  void _toast(Map<String, dynamic> res, String done) {
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? done : res['error']?.toString() ?? 'Could not save')),
    );
    if (ok) {
      setState(() {
        _questions = (res['questions'] as List? ?? [])
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();
      });
    }
  }

  Future<void> _move(int index, int dir) async {
    final target = index + dir;
    if (target < 0 || target >= _questions.length) return;
    final next = [..._questions];
    final item = next.removeAt(index);
    next.insert(target, item);
    final res = await _api.reorderFeedbackQuestions(
      next.map((q) => q['questionId'].toString()).toList(),
    );
    if (!mounted) return;
    _toast(res, 'Order updated');
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question'),
        content: const Text(
          'Participants will no longer be asked this. Answers already submitted stay on file.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.deleteFeedbackQuestion(q['questionId'].toString());
    if (!mounted) return;
    _toast(res, 'Question deleted');
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DarkColors.card,
      builder: (ctx) => _QuestionSheet(existing: existing),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Feedback questions',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DarkColors.accent,
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(child: Text(_error!, style: GoogleFonts.inter(color: DarkColors.muted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                Text(
                  'Participants see this list after their certificate is enabled. Numbers follow this order.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: DarkColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (_questions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'No questions yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: DarkColors.muted),
                    ),
                  ),
                for (var i = 0; i < _questions.length; i++)
                  _tile(i),
              ],
            ),
    );
  }

  Widget _tile(int index) {
    final q = _questions[index];
    final options = (q['options'] as List? ?? []).map((o) => o.toString()).join(' · ');
    final kind = q['type'] == 'choice'
        ? 'Choice'
        : q['multiline'] == true
        ? 'Paragraph'
        : 'Short answer';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      decoration: darkCardDecoration(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${q['number']}. ${q['section']}${q['required'] == true ? ' · Required' : ''} · $kind',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: DarkColors.muted),
          ),
          const SizedBox(height: 4),
          Text(q['prompt']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(options, style: GoogleFonts.inter(fontSize: 12, color: DarkColors.muted)),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: index == 0 ? null : () => _move(index, -1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                onPressed: index == _questions.length - 1 ? null : () => _move(index, 1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              IconButton(onPressed: () => _edit(q), icon: const Icon(Icons.edit_outlined, size: 18)),
              IconButton(
                onPressed: () => _delete(q),
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF87171)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _QuestionSheet({this.existing});

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  final _api = ApiService();
  late final TextEditingController _section;
  late final TextEditingController _prompt;
  late final TextEditingController _options;
  late String _type;
  late bool _required;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _section = TextEditingController(text: q?['section']?.toString() ?? '');
    _prompt = TextEditingController(text: q?['prompt']?.toString() ?? '');
    _options = TextEditingController(
      text: q == null
          ? 'Excellent\nVery good\nGood\nFair\nPoor'
          : ((q['options'] as List?) ?? const []).map((o) => o.toString()).join('\n'),
    );
    _type = q == null
        ? 'choice'
        : q['type'] == 'text' && q['multiline'] == true
        ? 'paragraph'
        : q['type']?.toString() ?? 'choice';
    _required = q?['required'] != false;
  }

  @override
  void dispose() {
    _section.dispose();
    _prompt.dispose();
    _options.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = {
      'section': _section.text,
      'prompt': _prompt.text,
      'type': _type == 'choice' ? 'choice' : 'text',
      'required': _required,
      'multiline': _type == 'paragraph',
      'options': _type == 'choice' ? _options.text.split('\n') : <String>[],
    };
    final id = widget.existing?['questionId']?.toString();
    final res = id == null ? await _api.createFeedbackQuestion(body) : await _api.updateFeedbackQuestion(id, body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not save')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: DarkColors.muted),
      filled: true,
      fillColor: DarkColors.field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Add question' : 'Edit question',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _section,
              style: const TextStyle(color: Colors.white),
              decoration: deco('Section'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: deco('Question'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              dropdownColor: DarkColors.card,
              style: const TextStyle(color: Colors.white),
              decoration: deco('Type'),
              items: const [
                DropdownMenuItem(value: 'choice', child: Text('Choice')),
                DropdownMenuItem(value: 'text', child: Text('Short answer')),
                DropdownMenuItem(value: 'paragraph', child: Text('Paragraph')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'choice'),
            ),
            if (_type == 'choice') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _options,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: deco('Options, one per line'),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Required', style: GoogleFonts.inter(color: Colors.white)),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: DarkColors.accent),
                child: Text(_saving ? 'Saving…' : 'Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
