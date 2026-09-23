import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  Timer? _navigationTimer;
  bool _hasNavigated = false;
  bool _permissionsRequested = false;
  bool _storeUpdateChecked = false;
  final AppUpdateService _appUpdateService = AppUpdateService();
  final PermissionService _permissionService = PermissionService();
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );
    _progressController.forward();

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
    _progressController.dispose();
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
        route = AppRoutes.userTypeSelection;
        break;
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
      case UserType.participant:
        route = AppRoutes.participantHome;
        break;
      case UserType.speaker:
        route = AppRoutes.speakerHome;
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
        backgroundColor: const Color(0xFF021B4D),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/splash.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              bottom: 42,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Container(
                    width: 155,
                    height: 6.5,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor:
                                _progressAnimation.value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF26D6FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
