import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/services/api_service.dart';

class CreateApartmentPage extends StatefulWidget {
  const CreateApartmentPage({super.key});

  @override
  State<CreateApartmentPage> createState() => _CreateApartmentPageState();
}

class _CreateApartmentPageState extends State<CreateApartmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerMobileController = TextEditingController();
  final _wardenNameController = TextEditingController();
  final _wardenContactController = TextEditingController();
  final _emailController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  PropertyType _propertyType = PropertyType.apartment;
  String _hostelType = 'co-living';
  String _institutionType = 'private';

  static const _institutionOptions = <MapEntry<String, String>>[
    MapEntry('autonomous', 'Autonomous'),
    MapEntry('government', 'Government'),
    MapEntry('government_aided', 'Government Aided'),
    MapEntry('private', 'Private'),
    MapEntry('others', 'Others'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ownerNameController.dispose();
    _ownerMobileController.dispose();
    _wardenNameController.dispose();
    _wardenContactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _pageTitle {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Create Apartment';
      case PropertyType.company:
        return 'Create Company';
      case PropertyType.hostel:
        return 'Create Hostel';
      case PropertyType.college:
        return 'Create College / School';
      case PropertyType.events:
        return 'Create Events Management';
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

  String get _createButtonLabel {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Create Apartment';
      case PropertyType.company:
        return 'Create Company';
      case PropertyType.hostel:
        return 'Create Hostel';
      case PropertyType.college:
        return 'Create College / School';
      case PropertyType.events:
        return 'Create Events Management';
    }
  }

  Future<void> _submit() async {
    _error = null;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final isHostel = _propertyType == PropertyType.hostel;
    final isCollege = _propertyType == PropertyType.college;
    final isEvents = _propertyType == PropertyType.events;
    final result = await _apiService.createApartment(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      contactPhone: isHostel
          ? _ownerMobileController.text.trim()
          : (_contactPhoneController.text.trim().isEmpty
              ? null
              : _contactPhoneController.text.trim()),
      password: _passwordController.text,
      propertyType: _propertyType.name,
      hostelType: isHostel ? _hostelType : null,
      roomType: null,
      bedCountPerRoom: null,
      ownerName: isHostel || isCollege || isEvents
          ? (isEvents
              ? _nameController.text.trim()
              : _ownerNameController.text.trim())
          : null,
      ownerMobile: isHostel ? _ownerMobileController.text.trim() : null,
      wardenName: isHostel ? _wardenNameController.text.trim() : null,
      wardenContact: isHostel ? _wardenContactController.text.trim() : null,
      email: isHostel ||
              _propertyType == PropertyType.company ||
              isCollege ||
              isEvents
          ? _emailController.text.trim()
          : null,
      institutionType: isCollege ? _institutionType : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      final aptMap = result['apartment'] as Map<String, dynamic>?;
      final apartment = aptMap != null ? ApartmentModel.fromJson(aptMap) : null;
      Navigator.pop(context, apartment);
    } else {
      setState(() => _error = result['error'] as String? ?? 'Failed to create property');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCollege = _propertyType == PropertyType.college;
    final isHostel = _propertyType == PropertyType.hostel;
    final isEvents = _propertyType == PropertyType.events;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_pageTitle),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const Text(
                'Property Type *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PropertyType>(
                    value: _propertyType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textColor),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor),
                    items: PropertyType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _propertyType = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isEvents) ...[
                _HostelSectionHeader(
                  title: 'Event organizer account',
                  subtitle:
                      'Organizer signs in with Management/Apartment login using mobile and password. 30-day free trial starts on create.',
                  icon: Icons.event_available_outlined,
                ),
                const SizedBox(height: 12),
              ],
              _buildCleanFormField(
                controller: _nameController,
                labelText: _nameLabel,
                hintText: _propertyType == PropertyType.apartment
                    ? 'e.g. Sunrise Residency'
                    : _propertyType == PropertyType.company
                        ? 'e.g. Tech Corp Pvt Ltd'
                        : isCollege
                            ? 'e.g. ABC Engineering College'
                            : isEvents
                                ? 'e.g. Raj Events'
                                : 'e.g. Boys Hostel A',
                icon: isEvents
                    ? Icons.event_rounded
                    : isCollege
                        ? Icons.school_rounded
                        : _propertyType == PropertyType.company
                            ? Icons.business_rounded
                            : Icons.apartment_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return isEvents
                        ? 'Event organizer name is required'
                        : 'Name is required';
                  }
                  return null;
                },
              ),
              if (isHostel) ...[
                const SizedBox(height: 14),
                const Text(
                  'Hostel Type *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textColor),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _hostelType,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textColor),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor),
                      items: const [
                        DropdownMenuItem(value: 'co-living', child: Text('Co-living')),
                        DropdownMenuItem(value: 'girls_hostel', child: Text('Girls hostel')),
                        DropdownMenuItem(value: 'boys_hostel', child: Text('Boys hostel')),
                        DropdownMenuItem(value: 'others', child: Text('Others')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _hostelType = v);
                      },
                    ),
                  ),
                ),
              ],
              if (isCollege) ...[
                const SizedBox(height: 14),
                const Text(
                  'College or school type *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textColor),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _institutionType,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textColor),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor),
                      items: _institutionOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _institutionType = v);
                      },
                    ),
                  ),
                ),
              ],
              if (!isEvents) ...[
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _addressController,
                  labelText: isHostel || isCollege
                      ? (isCollege ? 'College or school address *' : 'Hostel address *')
                      : 'Address',
                  hintText: 'Full address',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if ((isHostel || isCollege) && (v == null || v.trim().isEmpty)) {
                      return isCollege
                          ? 'College/school address is required'
                          : 'Hostel address is required';
                    }
                    return null;
                  },
                ),
              ],
              if (!isHostel && !isCollege && !isEvents) ...[
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _contactPhoneController,
                  labelText: 'Mobile number *',
                  hintText: '10-digit number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                    if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
              ],
              if (isEvents) ...[
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _emailController,
                  labelText: 'Event organizer email *',
                  hintText: 'e.g. organizer@events.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email ID is required';
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _contactPhoneController,
                  labelText: 'Event organizer mobile number *',
                  hintText: '10-digit number for login',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Event organizer mobile number is required';
                    }
                    if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
              ],
              if (isCollege) ...[
                const SizedBox(height: 16),
                _HostelSectionHeader(
                  title: 'Management account',
                  subtitle:
                      'Management signs in with Login type Management/Apartment using mobile and password below. 30-day free trial starts on create.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _ownerNameController,
                  labelText: 'Management person name *',
                  hintText: 'Full name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Management person name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _contactPhoneController,
                  labelText: 'Management mobile number *',
                  hintText: '10-digit number for login',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Management mobile number is required';
                    }
                    if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _emailController,
                  labelText: 'Management email ID *',
                  hintText: 'e.g. principal@college.edu',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email ID is required';
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
              if (isHostel) ...[
                const SizedBox(height: 16),
                _HostelSectionHeader(
                  title: 'Owner account (management login)',
                  subtitle:
                      'The owner signs in with Login type Apartment/Property, using owner mobile and password below.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _ownerNameController,
                  labelText: 'Owner name *',
                  hintText: 'Full name of hostel owner',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Owner name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _ownerMobileController,
                  labelText: 'Owner mobile number *',
                  hintText: '10-digit number for login',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Owner mobile number is required';
                    }
                    if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _HostelSectionHeader(
                  title: 'Warden details',
                  subtitle:
                      'Warden can also sign in via Management login using warden mobile and the property password below.',
                  icon: Icons.supervisor_account_outlined,
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _wardenNameController,
                  labelText: 'Warden name *',
                  hintText: 'Full name of warden',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Warden name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _wardenContactController,
                  labelText: 'Warden mobile number *',
                  hintText: '10-digit number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Warden mobile number is required';
                    if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _emailController,
                  labelText: 'Email ID *',
                  hintText: 'e.g. hostel@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email ID is required';
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
              if (_propertyType == PropertyType.company) ...[
                const SizedBox(height: 14),
                _buildCleanFormField(
                  controller: _emailController,
                  labelText: 'Email ID *',
                  hintText: 'e.g. company@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email ID is required';
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              _buildCleanFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                labelText: isHostel ? 'Owner password *' : 'Password *',
                hintText: 'Min 6 characters',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildCleanFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                labelText: 'Confirm password *',
                hintText: 'Re-enter password',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please confirm password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _createButtonLabel,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13, color: AppTheme.textColor.withValues(alpha: 0.4)),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textColor.withValues(alpha: 0.65)),
        floatingLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

class _HostelSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HostelSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppTheme.brandSoftSurfaceGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacityCompat(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textColor.withOpacityCompat(0.6),
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
