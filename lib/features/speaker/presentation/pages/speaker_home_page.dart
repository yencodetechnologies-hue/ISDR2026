import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../participant/presentation/pages/schedule_detail_page.dart';
import '../../../participant/presentation/widgets/live_show_card.dart';
import '../widgets/speaker_ui.dart';
import 'speaker_session_polls_page.dart';
import 'speaker_session_questions_page.dart';

typedef _C = SpeakerColors;

/// One of the speaker's sessions with its start/end resolved to local time.
class _Session {
  final Map<String, dynamic> raw;
  final DateTime start;
  final DateTime end;

  const _Session(this.raw, this.start, this.end);

  String get name => raw['scheduleName']?.toString() ?? '';
  String get hall => raw['hall']?.toString() ?? '';

  static _Session? fromJson(Map<String, dynamic> s) {
    final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
    if (d == null) return null;
    DateTime at(String? hhmm) {
      final p = (hhmm ?? '').split(':');
      return DateTime(
        d.year,
        d.month,
        d.day,
        int.tryParse(p[0]) ?? 0,
        p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
      );
    }

    return _Session(
      s,
      at(s['fromTime']?.toString()),
      at(s['toTime']?.toString()),
    );
  }
}

enum _Status { completed, live, upcoming }

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color? tint; // tile tinted in this colour instead of plain navy
  final bool picksSession; // opens the list of the speaker's sessions first

  const _QuickAction(
    this.title,
    this.subtitle,
    this.icon,
    this.colors, {
    this.tint,
    this.picksSession = false,
  });
}

/// Home page for a speaker login (one login covers all their session dates).
class SpeakerHomePage extends StatefulWidget {
  const SpeakerHomePage({super.key});

  @override
  State<SpeakerHomePage> createState() => _SpeakerHomePageState();
}

