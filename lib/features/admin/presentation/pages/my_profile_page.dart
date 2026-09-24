import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../participant/presentation/widgets/inclusions_section.dart';
import '../widgets/delegate_badge.dart';

/// Shows the details of the account that is currently logged in.
class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  bool _uploading = false;
  bool _savingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageOff();
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changePassword() async {
    final current = _currentPw.text;
    final next = _newPw.text.trim();
    final confirm = _confirmPw.text.trim();
    if (current.isEmpty && next.isEmpty && confirm.isEmpty) {
      _toast('Enter your current and new password');
      return;
    }
    if (current.isEmpty) {
      _toast('Enter your current password');
      return;
    }
    if (next.length < 6) {
      _toast('New password must be at least 6 characters');
      return;
    }
    if (next != confirm) {
      _toast('New password and confirm password do not match');
      return;
    }
    setState(() => _savingPassword = true);
    final result = await ApiService().changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _savingPassword = false);
    if (result['success'] == true) {
      _currentPw.clear();
      _newPw.clear();
      _confirmPw.clear();
      _toast('Password updated successfully');
    } else {
      _toast(result['error']?.toString() ?? 'Failed to update password');
    }
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
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
    return user.userType == UserType.apartment
        ? 'Event Management'
        : user.userType.name[0].toUpperCase() + user.userType.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    final isParticipant = user?.userType == UserType.participant;

    return Scaffold(
      backgroundColor: isParticipant
          ? const Color(0xFF0F172A)
          : const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: isParticipant
            ? const Color(0xFF0F172A)
            : const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : isParticipant
          ? _buildParticipantBadgeView(user)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                _idCard(user),
                const SizedBox(height: 12),
                _tile(
                  Icons.phone_rounded,
                  'Mobile',
                  user.mobileNumber,
                  const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 8),
                _tile(
                  Icons.email_rounded,
                  'Email address',
                  user.email,
                  const Color(0xFF3B82F6),
                ),
                if ((user.apartmentName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _tile(
                    Icons.event_rounded,
                    'Event',
                    user.apartmentName!,
                    const Color(0xFF3B82F6),
                  ),
                ],
                const SizedBox(height: 12),
                _passwordCard(),
              ],
            ),
    );
  }

  Widget _buildParticipantBadgeView(UserModel user) {
    final idNumber = (user.employeeId ?? '').isNotEmpty
        ? user.employeeId!
        : (user.apartmentId ?? user.id);
    final qrData = idNumber;

    final registrationMap = {
      'name': user.name,
      'title': '',
      'participantType': 'DELEGATE',
      'idNumber': idNumber,
      'designation': user.department ?? '',
      'institution': user.apartmentName ?? '',
      'qrCode': qrData,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DelegateBadge(registration: registrationMap),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  'ID: $idNumber   •   ${user.mobileNumber}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const InclusionsSection(),
        ],
      ),
    );
  }

  InputDecoration _pwDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(
        color: const Color(0xFF9CA3AF),
        fontSize: 14.5,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF0A0A12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFF3B82F6), width: 1.4),
      ),
    );
  }

  Widget _eye(bool obscured, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(
      obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: const Color(0xFF9CA3AF),
      size: 20,
    ),
  );

  Widget _passwordCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: const Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Enter current password to set a new one',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currentPw,
            obscureText: _obscureCurrent,
            textInputAction: TextInputAction.next,
            decoration: _pwDecoration(
              'Current password',
              Icons.lock_outline_rounded,
              suffix: _eye(
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPw,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.next,
            decoration: _pwDecoration(
              'New password',
              Icons.lock_rounded,
              suffix: _eye(
                _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPw,
            obscureText: _obscureNew,
            textInputAction: TextInputAction.done,
            decoration: _pwDecoration(
              'Confirm new password',
              Icons.lock_rounded,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _savingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _savingPassword
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dark ID-card style block with the photo and name.
  Widget _idCard(UserModel user) {
    final hasPhoto = user.profilePic != null && user.profilePic!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                          )
                        : Center(
                            child: Text(
                              user.name.trim().isEmpty
                                  ? '?'
                                  : user.name.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ),
                if (_uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CA3AF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
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
                      color: const Color(0xFF14141F),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: const Color(0xFF3B82F6),
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
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleLabel(user),
                  style: const TextStyle(color: Colors.white60, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
