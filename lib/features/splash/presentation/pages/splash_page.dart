import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/permission_service.dart';
import '../../../app_update/presentation/pages/app_update_required_page.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _navigationTimer;
  bool _hasNavigated = false;
  bool _permissionsRequested = false;
  bool _storeUpdateChecked = false;
  final AppUpdateService _appUpdateService = AppUpdateService();
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    unawaited(_checkStoreUpdate());
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeNavigateFromCurrentAuthState();
    });
  }

  Future<void> _checkStoreUpdate() async {
    final updateInfo = await _appUpdateService.checkForStoreUpdate();
    if (!mounted) return;

    if (updateInfo != null && updateInfo.isRequired) {
      _hasNavigated = true;
      _navigationTimer?.cancel();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppUpdateRequiredPage(updateInfo: updateInfo),
        ),
      );
      return;
    }

    _storeUpdateChecked = true;
    _maybeNavigateFromCurrentAuthState();
  }

  void _maybeNavigateFromCurrentAuthState() {
    if (!_storeUpdateChecked || _hasNavigated || !mounted) return;

    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      _navigationTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_hasNavigated && mounted) {
          _navigateToDashboard(state.user);
        }
      });
    } else if (state is AuthUnauthenticated) {
      _navigationTimer?.cancel();
      _navigationTimer = Timer(const Duration(seconds: 3), () {
        if (!_hasNavigated && mounted) {
          _navigateToUserTypeSelection();
        }
      });
    } else if (state is AuthLoading || state is AuthInitial) {
      _navigationTimer?.cancel();
    }
  }

  /// Request all required permissions during splash screen
  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    try {
      final results = await _permissionService.requestAllPermissions();

      if (kDebugMode) {
        results.forEach((type, status) {
          debugPrint('Permission ${type.name}: ${status.name}');
        });
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _navigateToUserTypeSelection() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.userTypeSelection);
  }

  void _navigateToDashboard(UserModel user) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    if (!mounted) return;

    String route = AppRoutes.login;
    switch (user.userType) {
      case UserType.admin:
      case UserType.apartment:
        route = AppRoutes.adminDashboard;
        break;
      case UserType.user:
      case UserType.tenant:
        route = AppRoutes.userDashboard;
        break;
      case UserType.security:
        route = AppRoutes.securityDashboard;
        break;
    }

    AppNavigation.resetTo(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_hasNavigated) return;
        _maybeNavigateFromCurrentAuthState();
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/maccess.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: GoogleFonts.montserrat(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
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
