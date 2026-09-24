import 'package:flutter/material.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/utils/current_property_context.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../bloc/user_bloc.dart';
import 'widgets/home_tab.dart';
import 'widgets/profile_tab.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
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
            appBar: AppBar(
              backgroundColor: isEventsProperty
                  ? const Color(0xFF0A0A12)
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              centerTitle: true,
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
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: () {
                        LogoutConfirmSheet.showLogoutConfirmSheet(
                          context,
                          onLogout: () {
                            context.read<AuthBloc>().add(LogoutEvent());
                          },
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
