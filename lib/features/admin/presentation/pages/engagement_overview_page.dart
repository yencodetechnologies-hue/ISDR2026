import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
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

  @override
  bool get wantKeepAlive => true;

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
    _Kind.questions => _SessionQuestionCard(item: item),
    _Kind.polls => _PollCard(item: item),
    _Kind.speakerQuestions => _SpeakerQuestionCard(item: item),
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null || _items.isEmpty)
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
            for (final item in _items) _card(item),
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

  const _SessionQuestionCard({required this.item});

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

  const _PollCard({required this.item});

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

/// A participant's question to a speaker and the speaker's answer.
class _SpeakerQuestionCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SpeakerQuestionCard({required this.item});

  @override
  Widget build(BuildContext context) {
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
          if (answered) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DarkColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SPEAKER'S ANSWER",
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: status,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['answer']?.toString() ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
