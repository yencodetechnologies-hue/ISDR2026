import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../admin/presentation/pages/my_profile_page.dart';
import '../../../admin/presentation/pages/event_schedule_list_page.dart';
import '../../../admin/presentation/pages/event_schedules_page.dart';
import '../../../admin/presentation/widgets/auto_scroll_banner.dart';
import 'about_isdr_page.dart';
import 'organizing_committee_page.dart';
import 'student_conference_page.dart';
import 'awards_page.dart';
import 'accommodation_page.dart';
import 'claimed_inclusion_page.dart';
import 'available_inclusion_page.dart';
import 'schedule_detail_page.dart';

// ---------------------------------------------------------------------------
// Management Theme Palette
// ---------------------------------------------------------------------------
class _MgmtColors {
  static const ink = Color(0xFF0F172A);
  static const charcoal2 = Color(0xFF1E3A8A);
  static const primaryBlue = Color(0xFF2563EB);
  static const bg = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
  static const iconBg = Color(0xFFF2F2F1);
}

/// Participant Home Page styled with the exact UI design language of the
/// Management screen (BrandGradientAppBar, category headers, management module tiles).
class ParticipantHomePage extends StatefulWidget {
  const ParticipantHomePage({super.key});

  @override
  State<ParticipantHomePage> createState() => _ParticipantHomePageState();
}

