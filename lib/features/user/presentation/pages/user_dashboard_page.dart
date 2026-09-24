import 'package:flutter/material.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/utils/current_property_context.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../bloc/user_bloc.dart';
import 'widgets/home_tab.dart';
import 'widgets/profile_tab.dart';
import 'visitors_page.dart';
import 'my_event_tickets_page.dart';
import 'gate_approval_page.dart';
import 'terms_and_conditions_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  // Set while building the drawer: dark theme for event staff.
  bool _darkDrawer = false;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserDataEvent());
    context.read<NotificationBloc>().add(const LoadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          final propertyCtx = resolvePropertyContext(
            authState.user,
            selectedApartmentId: authState.selectedApartmentId,
          );
          final currentProp = resolveCurrentProperty(authState.user);
          final propType =
              currentProp?.propertyType ??
              authState.user.propertyType ??
              (authState.user.apartments != null &&
                      authState.user.apartments!.isNotEmpty
                  ? authState.user.apartments!.first.propertyType
                  : null);
          final isStaffSchoolOrCollege = false;
          final isEventsProperty = propType == PropertyType.events;

          final complaintsEnabled =
              propertyCtx.complaintsEnabled &&
              !isStaffSchoolOrCollege &&
              !isEventsProperty;
          final tabCount = isEventsProperty ? 1 : (complaintsEnabled ? 4 : 3);
          final effectiveIndex = _currentIndex >= tabCount
              ? tabCount - 1
              : _currentIndex;
          return Scaffold(
            // Event staff get the dark theme of the participant screens.
            backgroundColor: isEventsProperty ? const Color(0xFF0A0A12) : null,
            drawer: _buildDrawer(
              context,
              authState.user,
              authState.selectedApartmentId,
              propertyCtx: propertyCtx,
              complaintsEnabled: complaintsEnabled,
              securityEnabled: propertyCtx.securityEnabled,
              currentIndex: effectiveIndex,
              isEventsProperty: isEventsProperty,
              isStaffSchoolOrCollege: isStaffSchoolOrCollege,
            ),
            appBar: AppBar(
              backgroundColor: isEventsProperty
                  ? const Color(0xFF0A0A12)
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              title: Text(
                _getAppBarTitle(
                  effectiveIndex,
                  complaintsEnabled,
                  isHostel: propertyCtx.isHostel,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BlocBuilder<NotificationBloc, NotificationState>(
                      builder: (context, state) {
                        int unreadCount = 0;
                        if (state is NotificationLoaded) {
                          unreadCount = state.unreadCount;
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            context.read<NotificationBloc>().add(
                              const LoadUnreadCount(),
                            );
                          });
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.all(8),
                              icon: SvgPicture.asset(
                                'assets/notification.svg',
                                width: 22,
                                height: 22,
                                colorFilter: ColorFilter.mode(
                                  Theme.of(
                                        context,
                                      ).appBarTheme.iconTheme?.color ??
                                      Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.notifications,
                                );
                              },
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
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
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
            body: IndexedStack(
              index: effectiveIndex,
              children: [
                HomeTab(
                  user: authState.user,
                  isHostel: propertyCtx.isHostel,
                  securityEnabled: propertyCtx.securityEnabled,
                  assignPaymentEnabled: propertyCtx.assignPaymentEnabled,
                  showLeaveRequests: false,
                  complaintsEnabled: false,
                  adsEnabled: propertyCtx.adsEnabled,
                  onSwitchToComplaints: null,
                  onSwitchToProfile: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: const Color(0xFF0A0A12),
                          appBar: buildDarkAppBar(title: const Text('Profile')),
                          body: ProfileTab(
                            user: authState.user,
                            isHostel: propertyCtx.isHostel,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    UserModel user,
    String? selectedApartmentId, {
    required CurrentPropertyContext propertyCtx,
    required bool complaintsEnabled,
    required bool securityEnabled,
    required int currentIndex,
    bool isEventsProperty = false,
    bool isStaffSchoolOrCollege = false,
  }) {
    final isHostel = propertyCtx.isHostel;
    final primaryColor = Theme.of(context).primaryColor;
    // Event staff get the dark theme; _buildDrawerItem reads this too.
    _darkDrawer = isEventsProperty;

    return Drawer(
      width: 275,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Container(
        color: _darkDrawer ? const Color(0xFF0A0A12) : const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Top Gradient Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    const Color(0xFF1E3A8A),
                    const Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  child: Column(
                    children: [
                      // Avatar Circle with Ring Glow
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: user.profilePic != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(36),
                                  child: Image.network(
                                    user.profilePic!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 42,
                                  color: primaryColor,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User Name
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Property Context / Switcher Pill
                      Builder(
                        builder: (context) {
                          final apartments = user.apartments;
                          final selectedId =
                              selectedApartmentId ?? user.apartmentId;
                          final propertyLabel = propertyCtx.propertyLabel;

                          if (apartments == null || apartments.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          if (apartments.length == 1) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                apartments.first.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          final currentName = selectedId != null
                              ? (apartments
                                    .firstWhere(
                                      (a) => a.id == selectedId,
                                      orElse: () => apartments.first,
                                    )
                                    .name)
                              : apartments.first.name;

                          return PopupMenuButton<String>(
                            tooltip: 'Switch $propertyLabel',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            onSelected: (String id) {
                              context.read<AuthBloc>().add(
                                SelectUserApartmentEvent(apartmentId: id),
                              );
                              context.read<UserBloc>().add(LoadUserDataEvent());
                            },
                            itemBuilder: (context) => apartments
                                .map(
                                  (a) => PopupMenuItem<String>(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Phone Number & Room Chips Row
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.mobileNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isHostel &&
                              ((user.hostelRoom != null &&
                                      user.hostelRoom!.isNotEmpty) ||
                                  (user.hostelBed != null &&
                                      user.hostelBed!.isNotEmpty)))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                [
                                  if (user.hostelRoom != null &&
                                      user.hostelRoom!.isNotEmpty)
                                    'Room ${user.hostelRoom}',
                                  if (user.hostelBed != null &&
                                      user.hostelBed!.isNotEmpty)
                                    'Bed ${user.hostelBed}',
                                ].join(' • '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else if (!isHostel &&
                              user.block != null &&
                              user.roomNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Block ${user.block} • Room ${user.roomNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Menu Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  if (!user.isStaff && !isEventsProperty)
                    _buildDrawerItem(
                      context,
                      icon: Icons.notifications_rounded,
                      title: 'Notices',
                      index: 1,
                      currentIndex: currentIndex,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 1);
                      },
                    ),
                  if (complaintsEnabled && !isEventsProperty)
                    _buildDrawerItem(
                      context,
                      icon: Icons.report_problem_rounded,
                      title: 'Complaints',
                      index: 2,
                      currentIndex: currentIndex,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 2);
                      },
                    ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    index: complaintsEnabled ? (user.isStaff ? 1 : 3) : 2,
                    currentIndex: currentIndex,
                    onTap: () {
                      Navigator.pop(context);
                      if (isEventsProperty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: const Color(0xFF0A0A12),
                              appBar: buildDarkAppBar(
                                title: const Text('Profile'),
                              ),
                              body: ProfileTab(user: user, isHostel: isHostel),
                            ),
                          ),
                        );
                        return;
                      }
                      setState(
                        () => _currentIndex = complaintsEnabled
                            ? (user.isStaff ? 1 : 3)
                            : 2,
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFE2E8F0), height: 1),
                  ),
                  if (user.userType == UserType.tenant) ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.supervisor_account_rounded,
                      title: 'Owner Details',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.ownerDetails);
                      },
                    ),
                  ],
                  if (securityEnabled &&
                      !user.isStaff &&
                      !isEventsProperty &&
                      !isStaffSchoolOrCollege) ...[
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Gate Approval',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GateApprovalPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.group_rounded,
                      title: isHostel ? 'Guests' : 'Visitors',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VisitorsPage(user: user),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.confirmation_number_rounded,
                      title: 'Event tickets',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyEventTicketsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                  if (!user.isStaff)
                    _buildDrawerItem(
                      context,
                      icon: Icons.description_rounded,
                      title: 'Terms & Conditions',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TermsAndConditionsPage(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            // Bottom Logout Action
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildDrawerItem(
                context,
                icon: Icons.logout_rounded,
                title: 'Logout',
                isLogout: true,
                onTap: () {
                  Navigator.pop(context);
                  LogoutConfirmSheet.showLogoutConfirmSheet(
                    context,
                    onLogout: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                      AppNavigation.resetTo(
                        context,
                        AppRoutes.userTypeSelection,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int? index,
    int? currentIndex,
    bool isLogout = false,
  }) {
    final effectiveCurrent = currentIndex ?? _currentIndex;
    final isSelected = index != null && effectiveCurrent == index;
    // Navy is too dark to read on the black drawer, so use a lighter blue.
    final primaryColor = _darkDrawer
        ? const Color(0xFF3B82F6)
        : Theme.of(context).primaryColor;

    if (isLogout) {
      return Material(
        color: _darkDrawer ? const Color(0x26EF4444) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFCA5A5).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _darkDrawer
                        ? const Color(0x33EF4444)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (_darkDrawer
                              ? const Color(0xFF1E1E2A)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : (_darkDrawer
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF64748B)),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? (_darkDrawer
                                ? const Color(0xFF60A5FA)
                                : primaryColor)
                          : (_darkDrawer
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF334155)),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle(
    int index,
    bool complaintsEnabled, {
    bool isHostel = false,
  }) {
    final homeTitle = isHostel ? 'Hostel' : 'Dashboard';
    if (complaintsEnabled) {
      switch (index) {
        case 0:
          return homeTitle;
        case 1:
          return 'Notices';
        case 2:
          return 'Complaints';
        case 3:
          return 'Profile';
        default:
          return homeTitle;
      }
    } else {
      switch (index) {
        case 0:
          return homeTitle;
        case 1:
          return 'Notices';
        case 2:
          return 'Profile';
        default:
          return homeTitle;
      }
    }
  }
}
