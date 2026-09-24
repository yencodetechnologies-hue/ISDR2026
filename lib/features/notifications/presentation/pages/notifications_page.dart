import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/models/user_model.dart';
import '../bloc/notification_bloc.dart';
import '../widgets/notification_item.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _selectedType;
  bool? _readFilter;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(const LoadNotifications());
    context.read<NotificationBloc>().add(const LoadUnreadCount());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final state = context.read<NotificationBloc>().state;
      if (state is NotificationLoaded && state.hasMore) {
        context.read<NotificationBloc>().add(
          LoadNotifications(
            page: _currentPage + 1,
            type: _selectedType,
            read: _readFilter,
          ),
        );
        setState(() => _currentPage++);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter({String? type, bool? read}) {
    setState(() {
      _selectedType = type;
      _readFilter = read;
      _currentPage = 1;
    });
    context.read<NotificationBloc>().add(
      LoadNotifications(page: 1, type: _selectedType, read: _readFilter),
    );
  }

  /// Every logged-in role now uses the black theme.
  bool get _dark => true;

  Color get _ink => _dark ? Colors.white : const Color(0xFF0F172A);
  Color get _accent =>
      _dark ? const Color(0xFF3B82F6) : const Color(0xFF13275D);

  bool _isFilterActive(String key) {
    switch (key) {
      case 'all':
        return _selectedType == null && _readFilter == null;
      case 'unread':
        return _readFilter == false && _selectedType == null;
      case 'read':
        return _readFilter == true && _selectedType == null;
      default:
        return _selectedType == key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark
          ? const Color(0xFF0A0A12)
          : const Color(0xFFFAFAF9),
      appBar: (_dark ? buildDarkAppBar : buildBrandGradientAppBar)(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state is NotificationLoaded && state.unreadCount > 0) {
                return IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: () {
                    context.read<NotificationBloc>().add(const MarkAllAsRead());
                  },
                  tooltip: 'Mark all as read',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Builder(
            builder: (context) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.tune_rounded),
                color: _dark ? const Color(0xFF1E1E2A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  if (value == 'all') {
                    _applyFilter();
                  } else if (value == 'unread') {
                    _applyFilter(read: false);
                  } else if (value == 'read') {
                    _applyFilter(read: true);
                  } else {
                    _applyFilter(type: value);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'all', child: Text('All')),
                  const PopupMenuItem(value: 'unread', child: Text('Unread')),
                  const PopupMenuItem(value: 'read', child: Text('Read')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'message', child: Text('Message')),
                  const PopupMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                  const PopupMenuItem(
                    value: 'complaint',
                    child: Text('Complaint'),
                  ),
                  const PopupMenuItem(value: 'notice', child: Text('Notice')),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          final unreadCount = state is NotificationLoaded
              ? state.unreadCount
              : 0;

          return Column(
            children: [
              _buildSummaryHeader(unreadCount),
              _buildFilterChips(),
              Expanded(child: _buildBody(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(int unreadCount) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount > 0
                      ? '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}'
                      : 'All caught up',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unreadCount > 0
                      ? 'Tap a notification to mark it as read'
                      : 'No new alerts right now',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Text(
                '$unreadCount',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <Map<String, String>>[
      {'key': 'all', 'label': 'All'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'read', 'label': 'Read'},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final active = _isFilterActive(chip['key']!);

          return Material(
            color: active
                ? _accent
                : (_dark ? const Color(0xFF14141F) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            elevation: active ? 2 : 0,
            child: InkWell(
              onTap: () {
                final key = chip['key']!;
                if (key == 'all') {
                  _applyFilter();
                } else if (key == 'unread') {
                  _applyFilter(read: false);
                } else {
                  _applyFilter(read: true);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? _accent
                        : (_dark
                              ? const Color(0x14FFFFFF)
                              : const Color(0xFFECECEA)),
                  ),
                ),
                child: Text(
                  chip['label']!,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: active
                        ? Colors.white
                        : (_dark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state is NotificationLoading) {
      return Center(child: CircularProgressIndicator(color: _accent));
    }

    if (state is NotificationError) {
      return _buildErrorState(state.message);
    }

    if (state is NotificationLoaded) {
      if (state.notifications.isEmpty) {
        return _buildEmptyState();
      }

      final grouped = _groupNotificationsByDate(state.notifications);

      return RefreshIndicator(
        color: _accent,
        onRefresh: () async {
          context.read<NotificationBloc>().add(const RefreshNotifications());
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 20, top: 6),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final entry = grouped[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry['label'] as String,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                ...(entry['notifications'] as List<NotificationModel>).map(
                  (notification) => NotificationItem(
                    notification: notification,
                    dark: _dark,
                    onTap: () {
                      if (!notification.read) {
                        context.read<NotificationBloc>().add(
                          MarkAsRead(notification.id),
                        );
                      }
                    },
                    onDelete: () {
                      context.read<NotificationBloc>().add(
                        DeleteNotification(notification.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  List<Map<String, dynamic>> _groupNotificationsByDate(
    List<NotificationModel> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<NotificationModel>>{};

    for (final notification in notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else if (date.isAfter(weekAgo)) {
        label = 'This Week';
      } else {
        label = DateFormat('MMMM yyyy').format(notification.createdAt);
      }

      groups.putIfAbsent(label, () => []).add(notification);
    }

    return groups.entries.map((entry) {
      return {'label': entry.key, 'notifications': entry.value};
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accent.withOpacity(_dark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: _accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notifications',
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'re all caught up!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8C8C90),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<NotificationBloc>().add(const LoadNotifications());
              },
              style: AppTheme.primaryElevatedStyle,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
