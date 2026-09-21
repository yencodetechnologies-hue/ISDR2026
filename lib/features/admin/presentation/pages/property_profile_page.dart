import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class PropertyProfilePage extends StatefulWidget {
  const PropertyProfilePage({
    super.key,
    required this.apartment,
    required this.canEdit,
    this.onSaved,
  });

  final ApartmentModel apartment;
  final bool canEdit;
  final VoidCallback? onSaved;

  @override
  State<PropertyProfilePage> createState() => _PropertyProfilePageState();
}

class _PropertyProfilePageState extends State<PropertyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  late final TextEditingController _wardenNameController;
  late final TextEditingController _wardenContactController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _loading = true;
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;
  late PropertyType _propertyType;

  @override
  void initState() {
    super.initState();
    _propertyType = widget.apartment.propertyType;
    _nameController = TextEditingController(text: widget.apartment.name);
    _emailController = TextEditingController(text: widget.apartment.email);
    _mobileController = TextEditingController(text: widget.apartment.contactPhone);
    _wardenNameController = TextEditingController(text: widget.apartment.wardenName);
    _wardenContactController = TextEditingController(text: widget.apartment.wardenContact);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _loadApartment();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _wardenNameController.dispose();
    _wardenContactController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadApartment() async {
    try {
      final res = await _apiService.getApartment(widget.apartment.id);
      if (!mounted) return;
      if (res['success'] == true) {
        final raw = res['apartment'];
        if (raw is Map) {
          final apt = ApartmentModel.fromJson(Map<String, dynamic>.from(raw));
          _nameController.text = apt.name;
          _emailController.text = apt.email;
          _mobileController.text = apt.contactPhone;
          _wardenNameController.text = apt.wardenName;
          _wardenContactController.text = apt.wardenContact;
          _propertyType = apt.propertyType;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _pageTitle {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Apartment Profile';
      case PropertyType.company:
        return 'Company Profile';
      case PropertyType.hostel:
        return 'Hostel Profile';
      case PropertyType.college:
        return 'College / School Profile';
      case PropertyType.events:
        return 'Events Management Profile';
    }
  }

  String get _nameLabel {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Apartment name *';
      case PropertyType.company:
        return 'Company name *';
      case PropertyType.hostel:
        return 'Hostel name *';
      case PropertyType.college:
        return 'College or school name *';
      case PropertyType.events:
        return 'Event organizer name *';
    }
  }

  IconData get _propertyIcon {
    switch (_propertyType) {
      case PropertyType.apartment:
        return Icons.apartment_rounded;
      case PropertyType.company:
        return Icons.business_rounded;
      case PropertyType.hostel:
        return Icons.night_shelter_rounded;
      case PropertyType.college:
        return Icons.school_rounded;
      case PropertyType.events:
        return Icons.event_rounded;
    }
  }

  String get _propertySubtitle {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Manage apartment contact details';
      case PropertyType.company:
        return 'Manage company contact details';
      case PropertyType.hostel:
        return 'Manage hostel & warden details';
      case PropertyType.college:
        return 'Manage college/school & management details';
      case PropertyType.events:
        return 'Manage event organizer account details';
    }
  }

  bool get _isHostel => _propertyType == PropertyType.hostel;

  bool get _isManagementLogin {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.user.userType == UserType.apartment;
  }

  String? _validatePhone10(String? v, {required String emptyMsg}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return emptyMsg;
    if (s.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^\d{10}$').hasMatch(s)) return 'Enter digits only';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email ID is required';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final changingPassword =
        newPassword.isNotEmpty || confirmPassword.isNotEmpty || currentPassword.isNotEmpty;

    if (changingPassword) {
      if (currentPassword.isEmpty) {
        setState(() => _error = 'Enter your current password to set a new one');
        return;
      }
      if (newPassword.length < 6) {
        setState(() => _error = 'New password must be at least 6 characters');
        return;
      }
      if (newPassword != confirmPassword) {
        setState(() => _error = 'New password and confirmation do not match');
        return;
      }
    }

    setState(() => _saving = true);

    final authState = context.read<AuthBloc>().state;
    final isManagementLogin =
        authState is AuthAuthenticated && authState.user.userType == UserType.apartment;

    final Map<String, dynamic> result;
    if (isManagementLogin) {
      result = await _apiService.updateManagementProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        currentPassword: changingPassword ? currentPassword : null,
        newPassword: changingPassword ? newPassword : null,
        wardenName: _isHostel ? _wardenNameController.text.trim() : null,
        wardenContact: _isHostel ? _wardenContactController.text.trim() : null,
      );
    } else {
      result = await _apiService.updateApartment(
        id: widget.apartment.id,
        name: _nameController.text.trim(),
        contactPhone: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        wardenName: _isHostel ? _wardenNameController.text.trim() : null,
        wardenContact: _isHostel ? _wardenContactController.text.trim() : null,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      if (authState is AuthAuthenticated &&
          authState.user.userType == UserType.apartment) {
        context.read<AuthBloc>().add(RefreshCurrentUserEvent());
      }
      widget.onSaved?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              changingPassword
                  ? 'Profile and password updated successfully'
                  : 'Profile updated successfully',
            ),
            backgroundColor: const Color(0xFF13275D),
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    setState(() => _error = result['error'] as String? ?? 'Failed to update profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF9),
      appBar: buildBrandGradientAppBar(title: Text(_pageTitle)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF13275D)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 16),
                    if (!widget.canEdit) ...[
                      _buildInfoBanner(
                        icon: Icons.lock_outline_rounded,
                        message: _isHostel
                            ? 'Only the hostel owner can edit property details.'
                            : 'Only the property owner can edit these details.',
                        bgColor: const Color(0xFF13275D).withOpacity(0.08),
                        iconColor: const Color(0xFF13275D),
                        textColor: const Color(0xFF13275D),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_error != null) ...[
                      _buildInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: _error!,
                        bgColor: const Color(0xFFFEF2F2),
                        iconColor: const Color(0xFFDC2626),
                        textColor: const Color(0xFF991B1B),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildSectionCard(
                      title: 'Property Information',
                      icon: _propertyIcon,
                      children: [
                        _buildStyledField(
                          controller: _nameController,
                          label: _nameLabel,
                          icon: _propertyIcon,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildStyledField(
                          controller: _emailController,
                          label: 'Email *',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        _buildStyledField(
                          controller: _mobileController,
                          label: 'Mobile number *',
                          icon: Icons.phone_outlined,
                          helperText: _isHostel ? 'Owner login mobile' : null,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          validator: (v) =>
                              _validatePhone10(v, emptyMsg: 'Mobile number is required'),
                        ),
                      ],
                    ),
                    if (_isHostel) ...[
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Warden Details',
                        icon: Icons.shield_outlined,
                        subtitle:
                            'Warden can sign in via Management login with warden mobile and property password.',
                        children: [
                          _buildStyledField(
                            controller: _wardenNameController,
                            label: 'Warden name *',
                            hint: 'Full name of warden',
                            icon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) {
                              if (!_isHostel || !widget.canEdit) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Warden name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildStyledField(
                            controller: _wardenContactController,
                            label: 'Warden mobile number *',
                            hint: '10-digit number',
                            icon: Icons.phone_rounded,
                            helperText: 'Warden login mobile',
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (v) {
                              if (!_isHostel || !widget.canEdit) return null;
                              final phoneError = _validatePhone10(
                                v,
                                emptyMsg: 'Warden mobile number is required',
                              );
                              if (phoneError != null) return phoneError;
                              if (v!.trim() == _mobileController.text.trim()) {
                                return 'Owner mobile and warden mobile must be different';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ],
                    if (widget.canEdit && _isManagementLogin) ...[
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Change Password',
                        icon: Icons.lock_outline_rounded,
                        subtitle: 'Leave blank to keep your current password',
                        children: [
                          _buildStyledField(
                            controller: _currentPasswordController,
                            label: 'Current password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureCurrent,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscureCurrent = !_obscureCurrent),
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF8C8C90),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildStyledField(
                            controller: _newPasswordController,
                            label: 'New password',
                            icon: Icons.lock_rounded,
                            obscureText: _obscureNew,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF8C8C90),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildStyledField(
                            controller: _confirmPasswordController,
                            label: 'Confirm new password',
                            icon: Icons.lock_rounded,
                            obscureText: _obscureNew,
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ],
                    if (widget.canEdit) ...[
                      const SizedBox(height: 24),
                      BrandGradientCtaButton(
                        label: 'Save Profile',
                        icon: Icons.check_rounded,
                        isLoading: _saving,
                        onPressed: _saving ? null : _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroHeader() {
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.apartment.name;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _propertyIcon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _propertySubtitle,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isHostel) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.canEdit ? 'Owner Access' : 'View Only',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String message,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFECECEA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF13275D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF13275D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8C8C90),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final enabled = widget.canEdit && !_saving;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: !widget.canEdit,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      maxLength: maxLength,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF13275D),
        ),
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF94A3B8),
        ),
        helperText: helperText,
        helperStyle: GoogleFonts.inter(
          fontSize: 11.5,
          color: const Color(0xFF8C8C90),
        ),
        counterText: maxLength != null ? '' : null,
        filled: true,
        fillColor: enabled ? const Color(0xFFFAFAF9) : const Color(0xFFF1F5F9),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF13275D),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFECECEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFECECEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

