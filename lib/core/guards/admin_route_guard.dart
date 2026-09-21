import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../models/apartment_model.dart';
import '../models/user_model.dart';
import '../navigation/app_navigation.dart';
import '../routes/app_routes.dart';

/// Ensures only admins or apartments can access the Admin area.
/// Admin: always shows the admin dashboard (optional selectedApartmentId from route arguments).
/// Apartment: always shows dashboard scoped to their apartment.
class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({super.key});

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  bool _redirecting = false;
  bool _hasBeenAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_redirecting) return;
        if (state is AuthAuthenticated) {
          _hasBeenAuthenticated = true;
          if (state.user.userType != UserType.apartment) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
              }
            });
          }
        } else if (state is AuthUnauthenticated) {
          // Only redirect if we were previously authenticated (actual logout)
          // Don't redirect if we're just loading/initializing
          if (_hasBeenAuthenticated) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
              }
            });
          }
        }
        // Don't redirect on AuthError - errors can be temporary (network issues, etc.)
        // Only redirect on explicit AuthUnauthenticated state
      },
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final userType = state.user.userType;
          if (userType == UserType.apartment) {
            final aptId = state.user.apartmentId;
            if (aptId != null && aptId.isNotEmpty) {
              final apartment = ApartmentModel(
                id: aptId,
                name: state.user.name,
                address: '',
                contactPhone: state.user.mobileNumber,
                securityEnabled: state.user.securityEnabled ?? true,
                assignPaymentEnabled: state.user.assignPaymentEnabled ?? true,
                complaintsEnabled: state.user.complaintsEnabled ?? true,
                propertyType: state.user.propertyType ?? PropertyType.events,
              );
              return AdminDashboardPage(
                selectedApartmentId: aptId,
                apartment: apartment,
              );
            }
          }
        }
        if (state is AuthLoading || state is AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
