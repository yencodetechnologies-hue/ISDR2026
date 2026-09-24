import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../admin/presentation/pages/my_profile_page.dart';
import '../../../admin/presentation/pages/event_schedule_list_page.dart';
import '../../../admin/presentation/pages/event_schedules_page.dart';
// import '../../../admin/presentation/widgets/auto_scroll_banner.dart'; // image banner swiping — commented out
import 'about_isdr_page.dart';
import 'organizing_committee_page.dart';
import 'student_conference_page.dart';
import 'awards_page.dart';
import 'accommodation_page.dart';
import 'claimed_inclusion_page.dart';
import 'available_inclusion_page.dart';
import 'schedule_detail_page.dart';
import 'participant_feed_page.dart';

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

  // All not-yet-ended programs on days other than today, chronological.
  // Grouped by calendar day and shown as a day-tab schedule list below the
  // "Next Session" card. Picking a day tab jumps straight to that day's list.
  final List<Map<String, dynamic>> _upcomingQueue = [];
  DateTime? _selectedScheduleDate;

  /// Every day that has a schedule — today (if it still has items) first,
  /// then each future day with upcoming programs, chronological.
  List<DateTime> get _scheduleDates {
    final seen = <DateTime>{};
    if (_todayItems.isNotEmpty) {
      final now = DateTime.now();
      seen.add(DateTime(now.year, now.month, now.day));
    }
    for (final item in _upcomingQueue) {
      final start = item['start'] as DateTime;
      seen.add(DateTime(start.year, start.month, start.day));
    }
    final list = seen.toList()..sort();
    return list;
  }

  /// All schedule items (today's remaining ones + future days) for one
  /// calendar day, sorted by start time.
  List<Map<String, dynamic>> _itemsForDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final source = isToday ? _todayItems : _upcomingQueue;
    final items = source.where((item) {
      final start = item['start'] as DateTime;
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }).toList();
    items.sort(
      (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
    );
    return items;
  }

  /// The single closest program that hasn't started yet, across today and
  /// every future day — shown as the standalone "Next Session" card.
  Map<String, dynamic>? get _nextSessionItem {
    final now = DateTime.now();
    final candidates = [
      ..._todayItems.where((i) => (i['start'] as DateTime).isAfter(now)),
      ..._upcomingQueue,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
    );
    return candidates.first;
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
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _cycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveSchedule() async {
    try {
      final eventsRes = await _api.listManagedEvents();
      if (eventsRes['success'] != true) return;
      final events = List<Map<String, dynamic>>.from(
        (eventsRes['events'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      );
      if (events.isEmpty) return;

      final now = DateTime.now();
      Map<String, dynamic>? liveEv;
      Map<String, dynamic>? nextUpcomingEv;
      DateTime? earliestUpcomingTime;
      final todayList = <Map<String, dynamic>>[];
      final upcomingList = <Map<String, dynamic>>[];

      for (final event in events) {
        final eventId =
            event['id']?.toString() ?? event['_id']?.toString() ?? '';
        if (eventId.isEmpty) continue;
        final schedRes = await _api.listEventSchedules(eventId);
        if (schedRes['success'] != true) continue;
        final schedules = List<Map<String, dynamic>>.from(
          (schedRes['schedules'] as List?)?.map(
                (s) => Map<String, dynamic>.from(s as Map),
              ) ??
              [],
        );

        for (final s in schedules) {
          final d = DateTime.tryParse(s['date']?.toString() ?? '')?.toUtc();
          if (d == null) continue;
          final fromParts = s['fromTime'].toString().split(':');
          final toParts = s['toTime'].toString().split(':');
          final start = DateTime(
            d.year,
            d.month,
            d.day,
            int.tryParse(fromParts[0]) ?? 0,
            fromParts.length > 1 ? int.tryParse(fromParts[1]) ?? 0 : 0,
          );
          final end = DateTime(
            d.year,
            d.month,
            d.day,
            int.tryParse(toParts[0]) ?? 0,
            toParts.length > 1 ? int.tryParse(toParts[1]) ?? 0 : 0,
          );

          final isToday =
              d.year == now.year && d.month == now.month && d.day == now.day;

          // Check if currently LIVE
          if (!now.isBefore(start) && now.isBefore(end)) {
            liveEv = event;
          }

          // Check if upcoming in the future
          if (now.isBefore(start)) {
            if (earliestUpcomingTime == null ||
                start.isBefore(earliestUpcomingTime)) {
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

      todayList.sort(
        (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
      );
      upcomingList.sort(
        (a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _matchedEvent =
              liveEv ??
              nextUpcomingEv ??
              (events.isNotEmpty ? events.first : null);
          _upcomingEvent =
              nextUpcomingEv ?? (events.isNotEmpty ? events.first : null);
          _todayItems
            ..clear()
            ..addAll(todayList);
          if (_cycleIndex >= _todayItems.length) _cycleIndex = 0;
          _upcomingQueue
            ..clear()
            ..addAll(upcomingList);
          final dates = _scheduleDates;
          final stillValid =
              _selectedScheduleDate != null &&
              dates.any((d) => d == _selectedScheduleDate);
          if (!stillValid) {
            _selectedScheduleDate = dates.isNotEmpty ? dates.first : null;
          }
        });
      }
    } catch (_) {}
  }

  /// Placeholder tap for modules with no real feature behind them yet.
  void _dummyTap(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  /// The full, ordered list of Participant Module tiles — shared by the grid
  /// and the bottom nav's "More" tab so both stay in sync.
  List<_ParticipantModuleItem> get _allModuleItems => [
    _ParticipantModuleItem(
      label: 'Id Card',
      icon: Icons.badge_rounded,
      color: const Color(0xFF6366F1),
      onTap: () => _onTileTap('Profile'),
    ),
    _ParticipantModuleItem(
      label: 'Feed',
      icon: Icons.dynamic_feed_rounded,
      color: const Color(0xFFEC4899),
      onTap: () => _onTileTap('Feed'),
    ),
    _ParticipantModuleItem(
      label: 'Speakers',
      icon: Icons.groups_rounded,
      color: const Color(0xFF14B8A6),
      onTap: () => _dummyTap('Speakers'),
    ),
    _ParticipantModuleItem(
      label: 'Schedule',
      icon: Icons.event_note_rounded,
      color: const Color(0xFFF97316),
      onTap: () => _dummyTap('Schedule'),
    ),
    _ParticipantModuleItem(
      label: 'Inclusion',
      icon: Icons.card_giftcard_rounded,
      color: const Color(0xFF0EA5E9),
      onTap: _showInclusionPicker,
    ),
    _ParticipantModuleItem(
      label: 'Committee',
      icon: Icons.account_balance_rounded,
      color: const Color(0xFFA855F7),
      onTap: () => _onTileTap('Organizational Committee'),
    ),
    _ParticipantModuleItem(
      label: 'Conference',
      icon: Icons.school_rounded,
      color: const Color(0xFF2563EB),
      onTap: () => _onTileTap('Student Conference'),
    ),
    _ParticipantModuleItem(
      label: 'Awards',
      icon: Icons.emoji_events_rounded,
      color: const Color(0xFFF59E0B),
      onTap: () => _onTileTap('Awards'),
    ),
    _ParticipantModuleItem(
      label: 'About',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF8B5CF6),
      onTap: () => _onTileTap('About ISDR'),
    ),
    _ParticipantModuleItem(
      label: 'Yencode Support',
      icon: Icons.support_agent_rounded,
      color: const Color(0xFF22C55E),
      onTap: () => _dummyTap('Yencode Support'),
    ),
    _ParticipantModuleItem(
      label: 'Help and Support',
      icon: Icons.help_rounded,
      color: const Color(0xFF06B6D4),
      onTap: () => _dummyTap('Help and Support'),
    ),
    _ParticipantModuleItem(
      label: 'Exhibitor',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFEF4444),
      onTap: () => _dummyTap('Exhibitor'),
    ),
  ];

  /// Opens the same "More" overflow page the module grid's own More tile
  /// opens — whatever didn't fit in the grid's fixed slots, plus Settings.
  void _openMoreModules() {
    const crossAxisCount = 6;
    const maxRealSlots = crossAxisCount * 2 - 1;
    final items = _allModuleItems;
    final overflow = items.length > maxRealSlots
        ? items.sublist(maxRealSlots)
        : <_ParticipantModuleItem>[];
    _showMoreModules(overflow);
  }

  /// "Inclusion" combines the Claimed and Available Inclusion pages behind
  /// one module button — a picker sheet lets the participant choose which.
  void _showInclusionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModuleSheet(
        title: 'Inclusion',
        items: [
          _ModuleSheetItem(
            label: 'Claimed Inclusion',
            icon: Icons.verified_rounded,
            color: const Color(0xFF0EA5E9),
            onTap: () {
              Navigator.pop(ctx);
              _onTileTap('Claimed Inclusion');
            },
          ),
          _ModuleSheetItem(
            label: 'Available Inclusion',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFFF97316),
            onTap: () {
              Navigator.pop(ctx);
              _onTileTap('Available Inclusion');
            },
          ),
        ],
      ),
    );
  }

  /// "More" holds every module that doesn't fit in the first two grid rows.
  /// Opens the overflow sheet for whichever modules didn't fit in the grid.
  void _showMoreModules(List<_ParticipantModuleItem> overflow) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MoreModulesPage(
          items: [
            ...overflow.map(
              (item) => _ModuleSheetItem(
                label: item.label.replaceAll('\n', ' '),
                icon: item.icon,
                color: item.color,
                onTap: item.onTap,
              ),
            ),
            _ModuleSheetItem(
              label: 'Settings',
              icon: Icons.settings_rounded,
              color: const Color(0xFF64748B),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _SettingsPage()),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (lower == 'feed') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantFeedPage()),
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
            builder: (_) =>
                EventScheduleListPage(event: targetEvent, isReadOnly: true),
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
      backgroundColor: const Color(0xFF0A0A12),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: _MgmtColors.primaryBlue),
                child: Text(
                  'ISDR 2026',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.notifications);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  LogoutConfirmSheet.showLogoutConfirmSheet(
                    context,
                    onLogout: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                      AppNavigation.resetTo(context, AppRoutes.login);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        flexibleSpace: Container(color: const Color(0xFF0A0A12)),
        title: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                'assets/tooth icon.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'ISDR ',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: '2026',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF60A5FA),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Indian Division  •  IADR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              int unreadCount = 0;
              if (state is NotificationLoaded) {
                unreadCount = state.unreadCount;
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.read<NotificationBloc>().add(
                      const LoadUnreadCount(),
                    );
                  }
                });
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Builder(
            builder: (context) {
              final authState = context.watch<AuthBloc>().state;
              final photo = authState is AuthAuthenticated
                  ? (authState.user.profilePic ?? '')
                  : '';
              final name = authState is AuthAuthenticated
                  ? authState.user.name
                  : '';
              return Padding(
                padding: const EdgeInsets.only(right: 12, left: 2),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfilePage()),
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    backgroundImage: photo.isNotEmpty
                        ? CachedNetworkImageProvider(photo)
                        : null,
                    child: photo.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner sits in front of the blue fade — no gap between them.
            // Image banner swiping — commented out.
            // Stack(
            //   children: [
            //     Container(
            //       height: 140,
            //       decoration: const BoxDecoration(
            //         gradient: LinearGradient(
            //           begin: Alignment.topCenter,
            //           end: Alignment.bottomCenter,
            //           colors: [
            //             Color(0xFF60A5FA),
            //             Color(0x0060A5FA),
            //           ],
            //         ),
            //       ),
            //     ),
            //     Padding(
            //       padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            //       child: Container(
            //         decoration: BoxDecoration(
            //           borderRadius: BorderRadius.circular(20),
            //           boxShadow: [
            //             BoxShadow(
            //               color: Colors.black.withValues(alpha: 0.15),
            //               blurRadius: 12,
            //               offset: const Offset(0, 6),
            //             ),
            //           ],
            //         ),
            //         child: const ClipRRect(
            //           borderRadius: BorderRadius.all(Radius.circular(20)),
            //           child: AutoScrollBanner(items: defaultManagementBanners),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            // Live Show Hero Banner Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildLiveShowBanner(),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _NewsTickerStrap(
                text:
                    'Welcome to ISDR 2026 — 36th International Conference  •  IADR Indian Division  •  Register your sessions and claim your inclusions on time  •  ',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // =================================================================
                  // 2. PARTICIPANT MODULES (4-column flat icon grid in a boxed panel)
                  // =================================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: _buildModuleGrid(_allModuleItems),
                  ),
                  const SizedBox(height: 20),

                  // Next Session + Today's Schedule (day tabs + list)
                  _buildNextSessionCard(),
                  const SizedBox(height: 20),
                  _buildScheduleSection(),
                  const SizedBox(height: 20),

                  // =================================================================
                  // 3. ACCOMMODATION SECTION
                  // =================================================================
                  _buildAccommodationHeader(),
                  const SizedBox(height: 10),
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
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    final items = <_BottomNavItem>[
      _BottomNavItem(label: 'Home', icon: Icons.home_rounded, onTap: () {}),
      _BottomNavItem(
        label: 'Favorites',
        icon: Icons.favorite_rounded,
        onTap: () => _dummyTap('Favorites'),
      ),
      _BottomNavItem(
        label: 'Speaker',
        icon: Icons.groups_rounded,
        onTap: () => _dummyTap('Speaker'),
      ),
      _BottomNavItem(
        label: 'QR Pass',
        icon: Icons.qr_code_rounded,
        onTap: () => _onTileTap('Profile'),
      ),
      _BottomNavItem(
        label: 'More',
        icon: Icons.grid_view_rounded,
        onTap: _openMoreModules,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavTile(item: items[i], active: i == 0),
                ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Facebook — real logos fetched live from an icon CDN (icons8)
            _buildSocialIconItem(
              label: 'Facebook',
              imageUrl: 'https://img.icons8.com/color/96/facebook-new.png',
              fallbackIcon: Icons.facebook_rounded,
              textIcon: 'f',
              fontSize: 17,
              isBold: true,
              color: const Color(0xFF1877F2),
              onTap: () =>
                  _launchSocialUrl('https://www.facebook.com/sbdch.dental'),
            ),
            _buildSocialDivider(),

            // Instagram
            _buildSocialIconItem(
              label: 'Instagram',
              imageUrl: 'https://img.icons8.com/color/96/instagram-new.png',
              fallbackIcon: Icons.camera_alt_rounded,
              color: const Color(0xFFE1306C),
              onTap: () =>
                  _launchSocialUrl('https://www.instagram.com/sbdch_dental/'),
            ),
            _buildSocialDivider(),

            // YouTube
            _buildSocialIconItem(
              label: 'YouTube',
              imageUrl: 'https://img.icons8.com/color/96/youtube-play.png',
              fallbackIcon: Icons.play_circle_fill_rounded,
              color: const Color(0xFFFF0000),
              onTap: () => _launchSocialUrl(
                'https://www.youtube.com/@TheDental-Classroom',
              ),
            ),
            _buildSocialDivider(),

            // X (Twitter)
            _buildSocialIconItem(
              label: 'X (Twitter)',
              imageUrl: 'https://img.icons8.com/color/96/twitterx.png',
              fallbackIcon: Icons.close_rounded,
              textIcon: '𝕏',
              fontSize: 15,
              isBold: true,
              color: Colors.black,
              onTap: () => _launchSocialUrl('https://x.com/sbdch_dental'),
            ),
            _buildSocialDivider(),

            // LinkedIn
            _buildSocialIconItem(
              label: 'LinkedIn',
              imageUrl: 'https://img.icons8.com/color/96/linkedin.png',
              fallbackIcon: Icons.business_center_rounded,
              textIcon: 'in',
              fontSize: 15,
              isBold: true,
              color: const Color(0xFF0A66C2),
              onTap: () => _launchSocialUrl(
                'https://www.linkedin.com/school/sree-balaji-dental-college-and-hospital/?originalSubdomain=in',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Container(width: 1, height: 18, color: const Color(0xFFCBD5E1));
  }

  Widget _buildSocialIconItem({
    required String label,
    required Color color,
    IconData? icon,
    String? textIcon,
    String? imageUrl,
    IconData? fallbackIcon,
    double fontSize = 14,
    bool isBold = false,
    required VoidCallback onTap,
  }) {
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
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 21,
                      height: 21,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        fallbackIcon ?? Icons.link_rounded,
                        size: 19,
                        color: color,
                      ),
                    )
                  : icon != null
                  ? Icon(icon, size: 19, color: color)
                  : Text(
                      textIcon!,
                      style: GoogleFonts.outfit(
                        fontSize: fontSize,
                        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                        color: color,
                        height: 1.1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header for the Accommodation section: bed icon + title, a divider line,
  /// then a "More" link.
  Widget _buildAccommodationHeader() {
    return Row(
      children: [
        Icon(
          Icons.bed_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 8),
        Text(
          'ACCOMMODATION & SERVICES',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _onTileTap('Accommodation'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'More',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _MgmtColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: _MgmtColors.primaryBlue,
              ),
            ],
          ),
        ),
      ],
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
      final hall = schedule['hall']?.toString() ?? '';

      return Column(
        children: [
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < 100 || _todayItems.length < 2) return;
              setState(() {
                _cycleIndex = velocity < 0
                    ? (_cycleIndex + 1) % _todayItems.length
                    : (_cycleIndex - 1 + _todayItems.length) %
                          _todayItems.length;
              });
            },
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Real auditorium/stage photo as the card background.
                  Positioned.fill(
                    child: Image.asset(
                      'assets/live banner-clean.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dark gradient overlay so the text stays readable.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF0A0E1A).withValues(alpha: 0.92),
                            const Color(0xFF0A0E1A).withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
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
                        padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isLive
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLive)
                                    const _GlowingDot(color: Colors.white)
                                  else
                                    const Icon(
                                      Icons.campaign_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLive ? 'LIVE NOW' : 'Next Session',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scheduleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            if (speakerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 16,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      right: speakerPhoto.isNotEmpty ? 52 : 0,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          speakerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (speakerPhoto.isNotEmpty)
                                      Positioned(
                                        right: 0,
                                        top: -14,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Image.network(
                                            speakerPhoto,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            if (fromTime.isNotEmpty || hall.isNotEmpty)
                              Row(
                                children: [
                                  if (fromTime.isNotEmpty &&
                                      toTime.isNotEmpty) ...[
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (hall.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        hall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View Details',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_todayItems.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_todayItems.length, (i) {
                final active = i == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF60A5FA)
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
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

  static const List<Color> _scheduleAccents = [
    Color(0xFF14B8A6),
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
  ];

  /// "Next Session" — the single closest program that hasn't started yet,
  /// shown as a standalone card above the day-by-day schedule list.
  Widget _buildNextSessionCard() {
    final item = _nextSessionItem;
    if (item == null) return const SizedBox.shrink();
    final schedule = item['schedule'] as Map<String, dynamic>;
    final event = item['event'] as Map<String, dynamic>;
    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final speakerName = schedule['speakerName']?.toString() ?? '';
    final speakerPhoto = schedule['speakerPhoto']?.toString() ?? '';
    final fromTime = schedule['fromTime']?.toString() ?? '';
    final toTime = schedule['toTime']?.toString() ?? '';
    final hall = schedule['hall']?.toString() ?? '';
    const accent = Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF14141F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ScheduleDetailPage(schedule: schedule, event: event),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 20, 40, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: speakerPhoto.isNotEmpty
                            ? Image.network(
                                speakerPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: accent,
                                ),
                              )
                            : const Icon(Icons.person_rounded, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    scheduleName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ],
                            ),
                            if (speakerName.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '|  $speakerName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (fromTime.isNotEmpty &&
                                    toTime.isNotEmpty) ...[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                ],
                                if (hall.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      hall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Small notification icon tucked into the card's bottom-right corner.
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          // "Next Session" label overlapping the card's top-left corner.
          Positioned(
            left: 12,
            top: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A33),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Next Session',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Today's Schedule" — day tabs (Day 1, Day 2, ...) with a full list of
  /// that day's programs below, each row tagged Live or Upcoming.
  Widget _buildScheduleSection() {
    final dates = _scheduleDates;
    if (dates.isEmpty) return const SizedBox.shrink();
    final selected =
        _selectedScheduleDate != null && dates.contains(_selectedScheduleDate)
        ? _selectedScheduleDate!
        : dates.first;
    final items = _itemsForDate(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Today's Schedule",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _onTileTap('Upcoming Events'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < dates.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (_) {
                    final d = dates[i];
                    final active = d == selected;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedScheduleDate = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF0D2B28)
                              : const Color(0xFF14141F),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF2DD4BF)
                                : Colors.white.withValues(alpha: 0.08),
                            width: active ? 1.4 : 1,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2DD4BF,
                                    ).withValues(alpha: 0.55),
                                    blurRadius: 14,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Day ${i + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF2DD4BF)
                                    : Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              DateFormat('MMM d').format(d),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: active
                                    ? const Color(0xFF2DD4BF)
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No sessions on this day',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ...List.generate(items.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _scheduleListRow(
                items[i],
                _scheduleAccents[i % _scheduleAccents.length],
              ),
            );
          }),
        const SizedBox(height: 4),
        _buildCmeCreditsBanner(),
      ],
    );
  }

  /// CE/CME Credits banner — a plain teal gradient card and a "View Progress"
  /// button, no decorative tooth artwork.
  Widget _buildCmeCreditsBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D3A), Color(0xFF115E59)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CE/CME credit tracking is coming soon'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF5EEAD4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CE/CME Credits',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Earn credits by attending sessions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Progress',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF115E59),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Color(0xFF115E59),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleListRow(Map<String, dynamic> item, Color accent) {
    final schedule = item['schedule'] as Map<String, dynamic>;
    final event = item['event'] as Map<String, dynamic>;
    final start = item['start'] as DateTime;
    final end = item['end'] as DateTime;
    final now = DateTime.now();
    final isLive = !now.isBefore(start) && now.isBefore(end);
    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final fromTime = schedule['fromTime']?.toString() ?? '';
    final toTime = schedule['toTime']?.toString() ?? '';
    final hall = schedule['hall']?.toString() ?? '';
    final rowAccent = isLive ? const Color(0xFF22C55E) : accent;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14141F),
            border: Border.all(color: rowAccent.withValues(alpha: 0.4)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: rowAccent),
                Expanded(
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
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: rowAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: rowAccent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (fromTime.isNotEmpty && toTime.isNotEmpty)
                                    Text(
                                      '${_fmtTimeStr(fromTime)} - ${_fmtTimeStr(toTime)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    scheduleName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (hall.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          hall,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white.withValues(
                                              alpha: 0.45,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: rowAccent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isLive ? 'Live' : 'Upcoming',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: rowAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF0F2B66)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative soft swoosh, evoking a room-photo backdrop without a real asset.
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onTileTap('Accommodation'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.bed_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Accommodation',
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Book your stay & explore services',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _MgmtColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4-column flat icon-badge grid — colored icon square + label, no card.
  /// Lays out modules in a 6-column, 2-row grid (12 slots). If there are
  /// more items than that, the last slot becomes a "More" tile that opens a
  /// sheet with everything that didn't fit — so the row count stays fixed
  /// regardless of how many modules are added.
  Widget _buildModuleGrid(List<_ParticipantModuleItem> items) {
    const crossAxisCount = 6;
    const maxSlots = crossAxisCount * 2;
    // "More" always takes the last slot, however many modules fit before it.
    const maxRealSlots = maxSlots - 1;

    final shown = items.length > maxRealSlots
        ? items.sublist(0, maxRealSlots)
        : items;
    final overflow = items.length > maxRealSlots
        ? items.sublist(maxRealSlots)
        : <_ParticipantModuleItem>[];

    final visible = [
      ...shown,
      _ParticipantModuleItem(
        label: 'More',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF64748B),
        onTap: () => _showMoreModules(overflow),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final item = visible[index];
        return _ManagementTileWidget(item: item);
      },
    );
  }
}

class _ParticipantModuleItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ParticipantModuleItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ModuleSheetItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleSheetItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Bottom sheet listing a handful of module shortcuts — used for the
/// combined "Inclusion" picker and the "More" overflow menu.
class _ModuleSheet extends StatelessWidget {
  final String title;
  final List<_ModuleSheetItem> items;

  const _ModuleSheet({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14141F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: item.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon, size: 19, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
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
      ),
    );
  }
}

/// Full page listing every module that didn't fit in the grid, plus Settings.
class _MoreModulesPage extends StatelessWidget {
  final List<_ModuleSheetItem> items;

  const _MoreModulesPage({required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(context);
              item.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.icon, size: 19, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
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
          );
        },
      ),
    );
  }
}

/// Participant settings — currently just Logout.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'Settings',
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

class _BottomNavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _BottomNavTile extends StatelessWidget {
  final _BottomNavItem item;
  final bool active;

  const _BottomNavTile({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF3B82F6)
        : Colors.white.withValues(alpha: 0.45);
    return InkWell(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 2,
            width: active ? 22 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(item.icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
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

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: item.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.15,
                ),
              ),
            ),
          ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 34,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: _MgmtColors.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
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

class _GlowingDotState extends State<_GlowingDot>
    with SingleTickerProviderStateMixin {
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
          _on
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: 18,
          color: _on ? widget.activeColor : widget.inactiveColor,
        ),
      ),
    );
  }
}
