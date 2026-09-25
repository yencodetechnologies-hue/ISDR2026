import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../../core/app_theme.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../bloc/admin_bloc.dart';
import 'tabs/users_tab.dart';
import 'tabs/managed_events_tab.dart';
import '../widgets/management_module_grid.dart';
import 'manage_speakers_page.dart';
import 'manage_exhibitors_page.dart';
import 'manage_banner_page.dart';
import '../../../support/presentation/pages/help_tickets_page.dart';
import 'engagement_overview_page.dart';
import '../../../user/presentation/pages/user_events_page.dart';
import '../../../participant/presentation/widgets/live_show_card.dart';
import '../widgets/auto_scroll_banner.dart';
import 'property_profile_page.dart';
import 'management_team_page.dart';
import 'brochure_page.dart';
import 'my_profile_page.dart';
import 'event_schedules_page.dart';
import 'send_notification_page.dart';

class _PropertyTabItem {
  final String label;
  final Widget Function(AdminLoaded state) buildContent;

  const _PropertyTabItem({required this.label, required this.buildContent});
}

/// Management property dashboard: one bloc listener, only the active tab is built.
class _PropertyTabShell extends StatefulWidget {
  const _PropertyTabShell({
    super.key,
    required this.tabController,
    required this.tabs,
  });

  final TabController tabController;
  final List<_PropertyTabItem> tabs;

  @override
  State<_PropertyTabShell> createState() => _PropertyTabShellState();
}

