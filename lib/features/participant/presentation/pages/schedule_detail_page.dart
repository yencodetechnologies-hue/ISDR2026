import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/session_content_section.dart';
import '../programme.dart';

class _Colors {
  static const bg = Color(0xFF0A0F24);
  static const line = Color(0x1AFFFFFF);
  static const live = Color(0xFF22C55E);
}

/// Full details of one speaker/program — opened from the live-show card, the
/// schedule lists, Speakers and Favorites.
class ScheduleDetailPage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> event;

  const ScheduleDetailPage({
    super.key,
    required this.schedule,
    required this.event,
  });

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  final _api = ApiService();
  // In the participant's favorites ("My Schedule"); null = not loaded yet.
  bool? _saved;
  bool _saving = false;

  Map<String, dynamic> get _s => widget.schedule;
  String get _scheduleId => _s['id']?.toString() ?? '';

  bool get _isParticipant {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated &&
        state.user.userType == UserType.participant;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isParticipant && _scheduleId.isNotEmpty) _loadSaved();
    });
  }

  Future<void> _loadSaved() async {
    final res = await _api.getMyFavorites();
    if (!mounted || res['success'] != true) return;
    final ids = ((res['scheduleIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    setState(() => _saved = ids.contains(_scheduleId));
  }

  /// Saves / removes the session from "My Schedule" (the Favorites list).
  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    final res = await _api.toggleFavoriteSchedule(_scheduleId);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (res['success'] == true) _saved = res['favorite'] == true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? (_saved == true
                    ? 'Saved to My Schedule'
                    : 'Removed from My Schedule')
              : res['error']?.toString() ?? 'Could not update',
        ),
      ),
    );
  }

  Future<void> _openMap(String venue) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(venue)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  DateTime? _calendarDay() {
    final d = DateTime.tryParse(_s['date']?.toString() ?? '')?.toUtc();
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  ({DateTime start, DateTime end})? _window() {
    final day = _calendarDay();
    if (day == null) return null;
    final from = _s['fromTime']?.toString().trim() ?? '';
    final to = _s['toTime']?.toString().trim() ?? '';
    if (from.isEmpty || to.isEmpty) return null;
    DateTime at(String hhmm) {
      final p = hhmm.split(':');
      return DateTime(
        day.year,
        day.month,
        day.day,
        int.tryParse(p[0]) ?? 0,
        p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
      );
    }

    return (start: at(from), end: at(to));
  }

  @override
  Widget build(BuildContext context) {
    final scheduleName = _s['scheduleName']?.toString() ?? '';
    final speakers = splitSpeakerNames(_s['speakerName']?.toString());
    final speakerPhoto = _s['speakerPhoto']?.toString() ?? '';
    final description = _s['description']?.toString() ?? '';
    final hall = _s['hall']?.toString() ?? '';
    final eventTitle = widget.event['title']?.toString() ?? '';
    final venue = widget.event['venue']?.toString() ?? '';

    final window = _window();
    final now = DateTime.now();
    final isLive =
        window != null &&
        !now.isBefore(window.start) &&
        now.isBefore(window.end);
    final isPast = window != null && now.isAfter(window.end);

    final calendarDay = scheduleDateVisible(_s) ? _calendarDay() : null;
    final dateTile = calendarDay == null
        ? null
        : _InfoTile(
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF3B82F6),
            label: 'DATE',
            value: DateFormat('EEEE,\nd MMM yyyy').format(calendarDay),
          );
    final shownFrom = visibleFromTime(_s);
    final shownTo = visibleToTime(_s);
    final timeTile = window == null || (shownFrom.isEmpty && shownTo.isEmpty)
        ? null
        : _InfoTile(
            icon: Icons.access_time_rounded,
            color: const Color(0xFF14B8A6),
            label: 'TIME',
            value: [
              if (shownFrom.isNotEmpty) DateFormat('h:mm a').format(window.start),
              if (shownTo.isNotEmpty) DateFormat('h:mm a').format(window.end),
            ].join(' -\n'),
          );
    final hallTile = hall.isEmpty
        ? null
        : _InfoTile(
            icon: Icons.apartment_rounded,
            color: const Color(0xFF8B5CF6),
            label: 'HALL',
            value: hall,
          );
    final locationTile = venue.isEmpty
        ? null
        : _InfoTile(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFE11D48),
            label: 'LOCATION',
            value: venue,
            onTap: () => _openMap(venue),
          );

    // Two tiles side by side (or one full width when the other is missing).
    Widget pair(Widget? a, Widget? b) {
      final tiles = [a, b].whereType<Widget>().toList();
      if (tiles.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              if (tiles.length > 1) ...[
                const SizedBox(width: 10),
                Expanded(child: tiles[1]),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: AppBar(
        backgroundColor: _Colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        toolbarHeight: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Program Details',
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: const [_ReminderBellButton(), SizedBox(width: 14)],
      ),
      bottomNavigationBar: _isParticipant && _scheduleId.isNotEmpty
          ? _saveButton()
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        children: [
          if (speakers.isNotEmpty)
            _speakerHeader(speakers, speakerPhoto, isLive, isPast, window != null),
          const SizedBox(height: 10),
          _titlePanel(scheduleName, eventTitle),
          pair(dateTile, timeTile),
          pair(hallTile, locationTile),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            _aboutCard(description),
          ],
          // Files, polls and questions the speaker added to this session.
          if (_scheduleId.isNotEmpty)
            SessionContentSection(scheduleId: _scheduleId),
        ],
      ),
    );
  }

  /// Glowing card: speaker photo, "SPEAKER" pill, name, tagline, status pill
  /// and the light-bulb quote on the right.
  Widget _speakerHeader(
    List<String> names,
    String photo,
    bool isLive,
    bool isPast,
    bool showStatus,
  ) {
    final name = names.isEmpty ? '' : names.first;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !w.toLowerCase().startsWith('dr'))
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final statusLabel = isLive ? 'LIVE NOW' : (isPast ? 'ENDED' : 'UPCOMING');
    final statusColor = isLive
        ? const Color(0xFF22C55E)
        : isPast
        ? const Color(0xFF94A3B8)
        : const Color(0xFF60A5FA);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1A46), Color(0xFF1A1250), Color(0xFF3B1780)],
        ),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFFA855F7),
                  Color(0xFFEC4899),
                  Color(0xFF3B82F6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage: photo.isNotEmpty
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: photo.isEmpty
                  ? Text(
                      initials.isEmpty ? (name.isEmpty ? 'IS' : '?') : initials,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(
                  Icons.mic_rounded,
                  name.isEmpty ? 'SESSION' : 'SPEAKER',
                  const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                ),
                const SizedBox(height: 5),
                if (names.isEmpty)
                  Text(
                    'Programme',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  )
                else
                  for (final speaker in names)
                    Text(
                      speaker,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  'Inspiring Minds  |  Building Futures',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                if (showStatus) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLive
                              ? Icons.sensors_rounded
                              : Icons.person_outline_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 24,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(height: 4),
                Text(
                  '“Ideas today build better tomorrows”',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.dancingScript(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small gradient pill with an icon, e.g. "SPEAKER" or "KEYNOTE".
  Widget _pill(IconData icon, String label, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient panel: graduation-cap art, "KEYNOTE"/"SESSION" pill, session
  /// title, the event name pill and the tooth mark.
  Widget _titlePanel(String scheduleName, String eventTitle) {
    final isKeynote = scheduleName.toLowerCase().contains('keynote');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2F8A), Color(0xFF2B2A9E), Color(0xFF4C1D95)],
        ),
        border: Border.all(
          color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 44,
                color: Color(0xFFE0E7FF),
              ),
              Positioned(
                top: -13,
                left: 4,
                child: Icon(
                  Icons.school_rounded,
                  size: 33,
                  color: const Color(0xFF2563EB).withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(
                  Icons.star_rounded,
                  isKeynote ? 'KEYNOTE' : 'SESSION',
                  const [Color(0xFFA855F7), Color(0xFF7C3AED)],
                ),
                const SizedBox(height: 6),
                Text(
                  scheduleName,
                  style: GoogleFonts.outfit(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                if (eventTitle.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      eventTitle,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Opacity(
            opacity: 0.9,
            child: Image.asset(
              'assets/ISDR 2026 Logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.medical_services_outlined,
                size: 44,
                color: Color(0xFF7DD3FC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Designation & Affiliation" card: document icon, accent line and the text.
  Widget _aboutCard(String description) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14163F), Color(0xFF2A1466)],
        ),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -10,
            child: Icon(
              Icons.biotech_rounded,
              size: 70,
              color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF6D28D9)],
                  ),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESIGNATION & AFFILIATION',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Full-width gradient "Save to My Schedule" button (the Favorites list).
  Widget _saveButton() {
    final saved = _saved == true;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: saved
                    ? const [Color(0xFF15803D), Color(0xFF16A34A)]
                    : const [Color(0xFF9333EA), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: (saved ? _Colors.live : const Color(0xFF818CF8))
                    .withValues(alpha: 0.7),
                width: 1.4,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _saved == null || _saving ? null : _toggleSaved,
              child: Row(
                children: [
                  const SizedBox(width: 26),
                  Icon(
                    saved
                        ? Icons.event_available_rounded
                        : Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  Expanded(
                    child: _saving || _saved == null
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            saved
                                ? 'Saved to My Schedule'
                                : 'Save to My Schedule',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  Icon(
                    saved ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark round button used in the app bar.
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;

  const _CircleButton({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: const Color(0xFF16213F),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
          if (badge != null) Positioned(right: 2, top: 2, child: badge!),
        ],
      ),
    );
  }
}

/// Visual-only "notify me" toggle in the app bar — fills in when tapped.
/// Not yet wired to real notification scheduling.
class _ReminderBellButton extends StatefulWidget {
  const _ReminderBellButton();

  @override
  State<_ReminderBellButton> createState() => _ReminderBellButtonState();
}

class _ReminderBellButtonState extends State<_ReminderBellButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: _on
          ? Icons.notifications_active_rounded
          : Icons.notifications_none_rounded,
      onTap: () => setState(() => _on = !_on),
      badge: _on
          ? Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// One detail row: coloured round icon, small caps label, value and chevron.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1638),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Colors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.7)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: color.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
