import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/constants/app_constants.dart';
import '../../../../../../core/models/ad_model.dart';
import '../../../../../../core/models/apartment_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/models/visitor_model.dart';
import '../../../../../../core/routes/app_routes.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/utils/current_property_context.dart';
import '../../../../chat/presentation/pages/guard_conversations_page.dart';
import 'raise_complaint_dialog.dart';
import 'report_kid_exit_sheet.dart';
import 'create_post_sheet.dart';
import 'create_poll_sheet.dart';
import 'create_event_sheet.dart';
import 'profile_qr_sheet.dart';
import '../visitors_page.dart';
import '../feed_page.dart';
import '../my_posts_page.dart';
import '../vehicles_page.dart';
import '../family_page.dart';
import '../gate_approval_page.dart';
import '../security_list_page.dart';
import '../unit_visitor_list_page.dart';
import '../monthly_access_page.dart';
import '../terms_and_conditions_page.dart';
import '../leave_requests_page.dart';
import '../user_events_page.dart';

class HomeTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onSwitchToComplaints;
  final VoidCallback? onSwitchToProfile;
  final bool isHostel;
  final bool securityEnabled;
  final bool showLeaveRequests;
  final bool assignPaymentEnabled;
  final bool complaintsEnabled;
  final bool adsEnabled;

  const HomeTab({
    super.key,
    required this.user,
    this.isHostel = false,
    this.showLeaveRequests = false,
    this.onSwitchToComplaints,
    this.onSwitchToProfile,
    this.securityEnabled = true,
    this.assignPaymentEnabled = true,
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

  void _showRaiseComplaintDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RaiseComplaintDialog(
        userId: widget.user.id,
        initialType: null,
      ),
    );
  }

  void _navigateToVisitors() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => VisitorsPage(user: widget.user),
      ),
    );
  }

  void _navigateToVehicles() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => VehiclesPage(user: widget.user),
      ),
    );
  }

  void _navigateToFamily() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FamilyPage(user: widget.user),
      ),
    );
  }

  void _navigateToGateApproval() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const GateApprovalPage(),
      ),
    );
  }

  void _navigateToSecurityList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const SecurityListPage(),
      ),
    );
  }

  void _navigateToCabAutoList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => UnitVisitorListPage(
          title: 'Cab / Auto',
          visitorTypes: [VisitorType.cabDriver],
        ),
      ),
    );
  }

  void _navigateToAllowedDeliveryList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => UnitVisitorListPage(
          title: 'Allowed Delivery',
          visitorTypes: [VisitorType.courierDelivery],
        ),
      ),
    );
  }

  void _navigateToDailyHelpList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => UnitVisitorListPage(
          title: 'My Daily Help',
          visitorTypes: [VisitorType.otherVendors],
        ),
      ),
    );
  }

  bool get _isStaffSchoolOrCollege {
    final currentProp = resolveCurrentProperty(widget.user);
    final propType = currentProp?.propertyType ?? widget.user.propertyType ?? (widget.user.apartments != null && widget.user.apartments!.isNotEmpty ? widget.user.apartments!.first.propertyType : null);
    return propType == PropertyType.college;
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

  void _showReportKidExitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ReportKidExitSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickOptionsGrid(),
          if (!widget.isHostel && !_isStaffSchoolOrCollege && !_isEventsProperty) ...[
            const SizedBox(height: 24),
            _buildFeedSection(),
          ],
        ],
      ),
    );
  }

  bool get _isEventsProperty {
    final currentProp = resolveCurrentProperty(widget.user);
    final propType = currentProp?.propertyType ??
        widget.user.propertyType ??
        (widget.user.apartments != null && widget.user.apartments!.isNotEmpty ? widget.user.apartments!.first.propertyType : null);
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
      _QuickOption('Complaints', Icons.report_problem_rounded, _Action.complaints),
      _QuickOption('Payments', Icons.payment_rounded, _Action.payments),
      _QuickOption('Amenities', Icons.spa_rounded, _Action.amenities),
      _QuickOption('Security', Icons.security_rounded, _Action.securityList),
      _QuickOption('Gate Approval', Icons.how_to_reg_rounded, _Action.gateApproval),
      _QuickOption('Invite Guest', Icons.person_add_rounded, _Action.inviteGuest),
      _QuickOption('Cab/Auto', Icons.local_taxi_rounded, _Action.cabAuto),
      _QuickOption('Allowed Delivery', Icons.delivery_dining_rounded, _Action.allowedDelivery),
      _QuickOption('Call Security', Icons.phone_rounded, _Action.securityList),
      _QuickOption('Message Guard', Icons.message_rounded, _Action.messageGuard),
      _QuickOption('My Family', Icons.family_restroom_rounded, _Action.family),
      _QuickOption('My Daily Help', Icons.cleaning_services_rounded, _Action.dailyHelp),
      _QuickOption('Monthly Access', Icons.repeat_rounded, _Action.monthlyAccess),
      _QuickOption('My Vehicles', Icons.directions_car_rounded, _Action.vehicles),
      _QuickOption('Hostel Help & Support', Icons.support_agent_rounded, _Action.hostelHelpDesk),
      _QuickOption('Help and Support', Icons.support_agent_rounded, _Action.helpDesk),
      _QuickOption('Kid Exit', Icons.child_care_rounded, _Action.kidExit),
      _QuickOption('${AppConstants.appName} Services', Icons.miscellaneous_services_rounded, _Action.accessServices),
      _QuickOption('Terms & Conditions', Icons.description_rounded, _Action.termsAndConditions),
      _QuickOption('Out pass', Icons.exit_to_app_rounded, _Action.leaveRequest),
      _QuickOption('Hostel ID', Icons.badge_rounded, _Action.hostelId),
      _QuickOption('Events', Icons.event_rounded, _Action.events),
      _QuickOption('History', Icons.history_rounded, _Action.history),
      _QuickOption('Create post', Icons.edit_note_rounded, _Action.createPost),
      _QuickOption('My post', Icons.article_rounded, _Action.myPost),
    ];
    final currentProp = resolveCurrentProperty(widget.user);
    final propType = currentProp?.propertyType ?? widget.user.propertyType ?? (widget.user.apartments != null && widget.user.apartments!.isNotEmpty ? widget.user.apartments!.first.propertyType : null);
    final isStaffSchoolOrCollege = propType == PropertyType.college;
    final isEventsProperty = propType == PropertyType.events;

    if (isStaffSchoolOrCollege) {
      final byAction = {for (final o in allOptions) o.action: o};
      final ordered = <_QuickOption>[
        byAction[_Action.profile]!,
        allOptions.firstWhere((o) => o.action == _Action.securityList && o.title == 'Security'),
        byAction[_Action.termsAndConditions]!,
        byAction[_Action.accessServices]!,
        byAction[_Action.createPost]!,
        byAction[_Action.myPost]!,
      ];
      return _buildQuickOptionsGridFor(ordered);
    }

    final options = allOptions.where((o) {
      // Events Management properties: strictly Profile + Events only.
      if (isEventsProperty) {
        return o.action == _Action.profile || o.action == _Action.events ||
            o.action == _Action.history ||
            o.action == _Action.createPost ||
            o.action == _Action.myPost;
      }
      if (o.action == _Action.events || o.action == _Action.history) {
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
      if (o.action == _Action.leaveRequest) {
        return widget.showLeaveRequests;
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
        case _Action.payments:
          return widget.assignPaymentEnabled;
        case _Action.securityList:
        case _Action.gateApproval:
        case _Action.inviteGuest:
        case _Action.cabAuto:
        case _Action.allowedDelivery:
        case _Action.messageGuard:
          return widget.securityEnabled;
        default:
          return true;
      }
    }).toList();

    return _buildQuickOptionsGridFor(options);
  }

  Widget _buildQuickOptionsGridFor(List<_QuickOption> options) {
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
      case _Action.amenities:
      case _Action.family:
      case _Action.dailyHelp:
      case _Action.monthlyAccess:
      case _Action.vehicles:
      case _Action.kidExit:
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
      case _Action.raiseAlert:
        _showRaiseComplaintDialog();
        break;
      case _Action.gateApproval:
        _navigateToGateApproval();
        break;
      case _Action.inviteGuest:
        _navigateToVisitors();
        break;
      case _Action.vehicles:
        _navigateToVehicles();
        break;
      case _Action.family:
        _navigateToFamily();
        break;
      case _Action.securityList:
        _navigateToSecurityList();
        break;
      case _Action.amenities:
        Navigator.pushNamed(context, AppRoutes.amenities);
        break;
      case _Action.payments:
        Navigator.pushNamed(context, AppRoutes.payments);
        break;
      case _Action.hostelHelpDesk:
      case _Action.helpDesk:
        Navigator.pushNamed(
          context,
          AppRoutes.support,
          arguments: {'isHostel': o.action == _Action.hostelHelpDesk},
        );
        break;
      case _Action.cabAuto:
        _navigateToCabAutoList();
        break;
      case _Action.allowedDelivery:
        _navigateToAllowedDeliveryList();
        break;
      case _Action.dailyHelp:
        _navigateToDailyHelpList();
        break;
      case _Action.monthlyAccess:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MonthlyAccessPage(),
          ),
        );
        break;
      case _Action.kidExit:
        _showReportKidExitSheet();
        break;
      case _Action.messageGuard:
        _navigateToMessageGuard();
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
      case _Action.leaveRequest:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveRequestsPage(
              securityEnabled: widget.securityEnabled,
            ),
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

  Future<void> _navigateToMessageGuard() async {
    final token = await _apiService.getToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GuardConversationsPage(
            token: token,
            odId: widget.user.id,
            userType: 'user',
          ),
        ),
      );
    }
  }
}

enum _Action {
  profile,
  complaints,
  raiseAlert,
  gateApproval,
  inviteGuest,
  vehicles,
  family,
  securityList,
  amenities,
  payments,
  helpDesk,
  hostelHelpDesk,
  cabAuto,
  allowedDelivery,
  dailyHelp,
  monthlyAccess,
  kidExit,
  messageGuard,
  accessServices,
  termsAndConditions,
  leaveRequest,
  hostelId,
  comingSoon,
  events,
  history,
  createPost,
  myPost,
}

class _QuickOption {
  final String title;
  final IconData icon;
  final _Action action;
  const _QuickOption(this.title, this.icon, this.action);
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
                    child: Icon(
                      icon,
                      color: const Color(0xFF13275D),
                      size: 24,
                    ),
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
