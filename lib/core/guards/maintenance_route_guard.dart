import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/maintenance/presentation/pages/maintenance_page.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

/// Wraps user or security dashboard: if app subscription is inactive,
/// shows [MaintenancePage] instead of [child].
class MaintenanceRouteGuard extends StatefulWidget {
  final Widget child;

  const MaintenanceRouteGuard({super.key, required this.child});

  @override
  State<MaintenanceRouteGuard> createState() => _MaintenanceRouteGuardState();
}

class _MaintenanceRouteGuardState extends State<MaintenanceRouteGuard> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _active = true;
  String? _reason;
  String? _subscriptionEndsAtIso;
  int _daysLeft = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    String? apartmentHeader;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      apartmentHeader = authState.selectedApartmentId ?? authState.user.apartmentId;
      if (authState.user.userType == UserType.admin &&
          (apartmentHeader == null || apartmentHeader.isEmpty)) {
        apartmentHeader = null;
      }
    }

    final res = await _api.getSubscriptionAppActive(
      apartmentIdHeader: apartmentHeader,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _active = res['active'] == true;
        _reason = res['reason']?.toString();
        _subscriptionEndsAtIso = res['subscriptionEndsAt']?.toString();
        _daysLeft = (res['daysLeft'] is int)
            ? res['daysLeft'] as int
            : int.tryParse(res['daysLeft']?.toString() ?? '') ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_active) {
      return MaintenancePage(
        reason: _reason,
        subscriptionEndsAtIso: _subscriptionEndsAtIso,
        daysLeft: _daysLeft,
      );
    }
    return widget.child;
  }
}