class _PropertyTabShellState extends State<_PropertyTabShell> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabIndexChanged);
  }

  @override
  void didUpdateWidget(covariant _PropertyTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      oldWidget.tabController.removeListener(_onTabIndexChanged);
      widget.tabController.addListener(_onTabIndexChanged);
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabIndexChanged);
    super.dispose();
  }

  void _onTabIndexChanged() {
    if (!mounted || widget.tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (previous, current) =>
          current is AdminLoaded || previous is AdminLoaded,
      builder: (context, state) {
        if (state is! AdminLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Material(
              color: const Color(0xFF14141F),
              child: TabBar(
                controller: widget.tabController,
                isScrollable: true,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: Colors.white.withOpacity(0.55),
                indicatorColor: const Color(0xFF3B82F6),
                tabAlignment: TabAlignment.start,
                tabs: widget.tabs.map((t) => Tab(text: t.label)).toList(),
              ),
            ),
            Expanded(
              child: widget.tabs[widget.tabController.index].buildContent(
                state,
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  final String? selectedApartmentId;
  final dynamic apartment;
  final int? initialTabIndex;

  const AdminDashboardPage({
    super.key,
    this.selectedApartmentId,
    this.apartment,
    this.initialTabIndex,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with TickerProviderStateMixin {
  AdminLoaded? _lastLoadedState;
  bool _errorSnackBarShown = false;
  final ApiService _apiService = ApiService();
  TabController? _tabController;
  List<_PropertyTabItem> _propertyTabs = [];
  ApartmentModel? _effectiveApartment;

  /// Null = module grid home; set when an apartment account opens a module.
  int? _managementModuleIndex;

  bool get _isPropertyScoped {
    final id = widget.selectedApartmentId;
    return id != null && id.isNotEmpty;
  }

  ApartmentModel? get _apartmentModel =>
      _effectiveApartment ??
      (widget.apartment is ApartmentModel
          ? widget.apartment as ApartmentModel
          : null);

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    final apartmentId = widget.selectedApartmentId;
    context.read<AdminBloc>().add(
      SelectApartmentEvent(apartmentId: apartmentId),
    );
    context.read<AdminBloc>().add(LoadBlocksEvent());
    if (_isPropertyScoped) {
      _propertyTabs = _buildPropertyTabItems();
      if (!_isApartmentAccount()) {
        final initial = (widget.initialTabIndex ?? 0).clamp(
          0,
          _propertyTabs.length - 1,
        );
        _tabController = TabController(
          length: _propertyTabs.length,
          vsync: this,
          initialIndex: initial,
        );
      }
    }
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      context.read<AdminBloc>().add(LoadBlocksEvent());
    });
  }

  Future<void> _hydrateApartmentFromApi() async {
    final id = widget.selectedApartmentId;
    if (id == null || id.isEmpty) return;
    try {
      final res = await _apiService.getApartment(id);
      if (!mounted || res['success'] != true) return;
      final raw = res['apartment'];
      if (raw is! Map) return;
      final apt = ApartmentModel.fromJson(Map<String, dynamic>.from(raw));
      final prev = _apartmentModel;
      final sameType = prev?.propertyType == apt.propertyType;
      final sameFlags =
          prev?.securityEnabled == apt.securityEnabled &&
          prev?.assignPaymentEnabled == apt.assignPaymentEnabled &&
          prev?.complaintsEnabled == apt.complaintsEnabled &&
          prev?.showUserMobile == apt.showUserMobile &&
          prev?.wardenFacilityEnabled == apt.wardenFacilityEnabled &&
          prev?.supportEnabled == apt.supportEnabled &&
          prev?.adsEnabled == apt.adsEnabled;

      if (prev != null &&
          sameType &&
          sameFlags &&
          prev.blockCreationEnabled == apt.blockCreationEnabled &&
          prev.name == apt.name &&
          prev.address == apt.address &&
          prev.contactPhone == apt.contactPhone &&
          prev.email == apt.email &&
          prev.wardenName == apt.wardenName &&
          prev.wardenContact == apt.wardenContact &&
          prev.ownerName == apt.ownerName) {
        return;
      }

      setState(() {
        _effectiveApartment = apt;
        if (_isPropertyScoped) {
          final newTabs = _buildPropertyTabItems();
          final tabsChanged =
              !sameType || !sameFlags || newTabs.length != _propertyTabs.length;
          _propertyTabs = newTabs;
          if (tabsChanged && !_isApartmentAccount()) {
            _rebuildPropertyTabs();
          } else if (tabsChanged && _managementModuleIndex != null) {
            _managementModuleIndex = _managementModuleIndex!.clamp(
              0,
              _propertyTabs.length - 1,
            );
          }
        }
      });
    } catch (_) {}
  }

  void _rebuildPropertyTabs() {
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    if (_propertyTabs.isEmpty) {
      _tabController = null;
      return;
    }
    final initial = oldIndex.clamp(0, _propertyTabs.length - 1);
    _tabController = TabController(
      length: _propertyTabs.length,
      vsync: this,
      initialIndex: initial,
    );
  }

  void _clearPropertyScopeOnExit() {
    if (!_isPropertyScoped) return;
    final bloc = context.read<AdminBloc>();
    bloc.add(const SelectApartmentEvent(apartmentId: null));
    bloc.add(LoadBlocksEvent());
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<_PropertyTabItem> _buildPropertyTabItems() {
    final apt = _apartmentModel;
    final apartmentId = widget.selectedApartmentId;

    return <_PropertyTabItem>[
      _PropertyTabItem(
        label: 'Events',
        buildContent: (state) => ManagedEventsTab(
          state: state,
          selectedApartmentId: apartmentId,
          isEventsProperty: true,
        ),
      ),
      _PropertyTabItem(
        label: 'Event Staff',
        buildContent: (state) => UsersTab(state: state, apartment: apt),
      ),
      _PropertyTabItem(
        label: 'Admin IDs',
        buildContent: (_) =>
            ManagementTeamPage(apartmentId: apartmentId, hideAppBar: true),
      ),
    ];
  }

  void _navigateToModule(String label) {
    if (label.trim().toLowerCase() == 'support tickets') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HelpTicketsPage(isParticipant: false),
        ),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'banner') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageBannerPage()),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'q&a & polls') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EngagementOverviewPage()),
      );
      return;
    }
    // Same flow as the event staff: pick an event, tap an inclusion, then
    // scan the participant's QR or enter their ID number.
    if (label.trim().toLowerCase() == 'scan inclusion') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserEventsListPage(
            apartmentId: widget.selectedApartmentId ?? _apartmentModel?.id,
          ),
        ),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'speakers') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageSpeakersPage()),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'add exhibitors') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManageExhibitorsPage()),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'brochure') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BrochurePage()),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'send notification') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SendNotificationPage(
            apartmentId: widget.selectedApartmentId ?? _apartmentModel?.id,
          ),
        ),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'event schedules') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventSchedulesPage(
            apartmentId: widget.selectedApartmentId ?? _apartmentModel?.id,
          ),
        ),
      );
      return;
    }
    if (label.trim().toLowerCase() == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyProfilePage()),
      );
      return;
    }
    final idx = _propertyTabs.indexWhere(
      (t) => t.label.trim().toLowerCase() == label.trim().toLowerCase(),
    );
    if (idx == -1) return;
    if (_isApartmentAccount()) {
      setState(() => _managementModuleIndex = idx);
      return;
    }
    _tabController?.animateTo(idx);
  }

  void _goToManagementGridHome() {
    if (_managementModuleIndex == null) return;
    setState(() => _managementModuleIndex = null);
  }

  bool _isApartmentAccount() {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.user.userType == UserType.apartment;
  }

  bool _isAdminUser(AuthState authState) {
    return authState is AuthAuthenticated &&
        authState.user.userType == UserType.admin;
  }

  String _appBarTitle(AuthState authState) {
    if (_isApartmentAccount() &&
        _isPropertyScoped &&
        _managementModuleIndex != null &&
        _managementModuleIndex! < _propertyTabs.length) {
      return _propertyTabs[_managementModuleIndex!].label;
    }
    if (_isPropertyScoped && _apartmentModel != null) {
      return _apartmentModel!.name;
    }
    if (_isAdminUser(authState)) return 'Admin Dashboard';
    if (authState is AuthAuthenticated) return authState.user.name;
    return 'Admin Dashboard';
  }

  void _openPropertyProfile(BuildContext context) {
    final apt = _apartmentModel;
    if (apt == null) return;
    final authState = context.read<AuthBloc>().state;
    final isWarden =
        authState is AuthAuthenticated && authState.user.loginRole == 'warden';
    final isAdmin =
        authState is AuthAuthenticated &&
        authState.user.userType == UserType.admin;
    final canEdit = isAdmin || !isWarden;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyProfilePage(
          apartment: apt,
          canEdit: canEdit,
          onSaved: _hydrateApartmentFromApi,
        ),
      ),
    ).then((saved) {
      if (saved == true && mounted) setState(() {});
    });
  }

  /// Logo + "ISDR 2026" + "Indian Division • IADR", then notifications,
  /// logout and the profile avatar — the participant home's header.
  Widget _buildHomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Image.asset(
              'assets/ISDR 2026 Logo.png',
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
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => LogoutConfirmSheet.showLogoutConfirmSheet(
              context,
              onLogout: () {
                context.read<AuthBloc>().add(LogoutEvent());
                AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
              },
            ),
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
                padding: const EdgeInsets.only(left: 2, right: 4),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfilePage()),
                  ),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo)
                        : null,
                    child: photo.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
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
    );
  }

  Widget _buildManagementGridHome(AdminLoaded state) {
    final labels = [
      'Brochure',
      ..._propertyTabs.map((t) => t.label),
      'Profile',
      'Send Notification',
      'Event Schedules',
      'Speakers',
      'Scan Inclusion',
      'Q&A & Polls',
      'Add Exhibitors',
      'Banner',
      'Support Tickets',
    ];
    final isHostel = false;
    final totalRooms = totalRoomCountForProperty(blocks: state.blocks);
    final totalVacancies = vacantRoomCountForProperty(
      users: state.regularUsers,
      blocks: state.blocks,
      isHostel: isHostel,
    );

    return ColoredBox(
      color: const Color(0xFF0A0A12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Same header as the participant home: logo + ISDR 2026, then actions.
            SafeArea(bottom: false, child: _buildHomeHeader()),
            // Body: banner, live card and module grid
            const AutoScrollBanner(items: defaultManagementBanners),
            // Same live-show card as the participant, speaker and staff homes.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: LiveShowCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: ManagementModuleGrid(
                moduleLabels: labels,
                onModuleTap: _navigateToModule,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementApartmentBody() {
    return BlocBuilder<AdminBloc, AdminState>(
      buildWhen: (previous, current) =>
          current is AdminLoaded || previous is AdminLoaded,
      builder: (context, state) {
        if (state is! AdminLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_managementModuleIndex == null) {
          return _buildManagementGridHome(state);
        }
        return _propertyTabs[_managementModuleIndex!].buildContent(state);
      },
    );
  }

  Widget _buildManagementIdsTabContent(BuildContext context) {
    final apt = _apartmentModel;
    final propId = apt?.id ?? 'MG-8947291';
    final ownerPhone = (apt?.contactPhone.isNotEmpty == true)
        ? apt!.contactPhone
        : '9876543210';
    final wardenPhone = (apt?.wardenContact.isNotEmpty == true)
        ? apt!.wardenContact
        : '9876543218';
    final gateCode = propId.length >= 6
        ? 'SEC-${propId.substring(propId.length - 6).toUpperCase()}'
        : 'SEC-894729';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin IDs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Static Property Credentials & Gate Access Codes',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildIdRow(context, 'Property ID', propId),
          _buildIdRow(context, 'Admin Contact ID', ownerPhone),
          _buildIdRow(context, 'Warden Contact ID', wardenPhone),
          _buildIdRow(context, 'Security Gate Code', gateCode),
        ],
      ),
    );
  }

  void _showManagementIdsSheet(BuildContext context) {
    final apt = _apartmentModel;
    final propId = apt?.id ?? 'MG-8947291';
    final ownerPhone = (apt?.contactPhone.isNotEmpty == true)
        ? apt!.contactPhone
        : '9876543210';
    final wardenPhone = (apt?.wardenContact.isNotEmpty == true)
        ? apt!.wardenContact
        : '9876543218';
    final gateCode = propId.length >= 6
        ? 'SEC-${propId.substring(propId.length - 6).toUpperCase()}'
        : 'SEC-894729';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFF14141F),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: const Color(0xFF3B82F6),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Admin IDs (Static)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildIdRow(ctx, 'Property ID', propId),
            _buildIdRow(ctx, 'Admin Contact ID', ownerPhone),
            _buildIdRow(ctx, 'Warden Contact ID', wardenPhone),
            _buildIdRow(ctx, 'Security Gate Code', gateCode),
          ],
        ),
      ),
    );
  }

  Widget _buildIdRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: const Color(0xFF3B82F6),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppTheme.secondaryColor,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onAdminBlocSideEffect(BuildContext context, AdminState state) {
    if (state is AdminLoaded) {
      _lastLoadedState = state;
      _errorSnackBarShown = false;
    } else if (state is AdminError &&
        _lastLoadedState != null &&
        !_errorSnackBarShown) {
      _errorSnackBarShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                context.read<AdminBloc>().add(LoadBlocksEvent());
              },
            ),
          ),
        );
      });
    }
  }

  Widget _buildDashboardBody(AdminLoaded state) {
    return const SizedBox.shrink();
  }

  Widget? _buildLeading(AuthState authState) {
    if (_isApartmentAccount() &&
        _isPropertyScoped &&
        _managementModuleIndex != null) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _goToManagementGridHome,
      );
    }
    if (!_isPropertyScoped || !_isAdminUser(authState)) {
      return null;
    }
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.pop(context),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthState authState) {
    final leading = _buildLeading(authState);
    return buildDarkAppBar(
      automaticallyImplyLeading: leading != null,
      leading: leading,
      leadingWidth: leading != null ? null : 0,
      title: Text(_appBarTitle(authState)),
      actions: _appBarActions(context),
    );
  }

  Widget _wrapWithPropertyPopScope(Widget child) {
    if (!_isPropertyScoped) return child;
    return PopScope(
      canPop: !_isApartmentAccount() || _managementModuleIndex == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop &&
            _isApartmentAccount() &&
            _managementModuleIndex != null) {
          _goToManagementGridHome();
          return;
        }
        if (didPop) _clearPropertyScopeOnExit();
      },
      child: child,
    );
  }

  List<Widget> _appBarActions(BuildContext context) {
    const double iconSize = 22.0;
    final actions = <Widget>[];
    actions.add(
      BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          int unreadCount = 0;
          if (state is NotificationLoaded) {
            unreadCount = state.unreadCount;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.read<NotificationBloc>().add(const LoadUnreadCount());
              }
            });
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(
                  Icons.notifications_outlined,
                  size: iconSize,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications);
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    actions.add(
      IconButton(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: const Icon(
          Icons.logout_rounded,
          size: iconSize,
          color: Colors.white,
        ),
        tooltip: 'Logout',
        onPressed: () {
          LogoutConfirmSheet.showLogoutConfirmSheet(
            context,
            onLogout: () {
              context.read<AuthBloc>().add(LogoutEvent());
              AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
            },
          );
        },
      ),
    );
    actions.add(const SizedBox(width: 4));
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;

    final propertyTabs = _propertyTabs;
    final tabController = _tabController;

    return _wrapWithPropertyPopScope(
      Scaffold(
        // Management home is dark; the white showed below short content.
        backgroundColor:
            (_isApartmentAccount() && _managementModuleIndex == null)
            ? const Color(0xFF0A0A12)
            : null,
        appBar: (_isApartmentAccount() && _managementModuleIndex == null)
            ? null
            : _buildAppBar(authState),
        body: propertyTabs.isNotEmpty && _isApartmentAccount()
            ? BlocListener<AdminBloc, AdminState>(
                listener: _onAdminBlocSideEffect,
                child: _buildManagementApartmentBody(),
              )
            : tabController != null && propertyTabs.isNotEmpty
            ? BlocListener<AdminBloc, AdminState>(
                listener: _onAdminBlocSideEffect,
                child: _PropertyTabShell(
                  key: ValueKey('property-tabs-${widget.selectedApartmentId}'),
                  tabController: tabController,
                  tabs: propertyTabs,
                ),
              )
            : BlocConsumer<AdminBloc, AdminState>(
                listener: _onAdminBlocSideEffect,
                builder: (context, state) {
                  if (state is AdminLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminLoaded) {
                    return _buildDashboardBody(state);
                  }
                  if (state is AdminError) {
                    if (_lastLoadedState != null) {
                      return _buildDashboardBody(_lastLoadedState!);
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: ${state.message}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.read<AdminBloc>().add(
                                LoadBlocksEvent(),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
      ),
    );
  }
}

class _QuickActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickActionPill> createState() => _QuickActionPillState();
}

class _QuickActionPillState extends State<_QuickActionPill> {
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF14141F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: const Color(0xFF9CA3AF), size: 16),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
