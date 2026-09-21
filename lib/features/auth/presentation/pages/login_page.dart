import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  UserType? _selectedUserType;

  @override
  void initState() {
    super.initState();
    // Try to get user type from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is UserType && _selectedUserType == null) {
        setState(() {
          _selectedUserType = args;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get user type from route arguments - only set if not already set
    if (_selectedUserType == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      print('=== LOGIN PAGE INIT ===');
      print('Route arguments: $args');
      print('Arguments type: ${args.runtimeType}');
      if (args is UserType) {
        print('Setting userType to: $args');
        setState(() {
          _selectedUserType = args;
        });
        _prefillCredentials(args);
      } else {
        print('No UserType in arguments');
      }
    }
  }

  void _prefillCredentials(UserType userType) {
    // No longer pre-filling credentials - user can enter any email/password
    // The credentials are just for display purposes, any email/password will work
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // Prevent double taps
    if (_isLoading) return;

    // Unfocus text fields
    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Ensure user type is set - if not, try to get it from route arguments
      UserType? userType = _selectedUserType;
      if (userType == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is UserType) {
          userType = args;
          setState(() {
            _selectedUserType = userType;
          });
        } else {
          // Default to user if no type is specified
          userType = UserType.user;
        }
      }

      debugPrint('=== FRONTEND LOGIN ATTEMPT ===');
      debugPrint('Email: ${_emailController.text.trim()}');
      debugPrint('UserType: $userType');
      debugPrint('UserType.name: ${userType.name}');
      debugPrint('Selected UserType: $_selectedUserType');

      context.read<AuthBloc>().add(
            LoginEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              userType: userType,
            ),
          );
    }
  }

  void _navigateToDashboard(UserModel user) {
    final activeApartment = (user.apartments != null && user.apartments!.isNotEmpty)
        ? user.apartments!.first.name
        : (user.apartmentName ?? user.apartmentId ?? 'N/A');

    debugPrint('====================================================');
    debugPrint('📱 [MOBILE SIGN-IN LOG] 📱');
    debugPrint('🎭 SIGNING IN ROLE    : ${user.userType.name.toUpperCase()} (loginRole: ${user.loginRole ?? 'N/A'})');
    debugPrint('🏢 SIGNING IN PROPERTY: $activeApartment (ID: ${user.apartmentId ?? "N/A"})');
    debugPrint('🏫 PROPERTY TYPE     : ${user.propertyType?.name ?? "N/A"}');
    debugPrint('====================================================');

    String route = AppRoutes.login;
    switch (user.userType) {
      case UserType.admin:
        route = AppRoutes.adminDashboard;
        debugPrint('Selected route: $route (Admin Dashboard)');
        break;
      case UserType.apartment:
        route = AppRoutes.adminDashboard;
        debugPrint('Selected route: $route (Apartment Dashboard)');
        break;
      case UserType.user:
      case UserType.tenant:
        route = AppRoutes.userDashboard;
        debugPrint('Selected route: $route (User/Tenant Dashboard)');
        break;
      case UserType.security:
        route = AppRoutes.securityDashboard;
        debugPrint('Selected route: $route (Security Dashboard)');
        break;
      default:
        debugPrint('WARNING: Unknown userType, defaulting to login');
        route = AppRoutes.login;
    }

    debugPrint('Navigating to: $route');
    try {
      AppNavigation.resetTo(context, route);
      debugPrint('✓ Navigation successful');
    } catch (e) {
      debugPrint('✗ Navigation error: $e');
    }
  }

  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: const Text(
          'Please contact your administrator to reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          debugPrint('=== LOGIN PAGE STATE CHANGE ===');
          debugPrint('State: ${state.runtimeType}');

          if (state is AuthAuthenticated) {
            debugPrint('✓ Login successful!');
            setState(() {
              _isLoading = false;
            });
            if (state.user.status == AccountStatus.pending) {
              Navigator.pushReplacementNamed(
                  context, AppRoutes.waitingApproval);
            } else if (state.user.status == AccountStatus.approved) {
              _navigateToDashboard(state.user);
            } else if (state.user.status == AccountStatus.rejected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Your account has been rejected. Please contact administrator.'),
                  backgroundColor: AppTheme.errorColor,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          } else if (state is AuthUnauthenticated) {
            setState(() {
              _isLoading = false;
            });
          } else if (state is AuthError) {
            debugPrint('✗ Login error: ${state.message}');
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is AuthLoading) {
            setState(() {
              _isLoading = true;
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        },
        child: Stack(
          children: [
            // Ambient Glass Orbs
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF60A5FA),
                      Color(0xFF2563EB),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF38BDF8),
                      Color(0xFF0284C7),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Backdrop Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.white.withOpacity(0.4)),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),

                        // Glass Logo Container
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              height: 90,
                              width: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(4),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/maccess.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          AppConstants.appName,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Welcome Back',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Sign in to access your portal',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (_selectedUserType != null) ...[
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xFF2563EB).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.shield_outlined,
                                      color: Color(0xFF2563EB),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Login Type: ${_getUserTypeName(_selectedUserType!)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Form Container Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.75),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.05),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    enabled: !_isLoading,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                                    },
                                    decoration: InputDecoration(
                                      labelText: _selectedUserType == UserType.admin
                                          ? 'Email'
                                          : 'Email or mobile number',
                                      labelStyle: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                      prefixIcon: Icon(
                                        _selectedUserType == UserType.admin
                                            ? Icons.email_outlined
                                            : Icons.person_outline,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2563EB),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return _selectedUserType == UserType.admin
                                            ? 'Please enter your email'
                                            : 'Please enter your email or mobile number';
                                      }
                                      if (_selectedUserType != UserType.admin) {
                                        final trimmed = value.trim();
                                        if (RegExp(r'^\d{10}$').hasMatch(trimmed)) {
                                          return null;
                                        }
                                        final emailRegex = RegExp(
                                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                        );
                                        if (emailRegex.hasMatch(trimmed)) {
                                          return null;
                                        }
                                        return 'Please enter a valid email or 10-digit mobile number';
                                      }
                                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                      if (!emailRegex.hasMatch(value)) {
                                        return 'Please enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  TextFormField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    enabled: !_isLoading,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onFieldSubmitted: (_) {
                                      _handleLogin();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outlined,
                                        color: Color(0xFF2563EB),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: const Color(0xFF64748B),
                                        ),
                                        onPressed: _isLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2563EB),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 24),

                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (context, state) {
                                      final isLoading = state is AuthLoading || _isLoading;
                                      return BrandGradientCtaButton(
                                        label: 'Login',
                                        icon: Icons.login_rounded,
                                        onPressed: isLoading ? null : _handleLogin,
                                        isLoading: isLoading,
                                      );
                                    },
                                  ),

                                  if (_selectedUserType != UserType.admin) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading ? null : _navigateToForgotPassword,
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredential(String role, String email, String password) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$role: $email / $password',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String _getUserTypeName(UserType userType) {
    switch (userType) {
      case UserType.admin:
        return 'Admin';
      case UserType.security:
        return 'Security';
      case UserType.user:
        return 'User';
      case UserType.apartment:
        return 'Management';
      case UserType.tenant:
        return 'User';
    }
  }
}
