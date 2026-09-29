import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
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
import 'all_sessions_page.dart';
import 'participant_profile_page.dart';
import 'participant_feed_page.dart';
import 'favorites_page.dart';
import '../widgets/news_ticker_strap.dart';
import '../widgets/youtube_live_capsule.dart';
import '../../../admin/presentation/pages/brochure_page.dart';
import '../../../../core/widgets/get_live_photo_button.dart';
import 'speakers_page.dart';
import 'upcoming_schedules_page.dart';
import 'participant_qa_page.dart';
import 'participant_polls_page.dart';
import 'participant_exhibitors_page.dart';
import '../../../certificate/presentation/pages/participant_certificate_page.dart';
import '../../../support/presentation/pages/help_tickets_page.dart';
import '../../../admin/presentation/widgets/auto_scroll_banner.dart'
    show AutoScrollBanner, BannerItem;

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
  // admin banner. Picking a day tab jumps straight to that day's list.
  final List<Map<String, dynamic>> _upcomingQueue = [];
  DateTime? _selectedScheduleDate;

  // Every schedule (past ones too) and the event's own days, for the fixed
  // Day 1, Day 2, ... tabs — those never shift as days pass.
  final List<Map<String, dynamic>> _allItems = [];
  final List<DateTime> _eventDayList = [];

  // The day's list shows 3 sessions; "More" rolls down the rest.
  static const _daySessionsShown = 3;
  bool _showAllDaySessions = false;

  // The admin's image banner (Admin → Banner), shown where the Next Session
  // card was; empty when switched off.
  List<String> _bannerUrls = [];

  Future<void> _loadBanner() async {
    final res = await _api.getHomeBanner();
    if (!mounted || res['success'] != true || res['banner'] is! Map) return;
    final banner = Map<String, dynamic>.from(res['banner'] as Map);
    final urls = banner['enabled'] == false
        ? <String>[]
        : ((banner['images'] as List?) ?? const [])
              .map((i) => (i as Map)['url']?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList();
    if (urls.join() == _bannerUrls.join()) return;
    setState(() => _bannerUrls = urls);
  }

  // Upcoming schedules with a reminder: scheduleId -> minutes before the start
  // (0 = at the start).
  final Map<String, int> _reminders = {};

  /// Reminder choices, in minutes before the session starts.
  static const _reminderChoices = [0, 5, 10, 15, 30, 60];

  static String _reminderLabel(int minutes) => minutes == 0
      ? 'At session start'
      : minutes == 60
      ? '1 hour before'
      : '$minutes min before';

  Future<void> _loadReminders() async {
    final res = await _api.getMyReminders();
    if (!mounted || res['success'] != true) return;
    setState(() {
      _reminders.clear();
      final map = res['reminders'];
      if (map is Map) {
        map.forEach(
          (k, v) => _reminders[k.toString()] = (v as num?)?.toInt() ?? 0,
        );
      } else {
        for (final id in (res['scheduleIds'] as List?) ?? const []) {
          _reminders[id.toString()] = 0;
        }
      }
    });
  }

  /// Asks when to be reminded (or to turn it off), then saves it.
  Future<void> _pickReminder(
    String scheduleId,
    String scheduleName,
    DateTime start,
  ) async {
    final current = _reminders[scheduleId];
    // -1 = turn off.
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remind me',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  scheduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            for (final minutes in _reminderChoices)
              Builder(
                builder: (_) {
                  // Choices whose time has already passed can't be picked.
                  final open = start
                      .subtract(Duration(minutes: minutes))
                      .isAfter(DateTime.now());
                  final selected = current == minutes;
                  return ListTile(
                    enabled: open,
                    onTap: () => Navigator.pop(ctx, minutes),
                    leading: Icon(
                      minutes == 0
                          ? Icons.play_circle_outline_rounded
                          : Icons.schedule_rounded,
                      color: open
                          ? const Color(0xFF60A5FA)
                          : Colors.white.withValues(alpha: 0.25),
                    ),
                    title: Text(
                      _reminderLabel(minutes),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: open
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF22C55E),
                          )
                        : null,
                  );
                },
              ),
            if (current != null)
              ListTile(
                onTap: () => Navigator.pop(ctx, -1),
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  color: Color(0xFFF87171),
                ),
                title: Text(
                  'Turn off reminder',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF87171),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final minutes = picked < 0 ? null : picked;
    if (minutes == current) return;

    setState(() {
      minutes == null
          ? _reminders.remove(scheduleId)
          : _reminders[scheduleId] = minutes;
    });
    final res = await _api.setScheduleReminder(scheduleId, minutes);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (res['success'] != true) {
      setState(() {
        current == null
            ? _reminders.remove(scheduleId)
            : _reminders[scheduleId] = current;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not update')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          minutes == null
              ? 'Reminder off'
              : minutes == 0
              ? 'Reminder set — we\'ll notify you when "$scheduleName" starts'
              : 'Reminder set — ${_reminderLabel(minutes)} "$scheduleName"',
        ),
      ),
    );
  }

  // Ids of the schedules this participant marked hot (saved on their account).
  final Set<String> _favoriteIds = {};

  Future<void> _loadFavorites() async {
    final res = await _api.getMyFavorites();
    if (!mounted || res['success'] != true) return;
    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(
          ((res['scheduleIds'] as List?) ?? const []).map((e) => e.toString()),
        );
    });
  }

  /// Flips the hot button right away, then syncs with the server (and flips back
  /// if the request fails).
  Future<void> _toggleFavorite(String scheduleId) async {
    final wasFavorite = _favoriteIds.contains(scheduleId);
    setState(() {
      wasFavorite
          ? _favoriteIds.remove(scheduleId)
          : _favoriteIds.add(scheduleId);
    });
    final res = await _api.toggleFavoriteSchedule(scheduleId);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        wasFavorite
            ? _favoriteIds.add(scheduleId)
            : _favoriteIds.remove(scheduleId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not update')),
      );
    }
  }

  void _openSchedules() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpcomingSchedulesPage()),
    );
  }

  void _openSpeakers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpeakersPage()),
    );
  }

  Future<void> _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
    // Hot marks may have been removed on the Favorites page.
    _loadFavorites();
  }

  /// The event's days, in order (Day 1 = the event's first day). Falls back to
  /// the days that have schedules if the event has no dates.
  List<DateTime> get _scheduleDates {
    if (_eventDayList.isNotEmpty) return _eventDayList;
    final seen = <DateTime>{
      for (final item in _allItems)
        DateTime(
          (item['start'] as DateTime).year,
          (item['start'] as DateTime).month,
          (item['start'] as DateTime).day,
        ),
    };
    return seen.toList()..sort();
  }

  /// Each calendar day from the event's start date to its end date.
  static List<DateTime> _daysOfEvent(Map<String, dynamic> event) {
    final start = DateTime.tryParse(
      event['eventDate']?.toString() ?? '',
    )?.toLocal();
    if (start == null) return const [];
    final end =
        DateTime.tryParse(event['eventEndDate']?.toString() ?? '')?.toLocal() ??
        start;
    final days = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last) && days.length < 60) {
      days.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return days;
  }

  /// Every schedule item on one calendar day (finished ones too), sorted by
  /// start time.
  List<Map<String, dynamic>> _itemsForDate(DateTime date) {
    final items = _allItems.where((item) {
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

  @override
  void initState() {
    super.initState();
    _fetchLiveSchedule();
    _loadFavorites();
    _loadReminders();
    _loadBanner();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _fetchLiveSchedule();
      _loadBanner(); // picks up the admin switching it on/off
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

  /// The event this participant is registered for (loaded once).
  String? _myEventId;

  Future<void> _fetchLiveSchedule() async {
    try {
      // Only the participant's own event counts — the events list holds every
      // event on the property, and mixing them adds other events' days/sessions.
      if (_myEventId == null) {
        final regRes = await _api.getMyRegistration();
        if (regRes['success'] != true || regRes['registration'] is! Map) return;
        final id =
            (regRes['registration'] as Map)['eventId']?.toString() ?? '';
        if (id.isEmpty) return;
        _myEventId = id;
      }
      final eventsRes = await _api.listManagedEvents();
      if (eventsRes['success'] != true) return;
      final events = List<Map<String, dynamic>>.from(
        (eventsRes['events'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e as Map),
            ) ??
            [],
      ).where((e) => (e['id'] ?? e['_id'])?.toString() == _myEventId).toList();
      if (events.isEmpty) return;

      final now = DateTime.now();
      Map<String, dynamic>? liveEv;
      Map<String, dynamic>? nextUpcomingEv;
      DateTime? earliestUpcomingTime;
      final todayList = <Map<String, dynamic>>[];
      final upcomingList = <Map<String, dynamic>>[];
      final allList = <Map<String, dynamic>>[];
      final eventDays = <DateTime>{};

      for (final event in events) {
        final eventId =
            event['id']?.toString() ?? event['_id']?.toString() ?? '';
        if (eventId.isEmpty) continue;
        eventDays.addAll(_daysOfEvent(event));
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

          allList.add({
            'schedule': s,
            'event': event,
            'start': start,
            'end': end,
          });

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
          _allItems
            ..clear()
            ..addAll(allList);
          _eventDayList
            ..clear()
            ..addAll(eventDays.toList()..sort());
          final dates = _scheduleDates;
          final stillValid =
              _selectedScheduleDate != null &&
              dates.any((d) => d == _selectedScheduleDate);
          if (!stillValid) {
            // Open on today during the event; on other dates no day is
            // selected until the participant taps one.
            final today = DateTime(now.year, now.month, now.day);
            _selectedScheduleDate = dates.contains(today) ? today : null;
          }
        });
      }
    } catch (_) {}
  }

  /// The full, ordered list of Participant Module tiles — shared by the grid
  /// and the bottom nav's "More" tab so both stay in sync.
  List<_ParticipantModuleItem> get _allModuleItems => [
    _ParticipantModuleItem(
      label: 'Schedule',
      icon: Icons.event_note_rounded,
      color: const Color(0xFFF97316),
      onTap: _openSchedules,
    ),
    _ParticipantModuleItem(
      label: 'Feed',
      icon: Icons.dynamic_feed_rounded,
      color: const Color(0xFFEC4899),
      onTap: () => _onTileTap('Feed'),
    ),
    _ParticipantModuleItem(
      label: 'Committee',
      icon: Icons.account_balance_rounded,
      color: const Color(0xFFA855F7),
      onTap: () => _onTileTap('Organizational Committee'),
    ),
    _ParticipantModuleItem(
      label: 'Favorites',
      icon: Icons.star_rounded,
      color: const Color(0xFFE11D48),
      onTap: _openFavorites,
    ),
    _ParticipantModuleItem(
      label: 'Brochure',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF10B981),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BrochurePage()),
      ),
    ),
    _ParticipantModuleItem(
      label: 'Help &\nSupport',
      icon: Icons.help_rounded,
      color: const Color(0xFF06B6D4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HelpTicketsPage(isParticipant: true),
        ),
      ),
    ),
    _ParticipantModuleItem(
      label: 'Certificate',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFFF59E0B),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantCertificatePage()),
      ),
    ),
    _ParticipantModuleItem(
      label: 'Exhibitors',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFEF4444),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantExhibitorsPage()),
      ),
    ),
    _ParticipantModuleItem(
      label: 'Q/A',
      icon: Icons.question_answer_rounded,
      color: const Color(0xFF3B82F6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantQaPage()),
      ),
    ),
    _ParticipantModuleItem(
      label: 'Polls',
      icon: Icons.poll_rounded,
      color: const Color(0xFF8B5CF6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantPollsPage()),
      ),
    ),
    _ParticipantModuleItem(
      label: 'About',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF6366F1),
      onTap: () => _onTileTap('About ISDR'),
    ),
    _ParticipantModuleItem(
      label: 'Conference',
      icon: Icons.school_rounded,
      color: const Color(0xFF2563EB),
      onTap: () => _onTileTap('Student Conference'),
    ),
    _ParticipantModuleItem(
      label: 'Accommodation',
      icon: Icons.hotel_rounded,
      color: const Color(0xFF0EA5E9),
      onTap: () => _onTileTap('Accommodation'),
    ),
    _ParticipantModuleItem(
      label: 'Awards',
      icon: Icons.emoji_events_rounded,
      color: const Color(0xFFF59E0B),
      onTap: () => _onTileTap('Awards'),
    ),
  ];

  /// Opens the same "More" overflow page the module grid's own More tile
  /// opens — whatever didn't fit in the grid's fixed 2 rows (11 slots).
  void _openMoreModules() {
    const crossAxisCount = 6;
    const maxRealSlots = crossAxisCount * 2 - 1;
    final items = _allModuleItems;
    final overflow = items.length > maxRealSlots
        ? items.sublist(maxRealSlots)
        : <_ParticipantModuleItem>[];
    _showMoreModules(overflow);
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
          ],
        ),
      ),
    );
  }

  void _onTileTap(String title) {
    final lower = title.toLowerCase().trim();
    if (lower == 'qr pass') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyProfilePage()),
      );
      return;
    }
    if (lower == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParticipantProfilePage()),
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
              width: 58,
              height: 58,
              child: Image.asset(
                'assets/ISDR 2026 Logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 24,
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
                    MaterialPageRoute(
                      builder: (_) => const ParticipantProfilePage(),
                    ),
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
              child: AdminNewsTicker(),
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
                      horizontal: 2,
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

                  // YouTube live capsule, admin banner + Today's Schedule (day tabs + list)
                  const YoutubeLiveCapsule(),
                  _buildAdminBanner(),
                  const SizedBox(height: 20),
                  _buildScheduleSection(),
                  const SizedBox(height: 20),

                  // =================================================================
                  // 3. ACCOMMODATION SECTION
                  // =================================================================
                  _buildAccommodationHeader(),
                  const SizedBox(height: 10),
                  _buildAccommodationBanner(),
                  const SizedBox(height: 12),
                  const GetLivePhotoButton(),
                  const SizedBox(height: 12),

                  // =================================================================
                  // 4. SOCIAL MEDIA LINKS (Follow us chips)
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
        onTap: _openFavorites,
      ),
      _BottomNavItem(
        label: 'Speaker',
        icon: Icons.groups_rounded,
        onTap: _openSpeakers,
      ),
      _BottomNavItem(
        label: 'QR Pass',
        icon: Icons.qr_code_rounded,
        onTap: () => _onTileTap('qr pass'),
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
    // Real logos fetched live from an icon CDN (icons8).
    final links = <_SocialLink>[
      const _SocialLink(
        'Facebook',
        'https://img.icons8.com/color/96/facebook-new.png',
        Icons.facebook_rounded,
        Color(0xFF1877F2),
        'https://www.facebook.com/sbdch.dental',
      ),
      const _SocialLink(
        'Instagram',
        'https://img.icons8.com/color/96/instagram-new.png',
        Icons.camera_alt_rounded,
        Color(0xFFE1306C),
        'https://www.instagram.com/sbdch_dental/',
      ),
      const _SocialLink(
        'YouTube',
        'https://img.icons8.com/color/96/youtube-play.png',
        Icons.play_circle_fill_rounded,
        Color(0xFFFF0000),
        'https://www.youtube.com/@TheDental-Classroom',
      ),
      const _SocialLink(
        'X',
        'https://img.icons8.com/color/96/twitterx.png',
        Icons.close_rounded,
        Colors.black,
        'https://x.com/sbdch_dental',
      ),
      const _SocialLink(
        'LinkedIn',
        'https://img.icons8.com/color/96/linkedin.png',
        Icons.business_center_rounded,
        Color(0xFF0A66C2),
        'https://www.linkedin.com/school/sree-balaji-dental-college-and-hospital/?originalSubdomain=in',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOLLOW US',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < links.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _buildSocialChip(links[i]),
            ],
          ],
        ),
      ],
    );
  }

  /// One network: its logo on a small white circle inside a dark round chip.
  Widget _buildSocialChip(_SocialLink link) {
    return Material(
      color: const Color(0xFF14141F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _launchSocialUrl(link.url),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.network(
              link.imageUrl,
              fit: BoxFit.contain,
              semanticLabel: link.label,
              errorBuilder: (_, __, ___) =>
                  Icon(link.fallbackIcon, size: 17, color: link.color),
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

  /// The admin's images (Admin → Banner), scrolling to the next one
  /// automatically. Hidden when switched off or empty.
  Widget _buildAdminBanner() {
    if (_bannerUrls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AutoScrollBanner(
          key: ValueKey(_bannerUrls.join()),
          height: 160,
          items: [for (final url in _bannerUrls) BannerItem(imageUrl: url)],
        ),
      ),
    );
  }

  /// "Today's Schedule" — the event's day tabs (Day 1, Day 2, ...) with a full
  /// list of that day's programs below, each tagged Live, Upcoming or Completed.
  Widget _buildScheduleSection() {
    final dates = _scheduleDates;
    if (dates.isEmpty) return const SizedBox.shrink();
    final selected =
        _selectedScheduleDate != null && dates.contains(_selectedScheduleDate)
        ? _selectedScheduleDate
        : null;
    final items = selected == null
        ? const <Map<String, dynamic>>[]
        : _itemsForDate(selected);

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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllSessionsPage(
                    items: List.of(_allItems),
                    days: _scheduleDates,
                    initialDay: _selectedScheduleDate,
                  ),
                ),
              ),
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
        // Tabs share the width when they fit; with many days they keep a
        // minimum width and the row scrolls sideways.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final fitted =
                (constraints.maxWidth - gap * (dates.length - 1)) /
                dates.length;
            final tileWidth = fitted < 64 ? 64.0 : fitted;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < dates.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: tileWidth,
                      child: Builder(
                        builder: (_) {
                          final d = dates[i];
                          final active = d == selected;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedScheduleDate = d;
                              _showAllDaySessions = false;
                            }),
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
            );
          },
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              selected == null
                  ? 'Tap a day to see its sessions'
                  : 'No sessions on this day',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          )
        else ...[
          ...List.generate(
            items.length < _daySessionsShown ? items.length : _daySessionsShown,
            (i) => _daySessionRow(items, i),
          ),
          // Extra sessions roll down below the first three.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showAllDaySessions && items.length > _daySessionsShown
                ? Column(
                    children: [
                      for (var i = _daySessionsShown; i < items.length; i++)
                        _daySessionRow(items, i),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (items.length > _daySessionsShown)
            _moreSessionsButton(items.length - _daySessionsShown),
        ],
        const SizedBox(height: 4),
        _buildCmeCreditsBanner(),
      ],
    );
  }

  Widget _daySessionRow(List<Map<String, dynamic>> items, int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _scheduleListRow(
        items[i],
        _scheduleAccents[i % _scheduleAccents.length],
      ),
    );
  }

  /// "More (n)" / "Show less" toggle under the day's first three sessions.
  Widget _moreSessionsButton(int extra) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              setState(() => _showAllDaySessions = !_showAllDaySessions),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14141F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAllDaySessions ? 'Show less' : 'More ($extra)',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF60A5FA),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showAllDaySessions ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Color(0xFF60A5FA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParticipantCertificatePage(),
            ),
          ),
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
    final isDone = !now.isBefore(end);
    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final fromTime = schedule['fromTime']?.toString() ?? '';
    final toTime = schedule['toTime']?.toString() ?? '';
    final hall = schedule['hall']?.toString() ?? '';
    final rowAccent = isLive
        ? const Color(0xFF22C55E)
        : isDone
        ? const Color(0xFF64748B)
        : accent;
    final scheduleId = schedule['id']?.toString() ?? '';
    final isFavorite = _favoriteIds.contains(scheduleId);

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
                                isLive
                                    ? 'Live'
                                    : isDone
                                    ? 'Completed'
                                    : 'Upcoming',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: rowAccent,
                                ),
                              ),
                            ),
                            // Remind me when it starts (upcoming sessions only).
                            if (scheduleId.isNotEmpty && !isLive && !isDone)
                              IconButton(
                                tooltip: _reminders.containsKey(scheduleId)
                                    ? 'Reminder: ${_reminderLabel(_reminders[scheduleId]!)}'
                                    : 'Remind me',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.only(left: 6),
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                onPressed: () => _pickReminder(
                                  scheduleId,
                                  scheduleName,
                                  start,
                                ),
                                icon: Icon(
                                  _reminders.containsKey(scheduleId)
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_none_rounded,
                                  size: 22,
                                  color: _reminders.containsKey(scheduleId)
                                      ? const Color(0xFFFBBF24)
                                      : Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            if (scheduleId.isNotEmpty)
                              IconButton(
                                tooltip: isFavorite
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.only(left: 6),
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                onPressed: () => _toggleFavorite(scheduleId),
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 22,
                                  color: isFavorite
                                      ? const Color(0xFFEF4444)
                                      : Colors.white.withValues(alpha: 0.45),
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

  /// 6-column flat icon-badge grid — strictly 2 rows (12 slots).
  /// If items exceed 11 slots, the 12th slot becomes "More" and all exceeding
  /// modules go inside "More" so it never creates a 3rd row.
  Widget _buildModuleGrid(List<_ParticipantModuleItem> items) {
    const crossAxisCount = 6;
    const maxSlots = crossAxisCount * 2; // 12 slots (strictly 2 rows)
    const maxRealSlots = maxSlots - 1; // 11 module slots + 1 "More" slot

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

/// Full page listing every module that didn't fit in the grid.
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
      // Boxed grid, 4 per row (same look as the home's module grid).
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14141F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 2,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.icon, size: 22, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.label.replaceAll('\n', ' '),
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
                    ],
                  ),
                );
              },
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
    final isMultiLine = item.label.contains('\n');

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 21, color: Colors.white),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: isMultiLine ? 2 : 1,
                    softWrap: isMultiLine,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
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

/// A social network link on the home page's "Follow us" row.
class _SocialLink {
  final String label;
  final String imageUrl;
  final IconData fallbackIcon;
  final Color color;
  final String url;

  const _SocialLink(
    this.label,
    this.imageUrl,
    this.fallbackIcon,
    this.color,
    this.url,
  );
}
