import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/widgets/identity_document_card.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';
import '../bloc/auth_bloc.dart';
import '../../../admin/presentation/bloc/admin_bloc.dart';

class UserRegistrationPage extends StatefulWidget {
  final bool fromAdmin;
  final String? apartmentId;
  final String? propertyType;

  const UserRegistrationPage({
    super.key,
    this.fromAdmin = false,
    this.apartmentId,
    this.propertyType,
  });

  @override
  State<UserRegistrationPage> createState() => _UserRegistrationPageState();
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ImageType {
  profilePicture,
  aadhaarFront,
  aadhaarBack,
  panCard,
}

enum ResidentAccountType { owner, tenant }

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _secondaryMobileController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerMobileController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _totalOccupantsController = TextEditingController();
  final _otpController = TextEditingController();
  final _hostelRoomController = TextEditingController();
  final _hostelBedController = TextEditingController();
  final _designationController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureOwnerPassword = true;
  ResidentAccountType _accountType = ResidentAccountType.owner;
  bool _companySaving = false;
  UserType? _currentUserType;
  String? _currentUserApartmentId;

  Gender? _gender;
  FamilyType? _familyType;
  OccupationCategory? _occupationCategory;
  DateTime? _dateOfBirth;
  File? _profilePicture;
  File? _aadhaarFrontImage;
  File? _aadhaarBackImage;
  File? _panCardImage;
  bool _isEmailVerified = false;
  bool _isOtpSent = false;
  bool _isNRI = false;

  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;

  PropertyType get _propertyType {
    final pt = widget.propertyType;
    if (pt == 'company') return PropertyType.company;
    if (pt == 'hostel') return PropertyType.hostel;
    if (pt == 'college') return PropertyType.college;
    if (pt == 'events') return PropertyType.events;
    return PropertyType.apartment;
  }

  /// Public Create Account requires email OTP; staff Add User does not.
  bool get _requireEmailOtp => !widget.fromAdmin;

  /// Admin adding a resident: minimal fields (apartment & hostel).
  bool get _isAdminApartmentSimplified =>
      widget.fromAdmin &&
      (_propertyType == PropertyType.apartment ||
          _propertyType == PropertyType.hostel);

  /// Owner/tenant choice applies only when admin adds a user to an apartment.
  bool get _showAdminAccountType =>
      _isAdminApartmentSimplified && _propertyType == PropertyType.apartment;

