import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

List<Map<String, dynamic>> _list(dynamic raw) => ((raw as List?) ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

String _when(dynamic raw, [String pattern = 'd MMM, h:mm a']) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  return d == null ? '' : DateFormat(pattern).format(d);
}

TextStyle _small(Color color, {FontWeight weight = FontWeight.w500}) =>
    GoogleFonts.inter(fontSize: 11.5, fontWeight: weight, color: color);

/// Management's read-only view of every Q&A and poll: speakers' questions and
/// the participants' answers, poll results, and participants' questions to
/// speakers with the answers.
class EngagementOverviewPage extends StatelessWidget {
  const EngagementOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: DarkColors.bg,
        appBar: buildDarkAppBar(
          title: Text(
            'Q&A & Polls',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: DarkColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: DarkColors.muted,
            labelStyle: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Session Questions'),
              Tab(text: 'Polls'),
              Tab(text: 'Asked to Speakers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _Loader(kind: _Kind.questions),
            _Loader(kind: _Kind.polls),
            _Loader(kind: _Kind.speakerQuestions),
          ],
        ),
      ),
    );
  }
}

enum _Kind { questions, polls, speakerQuestions }

/// Loads one tab's list (pull down to refresh).
class _Loader extends StatefulWidget {
  final _Kind kind;

  const _Loader({required this.kind});

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final _search = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Everything a card shows: question, session, speaker, participant,
  /// answers and poll options.
  String _searchText(Map<String, dynamic> item) {
    final parts = <String>[
      for (final k in const [
        'question',
        'sessionName',
        'speakerName',
        'participantName',
        'answer',
      ])
        item[k]?.toString() ?? '',
      for (final o in (item['options'] as List?) ?? const []) o.toString(),
      for (final a in _list(item['answers'])) ...[
        a['name']?.toString() ?? '',
        a['text']?.toString() ?? '',
      ],
    ];
    return parts.join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) => _searchText(i).contains(q)).toList();
  }

  String get _searchHint => switch (widget.kind) {
    _Kind.questions => 'Search question, session, speaker, answer…',
    _Kind.polls => 'Search poll, option, session, speaker…',
    _Kind.speakerQuestions => 'Search question, participant, speaker…',
  };

  Widget _searchBox() {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: _searchHint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: DarkColors.muted),
        prefixIcon: const Icon(Icons.search_rounded, color: DarkColors.muted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded, color: DarkColors.muted),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: DarkColors.field,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiService();
    final res = switch (widget.kind) {
      _Kind.questions => await api.getAllQuestionsForManagement(),
      _Kind.polls => await api.getAllPollsForManagement(),
      _Kind.speakerQuestions => await api.getSpeakerQuestionsForManagement(),
    };
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _items = _list(
          widget.kind == _Kind.polls ? res['polls'] : res['questions'],
        );
      } else {
        _error = res['error']?.toString() ?? 'Could not load';
      }
    });
  }

  String get _emptyText => switch (widget.kind) {
    _Kind.questions => 'Speakers haven\'t added any questions yet',
    _Kind.polls => 'Speakers haven\'t added any polls yet',
    _Kind.speakerQuestions => 'Participants haven\'t asked speakers anything yet',
  };

  Widget _card(Map<String, dynamic> item) => switch (widget.kind) {
    _Kind.questions => _SessionQuestionCard(item: item, onChanged: _load),
    _Kind.polls => _PollCard(item: item, onChanged: _load),
    _Kind.speakerQuestions => _SpeakerQuestionCard(item: item, onChanged: _load),
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final shown = _shown;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error == null && _items.isNotEmpty) ...[
            _searchBox(),
            const SizedBox(height: 14),
          ],
          if (_error == null && _items.isNotEmpty && shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No results for "${_query.trim()}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: DarkColors.muted),
              ),
            )
          else if (_error != null || _items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(
                    _error != null
                        ? Icons.error_outline_rounded
                        : Icons.forum_outlined,
                    size: 40,
                    color: DarkColors.muted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error ?? _emptyText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: DarkColors.muted,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in shown) _card(item),
        ],
      ),
    );
  }
}

/// Session name · speaker · date, above a card's content.
class _SessionLine extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SessionLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final meta = [
      item['speakerName']?.toString() ?? '',
      _when(item['date'], 'd MMM'),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item['sessionName']?.toString() ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _small(DarkColors.accentLight, weight: FontWeight.w600),
        ),
        if (meta.isNotEmpty) Text(meta, style: _small(DarkColors.muted)),
      ],
    );
  }
}

Widget _questionText(String text) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text(
    text,
    style: GoogleFonts.outfit(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
);

/// A speaker's session question with every participant's answer (collapsible).
class _SessionQuestionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;

  const _SessionQuestionCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final answers = _list(item['answers']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: darkCardDecoration(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          iconColor: DarkColors.muted,
          collapsedIconColor: DarkColors.muted,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SessionLine(item: item),
              _questionText(item['question']?.toString() ?? ''),
              const SizedBox(height: 4),
              Text(
                answers.length == 1 ? '1 answer' : '${answers.length} answers',
                style: _small(const Color(0xFF22C55E), weight: FontWeight.w600),
              ),
              _AdminActions(item: item, isPoll: false, onChanged: onChanged),
            ],
          ),
          children: answers.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No answers yet', style: _small(DarkColors.muted)),
                  ),
                ]
              : [
                  for (final a in answers)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DarkColors.field,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (a['name']?.toString() ?? '').isEmpty
                                ? 'Participant'
                                : a['name'].toString(),
                            style: _small(
                              DarkColors.accentLight,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            a['text']?.toString() ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
        ),
      ),
    );
  }
}

