import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/config/app_update_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_update_info.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../splash/presentation/pages/splash_page.dart';

class AppUpdateRequiredPage extends StatefulWidget {
  const AppUpdateRequiredPage({
    super.key,
    required this.updateInfo,
    this.appUpdateService,
  });

  final AppUpdateInfo updateInfo;
  final AppUpdateService? appUpdateService;

  @override
  State<AppUpdateRequiredPage> createState() => _AppUpdateRequiredPageState();
}

class _AppUpdateRequiredPageState extends State<AppUpdateRequiredPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AppUpdateService _appUpdateService;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _appUpdateService = widget.appUpdateService ?? AppUpdateService();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAfterResume();
    }
  }

  Future<void> _recheckAfterResume() async {
    if (!widget.updateInfo.isIos || _isUpdating) return;

    final info = await _appUpdateService.checkForStoreUpdate();
    if (!mounted) return;
    if (info == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashPage()),
      );
    }
  }

  Future<void> _onUpdatePressed() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final outcome = await _appUpdateService.performStoreUpdate(widget.updateInfo);

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (outcome == StoreUpdateOutcome.success) {
      return;
    }
    if (outcome == StoreUpdateOutcome.storeOpened) {
      return;
    }

    final message = switch (outcome) {
      StoreUpdateOutcome.userDenied =>
        'Update was cancelled. Please update to continue using the app.',
      StoreUpdateOutcome.failed =>
        'Could not start the update. Please try again.',
      _ => null,
    };

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.brandHeaderGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 28),
                    _buildUpdateCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            color: Colors.white.withOpacityCompat(0.15),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacityCompat(0.25)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppConstants.appName,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateCard() {
    final latest = widget.updateInfo.latestVersion;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacityCompat(0.12),
                    AppTheme.secondaryColor.withOpacityCompat(0.14),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacityCompat(0.18),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                size: 36,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Update required',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.updateInfo.isIos
                ? 'A newer version is available on the App Store. Update now for the best experience.'
                : 'A newer version is ready to install. Update now for the best experience.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.textColor.withOpacityCompat(0.72),
            ),
          ),
          const SizedBox(height: 18),
          _buildVersionPill(latest),
          if (AppUpdateConfig.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildReleaseNotes(),
          ],
          const SizedBox(height: 28),
          BrandGradientCtaButton(
            label: widget.updateInfo.isIos ? 'Update on App Store' : 'Update now',
            icon: Icons.download_rounded,
            onPressed: _onUpdatePressed,
            isLoading: _isUpdating,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionPill(String? latest) {
    final current = widget.updateInfo.currentVersion;
    final label = latest != null ? 'v$current  →  v$latest' : 'v$current';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's new",
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 10),
        ...AppUpdateConfig.releaseNotes.map(
          (note) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textColor.withOpacityCompat(0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
