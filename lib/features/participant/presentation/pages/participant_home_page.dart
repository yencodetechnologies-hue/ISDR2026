import 'dart:async';
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
  Map<String, dynamic>? _liveSchedule;
  Map<String, dynamic>? _matchedEvent;
  Map<String, dynamic>? _upcomingSchedule;
  Map<String, dynamic>? _upcomingEvent;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _fetchLiveSchedule();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchLiveSchedule();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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
      Map<String, dynamic>? live;
      Map<String, dynamic>? liveEv;
      Map<String, dynamic>? nextUpcoming;
      Map<String, dynamic>? nextUpcomingEv;
      DateTime? earliestUpcomingTime;

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

          // Check if currently LIVE
          if (!now.isBefore(start) && now.isBefore(end)) {
            live = s;
            liveEv = event;
          }

          // Check if upcoming in the future
          if (now.isBefore(start)) {
            if (earliestUpcomingTime == null || start.isBefore(earliestUpcomingTime)) {
              earliestUpcomingTime = start;
              nextUpcoming = s;
              nextUpcomingEv = event;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _liveSchedule = live;
          _matchedEvent = liveEv ?? nextUpcomingEv ?? (events.isNotEmpty ? events.first : null);
          _upcomingSchedule = nextUpcoming;
          _upcomingEvent = nextUpcomingEv ?? (events.isNotEmpty ? events.first : null);
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AutoScrollBanner(items: defaultManagementBanners),
            const SizedBox(height: 20),
            // =================================================================
            // 1. LIVE & UPCOMING SECTION
            // =================================================================
            _buildSectionHeader('LIVE & UPCOMING'),
            const SizedBox(height: 8),

            // Live Show Hero Banner Card
            _buildLiveShowBanner(),
            const SizedBox(height: 10),

            // Upcoming Events Banner Card
            _buildUpcomingEventsBanner(),
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

  /// Live Show Banner Card - Shows active live schedule details or 'No live program' message
  Widget _buildLiveShowBanner() {
    final isLive = _liveSchedule != null;
    final scheduleName = _liveSchedule?['scheduleName']?.toString() ?? '';
    final speakerName = _liveSchedule?['speakerName']?.toString() ?? '';
    final fromTime = _liveSchedule?['fromTime']?.toString() ?? '';
    final toTime = _liveSchedule?['toTime']?.toString() ?? '';

    if (isLive) {
      // ACTIVE LIVE SCHEDULE STATE
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (_matchedEvent != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventScheduleListPage(
                      event: _matchedEvent!,
                      isReadOnly: true,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mic_external_on_rounded,
                          color: Color(0xFF4ADE80),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
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
                          Text(
                            'view schedule',
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

  /// Upcoming Events Banner Card - Shows the next upcoming schedule or opens event schedules
  Widget _buildUpcomingEventsBanner() {
    final hasUpcoming = _upcomingSchedule != null;
    final scheduleName = _upcomingSchedule?['scheduleName']?.toString() ?? 'Upcoming Events';
    final speakerName = _upcomingSchedule?['speakerName']?.toString() ?? '';
    final fromTime = _upcomingSchedule?['fromTime']?.toString() ?? '';
    final toTime = _upcomingSchedule?['toTime']?.toString() ?? '';
    final dateStr = _upcomingSchedule?['date']?.toString() ?? '';

    String displayDate = '';
    if (dateStr.isNotEmpty) {
      final d = DateTime.tryParse(dateStr)?.toUtc();
      if (d != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(d.year, d.month, d.day);
        final diff = day.difference(today).inDays;
        if (diff == 0) {
          displayDate = 'Today';
        } else if (diff == 1) {
          displayDate = 'Tomorrow';
        } else {
          displayDate = DateFormat('d MMM').format(day);
        }
      }
    }

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
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
              _onTileTap('Upcoming Events');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _MgmtColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              scheduleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: _MgmtColors.ink,
                              ),
                            ),
                          ),
                          if (displayDate.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Text(
                                displayDate,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (hasUpcoming && speakerName.isNotEmpty) ...[
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
                      ] else ...[
                        Text(
                          'View upcoming conference sessions',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: _MgmtColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _MgmtColors.muted,
                ),
              ],
            ),
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
