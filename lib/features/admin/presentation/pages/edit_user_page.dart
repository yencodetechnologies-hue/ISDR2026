import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/widgets/identity_document_card.dart';
import '../bloc/admin_bloc.dart';

enum _EditImageType {
  profilePicture,
  aadhaarFront,
  aadhaarBack,
  panCard,
}

class EditUserPage extends StatefulWidget {
  final UserModel user;
  final PropertyType? propertyType;

  const EditUserPage({
    super.key,
    required this.user,
    this.propertyType,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  late final TextEditingController _secondaryMobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _panController;
  late final TextEditingController _occupantsController;
  late final TextEditingController _departmentController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  Gender? _gender;
  FamilyType? _familyType;
  OccupationCategory? _occupationCategory;
  DateTime? _dateOfBirth;
  bool _isNRI = false;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _profilePicture;
  File? _aadhaarFrontImage;
  File? _aadhaarBackImage;
  File? _panCardImage;

  bool get _isHostel => false;
  bool get _isCompany => false;
  bool get _isEventsProperty =>
      widget.propertyType == PropertyType.events ||
      widget.user.isStaff;
  bool get _isApartment =>
      widget.propertyType == null ||
      (!_isEventsProperty && false);

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u.name);
    _usernameController = TextEditingController(text: u.username);
    _emailController = TextEditingController(text: u.email);
    _mobileController = TextEditingController(text: u.mobileNumber);
    _secondaryMobileController =
        TextEditingController(text: u.secondaryMobileNumber ?? '');
    _addressController = TextEditingController(text: u.address ?? '');
    _aadhaarController = TextEditingController(text: u.aadhaarCard ?? '');
    _panController = TextEditingController(text: u.panCard ?? '');
    _occupantsController = TextEditingController(
      text: u.totalOccupants?.toString() ?? '',
    );
    _departmentController = TextEditingController(text: u.department ?? '');
    _employeeIdController = TextEditingController(text: u.employeeId ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _gender = u.gender;
    _familyType = u.familyType;
    _occupationCategory = u.occupationCategory;
    _dateOfBirth = u.dateOfBirth;
    _isNRI = u.isNRI == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _secondaryMobileController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _occupantsController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceModal(_EditImageType imageType) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery, imageType);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera, imageType);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, _EditImageType imageType) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    setState(() {
      switch (imageType) {
        case _EditImageType.profilePicture:
          _profilePicture = File(image.path);
        case _EditImageType.aadhaarFront:
          _aadhaarFrontImage = File(image.path);
        case _EditImageType.aadhaarBack:
          _aadhaarBackImage = File(image.path);
        case _EditImageType.panCard:
          _panCardImage = File(image.path);
      }
    });
  }

  String? _dateOfBirthIso() {
    if (_dateOfBirth == null) return null;
    return _dateOfBirth!.toIso8601String().split('T').first;
  }

  UserModel _mergeUpdatedUser(Map<String, dynamic> json) {
    final parsed = UserModel.fromJson(json);
    return widget.user.copyWith(
      name: parsed.name,
      username: parsed.username,
      email: parsed.email,
      mobileNumber: parsed.mobileNumber,
      secondaryMobileNumber: parsed.secondaryMobileNumber,
      gender: parsed.gender,
      status: parsed.status,
      profilePic: parsed.profilePic,
      address: parsed.address,
      aadhaarCard: parsed.aadhaarCard,
      aadhaarCardFrontImage: parsed.aadhaarCardFrontImage,
      aadhaarCardBackImage: parsed.aadhaarCardBackImage,
      panCard: parsed.panCard,
      panCardImage: parsed.panCardImage,
      familyType: parsed.familyType,
      totalOccupants: parsed.totalOccupants,
      block: parsed.block,
      floor: parsed.floor,
      roomNumber: parsed.roomNumber,
      department: parsed.department,
      employeeId: parsed.employeeId,
      hostelRoom: parsed.hostelRoom,
      hostelBed: parsed.hostelBed,
      occupationCategory: parsed.occupationCategory,
      occupationDetails: parsed.occupationDetails,
      dateOfBirth: parsed.dateOfBirth,
      isNRI: parsed.isNRI,
      apartmentId: parsed.apartmentId ?? widget.user.apartmentId,
      apartments: parsed.apartments ?? widget.user.apartments,
      isActive: parsed.isActive,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (password.isNotEmpty) {
      if (password.length < 6) {
        _showSnack('Password must be at least 6 characters', isError: true);
        return;
      }
      if (password != confirm) {
        _showSnack('Passwords do not match', isError: true);
        return;
      }
    }

    if (_isHostel && _occupationCategory == null) {
      _showSnack('Please select occupation', isError: true);
      return;
    }
    if (_isApartment && !_isCompany && _familyType == null) {
      _showSnack('Please select family type', isError: true);
      return;
    }

    setState(() => _saving = true);

    final response = await _apiService.updateUser(
      userId: widget.user.id,
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      secondaryMobileNumber: _secondaryMobileController.text.trim().isEmpty
          ? ''
          : _secondaryMobileController.text.trim(),
      gender: _gender?.name,
      address: _addressController.text.trim(),
      familyType: _familyType?.name,
      totalOccupants: int.tryParse(_occupantsController.text.trim()),
      aadhaarCard: _aadhaarController.text.trim(),
      panCard: _panController.text.trim(),
      isNRI: _isNRI,
      department: _isCompany ? _departmentController.text.trim() : null,
      employeeId: _isCompany ? _employeeIdController.text.trim() : null,
      occupationCategory:
          _isHostel ? _occupationCategory?.name : null,
      dateOfBirth: _dateOfBirthIso(),
      password: password.isEmpty ? null : password,
      profilePic: _profilePicture,
      aadhaarFront: _aadhaarFrontImage,
      aadhaarBack: _aadhaarBackImage,
      panCardImage: _panCardImage,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (response['success'] == true) {
      UserModel? updatedUser;
      final userJson = response['user'];
      if (userJson is Map<String, dynamic>) {
        updatedUser = _mergeUpdatedUser(userJson);
      }
      context.read<AdminBloc>().add(LoadAllUsersEvent());
      if (!mounted) return;
      _showSnack(
        response['message'] as String? ?? 'User updated successfully',
      );
      Navigator.pop(context, updatedUser ?? true);
    } else {
      _showSnack(
        response['error'] as String? ?? 'Failed to update user',
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final hasAssignment =
        (u.block != null && u.block!.isNotEmpty) ||
        (u.roomNumber != null && u.roomNumber!.isNotEmpty);

    final pageTitle = _isEventsProperty ? 'Edit Event Staff' : 'Edit User';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: AppTheme.brandHeaderGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pageTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            u.name,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: _isEventsProperty
                    ? [
                        _sectionCard(
                          title: 'Event Staff Information',
                          icon: Icons.badge_rounded,
                          children: [
                            _buildProfilePicturePicker(),
                            const SizedBox(height: 16),
                            _field(
                              _nameController,
                              label: 'Full Name *',
                              icon: Icons.person_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            _field(
                              _emailController,
                              label: 'Email *',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            _field(
                              _mobileController,
                              label: 'Mobile Number *',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (v) {
                                if (v == null || v.trim().length != 10) {
                                  return 'Enter 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Security',
                          icon: Icons.lock_outline_rounded,
                          children: [
                            _field(
                              _passwordController,
                              label: 'New password (optional)',
                              icon: Icons.lock_outlined,
                              obscure: true,
                              isOptional: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            _field(
                              _confirmPasswordController,
                              label: 'Confirm new password',
                              icon: Icons.lock_reset_outlined,
                              obscure: true,
                              isOptional: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () => setState(() =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ],
                        ),
                      ]
                    : [
                        if (u.linkedOwner != null) ...[
                          _sectionCard(
                            title: 'Linked owner',
                            icon: Icons.supervisor_account_rounded,
                            children: [
                              _readOnlyTile('Owner name', u.linkedOwner!.name),
                              _readOnlyTile('Owner mobile', u.linkedOwner!.mobileNumber),
                              if (u.linkedOwner!.block != null)
                                _readOnlyTile('Owner block', u.linkedOwner!.block!),
                              if (u.linkedOwner!.roomNumber != null)
                                _readOnlyTile('Owner room', u.linkedOwner!.roomNumber!),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (hasAssignment) ...[
                          _sectionCard(
                            title: 'Unit assignment',
                            icon: Icons.apartment_rounded,
                            children: [
                              if (u.block != null && u.block!.isNotEmpty)
                                _readOnlyTile('Block', u.block!),
                              if (u.floor != null && u.floor!.isNotEmpty)
                                _readOnlyTile('Floor', u.floor!),
                              if (u.roomNumber != null && u.roomNumber!.isNotEmpty)
                                _readOnlyTile('Room', u.roomNumber!),
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Use Reassign from the user menu to change unit.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        _sectionCard(
                          title: 'Personal information',
                          icon: Icons.person_outline_rounded,
                          children: [
                            _buildProfilePicturePicker(),
                            const SizedBox(height: 16),
                            _field(_nameController,
                                label: 'Full name *', icon: Icons.person_rounded),
                            _field(_usernameController,
                                label: 'Username *', icon: Icons.alternate_email),
                            _field(
                              _emailController,
                              label: 'Email *',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Contact',
                          icon: Icons.phone_outlined,
                          children: [
                            _field(
                              _mobileController,
                              label: 'Mobile number *',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (v) {
                                if (v == null || v.trim().length != 10) {
                                  return 'Enter 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            _field(
                              _secondaryMobileController,
                              label: 'Secondary mobile (optional)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              isOptional: true,
                            ),
                            _field(
                              _addressController,
                              label: 'Address (optional)',
                              icon: Icons.location_on_outlined,
                              maxLines: 2,
                              isOptional: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isHostel)
                          _sectionCard(
                            title: 'Hostel details',
                            icon: Icons.hotel_rounded,
                            children: [
                              _buildGenderSelection(),
                              const SizedBox(height: 16),
                              _buildOccupationSelection(),
                              const SizedBox(height: 16),
                              _buildDateOfBirthPicker(),
                            ],
                          )
                        else if (_isCompany)
                          _sectionCard(
                            title: 'Company details',
                            icon: Icons.business_outlined,
                            children: [
                              _field(_departmentController,
                                  label: 'Department', icon: Icons.business_outlined,
                                  isOptional: true),
                              _field(_employeeIdController,
                                  label: 'Employee ID', icon: Icons.badge_outlined,
                                  isOptional: true),
                            ],
                          )
                        else
                          _sectionCard(
                            title: 'Resident details',
                            icon: Icons.home_rounded,
                            children: [
                              _buildGenderSelection(),
                              const SizedBox(height: 16),
                              _buildFamilyTypeSelection(),
                              const SizedBox(height: 16),
                              _buildNRIToggle(),
                              const SizedBox(height: 16),
                              _field(
                                _occupantsController,
                                label: 'Total occupants (optional)',
                                icon: Icons.people_outline,
                                keyboardType: TextInputType.number,
                                isOptional: true,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Identity documents',
                          icon: Icons.badge_rounded,
                          children: [
                            _field(
                              _aadhaarController,
                              label: 'ID card number (optional)',
                              icon: Icons.credit_card_outlined,
                              isOptional: true,
                              validator: (v) {
                                final trimmed = v?.trim() ?? '';
                                if (trimmed.isEmpty) return null;
                                if (trimmed.length < 5) {
                                  return 'ID card number must be at least 5 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            IdentityDocumentPair(
                              frontImageFile: _aadhaarFrontImage,
                              backImageFile: _aadhaarBackImage,
                              frontImageUrl: u.aadhaarCardFrontImage,
                              backImageUrl: u.aadhaarCardBackImage,
                              onFrontTap: () =>
                                  _showImageSourceModal(_EditImageType.aadhaarFront),
                              onBackTap: () =>
                                  _showImageSourceModal(_EditImageType.aadhaarBack),
                            ),
                            const SizedBox(height: 16),
                            _field(
                              _panController,
                              label: 'PAN number (optional)',
                              icon: Icons.account_balance_wallet_outlined,
                              maxLength: 10,
                              isOptional: true,
                              validator: (v) {
                                final trimmed = v?.trim() ?? '';
                                if (trimmed.isEmpty) return null;
                                if (trimmed.length != 10) {
                                  return 'PAN must be 10 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDocumentImagePicker(
                              'PAN card image',
                              _panCardImage,
                              u.panCardImage,
                              _EditImageType.panCard,
                              isFullWidth: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Security',
                          icon: Icons.lock_outline_rounded,
                          children: [
                            _field(
                              _passwordController,
                              label: 'New password (optional)',
                              icon: Icons.lock_outlined,
                              obscure: true,
                              isOptional: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            _field(
                              _confirmPasswordController,
                              label: 'Confirm new password',
                              icon: Icons.lock_reset_outlined,
                              obscure: true,
                              isOptional: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () => setState(() =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ],
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: BrandGradientCtaButton(
              height: 52,
              icon: Icons.save_rounded,
              label: _saving ? 'Saving...' : 'Save changes',
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _readOnlyTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.dividerColor.withOpacity(0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool obscure = false,
    bool isOptional = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscure,
        validator: validator ??
            (v) {
              if (!isOptional && !label.toLowerCase().contains('optional')) {
                if (v == null || v.trim().isEmpty) {
                  return 'This field is required';
                }
              }
              return null;
            },
        decoration: _inputDecoration(label, icon).copyWith(
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildProfilePicturePicker() {
    final existingUrl = widget.user.profilePic;
    return Center(
      child: Column(
        children: [
          const Text(
            'Profile picture (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showImageSourceModal(_EditImageType.profilePicture),
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (_profilePicture != null || existingUrl != null)
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipOval(
                    child: _profilePicture != null
                        ? Image.file(_profilePicture!, fit: BoxFit.cover)
                        : (existingUrl != null && existingUrl.isNotEmpty)
                            ? Image.network(existingUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: Colors.grey))
                            : const Icon(Icons.person_rounded,
                                size: 48, color: Colors.grey),
                  ),
                ),
                if (_profilePicture != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                _showImageSourceModal(_EditImageType.profilePicture),
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: Text(
              _profilePicture != null || existingUrl != null
                  ? 'Change profile picture'
                  : 'Add profile picture',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentImagePicker(
    String label,
    File? localFile,
    String? existingUrl,
    _EditImageType type, {
    bool isFullWidth = false,
  }) {
    final hasImage = localFile != null ||
        (existingUrl != null && existingUrl.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showImageSourceModal(type),
          child: Container(
            height: isFullWidth ? 150 : 130,
            width: isFullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? AppTheme.primaryColor : Colors.grey.shade300,
                width: hasImage ? 2 : 1,
              ),
            ),
            child: localFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(localFile, fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity),
                  )
                : (existingUrl != null && existingUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(existingUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                _uploadPlaceholder()),
                      )
                    : _uploadPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _uploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload_rounded, size: 36, color: Colors.grey[400]),
        const SizedBox(height: 6),
        Text('Tap to upload',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _genderOption('Male', Gender.male, Icons.male_rounded)),
            const SizedBox(width: 8),
            Expanded(
                child: _genderOption(
                    'Female', Gender.female, Icons.female_rounded)),
            const SizedBox(width: 8),
            Expanded(
                child: _genderOption(
                    'Other', Gender.other, Icons.transgender_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _genderOption(String label, Gender value, IconData icon) {
    final selected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppTheme.primaryColor : Colors.grey.shade700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Family type *',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _familyOption(
                  'Family', FamilyType.family, Icons.family_restroom_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _familyOption(
                  'Bachelor', FamilyType.bachelor, Icons.person_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _familyOption(String label, FamilyType value, IconData icon) {
    final selected = _familyType == value;
    return InkWell(
      onTap: () => setState(() => _familyType = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      selected ? AppTheme.primaryColor : Colors.grey.shade700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Occupation *',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _occupationOption(
                  'Working', OccupationCategory.working, Icons.work_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _occupationOption(
                  'Student', OccupationCategory.student, Icons.school_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _occupationOption('Others', OccupationCategory.others,
                  Icons.more_horiz_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _occupationOption(
      String label, OccupationCategory value, IconData icon) {
    final selected = _occupationCategory == value;
    return InkWell(
      onTap: () => setState(() => _occupationCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primaryColor : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppTheme.primaryColor : Colors.grey.shade700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of birth',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dateOfBirth ??
                  DateTime.now().subtract(const Duration(days: 365 * 18)),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _dateOfBirth = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  _dateOfBirth != null
                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                      : 'Select date of birth',
                  style: TextStyle(
                    color: _dateOfBirth != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNRIToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.public_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Non-Resident Indian (NRI)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Switch(
            value: _isNRI,
            onChanged: (v) => setState(() => _isNRI = v),
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 32),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                )),
          ],
        ),
      ),
    );
  }
}
