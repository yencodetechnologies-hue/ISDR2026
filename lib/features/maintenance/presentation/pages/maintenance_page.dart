import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MaintenancePage extends StatelessWidget {
  /// Backend `reason` when `active` is false (e.g. `subscription_expired`).
  final String? reason;

  /// ISO date string from API.
  final String? subscriptionEndsAtIso;

  /// Full days remaining when subscription is active (not shown on this page unless passed for copy).
  final int? daysLeft;

  /// Shown for apartment admins when subscription lapsed (opens pay flow).
  final VoidCallback? onRenewSubscription;

  /// When false, only the inner content is returned (no [Scaffold]) for embedding under another app bar.
  final bool wrapInScaffold;

  const MaintenancePage({
    super.key,
    this.reason,
    this.subscriptionEndsAtIso,
    this.daysLeft,
    this.onRenewSubscription,
    this.wrapInScaffold = true,
  });

  String? _detailText() {
    final r = reason ?? '';
    if (r == 'subscription_expired' &&
        subscriptionEndsAtIso != null &&
        subscriptionEndsAtIso!.isNotEmpty) {
      final d = DateTime.tryParse(subscriptionEndsAtIso!);
      if (d != null) {
        final formatted = DateFormat('d MMM yyyy').format(d.toLocal());
        return 'Subscription ended on $formatted.';
      }
    }
    if (r == 'apartment_inactive') {
      return 'This building has been deactivated.';
    }
    if (r == 'apartment_not_found') {
      return 'Building record was not found.';
    }
    if (r == 'no_apartment') {
      return 'No building is linked to this account.';
    }
    return null;
  }

  Widget _body(BuildContext context) {
    final detail = _detailText();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900,
            Colors.blue.shade700,
            Colors.indigo.shade800,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/maintance.svg',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'App under maintenance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                detail ??
                    'Your building may be inactive or the subscription has expired.\nPlease contact the administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              if (daysLeft != null && daysLeft! > 0 && reason == null) ...[
                const SizedBox(height: 12),
                Text(
                  '$daysLeft day(s) remaining on your subscription.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
              const Spacer(flex: 2),
              if (onRenewSubscription != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRenewSubscription,
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Renew subscription'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                      AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
                    });
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = _body(context);
    if (wrapInScaffold) {
      return Scaffold(body: inner);
    }
    return inner;
  }
}
