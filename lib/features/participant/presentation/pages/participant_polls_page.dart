import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';

/// Accent colours cycled through the poll cards (purple, teal, violet).
const _accents = [
  [Color(0xFF7C3AED), Color(0xFF2563EB)],
  [Color(0xFF14B8A6), Color(0xFF0D9488)],
  [Color(0xFFA855F7), Color(0xFF6D28D9)],
];

/// Faded art in the top-right corner of each card, cycled like the accents.
const _arts = [
  Icons.medical_services_rounded,
  Icons.flash_on_rounded,
  Icons.biotech_rounded,
];

/// Today's session polls, in one list. A participant votes once per poll;
/// results are shown to the speaker only.
class ParticipantPollsPage extends StatefulWidget {
  const ParticipantPollsPage({super.key});

  @override
  State<ParticipantPollsPage> createState() => _ParticipantPollsPageState();
}

class _ParticipantPollsPageState extends State<ParticipantPollsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _polls = [];
  bool _pendingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().getAllSessionPolls();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _polls = ((res['polls'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load polls';
      }
    });
  }

  Widget _empty(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Colors.white38),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
        ),
      ],
    ),
  );

  Widget _circleButton(IconData icon, VoidCallback onTap) => InkWell(
    customBorder: const CircleBorder(),
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111A3D),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  Widget _header() {
    Widget rule() => Container(
      width: 34,
      height: 1.5,
      color: const Color(0xFF3B82F6).withValues(alpha: 0.7),
    );
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _circleButton(
              Icons.arrow_back_ios_new_rounded,
              () => Navigator.pop(context),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Color(0xFF22D3EE), Color(0xFFA855F7)],
                      ).createShader(r),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Polls',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    rule(),
                    const SizedBox(width: 10),
                    Text(
                      'Your Voice Matters',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFFDBEAFE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    rule(),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _circleButton(
              Icons.notifications_none_rounded,
              () => Navigator.pushNamed(context, AppRoutes.notifications),
            ),
          ),
        ],
      ),
    );
  }

  /// "N Polls Waiting for Your Vote" — tap to show only those (or all again).
  Widget _waitingBanner(int pending) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
            width: 1.3,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _pendingOnly = !_pendingOnly),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.how_to_vote_rounded,
                  size: 34,
                  color: Color(0xFF7DD3FC),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending == 1
                            ? '1 Poll Waiting for Your Vote'
                            : '$pending Polls Waiting for Your Vote',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _pendingOnly
                            ? 'Showing only these — tap to show all'
                            : 'Make your voice count!',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _pendingOnly
                      ? Icons.close_rounded
                      : Icons.chevron_right_rounded,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _polls.where((p) => p['myVote'] == null).length;
    final shown = _pendingOnly
        ? _polls.where((p) => p['myVote'] == null).toList()
        : _polls;
    return Scaffold(
      backgroundColor: const Color(0xFF070B1F),
      bottomNavigationBar: _pendingOnly
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 6, 40, 10),
                child: _GradientButton(
                  label: 'View All Polls',
                  onTap: () => setState(() => _pendingOnly = false),
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
            children: [
              _header(),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _empty(Icons.error_outline_rounded, _error!)
              else if (_polls.isEmpty)
                _empty(Icons.poll_outlined, 'No polls from speakers yet')
              else ...[
                if (pending > 0) ...[
                  _waitingBanner(pending),
                  const SizedBox(height: 12),
                ],
                if (shown.isEmpty)
                  _empty(Icons.check_circle_outline, 'You have voted on every poll')
                else
                  for (var i = 0; i < shown.length; i++)
                    _PollCard(
                      key: ValueKey(shown[i]['id']),
                      number: _polls.indexOf(shown[i]) + 1,
                      poll: shown[i],
                      onVoted: (option) => setState(() {
                        shown[i]['myVote'] = option;
                        shown[i]['voteCount'] =
                            ((shown[i]['voteCount'] as num?) ?? 0) + 1;
                      }),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide purple-to-cyan pill button with a calendar icon and an arrow.
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFF2563EB), Color(0xFF06B6D4)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 24),
              const Icon(Icons.calendar_month_rounded, color: Colors.white),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// One poll: pick an option and submit; afterwards the choice stays marked.
class _PollCard extends StatefulWidget {
  final int number;
  final Map<String, dynamic> poll;
  final ValueChanged<int> onVoted;

  const _PollCard({
    super.key,
    required this.number,
    required this.poll,
    required this.onVoted,
  });

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  int? _selected;
  bool _sending = false;

  List<Color> get _accent => _accents[(widget.number - 1) % _accents.length];

  Future<void> _vote() async {
    final option = _selected;
    if (option == null) return;
    setState(() => _sending = true);
    final res = await ApiService().voteSessionPoll(
      widget.poll['scheduleId'].toString(),
      widget.poll['id'].toString(),
      option,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] == true) {
      widget.onVoted(option);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not vote')),
      );
    }
  }

  Widget _chip(String text, {bool gradient = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      gradient: gradient ? LinearGradient(colors: _accent) : null,
      color: gradient ? null : _accent.first.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      border: gradient
          ? null
          : Border.all(color: _accent.first.withValues(alpha: 0.7)),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final options = List<String>.from((p['options'] as List?) ?? const []);
    final myVote = (p['myVote'] as num?)?.toInt();
    final voted = myVote != null;
    final votes = (p['voteCount'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(p['date']?.toString() ?? '')?.toLocal();
    final session = p['sessionName']?.toString() ?? '';
    final speaker = p['speakerName']?.toString() ?? '';
    final isKeynote = session.toLowerCase().contains('keynote');
    final muted = Colors.white.withValues(alpha: 0.75);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0C1640),
            _accent.last.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: _accent.first.withValues(alpha: 0.7),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.first.withValues(alpha: 0.2),
            blurRadius: 14,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: Icon(
                _arts[(widget.number - 1) % _arts.length],
                size: 92,
                color: _accent.first.withValues(alpha: 0.22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session: number, keynote tag, title, speaker and date.
                  Padding(
                    padding: const EdgeInsets.only(right: 70),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip('#${widget.number}', gradient: true),
                            if (isKeynote) ...[
                              const SizedBox(width: 6),
                              _chip('Keynote'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (speaker.isNotEmpty) ...[
                              Icon(Icons.person_rounded, size: 15, color: muted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  speaker,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            if (date != null) ...[
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 14,
                                color: muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('d MMM yyyy').format(date),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 20, color: Colors.white.withValues(alpha: 0.1)),
                  // Question and total votes.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 20,
                        color: _accent.first,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p['question']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.groups_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$votes Vote${votes == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < options.length; i++)
                    _optionRow(
                      options[i],
                      chosen: voted ? myVote == i : _selected == i,
                      onTap: voted ? null : () => setState(() => _selected = i),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        voted
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        size: 16,
                        color: voted ? const Color(0xFF22C55E) : muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          voted ? 'Your vote is recorded' : 'Voting open',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: voted
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: voted ? const Color(0xFF22C55E) : muted,
                          ),
                        ),
                      ),
                      if (!voted) _submitButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() {
    final enabled = _selected != null && !_sending;
    return Opacity(
      opacity: _selected == null ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _accent),
            borderRadius: BorderRadius.circular(24),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: enabled ? _vote : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sending)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Vote',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(String label, {required bool chosen, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: chosen ? LinearGradient(colors: _accent) : null,
            color: chosen ? null : const Color(0xFF0B1230),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                chosen
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white,
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
