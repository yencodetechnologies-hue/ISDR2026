import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../participant/presentation/widgets/live_show_card.dart';
import '../../../../participant/presentation/widgets/news_ticker_strap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../core/models/ad_model.dart';
import '../../../../../../core/models/apartment_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/routes/app_routes.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/utils/current_property_context.dart';
import 'create_post_sheet.dart';
import 'create_poll_sheet.dart';
import 'create_event_sheet.dart';
import 'profile_qr_sheet.dart';
import '../feed_page.dart';
import '../my_posts_page.dart';
import '../terms_and_conditions_page.dart';
import '../user_events_page.dart';
import '../../../../support/presentation/pages/help_tickets_page.dart';
import '../../../../admin/presentation/pages/qr_pass_page.dart';
import '../../../../admin/presentation/widgets/auto_scroll_banner.dart';

class HomeTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onSwitchToComplaints;
  final VoidCallback? onSwitchToProfile;
  final bool isHostel;
  final bool showLeaveRequests;
  final bool complaintsEnabled;
  final bool adsEnabled;

  const HomeTab({
    super.key,
    required this.user,
    this.isHostel = false,
    this.showLeaveRequests = false,
    this.onSwitchToComplaints,
    this.onSwitchToProfile,
    this.complaintsEnabled = true,
    this.adsEnabled = true,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  List<AdModel> _ads = [];
  bool _adsLoading = true;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    if (widget.adsEnabled) {
      _loadAds();
    } else {
      _adsLoading = false;
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAds() async {
    setState(() => _adsLoading = true);
    try {
      final response = await _apiService.getAds();
      if (mounted && response['success'] == true && response['ads'] != null) {
        setState(() {
          _ads = (response['ads'] as List)
              .map((e) => AdModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _adsLoading = false;
        });
        if (_ads.length > 1) _startCarouselTimer();
      } else {
        if (mounted) setState(() => _adsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _adsLoading = false);
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients || _ads.isEmpty) return;
      final next = (_pageController.page?.round() ?? 0) + 1;
      if (next >= _ads.length) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _navigateToComingSoon(String featureName) {
    Navigator.pushNamed(
      context,
      AppRoutes.featureComingSoon,
      arguments: {'featureName': featureName},
    );
  }

  bool get _isStaffSchoolOrCollege {
    final currentProp = resolveCurrentProperty(widget.user);
    final propType =
        currentProp?.propertyType ??
        widget.user.propertyType ??
        (widget.user.apartments != null && widget.user.apartments!.isNotEmpty
            ? widget.user.apartments!.first.propertyType
            : null);
    return false;
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostSheet(
        user: widget.user,
        onSuccess: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEventsProperty) ...[
            const AutoScrollBanner(items: defaultManagementBanners),
            const SizedBox(height: 12),
            // Same news ticker as the participant home.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: AdminNewsTicker(),
            ),
            const SizedBox(height: 12),
            // Same live-show card as the participant and speaker homes.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LiveShowCard(),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.adsEnabled) ...[
                  _buildAdsCarousel(),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    widget.isHostel ? 'Hostel Services' : 'Quick Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isEventsProperty
                          ? Colors.white
                          : AppTheme.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickOptionsGrid(),
                if (!widget.isHostel &&
                    !_isStaffSchoolOrCollege &&
                    !_isEventsProperty) ...[
                  const SizedBox(height: 24),
                  _buildFeedSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isEventsProperty {
    final currentProp = resolveCurrentProperty(widget.user);
    final propType =
        currentProp?.propertyType ??
        widget.user.propertyType ??
        (widget.user.apartments != null && widget.user.apartments!.isNotEmpty
            ? widget.user.apartments!.first.propertyType
            : null);
    return propType == PropertyType.events;
  }

  Widget _buildFeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.feed);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all posts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FeedActionCard(
                title: 'Create post',
                icon: Icons.edit_note_rounded,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => CreatePostSheet(
                      user: widget.user,
                      onSuccess: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Post created'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (!_isEventsProperty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _FeedActionCard(
                  title: 'Create poll',
                  icon: Icons.poll_rounded,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => CreatePollSheet(
                        user: widget.user,
                        onSuccess: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Poll created'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeedActionCard(
                  title: 'Host events',
                  icon: Icons.event_rounded,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => CreateEventSheet(
                        user: widget.user,
                        onSuccess: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event created'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: _FeedActionCard(
                title: 'My post',
                icon: Icons.article_rounded,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.myPosts);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showComingSoonSheet(BuildContext context, String featureName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              featureName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Coming soon'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsCarousel() {
    if (_adsLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_ads.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _ads.length,
        itemBuilder: (context, index) {
          final ad = _ads[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: ad.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickOptionsGrid() {
    const allOptions = [
      _QuickOption('Profile', Icons.person_rounded, _Action.profile),
      _QuickOption(
        'Complaints',
        Icons.report_problem_rounded,
        _Action.complaints,
      ),
      _QuickOption(
        'Hostel Help & Support',
        Icons.support_agent_rounded,
        _Action.hostelHelpDesk,
      ),
      _QuickOption(
        'Help & Support',
        Icons.support_agent_rounded,
        _Action.helpDesk,
      ),
      _QuickOption(
        '${AppConstants.appName} Services',
        Icons.miscellaneous_services_rounded,
        _Action.accessServices,
      ),
      _QuickOption(
        'Terms & Conditions',
        Icons.description_rounded,
        _Action.termsAndConditions,
      ),
      _QuickOption('Hostel ID', Icons.badge_rounded, _Action.hostelId),
      _QuickOption('Events', Icons.event_rounded, _Action.events),
      _QuickOption('History', Icons.history_rounded, _Action.history),
      _QuickOption('QR Pass', Icons.qr_code_2_rounded, _Action.qrPass),
      _QuickOption(
        'Support Tickets',
        Icons.support_agent_rounded,
        _Action.supportTickets,
      ),
      _QuickOption('Create post', Icons.edit_note_rounded, _Action.createPost),
      _QuickOption('My post', Icons.article_rounded, _Action.myPost),
    ];
    final currentProp = resolveCurrentProperty(widget.user);
    final propType =
        currentProp?.propertyType ??
        widget.user.propertyType ??
        (widget.user.apartments != null && widget.user.apartments!.isNotEmpty
            ? widget.user.apartments!.first.propertyType
            : null);
    final isStaffSchoolOrCollege = false;
    final isEventsProperty = propType == PropertyType.events;

    if (isStaffSchoolOrCollege) {
      final byAction = {for (final o in allOptions) o.action: o};
      final ordered = <_QuickOption>[
        byAction[_Action.profile]!,
        byAction[_Action.termsAndConditions]!,
        byAction[_Action.accessServices]!,
        byAction[_Action.createPost]!,
        byAction[_Action.myPost]!,
      ];
      return _buildQuickOptionsGridFor(ordered);
    }

    final options = allOptions.where((o) {
      // Events properties: Profile, Events, History, Entry / Exit Scan and
      // Support Tickets.
      if (isEventsProperty) {
        return o.action == _Action.profile ||
            o.action == _Action.events ||
            o.action == _Action.history ||
            o.action == _Action.qrPass ||
            o.action == _Action.supportTickets;
      }
      if (o.action == _Action.events ||
          o.action == _Action.history ||
          o.action == _Action.qrPass ||
          o.action == _Action.supportTickets) {
        return false;
      }
      if (o.action == _Action.createPost || o.action == _Action.myPost) {
        return false;
      }
      if (widget.isHostel && _isApartmentOnlyQuickOption(o.action)) {
        return false;
      }
      if (o.action == _Action.termsAndConditions) {
        return widget.isHostel;
      }
      if (o.action == _Action.hostelId) {
        return widget.isHostel;
      }
      if (o.action == _Action.hostelHelpDesk) {
        return widget.isHostel;
      }
      if (o.action == _Action.helpDesk) {
        return !widget.isHostel;
      }
      switch (o.action) {
        case _Action.complaints:
          return widget.complaintsEnabled;
        default:
          return true;
      }
    }).toList();

    return _buildQuickOptionsGridFor(options);
  }

  /// Colour of each module button on the event staff dashboard (same palette
  /// as the participant homepage's module grid).
  static Color _eventsTileColor(_Action action) {
    switch (action) {
      case _Action.profile:
        return const Color(0xFF6366F1);
      case _Action.events:
        return const Color(0xFFF97316);
      case _Action.history:
        return const Color(0xFF14B8A6);
      case _Action.qrPass:
        return const Color(0xFF8B5CF6);
      case _Action.supportTickets:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildQuickOptionsGridFor(List<_QuickOption> options) {
    // Event staff: the participant homepage's boxed 6-column module grid.
    if (_isEventsProperty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF14141F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final o = options[index];
            return _ModuleTile(
              title: o.title,
              icon: o.icon,
              color: _eventsTileColor(o.action),
              onTap: () => _handleQuickOptionTap(o),
            );
          },
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 4;
        const spacing = 12.0;
        final availableWidth = constraints.maxWidth;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
        final itemHeight = itemWidth * 1.3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final o = options[index];
            return _QuickOptionTile(
              title: o.title,
              icon: o.icon,
              onTap: () => _handleQuickOptionTap(o),
            );
          },
        );
      },
    );
  }

  /// Apartment / society features not shown on the hostel resident dashboard.
  static bool _isApartmentOnlyQuickOption(_Action action) {
    switch (action) {
      case _Action.accessServices:
        return true;
      default:
        return false;
    }
  }

  void _handleQuickOptionTap(_QuickOption o) {
    switch (o.action) {
      case _Action.profile:
        widget.onSwitchToProfile?.call();
        break;
      case _Action.complaints:
        widget.onSwitchToComplaints?.call();
        break;
      case _Action.hostelHelpDesk:
      case _Action.helpDesk:
        Navigator.pushNamed(
          context,
          AppRoutes.support,
          arguments: {'isHostel': o.action == _Action.hostelHelpDesk},
        );
        break;
      case _Action.accessServices:
        _navigateToComingSoon('${AppConstants.appName} Services');
        break;
      case _Action.termsAndConditions:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TermsAndConditionsPage(),
          ),
        );
        break;
      case _Action.hostelId:
        _openHostelIdSheet();
        break;
      case _Action.comingSoon:
        _navigateToComingSoon(o.title);
        break;
      case _Action.events:
        _navigateToEvents();
        break;
      case _Action.history:
        _navigateToHistory();
        break;
      case _Action.qrPass:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const QrPassPage(role: 'EVENT STAFF'),
          ),
        );
        break;
      case _Action.supportTickets:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HelpTicketsPage(isParticipant: false),
          ),
        );
        break;
      case _Action.createPost:
        _showCreatePostSheet();
        break;
      case _Action.myPost:
        Navigator.pushNamed(context, AppRoutes.myPosts);
        break;
    }
  }

  void _navigateToHistory() {
    final currentProp = resolveCurrentProperty(widget.user);
    final apartmentId = currentProp?.id ?? widget.user.apartmentId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserClaimHistoryPage(apartmentId: apartmentId),
      ),
    );
  }

  void _navigateToEvents() {
    final currentProp = resolveCurrentProperty(widget.user);
    final apartmentId = currentProp?.id ?? widget.user.apartmentId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserEventsListPage(apartmentId: apartmentId),
      ),
    );
  }

  void _openHostelIdSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileQrSheet(
        user: widget.user,
        isHostel: true,
        hostelName: _hostelNameFromUser(),
      ),
    );
  }

  String? _hostelNameFromUser() {
    final apts = widget.user.apartments;
    if (apts == null || apts.isEmpty) return null;
    for (final a in apts) {
      if (a.id == widget.user.apartmentId) return a.name;
    }
    return apts.first.name;
  }

}

enum _Action {
  qrPass,
  profile,
  complaints,
  helpDesk,
  hostelHelpDesk,
  accessServices,
  termsAndConditions,
  hostelId,
  comingSoon,
  events,
  history,
  supportTickets,
  createPost,
  myPost,
}

class _QuickOption {
  final String title;
  final IconData icon;
  final _Action action;
  const _QuickOption(this.title, this.icon, this.action);
}

/// Solid coloured icon square with a label under it, shrinking a little
/// while pressed — the participant homepage's module button.
class _ModuleTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(widget.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 24,
              child: Text(
                widget.title,
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

class _QuickOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickOptionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(icon, color: const Color(0xFF13275D), size: 24),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _FeedActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.15),
                      AppTheme.primaryColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