class _ParticipantHomePageState extends State<ParticipantHomePage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _matchedEvent;
  Map<String, dynamic>? _upcomingEvent;
  Timer? _clockTimer;

  // Today's schedules only (live first, then upcoming for today), cycled
  // through the live-show card every few seconds like a rotating display.
  final List<Map<String, dynamic>> _todayItems = [];
  int _cycleIndex = 0;
  Timer? _cycleTimer;

  // All not-yet-started programs (any date), chronological. The card shows
  // one date at a time (defaulting to the earliest), 3 programs per batch,
  // cycling through that date's batches and looping back to the start.
  // Picking a date from the dropdown jumps straight to that date's programs.
  final List<Map<String, dynamic>> _upcomingQueue = [];
  int _upcomingBatchIndex = 0;
  DateTime? _selectedUpcomingDate;
  Timer? _upcomingCycleTimer;

  List<DateTime> get _upcomingDates {
    final seen = <DateTime>{};
    for (final item in _upcomingQueue) {
      final start = item['start'] as DateTime;
      seen.add(DateTime(start.year, start.month, start.day));
    }
    final list = seen.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _upcomingForSelectedDate {
    final date = _selectedUpcomingDate;
    if (date == null) return _upcomingQueue;
    return _upcomingQueue.where((item) {
      final start = item['start'] as DateTime;
      return start.year == date.year && start.month == date.month && start.day == date.day;
    }).toList();
  }

  List<List<Map<String, dynamic>>> get _upcomingBatches {
    final source = _upcomingForSelectedDate;
    final batches = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < source.length; i += 3) {
      batches.add(source.sublist(i, i + 3 > source.length ? source.length : i + 3));
    }
    return batches;
  }

  @override
  void initState() {
    super.initState();
    _fetchLiveSchedule();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchLiveSchedule();
    });
    _cycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _todayItems.length < 2) return;
      setState(() {
        _cycleIndex = (_cycleIndex + 1) % _todayItems.length;
      });
    });
    _upcomingCycleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final batches = _upcomingBatches;
      if (batches.length < 2) return;
      setState(() {
        _upcomingBatchIndex = (_upcomingBatchIndex + 1) % batches.length;
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _cycleTimer?.cancel();
    _upcomingCycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveSchedule() async {
    try {
      final eventsRes = await _api.listManagedEvents();
      if (eventsRes['success'] != true) return;
      final events = List<Map<String, dynamic>>.from(
        (eventsRes['events'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      if (events.isEmpty) return;

      final now = DateTime.now();
      Map<String, dynamic>? liveEv;
      Map<String, dynamic>? nextUpcomingEv;
      DateTime? earliestUpcomingTime;
      final todayList = <Map<String, dynamic>>[];
      final upcomingList = <Map<String, dynamic>>[];

      for (final event in events) {
        final eventId = event['id']?.toString() ?? event['_id']?.toString() ?? '';
        if (eventId.isEmpty) continue;
        final schedRes = await _api.listEventSchedules(eventId);
        if (schedRes['success'] != true) continue;
        final schedules = List<Map<String, dynamic>>.from(
          (schedRes['schedules'] as List?)?.map((s) => Map<String, dynamic>.from(s as Map)) ?? [],
        );

        for (final s in schedules) {
          final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
          if (d == null) continue;
          final fromParts = s['fromTime'].toString().split(':');
          final toParts = s['toTime'].toString().split(':');
          final start = DateTime(d.year, d.month, d.day, int.tryParse(fromParts[0]) ?? 0,
              fromParts.length > 1 ? int.tryParse(fromParts[1]) ?? 0 : 0);
          final end = DateTime(d.year, d.month, d.day, int.tryParse(toParts[0]) ?? 0,
              toParts.length > 1 ? int.tryParse(toParts[1]) ?? 0 : 0);

          final isToday =
              d.year == now.year && d.month == now.month && d.day == now.day;

          // Check if currently LIVE
          if (!now.isBefore(start) && now.isBefore(end)) {
            liveEv = event;
          }

          // Check if upcoming in the future
          if (now.isBefore(start)) {
            if (earliestUpcomingTime == null || start.isBefore(earliestUpcomingTime)) {
              earliestUpcomingTime = start;
              nextUpcomingEv = event;
            }
            // Today's programs are already shown in the live-show card above —
            // this list is only for future days.
            if (!isToday) {
              upcomingList.add({
                'schedule': s,
                'event': event,
                'start': start,
                'end': end,
              });
            }
          }

          // Same-day items still relevant right now (live or yet to end) —
          // these are what the live-show card cycles through.
          if (isToday && end.isAfter(now)) {
            todayList.add({
              'schedule': s,
              'event': event,
              'start': start,
              'end': end,
            });
          }
        }
      }

      todayList.sort((a, b) =>
          (a['start'] as DateTime).compareTo(b['start'] as DateTime));
      upcomingList.sort((a, b) =>
          (a['start'] as DateTime).compareTo(b['start'] as DateTime));

      if (mounted) {
        setState(() {
          _matchedEvent = liveEv ?? nextUpcomingEv ?? (events.isNotEmpty ? events.first : null);
          _upcomingEvent = nextUpcomingEv ?? (events.isNotEmpty ? events.first : null);
          _todayItems
            ..clear()
            ..addAll(todayList);
          if (_cycleIndex >= _todayItems.length) _cycleIndex = 0;
          _upcomingQueue
            ..clear()
            ..addAll(upcomingList);
          final dates = _upcomingDates;
          final stillValid = _selectedUpcomingDate != null &&
              dates.any((d) => d == _selectedUpcomingDate);
          if (!stillValid) {
            _selectedUpcomingDate = dates.isNotEmpty ? dates.first : null;
            _upcomingBatchIndex = 0;
          }
          final batchCount = _upcomingBatches.length;
          if (batchCount > 0 && _upcomingBatchIndex >= batchCount) {
            _upcomingBatchIndex = 0;
          }
        });
      }
    } catch (_) {}
  }
  void _onTileTap(String title) {
    final lower = title.toLowerCase().trim();
    if (lower == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyProfilePage()),
      );
      return;
    }
    if (lower == 'claimed inclusion') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClaimedInclusionPage()),
      );
      return;
    }
    if (lower == 'available inclusion') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AvailableInclusionPage()),
      );
      return;
    }
    if (lower == 'about isdr') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AboutISDRPage()),
      );
      return;
    }
    if (lower == 'organizational committee' ||
        lower == 'organising committee') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrganizingCommitteePage()),
      );
      return;
    }
    if (lower == 'student conference') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentConferencePage()),
      );
      return;
    }
    if (lower == 'awards') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AwardsPage()),
      );
      return;
    }
    if (lower == 'accommodation' || lower == 'scientific accommodation') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccommodationPage()),
      );
      return;
    }
    if (lower == 'upcoming events' || lower == 'live show') {
      final targetEvent = _upcomingEvent ?? _matchedEvent;
      if (targetEvent != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventScheduleListPage(
              event: targetEvent,
              isReadOnly: true,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EventSchedulesPage(isReadOnly: true),
          ),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title tapped'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MgmtColors.bg,
      appBar: buildBrandGradientAppBar(
        title: Text(
          'ISDR 2026',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                context.read<AuthBloc>().add(LogoutEvent());
                AppNavigation.resetTo(context, AppRoutes.login);
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AutoScrollBanner(items: defaultManagementBanners),
            const _NewsTickerStrap(
              text:
                  'Welcome to ISDR 2026 — 36th International Conference  •  IADR Indian Division  •  Register your sessions and claim your inclusions on time  •  ',
            ),
            // Live Show Hero Banner Card — full-bleed, no side padding
            _buildLiveShowBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            const SizedBox(height: 10),

            // Upcoming Programs — 3 rows, cycling through the next batches
            _buildUpcomingProgramsCard(),
            const SizedBox(height: 20),

            // =================================================================
            // 2. PARTICIPANT MODULES (3-column grid matching Management screen)
            // =================================================================
            _buildSectionHeader('PARTICIPANT MODULES'),
            const SizedBox(height: 8),
            _buildModuleGrid([
              _ParticipantModuleItem(
                label: 'Profile',
                icon: Icons.person_rounded,
                onTap: () => _onTileTap('Profile'),
              ),
              _ParticipantModuleItem(
                label: 'Claimed\nInclusion',
                icon: Icons.verified_rounded,
                accent: true,
                onTap: () => _onTileTap('Claimed Inclusion'),
              ),
              _ParticipantModuleItem(
                label: 'Available\nInclusion',
                icon: Icons.inventory_2_rounded,
                onTap: () => _onTileTap('Available Inclusion'),
              ),
              _ParticipantModuleItem(
                label: 'About\nISDR',
                icon: Icons.menu_book_rounded,
                onTap: () => _onTileTap('About ISDR'),
              ),
              _ParticipantModuleItem(
                label: 'Organizational\nCommittee',
                icon: Icons.groups_rounded,
                onTap: () => _onTileTap('Organizational Committee'),
              ),
              _ParticipantModuleItem(
                label: 'Student\nConference',
                icon: Icons.school_rounded,
                onTap: () => _onTileTap('Student Conference'),
              ),
              _ParticipantModuleItem(
                label: 'Awards',
                icon: Icons.emoji_events_rounded,
                accent: true,
                onTap: () => _onTileTap('Awards'),
              ),
            ]),
            const SizedBox(height: 20),

            // =================================================================
            // 3. ACCOMMODATION SECTION
            // =================================================================
            _buildSectionHeader('ACCOMMODATION & SERVICES'),
            const SizedBox(height: 8),
            _buildAccommodationBanner(),
            const SizedBox(height: 24),

            // =================================================================
            // 4. SOCIAL MEDIA LINKS (Golden Icons matching web design)
            // =================================================================
            _buildSocialLinksBar(),
            const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchSocialUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildSocialLinksBar() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Facebook
              _buildSocialIconItem(
                label: 'Facebook',
                textIcon: 'f',
                fontSize: 16,
                isBold: true,
                onTap: () => _launchSocialUrl('https://www.facebook.com/sbdch.dental'),
              ),
              _buildSocialDivider(),

              // Instagram
              _buildSocialIconItem(
                label: 'Instagram',
                icon: Icons.camera_alt_outlined,
                onTap: () => _launchSocialUrl('https://www.instagram.com/sbdch_dental/'),
              ),
              _buildSocialDivider(),

              // YouTube
              _buildSocialIconItem(
                label: 'YouTube',
                icon: Icons.play_circle_fill_rounded,
                onTap: () => _launchSocialUrl('https://www.youtube.com/@TheDental-Classroom'),
              ),
              _buildSocialDivider(),

              // X (Twitter)
              _buildSocialIconItem(
                label: 'X (Twitter)',
                textIcon: '𝕏',
                fontSize: 14,
                isBold: true,
                onTap: () => _launchSocialUrl('https://x.com/sbdch_dental'),
              ),
              _buildSocialDivider(),

              // LinkedIn
              _buildSocialIconItem(
                label: 'LinkedIn',
                textIcon: 'in',
                fontSize: 14,
                isBold: true,
                onTap: () => _launchSocialUrl(
                  'https://www.linkedin.com/school/sree-balaji-dental-college-and-hospital/?originalSubdomain=in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFCBD5E1),
    );
  }

  Widget _buildSocialIconItem({
    required String label,
    IconData? icon,
    String? textIcon,
    double fontSize = 14,
    bool isBold = false,
    required VoidCallback onTap,
  }) {
    const goldColor = Color(0xFFD97706);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: SizedBox(
            width: 22,
            height: 22,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 19, color: goldColor)
                  : Text(
                      textIcon!,
                      style: GoogleFonts.outfit(
                        fontSize: fontSize,
                        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                        color: goldColor,
                        height: 1.1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: _MgmtColors.muted,
      ),
    );
  }

  String _fmtTimeStr(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    final dt = DateTime(2026, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  /// Live Show Banner Card — cycles through today's schedules (live first,
  /// then each upcoming one for today) every 3 seconds, morphing between them.
  Widget _buildLiveShowBanner() {
    if (_todayItems.isNotEmpty) {
      final index = _cycleIndex < _todayItems.length ? _cycleIndex : 0;
      final item = _todayItems[index];
      final schedule = item['schedule'] as Map<String, dynamic>;
      final event = item['event'] as Map<String, dynamic>;
      final start = item['start'] as DateTime;
      final end = item['end'] as DateTime;
      final now = DateTime.now();
      final isLive = !now.isBefore(start) && now.isBefore(end);

      final scheduleName = schedule['scheduleName']?.toString() ?? '';
      final speakerName = schedule['speakerName']?.toString() ?? '';
      final speakerPhoto = schedule['speakerPhoto']?.toString() ?? '';
      final fromTime = schedule['fromTime']?.toString() ?? '';
      final toTime = schedule['toTime']?.toString() ?? '';
      final scheduleId = schedule['id']?.toString() ?? scheduleName;

      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduleDetailPage(
                    schedule: schedule,
                    event: event,
                  ),
                ),
              );
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: (isLive ? const Color(0xFF22C55E) : const Color(0xFF2563EB))
                                .withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: speakerPhoto.isNotEmpty
                              ? Image.network(
                                  speakerPhoto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    isLive
                                        ? Icons.mic_external_on_rounded
                                        : Icons.upcoming_rounded,
                                    color: isLive
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF93C5FD),
                                    size: 20,
                                  ),
                                )
                              : Icon(
                                  isLive ? Icons.mic_external_on_rounded : Icons.upcoming_rounded,
                                  color: isLive ? const Color(0xFF4ADE80) : const Color(0xFF93C5FD),
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scheduleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (speakerName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  speakerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLive)
                              const _GlowingDot(color: Color(0xFF22C55E))
                            else
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF93C5FD),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              isLive ? 'LIVE' : 'UPCOMING',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (fromTime.isNotEmpty && toTime.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF93C5FD)),
                              const SizedBox(width: 4),
                              Text(
                                '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF93C5FD),
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ReminderBellButton(
                              scheduleId: scheduleId,
                              activeColor: const Color(0xFFFBBF24),
                              inactiveColor: Colors.white.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'view details',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.90),
                            ),
                          ],
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

    // NO LIVE PROGRAM ACTIVE STATE
    return Container(
      color: _MgmtColors.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.podcasts_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Live Program',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No live program is currently active',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OFFLINE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _upcomingDisplayDate(DateTime start) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('d MMM').format(day);
  }

  /// Header showing the current date label with a dropdown of every date
  /// that has upcoming programs — picking one jumps straight to that date.
  Widget _upcomingDateDropdown(DateTime currentDate) {
    final dates = _upcomingDates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: PopupMenuButton<DateTime>(
        tooltip: 'Choose a date',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        onSelected: (picked) {
          setState(() {
            _selectedUpcomingDate = picked;
            _upcomingBatchIndex = 0;
          });
        },
        itemBuilder: (context) => dates
            .map((d) => PopupMenuItem<DateTime>(
                  value: d,
                  child: Text(
                    _upcomingDisplayDate(d),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ))
            .toList(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _upcomingDisplayDate(currentDate),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
                color: _MgmtColors.primaryBlue,
              ),
            ),
            if (dates.length > 1) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: _MgmtColors.primaryBlue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Upcoming Programs card — shows the next 3 (chronologically) at a time,
  /// morphing to the next batch of 3 every few seconds, looping forever.
  Widget _buildUpcomingProgramsCard() {
    final batches = _upcomingBatches;
    if (batches.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _MgmtColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _MgmtColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'No upcoming programs',
                style: GoogleFonts.inter(fontSize: 13, color: _MgmtColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final index = _upcomingBatchIndex < batches.length ? _upcomingBatchIndex : 0;
    final batch = batches[index];

    return Container(
      decoration: BoxDecoration(
        color: _MgmtColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _MgmtColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _upcomingDateDropdown(batch.first['start'] as DateTime),
            for (var i = 0; i < batch.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: _MgmtColors.line),
              _upcomingRow(batch[i]),
            ],
          ],
        ),
    );
  }

  Widget _upcomingRow(Map<String, dynamic> item) {
    final schedule = item['schedule'] as Map<String, dynamic>;
    final event = item['event'] as Map<String, dynamic>;
    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final speakerName = schedule['speakerName']?.toString() ?? '';
    final speakerPhoto = schedule['speakerPhoto']?.toString() ?? '';
    final fromTime = schedule['fromTime']?.toString() ?? '';
    final toTime = schedule['toTime']?.toString() ?? '';
    final scheduleId = schedule['id']?.toString() ?? scheduleName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScheduleDetailPage(schedule: schedule, event: event),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _MgmtColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: speakerPhoto.isNotEmpty
                    ? Image.network(
                        speakerPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.event_available_rounded,
                          color: _MgmtColors.primaryBlue,
                          size: 22,
                        ),
                      )
                    : const Icon(
                        Icons.event_available_rounded,
                        color: _MgmtColors.primaryBlue,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheduleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _MgmtColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (speakerName.isNotEmpty)
                      Text(
                        speakerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _MgmtColors.primaryBlue,
                        ),
                      ),
                    if (fromTime.isNotEmpty && toTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _MgmtColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _ReminderBellButton(
                scheduleId: scheduleId,
                activeColor: _MgmtColors.primaryBlue,
                inactiveColor: _MgmtColors.muted,
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _MgmtColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Accommodation Banner Card
  Widget _buildAccommodationBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0F2B66)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onTileTap('Accommodation'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hotel_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Accommodation',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3-Column Module Grid identical to the Management screen's Module Tile Grid
  Widget _buildModuleGrid(List<_ParticipantModuleItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ManagementTileWidget(item: item);
      },
    );
  }
}

class _ParticipantModuleItem {
  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;

  const _ParticipantModuleItem({
    required this.label,
    required this.icon,
    this.accent = false,
    required this.onTap,
  });
}

class _ManagementTileWidget extends StatefulWidget {
  final _ParticipantModuleItem item;
  const _ManagementTileWidget({required this.item});

  @override
  State<_ManagementTileWidget> createState() => _ManagementTileWidgetState();
}

class _ManagementTileWidgetState extends State<_ManagementTileWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final iconBg = item.accent
        ? const Color(0xFF13275D).withValues(alpha: 0.12)
        : _MgmtColors.iconBg;
    final iconColor = item.accent
        ? const Color(0xFF0284C7)
        : _MgmtColors.ink;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: item.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: _MgmtColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _MgmtColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _MgmtColors.ink,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A blue strap with continuously scrolling marquee text, like a news ticker —
/// loops forever, never stops.
class _NewsTickerStrap extends StatefulWidget {
  final String text;
  const _NewsTickerStrap({required this.text});

  @override
  State<_NewsTickerStrap> createState() => _NewsTickerStrapState();
}

class _NewsTickerStrapState extends State<_NewsTickerStrap> {
  final ScrollController _controller = ScrollController();
  Timer? _ticker;
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  void _measureAndStart() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _textStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _textWidth = painter.width + 40; // matches the SizedBox gap below
    _start();
  }

  void _start() {
    if (_textWidth <= 0) return;
    const step = 0.8; // px per tick — smooth, continuous scroll
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          !_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      var next = _controller.offset + step;
      if (next >= _textWidth) next -= _textWidth;
      _controller.jumpTo(next);
    });
  }

  static final TextStyle _textStyle = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _MgmtColors.primaryBlue,
      height: 34,
      alignment: Alignment.centerLeft,
      child: ListView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(3, (_) {
          return Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Center(
              child: Text(widget.text, maxLines: 1, style: _textStyle),
            ),
          );
        }),
      ),
    );
  }
}

/// A small dot with a soft pulsing glow, used for the "LIVE" indicator.
class _GlowingDot extends StatefulWidget {
  final Color color;
  const _GlowingDot({required this.color});

  @override
  State<_GlowingDot> createState() => _GlowingDotState();
}

class _GlowingDotState extends State<_GlowingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 6 + 10 * _pulse.value,
              height: 6 + 10 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.5 * (1 - _pulse.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.8),
                    blurRadius: 4,
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

/// Visual-only "notify me" toggle for a program — fills in when tapped.
/// Not yet wired to real notification scheduling.
class _ReminderBellButton extends StatefulWidget {
  final String scheduleId;
  final Color activeColor;
  final Color inactiveColor;

  const _ReminderBellButton({
    required this.scheduleId,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<_ReminderBellButton> createState() => _ReminderBellButtonState();
}

class _ReminderBellButtonState extends State<_ReminderBellButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _on = !_on),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          size: 18,
          color: _on ? widget.activeColor : widget.inactiveColor,
        ),
      ),
    );
  }
}