  @override
  void initState() {
    super.initState();
    // Store current logged-in user info before registration
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserType = authState.user.userType;
      // If apartmentId is provided via widget (from admin), use it; otherwise use current user's apartmentId
      _currentUserApartmentId = widget.apartmentId ?? authState.user.apartmentId;
    } else if (widget.apartmentId != null) {
      // If no auth state but apartmentId provided, use it
      _currentUserApartmentId = widget.apartmentId;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _secondaryMobileController.dispose();
    _ownerNameController.dispose();
    _ownerMobileController.dispose();
    _ownerPasswordController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _totalOccupantsController.dispose();
    _otpController.dispose();
    _hostelRoomController.dispose();
    _hostelBedController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceModal(ImageType imageType) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Image Source',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
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
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera, imageType);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, ImageType imageType) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        switch (imageType) {
          case ImageType.profilePicture:
            _profilePicture = File(image.path);
            break;
          case ImageType.aadhaarFront:
            _aadhaarFrontImage = File(image.path);
            break;
          case ImageType.aadhaarBack:
            _aadhaarBackImage = File(image.path);
            break;
          case ImageType.panCard:
            _panCardImage = File(image.path);
            break;
        }
      });
    }
  }

  void _sendOtp() {
    if (!_requireEmailOtp) return;
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter your email address', isError: true);
      return;
    }
    if (!_emailController.text.contains('@')) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }
    // Show OTP field immediately when verify is clicked
    setState(() {
      _isOtpSent = true;
    });
    context.read<AuthBloc>().add(SendOtpEvent(email: _emailController.text.trim()));
  }

  void _verifyOtp() {
    if (!_requireEmailOtp) return;
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter the OTP', isError: true);
      return;
    }
    context.read<AuthBloc>().add(
          VerifyOtpEvent(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
          ),
        );
  }

  void _handleRegister() {
    final isCompany = _propertyType == PropertyType.company;
    final isHostel = _propertyType == PropertyType.hostel;
    final isCollege = _propertyType == PropertyType.college;
    final isEvents = _propertyType == PropertyType.events;
    final noExtraFieldsType = isCollege || isEvents;
    final baseValid = _formKey.currentState!.validate() &&
        (isCompany || noExtraFieldsType ? true : (!_requireEmailOtp || _isEmailVerified));
    final companyValid = baseValid;
    final hostelValid = _isAdminApartmentSimplified
        ? (baseValid && _familyType != null)
        : (baseValid && _gender != null && _occupationCategory != null);
    final isTenantAccount = _showAdminAccountType &&
        _accountType == ResidentAccountType.tenant;
    final userValid = noExtraFieldsType
        ? baseValid
        : (_isAdminApartmentSimplified
            ? (baseValid && _familyType != null)
            : (baseValid && _familyType != null && _gender != null));

    if (isTenantAccount) {
      final ownerName = _ownerNameController.text.trim();
      final ownerMobile = _ownerMobileController.text.trim();
      final ownerPassword = _ownerPasswordController.text;
      if (ownerName.isEmpty) {
        _showSnackBar('Please enter owner name', isError: true);
        return;
      }
      if (ownerMobile.length != 10) {
        _showSnackBar('Please enter valid 10-digit owner mobile number', isError: true);
        return;
      }
      if (ownerPassword.length < 6) {
        _showSnackBar('Owner password must be at least 6 characters', isError: true);
        return;
      }
      if (ownerMobile == _mobileController.text.trim()) {
        _showSnackBar('Owner and tenant mobile numbers must be different', isError: true);
        return;
      }
    }

    if ((isCompany || noExtraFieldsType ? baseValid : (isHostel ? hostelValid : userValid))) {
      if (isCompany) {
        final pass = _passwordController.text.trim();
        final confirm = _confirmPasswordController.text.trim();
        if (confirm.isEmpty) {
          _showSnackBar('Please confirm password', isError: true);
          return;
        }
        if (confirm != pass) {
          _showSnackBar('Passwords do not match', isError: true);
          return;
        }
        final email = _emailController.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          _showSnackBar('Please enter a valid email address', isError: true);
          return;
        }

        _createCompanyProperty();
        return;
      }
      if (isTenantAccount) {
        context.read<AuthBloc>().add(
          RegisterResidentBundleEvent(
            name: _usernameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            mobileNumber: _mobileController.text.trim(),
            ownerName: _ownerNameController.text.trim(),
            ownerMobile: _ownerMobileController.text.trim(),
            ownerPassword: _ownerPasswordController.text,
            secondaryMobileNumber: _secondaryMobileController.text.trim().isEmpty
                ? null
                : _secondaryMobileController.text.trim(),
            familyType: _familyType,
            aadhaarCard: _aadhaarController.text.trim().isEmpty
                ? null
                : _aadhaarController.text.trim(),
            panCard: _panController.text.trim().isEmpty
                ? null
                : _panController.text.trim(),
            apartmentId: widget.apartmentId ?? _currentUserApartmentId,
            profilePicPath: _profilePicture?.path,
            aadhaarFrontPath: _aadhaarFrontImage?.path,
            aadhaarBackPath: _aadhaarBackImage?.path,
            panCardImagePath: _panCardImage?.path,
            isNRI: _isNRI,
          ),
        );
        return;
      }
      context.read<AuthBloc>().add(
        RegisterUserEvent(
          name: _usernameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          persistAuth: !widget.fromAdmin,
          secondaryMobileNumber: _secondaryMobileController.text.trim().isEmpty
              ? null
              : _secondaryMobileController.text.trim(),
          gender: _gender,
          userType: UserType.user,
          familyType: _familyType,
          aadhaarCard: _aadhaarController.text.trim().isEmpty
              ? null
              : _aadhaarController.text.trim(),
          panCard: _panController.text.trim().isEmpty
              ? null
              : _panController.text.trim(),
          totalOccupants: _totalOccupantsController.text.trim().isEmpty
              ? null
              : int.tryParse(_totalOccupantsController.text.trim()),
          department: _propertyType == PropertyType.college ? _designationController.text.trim() : null,
          hostelRoom: _propertyType == PropertyType.hostel ? _hostelRoomController.text.trim().isEmpty ? null : _hostelRoomController.text.trim() : null,
          hostelBed: _propertyType == PropertyType.hostel ? _hostelBedController.text.trim().isEmpty ? null : _hostelBedController.text.trim() : null,
          occupationCategory: _propertyType == PropertyType.hostel ? _occupationCategory : null,
          dateOfBirth: _propertyType == PropertyType.hostel ? _dateOfBirth : null,
          profilePicPath: _profilePicture?.path,
          aadhaarFrontPath: _aadhaarFrontImage?.path,
          aadhaarBackPath: _aadhaarBackImage?.path,
          panCardImagePath: _panCardImage?.path,
          isNRI: _isNRI,
        ),
      );
    } else {
      String errorMessage = '';
      if (isCompany) {
        // Company creation uses only form validation (no email/logo requirements).
      } else if (_propertyType == PropertyType.hostel && !_isAdminApartmentSimplified) {
        if (_occupationCategory == null) {
          errorMessage = 'Please select Occupation';
        } else if (_gender == null) {
          errorMessage = 'Please select Gender';
        } else if (_requireEmailOtp && !_isEmailVerified) {
          errorMessage = 'Please verify your email address';
        }
      } else if (_isAdminApartmentSimplified) {
        if (_familyType == null) {
          errorMessage = 'Please select Tenant Type';
        } else if (_requireEmailOtp && !_isEmailVerified) {
          errorMessage = 'Please verify your email address';
        }
      } else {
        if (_familyType == null) {
          errorMessage = 'Please select Tenant Type';
        } else if (_gender == null) {
          errorMessage = 'Please select Gender';
        } else if (_requireEmailOtp && !_isEmailVerified) {
          errorMessage = 'Please verify your email address';
        }
      }
      if (errorMessage.isNotEmpty) _showSnackBar(errorMessage, isError: true);
    }
  }

  Future<void> _createCompanyProperty() async {
    if (_companySaving) return;
    setState(() => _companySaving = true);
    final result = await _apiService.createCompanyPublic(
      name: _usernameController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      contactPhone: _mobileController.text.trim(),
      password: _passwordController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _companySaving = false);

    if (result['success'] == true) {
      _showSuccessDialog(
        title: 'Company Created Successfully!',
        message: 'The company account has been created successfully.',
        fromAdmin: widget.fromAdmin,
      );
    } else {
      _showSnackBar(result['error'] as String? ?? 'Failed to create company', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToDashboard(UserModel user) {
    String route = AppRoutes.login;
    switch (user.userType) {
      case UserType.admin:
        route = AppRoutes.adminDashboard;
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
      default:
        route = AppRoutes.login;
    }
    AppNavigation.resetTo(context, route);
  }

  void _showSuccessDialog({required String title, required String message, bool fromAdmin = false, UserModel? user}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.secondaryColor,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                BrandGradientCtaButton(
                  height: 50,
                  label: fromAdmin ? 'OK' : 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (fromAdmin) {
                      // Reload users list if from admin, then return to list page.
                      context.read<AdminBloc>().add(LoadBlocksEvent());

                      // Pop dialog + registration page safely (avoid blank/white screen).
                      final rootNav = Navigator.of(context, rootNavigator: true);
                      rootNav.popUntil((route) {
                        final name = route.settings.name;
                        return name == AppRoutes.adminDashboard ||
                            name == AppRoutes.adminApartmentList ||
                            route.isFirst;
                      });
                    } else if (user != null) {
                      Navigator.of(context).pop(); // Close dialog
                      // For regular registration, navigate based on user status
                      if (user.status == AccountStatus.pending) {
                        Navigator.pushReplacementNamed(context, AppRoutes.waitingApproval);
                      } else if (user.status == AccountStatus.approved) {
                        _navigateToDashboard(user);
                      } else {
                        // If rejected or other status, go to login
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      }
                    } else {
                      Navigator.of(context).pop(); // Close dialog
                      // Fallback to login if user is null
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is UserRegisteredSuccess && widget.fromAdmin) {
            final isBundle = _showAdminAccountType &&
                _accountType == ResidentAccountType.tenant;
            _showSuccessDialog(
              title: _propertyType == PropertyType.company
                  ? 'Company Created Successfully!'
                  : (isBundle ? 'Owner & Tenant Created' : 'User Registered Successfully!'),
              message: _propertyType == PropertyType.company
                  ? 'The company account has been created successfully.'
                  : (isBundle
                      ? 'The owner and tenant accounts have been registered successfully.'
                      : 'The user has been registered successfully.'),
              fromAdmin: true,
            );
          } else if (state is AuthAuthenticated && !widget.fromAdmin) {
            // For regular registration, check user status and navigate accordingly
            if (state.user.status == AccountStatus.pending) {
              // Show success message then navigate to waiting approval
              _showSuccessDialog(
                title: 'Account Created Successfully!',
                message: 'Your account is pending approval. You will be notified once it\'s approved.',
                fromAdmin: false,
                user: state.user,
              );
            } else if (state.user.status == AccountStatus.approved) {
              // Show success message then navigate to dashboard
              _showSuccessDialog(
                title: 'Account Created Successfully!',
                message: 'Welcome! You are now logged in.',
                fromAdmin: false,
                user: state.user,
              );
            } else {
              // Rejected or other status
              _showSuccessDialog(
                title: 'Account Created',
                message: 'Your account has been created. Please contact administrator for approval.',
                fromAdmin: false,
                user: state.user,
              );
            }
          } else if (state is AuthError) {
            _showSnackBar(state.message, isError: true);
          } else if (state is OtpSent) {
            if (!_requireEmailOtp) return;
            setState(() => _isOtpSent = true);
            _showSnackBar('OTP sent to your email', isError: false);
          } else if (state is OtpVerified) {
            if (!_requireEmailOtp) return;
            setState(() {
              _isEmailVerified = true;
              _isOtpSent = true; // Keep OTP field visible but show success
            });
            _showSnackBar('Email verified successfully!', isError: false);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              // expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.primaryColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _propertyType == PropertyType.company
                      ? 'Create Company'
                      : (_propertyType == PropertyType.events
                          ? 'Add Event Staff'
                          : (_isAdminApartmentSimplified ? 'Add User' : 'Create Account')),
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress Indicator
                      // _buildProgressIndicator(),
                      // const SizedBox(height: 32),

                      // Company form OR Personal Information Section
                      if (_propertyType == PropertyType.company) ...[
                        _buildSectionCard(
                          title: 'Company Information',
                          icon: Icons.business_rounded,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.apartment_rounded, color: AppTheme.primaryColor),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Property Type',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    PropertyType.company.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Company Name',
                              icon: Icons.person_rounded,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter company name' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _addressController,
                              label: 'Address',
                              icon: Icons.location_on_rounded,
                              maxLines: 2,
                              isOptional: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email ID',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter email';
                                if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(value!.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter password';
                                if (value!.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirmPassword,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please confirm password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter mobile number';
                                if (value!.length != 10) return 'Enter valid 10-digit number';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                      _buildSectionCard(
                        title: _propertyType == PropertyType.college
                            ? 'Add Staff Account'
                            : _propertyType == PropertyType.events
                                ? 'Add Event Staff Account'
                                : 'Personal Information',
                        icon: _propertyType == PropertyType.college ||
                                _propertyType == PropertyType.events
                            ? Icons.badge_rounded
                            : Icons.person_outline_rounded,
                        children: [
                          if (_propertyType == PropertyType.events) ...[
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Full Name *',
                              icon: Icons.person_rounded,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter full name' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number *',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter mobile number';
                                if (value!.length != 10) return 'Enter valid 10-digit number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildEmailWithOtp(),
                            if (_requireEmailOtp && _isOtpSent && !_isEmailVerified) ...[
                              const SizedBox(height: 20),
                              _buildOtpField(),
                            ],
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password *',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter password';
                                if (value!.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                          ] else if (_propertyType == PropertyType.college) ...[
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Full Name *',
                              icon: Icons.person_rounded,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter full name' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _designationController,
                              label: 'Designation *',
                              icon: Icons.work_outline_rounded,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter designation' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number *',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter mobile number';
                                if (value!.length != 10) return 'Enter valid 10-digit number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildEmailWithOtp(),
                            if (_requireEmailOtp && _isOtpSent && !_isEmailVerified) ...[
                              const SizedBox(height: 20),
                              _buildOtpField(),
                            ],
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password *',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter password';
                                if (value!.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                          ] else ...[
                            if (!_isAdminApartmentSimplified) ...[
                              _buildProfilePicturePicker(),
                              const SizedBox(height: 24),
                            ],
                            if (_showAdminAccountType) ...[
                              DropdownButtonFormField<ResidentAccountType>(
                                value: _accountType,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Account Type',
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  floatingLabelStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.account_circle_outlined,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEA),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEA),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: ResidentAccountType.owner,
                                    child: Text(
                                      'Owner',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: ResidentAccountType.tenant,
                                    child: Text(
                                      'Tenant',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _accountType = v);
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildTextField(
                              controller: _usernameController,
                              label: _showAdminAccountType &&
                                      _accountType == ResidentAccountType.tenant
                                  ? 'Tenant Name'
                                  : 'Full Name',
                              icon: Icons.person_rounded,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter your name' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildEmailWithOtp(),
                            if (_requireEmailOtp && _isOtpSent && !_isEmailVerified) ...[
                              const SizedBox(height: 20),
                              _buildOtpField(),
                            ],
                            if (_requireEmailOtp && _isEmailVerified) ...[
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter password';
                                if (value!.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _mobileController,
                              label: 'Mobile Number',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Please enter mobile number';
                                if (value!.length != 10) return 'Enter valid 10-digit number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _secondaryMobileController,
                              label: 'Secondary Mobile (Optional)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              isOptional: true,
                            ),
                            if (_showAdminAccountType &&
                                _accountType == ResidentAccountType.tenant) ...[
                              const SizedBox(height: 24),
                              _buildSectionCard(
                                title: 'Owner Details',
                                icon: Icons.supervisor_account_rounded,
                                children: [
                                  _buildTextField(
                                    controller: _ownerNameController,
                                    label: 'Owner Name',
                                    icon: Icons.person_rounded,
                                    validator: (value) =>
                                        value?.isEmpty ?? true ? 'Please enter owner name' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _ownerMobileController,
                                    label: 'Owner Mobile Number',
                                    icon: Icons.phone_rounded,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Please enter owner mobile number';
                                      }
                                      if (value!.length != 10) {
                                        return 'Enter valid 10-digit number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _ownerPasswordController,
                                    label: 'Owner Password',
                                    icon: Icons.lock_rounded,
                                    obscureText: _obscureOwnerPassword,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Please enter owner password';
                                      }
                                      if (value!.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureOwnerPassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureOwnerPassword = !_obscureOwnerPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                      ],

                      const SizedBox(height: 24),

                      // Tenant / Hostel Details Section (skip for company, college & events - family type/nri not relevant)
                      if (_propertyType != PropertyType.company &&
                          _propertyType != PropertyType.college &&
                          _propertyType != PropertyType.events)
                      _buildSectionCard(
                        title: _propertyType == PropertyType.hostel
                            ? 'Hostel Details'
                            : (_isAdminApartmentSimplified ? 'Family Type' : 'Tenant Details'),
                        icon: _propertyType == PropertyType.hostel
                            ? Icons.hotel_rounded
                            : Icons.home_rounded,
                        children: [
                          if (_isAdminApartmentSimplified) ...[
                            _buildFamilyTypeSelection(),
                            const SizedBox(height: 20),
                            _buildNRIToggle(),
                          ] else ...[
                            _buildGenderSelection(),
                            if (widget.fromAdmin) ...[
                              const SizedBox(height: 20),
                              const SizedBox(height: 20),
                            ] else ...[
                              const SizedBox(height: 20),
                            ],
                            if (_propertyType == PropertyType.hostel) ...[
                              _buildOccupationSelection(),
                              const SizedBox(height: 20),
                              _buildDateOfBirthPicker(),
                              const SizedBox(height: 20),
                            ] else ...[
                              _buildFamilyTypeSelection(),
                              const SizedBox(height: 20),
                              _buildNRIToggle(),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _totalOccupantsController,
                                label: 'Total Occupants',
                                icon: Icons.people_rounded,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Please enter total occupants';
                                  final num = int.tryParse(value!);
                                  if (num == null || num < 1) return 'Enter valid number';
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ],
                      ),

                      if (_propertyType != PropertyType.college &&
                          _propertyType != PropertyType.events) ...[
                        const SizedBox(height: 24),
                        _buildSectionCard(
                          title: 'Identity Documents',
                          icon: Icons.badge_rounded,
                        children: [
                          _buildTextField(
                            controller: _aadhaarController,
                            label: 'ID Card Number (Optional)',
                            icon: Icons.credit_card_rounded,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return null;
                              if (v.length < 5) {
                                return 'ID card number must be at least 5 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          IdentityDocumentPair(
                            frontImageFile: _aadhaarFrontImage,
                            backImageFile: _aadhaarBackImage,
                            onFrontTap: () =>
                                _showImageSourceModal(ImageType.aadhaarFront),
                            onBackTap: () =>
                                _showImageSourceModal(ImageType.aadhaarBack),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _panController,
                            label: 'PAN Number (Optional)',
                            icon: Icons.account_balance_wallet_rounded,
                            maxLength: 10,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return null;
                              if (v.length != 10) return 'PAN must be 10 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildImagePicker(
                            'PAN Card Image',
                            _panCardImage,
                            ImageType.panCard,
                            isFullWidth: true,
                          ),
                        ],
                      ),
                      ],

                      const SizedBox(height: 32),

                      // Register Button
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isCompany = _propertyType == PropertyType.company;
                          final isLoading = isCompany ? _companySaving : state is AuthLoading;
                          return BrandGradientCtaButton(
                            label: _propertyType == PropertyType.company
                                ? 'Create Company'
                                : (_propertyType == PropertyType.events
                                    ? 'Add Event Staff'
                                    : (_isAdminApartmentSimplified
                                        ? 'Add User'
                                        : 'Create Account')),
                            icon: _propertyType == PropertyType.company
                                ? Icons.business_rounded
                                : Icons.person_add_rounded,
                            onPressed: isLoading ? null : _handleRegister,
                            isLoading: isLoading,
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProgressStep(1, 'Personal', _currentStep >= 0),
              Expanded(child: _buildProgressLine(_currentStep >= 1)),
              _buildProgressStep(2, 'Tenant', _currentStep >= 1),
              Expanded(child: _buildProgressLine(_currentStep >= 2)),
              _buildProgressStep(3, 'Documents', _currentStep >= 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppTheme.primaryColor : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? AppTheme.primaryColor : Colors.grey[300],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
    int? maxLines = 1,
    bool isOptional = false,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final displayLabel = label.endsWith('(Optional)')
        ? label
        : (isOptional ? '$label (Optional)' : label);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      obscureText: obscureText,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: displayLabel,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
        ),
        counterText: '',
      ),
      validator: isOptional ? null : validator,
    );
  }

  Widget _buildEmailWithOtp() {
    if (!_requireEmailOtp) {
      return _buildTextField(
        controller: _emailController,
        label: 'Email',
        icon: Icons.email_rounded,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Please enter email';
          if (!value!.contains('@')) return 'Enter valid email';
          return null;
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isEmailVerified,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_rounded, color: AppTheme.primaryColor),
            suffixIcon: _isEmailVerified
                ? Container(
                    margin: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.verified,
                      color: Colors.green[600],
                      size: 24,
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.all(8),
                    child: ElevatedButton(
                      onPressed: _sendOtp,
                      style: AppTheme.secondaryElevatedStyle.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        minimumSize: WidgetStateProperty.all(Size.zero),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Verify',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
            filled: true,
            fillColor: _isEmailVerified ? Colors.green[50] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isEmailVerified ? Colors.green : Colors.grey[300]!,
                width: _isEmailVerified ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isEmailVerified ? Colors.green : AppTheme.primaryColor,
                width: 2,
              ),
            ),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Please enter email';
            if (!value!.contains('@')) return 'Enter valid email';
            return null;
          },
        ),
        if (_isEmailVerified) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[700],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Email verified successfully',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtpField() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'OTP sent to ${_emailController.text}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryColor),
                  hintText: 'Enter 6-digit code',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              BrandGradientCtaButton(
                label: 'Verify OTP',
                icon: Icons.verified_user_rounded,
                onPressed: isLoading ? null : _verifyOtp,
                isLoading: isLoading,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : () {
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                    });
                    _sendOtp();
                  },
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('Male', Gender.male, Icons.male_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Female', Gender.female, Icons.female_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Other', Gender.other, Icons.transgender_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String label, Gender value, IconData icon) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Occupation',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildOccupationOption('Working', OccupationCategory.working, Icons.work_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOccupationOption('Student', OccupationCategory.student, Icons.school_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOccupationOption('Others', OccupationCategory.others, Icons.more_horiz_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOccupationOption(String label, OccupationCategory value, IconData icon) {
    final isSelected = _occupationCategory == value;
    return InkWell(
      onTap: () => setState(() => _occupationCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
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
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  _dateOfBirth != null
                      ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                      : 'Select date of birth',
                  style: TextStyle(
                    fontSize: 16,
                    color: _dateOfBirth != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Family Type',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildFamilyOption('Family', FamilyType.family, Icons.family_restroom_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFamilyOption('Bachelor', FamilyType.bachelor, Icons.person_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyOption(String label, FamilyType value, IconData icon) {
    final isSelected = _familyType == value;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _familyType = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withAlpha(16)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : const Color(0xFFECECEA),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNRIToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.public_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Non-Resident Indian (NRI)',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select if you are an NRI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _isNRI,
            onChanged: (value) {
              setState(() {
                _isNRI = value;
              });
            },
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(
    String label,
    File? image,
    ImageType imageType, {
    bool isFullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showImageSourceModal(imageType),
          child: Container(
            height: isFullWidth ? 160 : 140,
            width: isFullWidth ? double.infinity : 150,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: image != null ? AppTheme.primaryColor : Colors.grey[300]!,
                width: 2,
                style: image != null ? BorderStyle.solid : BorderStyle.none,
              ),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          image,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePicturePicker() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Profile Picture (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showImageSourceModal(ImageType.profilePicture),
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _profilePicture != null
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: 3,
                    ),
                    color: Colors.grey[100],
                  ),
                  child: _profilePicture != null
                      ? ClipOval(
                          child: Image.file(
                            _profilePicture!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: Colors.grey,
                        ),
                ),
                if (_profilePicture != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showImageSourceModal(ImageType.profilePicture),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(
              _profilePicture != null ? 'Change Profile Picture' : 'Add Profile Picture',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
