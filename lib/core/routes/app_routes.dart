import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/user_registration_page.dart';
import '../../features/auth/presentation/pages/security_registration_page.dart';
import '../../features/auth/presentation/pages/user_type_selection_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/waiting_approval_page.dart';
import '../guards/admin_route_guard.dart';
import '../guards/maintenance_route_guard.dart';
import '../../features/maintenance/presentation/pages/maintenance_page.dart';
import '../../features/admin/presentation/pages/admin_apartment_list_page.dart';
import '../../features/admin/presentation/pages/block_details_page.dart';
import '../../features/user/presentation/pages/user_dashboard_page.dart';
import '../../features/security/presentation/pages/security_dashboard_page.dart';
import '../../features/user/presentation/pages/coming_soon_page.dart';
import '../../features/user/presentation/pages/amenities_page.dart';
import '../../features/user/presentation/pages/amenity_booking_page.dart';
import '../../features/user/presentation/pages/my_amenity_bookings_page.dart';
import '../../features/user/presentation/pages/add_tenant_page.dart';
import '../../features/user/presentation/pages/tenant_list_page.dart';
import '../../features/user/presentation/pages/owner_details_page.dart';
import '../../features/user/presentation/pages/payments_page.dart';
import '../../features/user/presentation/pages/support_page.dart';
import '../../features/user/presentation/pages/support_chat_page.dart';
import '../../features/user/presentation/pages/feed_page.dart';
import '../../features/user/presentation/pages/my_posts_page.dart';
import '../../features/admin/presentation/pages/accounts_list_page.dart';
import '../../features/admin/presentation/pages/create_subscription_plan_page.dart';
import '../../features/admin/presentation/pages/subscription_plans_list_page.dart';
import '../../features/admin/presentation/pages/subscription_purchase_history_page.dart';
import '../../features/admin/presentation/pages/edit_user_page.dart';
import '../../features/admin/presentation/pages/view_ads_page.dart';
import '../../features/admin/presentation/pages/add_ads_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../core/models/apartment_model.dart';
import '../../core/models/block_model.dart';
import '../../core/models/user_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String userTypeSelection = '/user-type-selection';
  static const String login = '/login';
  static const String userRegistration = '/user-registration';
  static const String securityRegistration = '/security-registration';
  static const String forgotPassword = '/forgot-password';
  static const String waitingApproval = '/waiting-approval';
  static const String adminApartmentList = '/admin-apartment-list';
  static const String adminDashboard = '/admin-dashboard';
  static const String blockDetails = '/block-details';
  static const String userDashboard = '/user-dashboard';
  static const String securityDashboard = '/security-dashboard';
  static const String featureComingSoon = '/feature-coming-soon';
  static const String amenities = '/amenities';
  static const String amenityBooking = '/amenity-booking';
  static const String myAmenityBookings = '/my-amenity-bookings';
  static const String payments = '/payments';
  static const String support = '/support';
  static const String supportChat = '/support-chat';
  static const String maintenance = '/maintenance';
    static const String addTenant = '/add-tenant';
    static const String tenantList = '/tenant-list';
    static const String ownerDetails = '/owner-details';
    static const String accountsList = '/accounts-list';
    static const String createSubscriptionPlan = '/create-subscription-plan';
    static const String subscriptionPlansList = '/subscription-plans-list';
    static const String subscriptionPurchaseHistory = '/subscription-purchase-history';
    static const String viewAds = '/view-ads';
    static const String addAds = '/add-ads';
    static const String notifications = '/notifications';
    static const String feed = '/feed';
    static const String myPosts = '/my-posts';
    static const String editUser = '/edit-user';

  static Map<String, WidgetBuilder> get routes {
    return {
      userTypeSelection: (context) => const UserTypeSelectionPage(),
      login: (context) => const LoginPage(),
      userRegistration: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final fromAdmin = args is Map && args['fromAdmin'] == true;
        final apartmentId = args is Map ? args['apartmentId'] as String? : null;
        final propertyType = args is Map ? args['propertyType'] as String? : null;
        return UserRegistrationPage(
          fromAdmin: fromAdmin,
          apartmentId: apartmentId,
          propertyType: propertyType,
        );
      },
      securityRegistration: (context) => const SecurityRegistrationPage(),
      forgotPassword: (context) => const ForgotPasswordPage(),
      waitingApproval: (context) => const WaitingApprovalPage(),
      adminApartmentList: (context) => const AdminApartmentListPage(),
      adminDashboard: (context) => const AdminRouteGuard(),
      blockDetails: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final block = args is BlockModel ? args : null;
        if (block == null) {
          return Builder(
            builder: (ctx) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) {
                  Navigator.of(ctx).maybePop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Block details unavailable. Please try again.'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            },
          );
        }
        return BlockDetailsPage(block: block);
      },
      userDashboard: (context) => MaintenanceRouteGuard(
        child: const UserDashboardPage(),
      ),
      securityDashboard: (context) => MaintenanceRouteGuard(
        child: const SecurityDashboardPage(),
      ),
      maintenance: (context) => const MaintenancePage(),
      featureComingSoon: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final featureName = args is Map ? args['featureName'] as String? : null;
        return ComingSoonPage(featureName: featureName);
      },
      amenities: (context) => const AmenitiesPage(),
      amenityBooking: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final amenityId = args?['amenityId'] as String? ?? '';
        final amenityName = args?['amenityName'] as String? ?? 'Amenity';
        return AmenityBookingPage(amenityId: amenityId, amenityName: amenityName);
      },
      myAmenityBookings: (context) => const MyAmenityBookingsPage(),
      payments: (context) => const PaymentsPage(),
      support: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final isHostel = args is Map && args['isHostel'] == true;
        return SupportPage(isHostel: isHostel);
      },
      supportChat: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final ticketId = args?['ticketId'] as String? ?? '';
        final isAdmin = args?['isAdmin'] as bool? ?? false;
        return SupportChatPage(ticketId: ticketId, isAdmin: isAdmin);
      },
      addTenant: (context) {
        final user = ModalRoute.of(context)?.settings.arguments as UserModel;
        return AddTenantPage(currentUser: user);
      },
      tenantList: (context) => const TenantListPage(),
      ownerDetails: (context) => const OwnerDetailsPage(),
      accountsList: (context) => const AccountsListPage(),
      createSubscriptionPlan: (context) => const CreateSubscriptionPlanPage(),
      subscriptionPlansList: (context) => const SubscriptionPlansListPage(),
      subscriptionPurchaseHistory: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final apartmentId = args is Map ? args['apartmentId'] as String? ?? '' : '';
        final apartmentName = args is Map ? args['apartmentName'] as String? : null;
        return SubscriptionPurchaseHistoryPage(
          apartmentId: apartmentId,
          apartmentName: apartmentName,
        );
      },
      viewAds: (context) => const ViewAdsPage(),
      addAds: (context) => const AddAdsPage(),
      notifications: (context) => const NotificationsPage(),
      feed: (context) => const FeedPage(),
      myPosts: (context) => const MyPostsPage(),
      editUser: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['user'] is UserModel) {
          return EditUserPage(
            user: args['user'] as UserModel,
            propertyType: args['propertyType'] as PropertyType?,
          );
        }
        if (args is UserModel) {
          return EditUserPage(user: args);
        }
        return const Scaffold(
          body: Center(child: Text('User not found')),
        );
      },
    };
  }
}

