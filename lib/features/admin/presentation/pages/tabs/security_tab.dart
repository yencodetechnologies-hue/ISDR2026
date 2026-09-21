import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/widgets/brand_form_bottom_sheet.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../bloc/admin_bloc.dart';

class SecurityTab extends StatefulWidget {
  final AdminLoaded state;

  const SecurityTab({required this.state});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterSecurityStaff(List<UserModel> staff) {
    if (_searchQuery.isEmpty) return staff;
    final q = _searchQuery.toLowerCase();
    return staff.where((s) {
      return (s.name.toLowerCase().contains(q)) ||
          (s.email.toLowerCase().contains(q)) ||
          (s.mobileNumber.toLowerCase().contains(q));
    }).toList();
  }

  void _showAddSecurityDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddSecuritySheetContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentState = widget.state;
    final filteredStaff = _filterSecurityStaff(currentState.securityStaff);
        
    final hasApartmentSelected = currentState.selectedApartmentId != null &&
        (currentState.selectedApartmentId ?? '').isNotEmpty;

    return Column(
      children: [
        if (!hasApartmentSelected)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFFC2410C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Open a property from the property list to view and add security staff.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              _SecurityHeaderStat(
                icon: Icons.shield_outlined,
                label: 'Security Staff',
                value: '${currentState.securityStaff.length}',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 12),
              BrandGradientCtaButton(
                label: 'Add Security Staff',
                icon: Icons.add_circle_outline_rounded,
                height: 50,
                onPressed: () => _showAddSecurityDialog(context),
              ),
            ],
          ),
        ),
        if (currentState.securityStaff.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, mobile...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFECECEA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFECECEA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        Expanded(
          child: currentState.securityStaff.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacityCompat(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacityCompat(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              size: 36,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Security Staff Added Yet',
                            style: GoogleFonts.sora(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add security personnel to manage gates, visitor verifications, and shifts for this property.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : filteredStaff.isEmpty
                  ? Center(
                      child: Text(
                        'No results for "$_searchQuery"',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: filteredStaff.length,
                      itemBuilder: (context, index) {
                        final security = filteredStaff[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFECECEA),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacityCompat(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Profile Avatar
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryColor,
                                    border: Border.all(
                                      color: const Color(0xFFECECEA),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: security.profilePic != null && security.profilePic!.isNotEmpty
                                        ? Image.network(
                                            security.profilePic!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                (security.name ?? 'S')
                                                    .trim()
                                                    .split(' ')
                                                    .map((e) => e.isNotEmpty ? e[0] : '')
                                                    .take(2)
                                                    .join()
                                                    .toUpperCase(),
                                                style: GoogleFonts.sora(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              (security.name ?? 'S')
                                                  .trim()
                                                  .split(' ')
                                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                                  .take(2)
                                                  .join()
                                                  .toUpperCase(),
                                              style: GoogleFonts.sora(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Info Section
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              security.name ?? 'No name',
                                              style: GoogleFonts.sora(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: security.isActive
                                                  ? const Color(0xFFECFDF5)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: security.isActive
                                                    ? const Color(0xFFA7F3D0)
                                                    : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: security.isActive
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  security.isActive ? 'Active' : 'Inactive',
                                                  style: GoogleFonts.inter(
                                                    color: security.isActive
                                                        ? const Color(0xFF047857)
                                                        : const Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.email_outlined,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              security.email ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color: const Color(0xFF475569),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_outlined,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            security.mobileNumber ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Actions Section
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Material(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                          child: InkWell(
                                            onTap: () => _showEditSecurityDialog(context, security),
                                            borderRadius: BorderRadius.circular(8),
                                            child: const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: Icon(
                                                Icons.edit_rounded,
                                                size: 18,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Material(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                          child: InkWell(
                                            onTap: () => _showDeleteSecurityDialog(context, security),
                                            borderRadius: BorderRadius.circular(8),
                                            child: const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: security.isActive,
                                        onChanged: (value) {
                                          context.read<AdminBloc>().add(
                                                ToggleUserActiveEvent(security.id),
                                              );
                                        },
                                        activeColor: AppTheme.primaryColor,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showEditSecurityDialog(BuildContext context, UserModel security) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _EditSecuritySheetContent(security: security),
    );
  }

  void _showDeleteSecurityDialog(BuildContext context, UserModel security) {
    showDialog(
      context: context,
      builder: (context) => BlocListener<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminLoaded) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Security staff deleted successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, blocState) {
            final isLoading = blocState is AdminLoading;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Delete Security Staff?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete ${security.name}?',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.read<AdminBloc>().add(
                                DeleteSecurityEvent(securityId: security.id),
                              );
                        },
                  style: AppTheme.errorElevatedStyle,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Stateful content for Add Security bottom sheet. Owns [TextEditingController]s
/// and disposes them in [dispose] to avoid "used after disposed" when the
/// route is popped.
class _AddSecuritySheetContent extends StatefulWidget {
  const _AddSecuritySheetContent();

  @override
  State<_AddSecuritySheetContent> createState() => _AddSecuritySheetContentState();
}

class _AddSecuritySheetContentState extends State<_AddSecuritySheetContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  late final TextEditingController _passwordController;
  File? _profilePic;
  File? _idProof;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _mobileController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter mobile number'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email ID'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter password'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    context.read<AdminBloc>().add(
      AddSecurityEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        password: _passwordController.text.trim(),
        profilePic: _profilePic,
        idProof: _idProof,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BrandFormBottomSheet(
      title: 'Add Security Staff',
      subtitle: 'Enter security staff details and upload images',
      headerIcon: Icons.security_rounded,
      submitLabel: 'Add Security Staff',
      submitIcon: Icons.person_add_alt_1_rounded,
      onCancel: () => Navigator.pop(context),
      onSubmit: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (image != null) setState(() => _profilePic = File(image.path));
              },
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(
                            color: _profilePic != null ? AppTheme.primaryColor : const Color(0xFFECECEA),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacityCompat(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _profilePic != null
                            ? ClipOval(child: Image.file(_profilePic!, fit: BoxFit.cover))
                            : const Icon(Icons.person_add_alt_1_rounded, size: 40, color: Color(0xFF64748B)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            _profilePic != null ? Icons.check_rounded : Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profile Picture',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: brandFormInputDecoration(label: 'Full Name', icon: Icons.person_rounded),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: brandFormInputDecoration(label: 'Mobile Number', icon: Icons.phone_rounded),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: brandFormInputDecoration(label: 'Email ID', icon: Icons.email_rounded),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: brandFormInputDecoration(
              label: 'Password',
              icon: Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (image != null) setState(() => _idProof = File(image.path));
            },
            child: Container(
              height: 115,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _idProof != null ? AppTheme.primaryColor : const Color(0xFFECECEA),
                  width: _idProof != null ? 2 : 1.2,
                ),
              ),
              child: _idProof != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_idProof!, fit: BoxFit.cover, width: double.infinity),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacityCompat(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            size: 24,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload ID Proof / Aadhaar',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload photo of ID proof for verification',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'ID Proof Document',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stateful content for Edit Security bottom sheet. Owns [TextEditingController]s
/// and disposes them in [dispose] to avoid "used after disposed" when
/// BlocListener pops the route on AdminLoaded.
class _EditSecuritySheetContent extends StatefulWidget {
  final UserModel security;

  const _EditSecuritySheetContent({required this.security});

  @override
  State<_EditSecuritySheetContent> createState() => _EditSecuritySheetContentState();
}

class _EditSecuritySheetContentState extends State<_EditSecuritySheetContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  late final TextEditingController _passwordController;
  File? _profilePic;
  File? _idProof;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.security.name);
    _emailController = TextEditingController(text: widget.security.email);
    _mobileController = TextEditingController(text: widget.security.mobileNumber);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter mobile number'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email ID'), backgroundColor: Colors.red),
      );
      return;
    }
    context.read<AdminBloc>().add(
      UpdateSecurityEvent(
        securityId: widget.security.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        password: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        profilePic: _profilePic,
        idProof: _idProof,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final security = widget.security;
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is AdminLoaded) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Security staff updated successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        } else if (state is AdminError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      },
      child: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, blocState) {
          final isLoading = blocState is AdminLoading;
          return BrandFormBottomSheet(
            title: 'Edit Security Staff',
            subtitle: 'Update security staff details',
            headerIcon: Icons.security_rounded,
            submitLabel: 'Update Security',
            submitIcon: Icons.save_rounded,
            isSubmitLoading: isLoading,
            onCancel: () => Navigator.pop(context),
            onSubmit: isLoading ? null : _submit,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => _profilePic = File(image.path));
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: _profilePic != null || (security.profilePic != null && security.profilePic!.isNotEmpty)
                                      ? AppTheme.primaryColor
                                      : const Color(0xFFECECEA),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacityCompat(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _profilePic != null
                                  ? ClipOval(child: Image.file(_profilePic!, fit: BoxFit.cover))
                                  : security.profilePic != null && security.profilePic!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            security.profilePic!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person_add_alt_1_rounded, size: 40, color: Color(0xFF64748B)),
                                          ),
                                        )
                                      : const Icon(Icons.person_add_alt_1_rounded, size: 40, color: Color(0xFF64748B)),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  _profilePic != null || (security.profilePic != null && security.profilePic!.isNotEmpty)
                                      ? Icons.check_rounded
                                      : Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Profile Picture',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: brandFormInputDecoration(label: 'Full Name', icon: Icons.person_rounded),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: brandFormInputDecoration(label: 'Mobile Number', icon: Icons.phone_rounded),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: brandFormInputDecoration(label: 'Email ID', icon: Icons.email_rounded),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: brandFormInputDecoration(
                    label: 'Password (optional)',
                    icon: Icons.lock_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (image != null) setState(() => _idProof = File(image.path));
                  },
                  child: Container(
                    height: 115,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _idProof != null || (security.aadhaarCardFrontImage != null && security.aadhaarCardFrontImage!.isNotEmpty)
                            ? AppTheme.primaryColor
                            : const Color(0xFFECECEA),
                        width: _idProof != null || (security.aadhaarCardFrontImage != null && security.aadhaarCardFrontImage!.isNotEmpty)
                            ? 2
                            : 1.2,
                      ),
                    ),
                    child: _idProof != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_idProof!, fit: BoxFit.cover, width: double.infinity),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          )
                        : security.aadhaarCardFrontImage != null && security.aadhaarCardFrontImage!.isNotEmpty
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      security.aadhaarCardFrontImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) => Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacityCompat(0.08),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.badge_outlined,
                                              size: 24,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap to upload ID Proof / Aadhaar',
                                            style: GoogleFonts.sora(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacityCompat(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.badge_outlined,
                                      size: 24,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to upload ID Proof / Aadhaar',
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Upload photo of ID proof for verification',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'ID Proof Document',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SecurityHeaderStat extends StatelessWidget {
  const _SecurityHeaderStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFECECEA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacityCompat(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
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