class _SpeakerHomePageState extends State<SpeakerHomePage> {
  final _api = ApiService();
  List<_Session> _sessions = [];
  Map<String, dynamic>? _event;
  bool _loading = true;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Keeps Completed / Live / Upcoming and the next-session card current.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _api.getMySpeakerSessions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _sessions =
            ((res['sessions'] as List?) ?? [])
                .map(
                  (s) => _Session.fromJson(Map<String, dynamic>.from(s as Map)),
                )
                .whereType<_Session>()
                .toList()
              ..sort((a, b) => a.start.compareTo(b.start));
        _event = res['event'] is Map
            ? Map<String, dynamic>.from(res['event'] as Map)
            : null;
      } else {
        _error = res['error']?.toString() ?? 'Could not load your sessions';
      }
    });
  }

  _Status _statusOf(_Session s, DateTime now) {
    if (!now.isBefore(s.end)) return _Status.completed;
    if (!now.isBefore(s.start)) return _Status.live;
    return _Status.upcoming;
  }

  void _dummyTap(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  void _openDetails(_Session s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleDetailPage(
          schedule: s.raw,
          event: _event ?? const <String, dynamic>{},
        ),
      ),
    );
  }

  /// Lists every one of the speaker's sessions (all dates) for [feature];
  /// tapping one opens that feature's page for the session.
  void _openSessionPicker(String feature) {
    final ValueChanged<_Session>? onPick = switch (feature) {
      'My Sessions' => _openDetails,
      'Poll' => (s) => _openSessionPage(
        s,
        (ref) => SpeakerSessionPollsPage(session: ref),
      ),
      'Q&A' => (s) => _openSessionPage(
        s,
        (ref) => SpeakerSessionQuestionsPage(session: ref),
      ),
      _ => null,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SessionPickerPage(
          title: feature,
          sessions: _sessions,
          onPick: onPick,
        ),
      ),
    );
  }

  void _openSessionPage(
    _Session s,
    Widget Function(SpeakerSessionRef ref) page,
  ) {
    final ref = SpeakerSessionRef(
      id: s.raw['id']?.toString() ?? '',
      name: s.name,
      when:
          '${DateFormat('EEE, d MMM').format(s.start)}  ·  '
          '${DateFormat('hh:mm a').format(s.start)} – '
          '${DateFormat('hh:mm a').format(s.end)}',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => page(ref)));
  }

  void _openMore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _SpeakerMorePage()),
    );
  }

  /// Second word of the "Good …" greeting in the header.
  String get _dayPart {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: _C.card.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _C.border),
  );

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _C.bg,
      bottomNavigationBar: _buildBottomNav(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.bgTop, _C.bg],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _C.green,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _buildHeader(user?.name ?? '', user?.profilePic ?? ''),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: _C.green),
                    ),
                  )
                else if (_error != null)
                  _buildError()
                else ...[
                  const LiveShowCard(),
                  const SizedBox(height: 14),
                  _buildTodaySchedule(now),
                ],
                const SizedBox(height: 14),
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String name, String photo) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: Image.asset(
            'assets/ISDR 2026 Logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.mic_rounded, color: Colors.white, size: 25),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Good ',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: _dayPart,
                      style: const TextStyle(color: _C.green),
                    ),
                  ],
                ),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'CONNECT  ·  INSPIRE  ·  IMPACT',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w500,
                    color: _C.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _avatar(name, photo),
      ],
    );
  }

  Widget _avatar(String name, String photo) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF14B8A6)],
              ),
            ),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage: photo.isNotEmpty
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: photo.isEmpty
                  ? Text(
                      initials.isEmpty ? '?' : initials,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _C.green,
                shape: BoxShape.circle,
                border: Border.all(color: _C.bgTop, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(18),
      child: Text(
        '${_error!}\nPull down to try again.',
        style: GoogleFonts.inter(fontSize: 13, color: _C.sub, height: 1.4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Next session
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Today's schedule
  // ---------------------------------------------------------------------------

  Widget _buildTodaySchedule(DateTime now) {
    final today = _sessions
        .where((s) => DateUtils.isSameDay(s.start, now))
        .toList();
    final statuses = today.map((s) => _statusOf(s, now)).toList();
    // The first session not yet completed is highlighted.
    final focus = statuses.indexWhere((st) => st != _Status.completed);

    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's Schedule",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _dummyTap('Full Schedule'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B2150),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2F5BD3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Full Schedule',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (today.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No sessions today',
                style: GoogleFonts.inter(fontSize: 13, color: _C.sub),
              ),
            )
          else
            for (var i = 0; i < today.length; i++)
              _scheduleRow(
                today[i],
                statuses[i],
                first: i == 0,
                last: i == today.length - 1,
                prevDone: i > 0 && statuses[i - 1] == _Status.completed,
                highlight: i == focus,
                divider: i < today.length - 1 && i != focus && i + 1 != focus,
              ),
        ],
      ),
    );
  }

  Widget _scheduleRow(
    _Session s,
    _Status st, {
    required bool first,
    required bool last,
    required bool prevDone,
    required bool highlight,
    required bool divider,
  }) {
    final idleLine = Colors.white.withValues(alpha: 0.12);
    return Container(
      height: 62,
      decoration: highlight
          ? BoxDecoration(
              color: const Color(0xFF13295C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22407A)),
            )
          : null,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: 2,
                              color: first
                                  ? Colors.transparent
                                  : (prevDone ? _C.green : idleLine),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: last
                                  ? Colors.transparent
                                  : (st == _Status.completed
                                        ? _C.green
                                        : idleLine),
                            ),
                          ),
                        ],
                      ),
                      _timelineNode(st),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: Text(
                    DateFormat('hh:mm a').format(s.start),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (s.hall.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: _C.sub,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                s.hall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: _C.sub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _statusPill(st),
              ],
            ),
          ),
          if (divider)
            Positioned(
              left: 46,
              right: 0,
              bottom: 0,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineNode(_Status st) {
    if (st == _Status.completed) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: _C.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
      );
    }
    final color = st == _Status.live
        ? const Color(0xFFEF4444)
        : const Color(0xFF3B82F6);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _statusPill(_Status st) {
    final (label, bg, fg) = switch (st) {
      _Status.completed => (
        'Completed',
        const Color(0xFF14532D),
        const Color(0xFF4ADE80),
      ),
      _Status.live => ('Live', const Color(0xFFDC2626), Colors.white),
      _Status.upcoming => ('Upcoming', const Color(0xFF2563EB), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions() {
    const actions = [
      _QuickAction(
        'Q&A',
        'View questions',
        Icons.mic_rounded,
        [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        tint: Color(0xFFF59E0B),
        picksSession: true,
      ),
      _QuickAction('Poll', 'Engage your audience', Icons.bar_chart_rounded, [
        Color(0xFF22D3EE),
        Color(0xFF0891B2),
      ], picksSession: true),
      _QuickAction(
        'My Sessions',
        'Your complete schedule',
        Icons.format_list_bulleted_rounded,
        [Color(0xFF818CF8), Color(0xFF6366F1)],
        picksSession: true,
      ),
      _QuickAction(
        'Green Room',
        'Check-in & updates',
        Icons.door_front_door_rounded,
        [Color(0xFF4ADE80), Color(0xFF16A34A)],
        tint: Color(0xFF22C55E),
      ),
    ];

    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFFACC15),
                size: 24,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Quick Actions',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Make your session smooth',
                style: GoogleFonts.inter(fontSize: 11, color: _C.sub),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: _C.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (_, i) => _quickTile(actions[i]),
          ),
        ],
      ),
    );
  }

  Widget _quickTile(_QuickAction a) {
    final tint = a.tint;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: tint != null
              ? tint.withValues(alpha: 0.10)
              : const Color(0xFF0F2350),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tint != null
                ? tint.withValues(alpha: 0.35)
                : const Color(0xFF1D3668),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              a.picksSession ? _openSessionPicker(a.title) : _dummyTap(a.title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: a.colors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: a.colors.last.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(a.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: _C.sub,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom nav
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav() {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.home_rounded, 'Home', () {}),
      (Icons.calendar_month_outlined, 'Schedule', () => _dummyTap('Schedule')),
      (Icons.groups_outlined, 'Speakers', () => _dummyTap('Speakers')),
      (Icons.qr_code_rounded, 'QR Pass', () => _dummyTap('QR Pass')),
      (Icons.grid_view_rounded, 'More', _openMore),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _C.nav,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: _C.border.withValues(alpha: 0.7)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: items[i].$3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].$1,
                          size: 24,
                          color: i == 0 ? _C.green : _C.sub,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$2,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: i == 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == 0 ? _C.green : _C.sub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: i == 0 ? 30 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _C.green,
                            borderRadius: BorderRadius.circular(2),
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
    );
  }
}

