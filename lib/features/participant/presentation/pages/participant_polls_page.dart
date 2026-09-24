import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Every poll speakers added to their sessions, in one list. A participant
/// votes once per poll; results are shown to the speaker only.
class ParticipantPollsPage extends StatefulWidget {
  const ParticipantPollsPage({super.key});

  @override
  State<ParticipantPollsPage> createState() => _ParticipantPollsPageState();
}

class _ParticipantPollsPageState extends State<ParticipantPollsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _polls = [];

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
    final pending = _polls.where((p) => p['myVote'] == null).length;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Polls',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_error != null)
                    _empty(Icons.error_outline_rounded, _error!)
                  else if (_polls.isEmpty)
                    _empty(Icons.poll_outlined, 'No polls from speakers yet')
                  else ...[
                    if (pending > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          pending == 1
                              ? '1 POLL WAITING FOR YOUR VOTE'
                              : '$pending POLLS WAITING FOR YOUR VOTE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                            color: DarkColors.muted,
                          ),
                        ),
                      ),
                    for (var i = 0; i < _polls.length; i++)
                      _PollCard(
                        key: ValueKey(_polls[i]['id']),
                        poll: _polls[i],
                        onVoted: (option) =>
                            setState(() => _polls[i]['myVote'] = option),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// One poll: pick an option and submit; afterwards the choice stays marked.
class _PollCard extends StatefulWidget {
  final Map<String, dynamic> poll;
  final ValueChanged<int> onVoted;

  const _PollCard({super.key, required this.poll, required this.onVoted});

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

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final options = List<String>.from((p['options'] as List?) ?? const []);
    final myVote = (p['myVote'] as num?)?.toInt();
    final voted = myVote != null;
    final date = DateTime.tryParse(p['date']?.toString() ?? '')?.toLocal();
    final meta = [
      p['speakerName']?.toString() ?? '',
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
            p['sessionName']?.toString() ?? '',
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
            p['question']?.toString() ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < options.length; i++)
            _optionRow(
              options[i],
              chosen: voted ? myVote == i : _selected == i,
              onTap: voted ? null : () => setState(() => _selected = i),
            ),
          if (voted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Thanks — your vote is recorded',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF22C55E),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _selected == null || _sending ? null : _vote,
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
                ? DarkColors.accent.withValues(alpha: 0.15)
                : DarkColors.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: chosen ? DarkColors.accent : DarkColors.line,
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
                color: chosen ? DarkColors.accent : DarkColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
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
