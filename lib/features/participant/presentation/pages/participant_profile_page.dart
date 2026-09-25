import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/change_password_page.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Participant's personal profile page — displays ID card, contact info,
/// Change Password, and Logout.
class ParticipantProfilePage extends StatefulWidget {
  const ParticipantProfilePage({super.key});

  @override
  State<ParticipantProfilePage> createState() => _ParticipantProfilePageState();
}

class _ParticipantProfilePageState extends State<ParticipantProfilePage> {
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    final result = await ApiService().uploadManagementProfilePhoto(picked.path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result['success'] == true) {
      context.read<AuthBloc>().add(RefreshCurrentUserEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Upload failed')),
      );
    }
  }

  String _roleLabel(UserModel user) {
    final loginRole = user.loginRole;
    if (loginRole != null && loginRole.isNotEmpty) {
      return loginRole[0].toUpperCase() + loginRole.substring(1);
    }
    return 'Delegate';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Not logged in',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                _buildIdCard(user),
                const SizedBox(height: 16),
                _buildSectionHeader('PERSONAL INFORMATION'),
                const SizedBox(height: 8),
                _buildTile(
                  icon: Icons.phone_rounded,
                  label: 'Mobile Number',
                  value: user.mobileNumber.isNotEmpty
                      ? user.mobileNumber
                      : '—',
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 10),
                _buildTile(
                  icon: Icons.email_rounded,
                  label: 'Email Address',
                  value: user.email.isNotEmpty ? user.email : '—',
                  color: const Color(0xFF3B82F6),
                ),
                if ((user.apartmentName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildTile(
                    icon: Icons.confirmation_number_rounded,
                    label: 'Registration / Package',
                    value: user.apartmentName!,
                    color: const Color(0xFFF59E0B),
                  ),
                ],
                if ((user.department ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildTile(
                    icon: Icons.school_rounded,
                    label: 'Institution / Department',
                    value: user.department!,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
                const SizedBox(height: 22),
                _buildSectionHeader('ACCOUNT & SECURITY'),
                const SizedBox(height: 8),
                _buildActionCard(
                  icon: Icons.lock_reset_rounded,
                  iconBgColor: const Color(0xFF3B82F6),
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionCard(
                  icon: Icons.logout_rounded,
                  iconBgColor: const Color(0xFFEF4444),
                  title: 'Logout',
                  subtitle: 'Sign out of this device',
                  titleColor: const Color(0xFFF87171),
                  onTap: () => LogoutConfirmSheet.showLogoutConfirmSheet(
                    context,
                    onLogout: () {
                      context.read<AuthBloc>().add(LogoutEvent());
                      AppNavigation.resetTo(context, AppRoutes.login);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Dark blue ID card hero showing photo, name, role badge, and ID.
  Widget _buildIdCard(UserModel user) {
    final hasPhoto = user.profilePic != null && user.profilePic!.isNotEmpty;
    final idNumber = (user.employeeId ?? '').isNotEmpty
        ? user.employeeId!
        : (user.apartmentId ?? user.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _pickPhoto,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: Colors.white24,
                    child: hasPhoto
                        ? CachedNetworkImage(
                            imageUrl: user.profilePic!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildInitial(user),
                          )
                        : _buildInitial(user),
                  ),
                ),
                if (_uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14141F),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ISDR 2026',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.name.trim().isEmpty ? 'Participant' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabel(user).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (idNumber.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'ID: $idNumber',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitial(UserModel user) {
    return Center(
      child: Text(
        user.name.trim().isEmpty ? '?' : user.name.trim()[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Informational tile for user attributes (phone, email, institution, etc.)
  Widget _buildTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Action card tile for Change Password and Logout
  Widget _buildActionCard({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF14141F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBgColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