/// Every one of the speaker's sessions, grouped by date — opened from the
/// Q&A / Poll / My Sessions quick actions.
class _SessionPickerPage extends StatelessWidget {
  final String title;
  final List<_Session> sessions;
  final ValueChanged<_Session>? onPick; // null → "coming soon"

  const _SessionPickerPage({
    required this.title,
    required this.sessions,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    DateTime? day;
    for (final s in sessions) {
      if (day == null || !DateUtils.isSameDay(day, s.start)) {
        day = s.start;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 4 : 16, bottom: 8),
            child: Text(
              DateFormat('EEE, d MMM').format(s.start),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _C.sub,
              ),
            ),
          ),
        );
      }
      children.add(_row(context, s));
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                'You have no sessions yet',
                style: GoogleFonts.inter(fontSize: 13, color: _C.sub),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: children,
            ),
    );
  }

  Widget _row(BuildContext context, _Session s) {
    final metaStyle = GoogleFonts.inter(fontSize: 11.5, color: _C.sub);
    final time =
        '${DateFormat('hh:mm a').format(s.start)} – '
        '${DateFormat('hh:mm a').format(s.end)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: _C.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onPick != null
                ? onPick!(s)
                : ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title is coming soon')),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: _C.sub,
                            ),
                            const SizedBox(width: 4),
                            Text(time, style: metaStyle),
                            if (s.hall.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: _C.sub,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  s.hall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaStyle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opened from the bottom nav's More tab — holds Logout.
class _SpeakerMorePage extends StatelessWidget {
  const _SpeakerMorePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'More',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => LogoutConfirmSheet.showLogoutConfirmSheet(
              context,
              onLogout: () {
                context.read<AuthBloc>().add(LogoutEvent());
                AppNavigation.resetTo(context, AppRoutes.login);
              },
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF87171),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