/// A poll with each option's vote count and share.
class _PollCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;

  const _PollCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from((item['options'] as List?) ?? const []);
    final counts = ((item['counts'] as List?) ?? const [])
        .map((c) => (c as num).toInt())
        .toList();
    final total = (item['totalVotes'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SessionLine(item: item),
          _questionText(item['question']?.toString() ?? ''),
          const SizedBox(height: 10),
          for (var i = 0; i < options.length; i++)
            _resultBar(options[i], i < counts.length ? counts[i] : 0, total),
          Text(
            total == 1 ? '1 vote' : '$total votes',
            style: _small(DarkColors.muted),
          ),
          _AdminActions(item: item, isPoll: true, onChanged: onChanged),
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
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '$count  ·  ${(fraction * 100).round()}%',
                style: _small(DarkColors.accentLight, weight: FontWeight.w600),
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
              valueColor: const AlwaysStoppedAnimation(DarkColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// A participant's question. Admin writes the answer and can publish it.
class _SpeakerQuestionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;

  const _SpeakerQuestionCard({required this.item, required this.onChanged});

  @override
  State<_SpeakerQuestionCard> createState() => _SpeakerQuestionCardState();
}

class _SpeakerQuestionCardState extends State<_SpeakerQuestionCard> {
  late final TextEditingController _answer;
  bool _saving = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _answer = TextEditingController(text: widget.item['answer']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _SpeakerQuestionCard oldWidget) {
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
    final res = await ApiService().answerSpeakerQuestionAsAdmin(
      widget.item['id'].toString(),
      text,
    );
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
    final res = await ApiService().setSpeakerQuestionPublic(
      widget.item['id'].toString(),
      isPublic,
    );
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
    final participant = (item['participantName']?.toString() ?? '').trim();
    final status = answered ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: darkCardDecoration(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: participant.isEmpty ? 'Participant' : participant,
                        style: _small(
                          DarkColors.accentLight,
                          weight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: '  →  ', style: _small(DarkColors.muted)),
                      TextSpan(
                        text: item['speakerName']?.toString() ?? 'Speaker',
                        style: _small(Colors.white, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: status.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  answered ? 'Answered' : 'Awaiting answer',
                  style: _small(status, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Asked ${_when(item['createdAt'])}',
              style: _small(DarkColors.muted),
            ),
          ),
          _questionText(item['question']?.toString() ?? ''),
          const SizedBox(height: 10),
          TextField(
            controller: _answer,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type the answer',
              hintStyle: const TextStyle(color: DarkColors.muted),
              filled: true,
              fillColor: DarkColors.field,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
              Expanded(
                child: Text(
                  'Show to all participants',
                  style: _small(DarkColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Admin's Edit / Delete buttons on a session poll or question card.
/// Calls [onChanged] after a successful change so the list reloads.
class _AdminActions extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isPoll;
  final VoidCallback onChanged;

  const _AdminActions({
    required this.item,
    required this.isPoll,
    required this.onChanged,
  });

  String get _scheduleId => item['scheduleId']?.toString() ?? '';
  String get _id => item['id']?.toString() ?? '';

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _edit(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(item: item, isPoll: isPoll),
    );
    if (saved == true) onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPoll ? 'Delete poll?' : 'Delete question?'),
        content: Text(
          isPoll
              ? 'The poll and all its votes will be removed.'
              : 'The question and all its answers will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final api = ApiService();
    final res = isPoll
        ? await api.deleteSessionPoll(_scheduleId, _id)
        : await api.deleteSessionQuestion(_scheduleId, _id);
    if (!context.mounted) return;
    if (res['success'] == true) {
      _toast(context, isPoll ? 'Poll deleted' : 'Question deleted');
      onChanged();
    } else {
      _toast(context, res['error']?.toString() ?? 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scheduleId.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF60A5FA)),
        ),
        TextButton.icon(
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
        ),
      ],
    );
  }
}

/// Edit a poll (question + options; options lock once someone has voted) or a
/// session question (text).
class _EditDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isPoll;

  const _EditDialog({required this.item, required this.isPoll});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _question = TextEditingController(
    text: widget.item['question']?.toString() ?? '',
  );
  late final List<TextEditingController> _options = [
    for (final o in (widget.item['options'] as List?) ?? const [])
      TextEditingController(text: o.toString()),
  ];
  bool _saving = false;

  bool get _optionsLocked =>
      ((widget.item['totalVotes'] as num?)?.toInt() ?? 0) > 0;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final question = _question.text.trim();
    if (question.isEmpty) return;
    final item = widget.item;
    final scheduleId = item['scheduleId'].toString();
    final id = item['id'].toString();
    List<String>? options;
    if (widget.isPoll && !_optionsLocked) {
      options = _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A poll needs at least 2 options')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final api = ApiService();
    final res = widget.isPoll
        ? await api.updateSessionPoll(scheduleId, id, question: question, options: options)
        : await api.updateSessionQuestion(scheduleId, id, question);
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
    return AlertDialog(
      title: Text(widget.isPoll ? 'Edit poll' : 'Edit question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _question,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            if (widget.isPoll) ...[
              const SizedBox(height: 12),
              if (_optionsLocked)
                const Text(
                  'Options can\'t be changed after people have voted.',
                  style: TextStyle(fontSize: 12),
                ),
              for (var i = 0; i < _options.length; i++)
                TextField(
                  controller: _options[i],
                  enabled: !_optionsLocked,
                  decoration: InputDecoration(labelText: 'Option ${i + 1}'),
                ),
              if (!_optionsLocked)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _options.add(TextEditingController()),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add option'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
