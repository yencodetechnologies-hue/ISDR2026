import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'participant_polls_page.dart';

List<Map<String, dynamic>> _list(dynamic raw) => ((raw as List?) ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

Text _title(String text) => Text(
  text,
  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
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
  bool _pendingOnly = false;

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
    final shown = _pendingOnly
        ? _questions.where((q) => q['myAnswer'] == null).toList()
        : _questions;
    return Scaffold(
      backgroundColor: const Color(0xFF070B1F),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 6, 40, 10),
          child: _GradientButton(
            icon: Icons.calendar_month_rounded,
            label: 'View All Polls & Q/A',
            onTap: () => _open(const ParticipantPollsPage()),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
            children: [
              _header(),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.mic_rounded,
                        colors: const [Color(0xFF3B1780), Color(0xFF1E1B6B)],
                        iconColors: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
                        border: const Color(0xFF8B5CF6),
                        title: 'Ask a Speaker',
                        subtitle: 'Send your question',
                        onTap: () => _open(const AskSpeakerPage()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.mark_chat_read_rounded,
                        colors: const [Color(0xFF0E3B66), Color(0xFF12235E)],
                        iconColors: const [Color(0xFF06B6D4), Color(0xFF2563EB)],
                        border: const Color(0xFF22D3EE),
                        title: 'My Questions',
                        subtitle: 'View your answers',
                        onTap: () => _open(const MyQuestionsPage()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.question_answer_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Questions for You',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pending TO ANSWER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Filter: only the questions still to answer, or all.
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _pendingOnly = !_pendingOnly),
                    child: Container(
                      width: 38,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _pendingOnly
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                            : const Color(0xFF0E1638),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _emptyState(Icons.error_outline_rounded, _error!)
              else if (shown.isEmpty)
                _emptyState(
                  Icons.quiz_outlined,
                  _pendingOnly
                      ? 'No questions left to answer'
                      : 'No questions from speakers yet',
                )
              else
                for (final q in shown)
                  _SessionQuestionCard(
                    key: ValueKey(q['id']),
                    question: q,
                    onAnswered: (text) => setState(() => q['myAnswer'] = text),
                  ),
              const SizedBox(height: 4),
              _tipCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Back button, the "Q/A" title with its badge, the tagline and the
  /// question-bubble art.
  Widget _header() {
    return SizedBox(
      height: 76,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context),
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
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
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
                    Container(
                      width: 38,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.help_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Q/A',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Ask  •  Discuss  •  Learn',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFFBFDBFE),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 44,
                  color: Color(0xFF3B82F6),
                ),
                const Positioned(
                  left: 13,
                  top: 8,
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
                Positioned(
                  right: -8,
                  bottom: -4,
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 24,
                    color: const Color(0xFFA855F7).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1638), Color(0xFF1B1452)],
        ),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF22D3EE), width: 1.5),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFF22D3EE),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your questions make the session more valuable!',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Be a part of the discussion.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide purple-to-blue pill button with an icon, a divider and an arrow.
class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9333EA), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 14,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 22),
              Icon(icon, color: Colors.white, size: 22),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withValues(alpha: 0.4),
              ),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final List<Color> iconColors;
  final Color border;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.colors,
    required this.iconColors,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: 0.8), width: 1.4),
          boxShadow: [
            BoxShadow(color: border.withValues(alpha: 0.25), blurRadius: 14),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: iconColors),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColors.last,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A speaker's session question: tap Submit Answer to type one answer, or see
/// the one you gave.
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
  bool _open = false;

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

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Asked just now';
    if (d.inHours < 1) return 'Asked ${d.inMinutes} min ago';
    if (d.inDays < 1) {
      return 'Asked ${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    }
    return 'Asked ${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final myAnswer = q['myAnswer']?.toString();
    final answered = myAnswer != null;
    final date = DateTime.tryParse(q['date']?.toString() ?? '')?.toLocal();
    final asked = DateTime.tryParse(q['createdAt']?.toString() ?? '')?.toLocal();
    final speaker = q['speakerName']?.toString() ?? '';
    final meta = [
      speaker,
      if (date != null) DateFormat('d MMM yyyy').format(date),
    ].where((s) => s.isNotEmpty).join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1F4A), Color(0xFF16124A)],
        ),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.55),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                  ),
                ),
                child: _avatar(
                  speaker,
                  q['speakerPhoto']?.toString() ?? '',
                  size: 50,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              q['sessionName']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        meta,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: answered
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFA855F7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: answered ? null : () => setState(() => _open = !_open),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q['question']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!answered)
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ),
          if (answered) ...[
            const SizedBox(height: 10),
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
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ] else if (_open) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
              decoration: _boxDecoration('Type your answer'),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _ago(asked),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              if (!answered)
                _answerButton()
              else
                Text(
                  'Answered',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Submit Answer": first tap opens the answer box, the next one sends it.
  Widget _answerButton() {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _sending
              ? null
              : (_open ? _submit : () => setState(() => _open = true)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                  const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Submit Answer',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
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
