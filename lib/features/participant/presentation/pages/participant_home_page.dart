import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Placeholder home page for a logged-in event participant.
/// Empty for now — content is added once the participant flow is defined.
class ParticipantHomePage extends StatelessWidget {
  const ParticipantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ISDR2026',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                context.read<AuthBloc>().add(LogoutEvent());
                AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
              });
            },
          ),
        ],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
