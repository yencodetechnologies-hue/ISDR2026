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

class _Colors {
  static const bg = Color(0xFF0A0F24);
  static const card = Color(0xFF111A33);
  static const panel = Color(0xFF15204A);
  static const line = Color(0x1AFFFFFF);
  static const muted = Color(0xFF9CA3AF);
  static const blue = Color(0xFF3B82F6);
  static const nameBlue = Color(0xFF60A5FA);
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

  ({DateTime start, DateTime end})? _window() {
    final d = DateTime.tryParse(_s['date']?.toString() ?? '')?.toUtc();
    if (d == null) return null;
    DateTime at(String hhmm) {
      final p = hhmm.split(':');
      return DateTime(
        d.year,
        d.month,
        d.day,
        int.tryParse(p[0]) ?? 0,
        p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
      );
    }

    return (
      start: at(_s['fromTime']?.toString() ?? '0:0'),
      end: at(_s['toTime']?.toString() ?? '0:0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleName = _s['scheduleName']?.toString() ?? '';
    final speakerName = _s['speakerName']?.toString() ?? '';
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

    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: AppBar(
        backgroundColor: _Colors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'Program Details',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: const [_ReminderBellButton(), SizedBox(width: 12)],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _Colors.line),
        ),
      ),
      bottomNavigationBar: _isParticipant && _scheduleId.isNotEmpty
          ? _saveButton()
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        children: [
          _speakerHeader(speakerName, speakerPhoto, isLive, isPast),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _Colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _Colors.line),
            ),
            child: Column(
              children: [
                _titlePanel(scheduleName, eventTitle),
                if (window != null) ...[
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF3B82F6),
                    label: 'DATE',
                    value: DateFormat('EEEE, d MMM yyyy').format(window.start),
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    color: const Color(0xFF14B8A6),
                    label: 'TIME',
                    value:
                        '${DateFormat('h:mm a').format(window.start)} - '
                        '${DateFormat('h:mm a').format(window.end)}',
                  ),
                ],
                if (hall.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.apartment_rounded,
                    color: const Color(0xFF8B5CF6),
                    label: 'HALL',
                    value: hall,
                  ),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'LOCATION',
                    value: venue,
                    onTap: () => _openMap(venue),
                  ),
                ],
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _Colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _Colors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ABOUT THIS SESSION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                      color: _Colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Files, polls and questions the speaker added to this session.
          if (_scheduleId.isNotEmpty)
            SessionContentSection(scheduleId: _scheduleId),
        ],
      ),
    );
  }

  /// Photo with a glowing ring, name ("Dr." white + name in blue), tagline and
  /// the status pill, with a light-bulb accent at the top right.
  Widget _speakerHeader(String name, String photo, bool isLive, bool isPast) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final hasPrefix =
        parts.length > 1 && parts.first.toLowerCase().startsWith('dr');
    final prefix = hasPrefix ? '${parts.first} ' : '';
    final rest = hasPrefix ? parts.skip(1).join(' ') : name.trim();
    final initials = (hasPrefix ? parts.skip(1) : parts)
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final statusLabel = isLive ? 'LIVE NOW' : (isPast ? 'ENDED' : 'UPCOMING');
    final statusColors = isLive
        ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
        : isPast
        ? const [Color(0xFF475569), Color(0xFF64748B)]
        : const [Color(0xFF2563EB), Color(0xFF4F46E5)];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 0,
          top: -6,
          child: Icon(
            Icons.lightbulb_outline_rounded,
            size: 38,
            color: _Colors.nameBlue.withValues(alpha: 0.8),
          ),
        ),
        Row(
          children: [
            Container(
              width: 116,
              height: 116,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 1,
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
                        initials.isEmpty ? '?' : initials,
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: prefix,
                            style: const TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: rest,
                            style: const TextStyle(color: _Colors.nameBlue),
                          ),
                        ],
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inspiring Minds  |  Building Futures',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: statusColors),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: statusColors.last.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLive
                              ? Icons.sensors_rounded
                              : Icons.person_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Gradient panel with the graduation-cap art, session title, the event
  /// name pill and the tooth mark.
  Widget _titlePanel(String scheduleName, String eventTitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2B5E), _Colors.panel],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduleName,
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                if (eventTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _Colors.blue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      eventTitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _Colors.nameBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Opacity(
            opacity: 0.85,
            child: Image.asset(
              'assets/ISDR 2026 Logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
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
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: saved
                    ? const [Color(0xFF15803D), Color(0xFF16A34A)]
                    : const [Color(0xFF1E1B6B), Color(0xFF2563EB)],
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
                              fontSize: 16.5,
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
          color: const Color(0xFF0E1630),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Colors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: color.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
