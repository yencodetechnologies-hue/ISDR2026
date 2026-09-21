import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/models/apartment_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/navigation/app_navigation.dart';
import '../../../../../../core/routes/app_routes.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../../../core/widgets/identity_document_card.dart';
import '../../../../../../core/widgets/property_document_upload_card.dart';
import '../../../../../../core/utils/current_property_context.dart';
import 'profile_qr_sheet.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';

class ProfileTab extends StatefulWidget {
  final UserModel user;
  final bool isHostel;

  const ProfileTab({
    super.key,
    required this.user,
    this.isHostel = false,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _uploadingPhoto = false;

  UserModel get user => widget.user;
  bool get isHostel => widget.isHostel;

  Future<void> _pickAndUploadProfilePic() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppTheme.primaryColor),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleImageSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleImageSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageSource(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final result = await _apiService.updateUser(
        userId: user.id,
        profilePic: File(picked.path),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        context.read<AuthBloc>().add(RefreshCurrentUserEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? 'Failed to update photo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Profile Header Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Top Dark Brand Gradient Hero
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Profile Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Profile Avatar
                            GestureDetector(
                              onTap: _uploadingPhoto ? null : _pickAndUploadProfilePic,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF2563EB), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 34,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      child: _uploadingPhoto
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : (user.profilePic != null && user.profilePic!.isNotEmpty
                                              ? ClipOval(
                                                  child: Image.network(
                                                    user.profilePic!,
                                                    fit: BoxFit.cover,
                                                    width: 68,
                                                    height: 68,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person_rounded,
                                                  size: 38,
                                                  color: Color(0xFF0F172A),
                                                )),
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: user.status == AccountStatus.approved
                                          ? const Color(0xFFDCFCE7)
                                          : user.status == AccountStatus.pending
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          user.status == AccountStatus.approved
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_rounded,
                                          size: 13,
                                          color: user.status == AccountStatus.approved
                                              ? const Color(0xFF166534)
                                              : const Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          user.status.name.toUpperCase(),
                                          style: TextStyle(
                                            color: user.status == AccountStatus.approved
                                                ? const Color(0xFF166534)
                                                : const Color(0xFFB45309),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (user.status == AccountStatus.approved) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final currentProp = resolveCurrentProperty(user);
                              final propType = currentProp?.propertyType ?? user.propertyType ?? (user.apartments != null && user.apartments!.isNotEmpty ? user.apartments!.first.propertyType : null);
                              final isStaffSchoolOrCollege = false;
                              final btnLabel = isHostel
                                  ? 'Digital Hostel ID'
                                  : (isStaffSchoolOrCollege ? 'View Staff Entry Pass' : 'View Digital Access Pass');

                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showQrCodeBottomSheet(context, user),
                                  icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                                  label: Text(
                                    btnLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.2,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    minimumSize: const Size(double.infinity, 48),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content Sections Container
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Personal Details Card Group
                  _buildSectionHeader('Personal Information', Icons.person_rounded),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildProfileFieldTile(
                          label: 'Username',
                          value: user.username,
                          icon: Icons.alternate_email_rounded,
                          iconBgColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildProfileFieldTile(
                          label: 'Email Address',
                          value: user.email,
                          icon: Icons.mail_outline_rounded,
                          iconBgColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildProfileFieldTile(
                          label: 'Mobile Number',
                          value: user.mobileNumber,
                          icon: Icons.phone_enabled_rounded,
                          iconBgColor: const Color(0xFFECFDF5),
                          iconColor: const Color(0xFF10B981),
                        ),
                        if (user.secondaryMobileNumber != null && user.secondaryMobileNumber!.isNotEmpty) ...[
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildProfileFieldTile(
                            label: 'Secondary Contact',
                            value: user.secondaryMobileNumber!,
                            icon: Icons.phone_iphone_rounded,
                            iconBgColor: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF10B981),
                          ),
                        ],
                        if (user.gender != null) ...[
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildProfileFieldTile(
                            label: 'Gender',
                            value: user.gender!.name.toUpperCase(),
                            icon: Icons.person_search_rounded,
                            iconBgColor: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                          ),
                        ],
                        if (user.address != null && user.address!.isNotEmpty) ...[
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildProfileFieldTile(
                            label: 'Residential Address',
                            value: user.address!,
                            icon: Icons.home_rounded,
                            iconBgColor: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Company Details Section
                  if ((user.department != null && user.department!.isNotEmpty) ||
                      (user.employeeId != null && user.employeeId!.isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Work / Company Information', Icons.work_rounded),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          if (user.department != null && user.department!.isNotEmpty)
                            _buildProfileFieldTile(
                              label: 'Department',
                              value: user.department!,
                              icon: Icons.corporate_fare_rounded,
                              iconBgColor: const Color(0xFFF1F5F9),
                              iconColor: const Color(0xFF0F172A),
                            ),
                          if (user.employeeId != null && user.employeeId!.isNotEmpty) ...[
                            if (user.department != null && user.department!.isNotEmpty)
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildProfileFieldTile(
                              label: 'Employee ID',
                              value: user.employeeId!,
                              icon: Icons.badge_rounded,
                              iconBgColor: const Color(0xFFF1F5F9),
                              iconColor: const Color(0xFF0F172A),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Hostel Details Section
                  if ((user.hostelRoom != null && user.hostelRoom!.isNotEmpty) ||
                      (user.hostelBed != null && user.hostelBed!.isNotEmpty)) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Hostel Room Info', Icons.hotel_rounded),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          if (user.hostelRoom != null && user.hostelRoom!.isNotEmpty)
                            _buildProfileFieldTile(
                              label: 'Room Number',
                              value: user.hostelRoom!,
                              icon: Icons.door_front_door_rounded,
                              iconBgColor: const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF2563EB),
                            ),
                          if (user.hostelBed != null && user.hostelBed!.isNotEmpty) ...[
                            if (user.hostelRoom != null && user.hostelRoom!.isNotEmpty)
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildProfileFieldTile(
                              label: 'Bed Allocated',
                              value: user.hostelBed!,
                              icon: Icons.single_bed_rounded,
                              iconBgColor: const Color(0xFFECFDF5),
                              iconColor: const Color(0xFF10B981),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Tenant Details Section (non-school staff)
                  Builder(
                    builder: (context) {
                      final currentProp = resolveCurrentProperty(user);
                      final propType = currentProp?.propertyType ?? user.propertyType ?? (user.apartments != null && user.apartments!.isNotEmpty ? user.apartments!.first.propertyType : null);
                      final isStaffSchoolOrCollege = false;

                      if (isStaffSchoolOrCollege || propType == PropertyType.events) {
                        return const SizedBox.shrink();
                      }

                      final showHeader = !isHostel &&
                          (user.familyType != null ||
                              user.totalOccupants != null ||
                              user.block != null ||
                              user.floor != null ||
                              user.roomNumber != null);

                      if (!showHeader) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSectionHeader('Property Unit Info', Icons.other_houses_rounded),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                if (user.block != null && user.block!.isNotEmpty)
                                  _buildProfileFieldTile(
                                    label: 'Block',
                                    value: user.block!,
                                    icon: Icons.apartment_rounded,
                                    iconBgColor: const Color(0xFFECFDF5),
                                    iconColor: const Color(0xFF10B981),
                                  ),
                                if (user.floor != null && user.floor!.isNotEmpty) ...[
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  _buildProfileFieldTile(
                                    label: 'Floor',
                                    value: user.floor!,
                                    icon: Icons.stairs_rounded,
                                    iconBgColor: const Color(0xFFFFFBEB),
                                    iconColor: const Color(0xFFD97706),
                                  ),
                                ],
                                if (user.roomNumber != null && user.roomNumber!.isNotEmpty) ...[
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  _buildProfileFieldTile(
                                    label: 'Unit / Door Number',
                                    value: user.roomNumber!,
                                    icon: Icons.door_front_door_rounded,
                                    iconBgColor: const Color(0xFFEFF6FF),
                                    iconColor: const Color(0xFF2563EB),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Documents Section
                  if (user.aadhaarCard != null || user.panCard != null ||
                      user.aadhaarCardFrontImage != null || user.aadhaarCardBackImage != null ||
                      user.panCardImage != null) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader('Identity Documents', Icons.shield_rounded),
                    const SizedBox(height: 10),
                  ],
                  if (user.aadhaarCard != null && user.aadhaarCard!.isNotEmpty) ...[
                    _buildCompactInfoCard(
                      'Aadhaar',
                      user.aadhaarCard!,
                      Icons.badge_outlined,
                      const Color(0xFF059669),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (user.aadhaarCardFrontImage != null || user.aadhaarCardBackImage != null) ...[
                    IdentityDocumentPair(
                      frontImageUrl: user.aadhaarCardFrontImage,
                      backImageUrl: user.aadhaarCardBackImage,
                      frontLabel: 'Identity card — front',
                      backLabel: 'Identity card — back',
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (user.panCard != null && user.panCard!.isNotEmpty) ...[
                    _buildCompactInfoCard(
                      'PAN Card',
                      user.panCard!,
                      Icons.credit_card_outlined,
                      const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (user.panCardImage != null) ...[
                    _buildCompactImageCard(
                      'PAN Card',
                      user.panCardImage!,
                    ),
                  ],

                  const SizedBox(height: 16),
                  PropertyDocumentsSection(
                    apartmentId: user.apartmentId,
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Account Management Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showDeleteAccountBottomSheet(context);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          label: const Text(
                            'Delete Account',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                              context.read<AuthBloc>().add(LogoutEvent());
                              AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
                            });
                          },
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrCodeBottomSheet(BuildContext context, UserModel user) {
    String? hostelName;
    if (isHostel && user.apartments != null) {
      for (final a in user.apartments!) {
        if (false) {
          hostelName = a.name;
          break;
        }
      }
      hostelName ??= user.apartments!.isNotEmpty ? user.apartments!.first.name : null;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileQrSheet(
        user: user,
        isHostel: isHostel,
        hostelName: hostelName,
      ),
    );
  }

  void _showDeleteAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Warning icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            // Message
            const Text(
              'Are you sure you want to delete the account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmationMessage(context);
                    },
                    style: AppTheme.errorElevatedStyle.copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      elevation: WidgetStateProperty.all(0),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Account will be deleted within 24 hours',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildProfileFieldTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactImageCard(String label, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 100,
                  color: const Color(0xFFF8FAFC),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.grey[400], size: 24),
                      const SizedBox(height: 4),
                      Text(
                        'Failed',
                        style: TextStyle(color: Colors.grey[600], fontSize: 9),
                      ),
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 100,
                  color: const Color(0xFFF8FAFC),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

