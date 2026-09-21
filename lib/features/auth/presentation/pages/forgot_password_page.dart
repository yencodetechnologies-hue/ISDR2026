import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/routes/app_routes.dart';
import '../bloc/auth_bloc.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _storedOTP;
  bool _isOtpSent = false;
  bool _isOtpVerified = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _requestOTP() {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter email address', isError: true);
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    context.read<AuthBloc>().add(
      SendOtpEvent(
        email: _emailController.text.trim(),
        isForgotPassword: true,
      ),
    );
  }

  void _verifyOTP() {
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter OTP', isError: true);
      return;
    }

    context.read<AuthBloc>().add(
      VerifyOtpEvent(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      ),
    );
  }

  void _resetPassword() {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please enter new password and confirm password', isError: true);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters long', isError: true);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    context.read<AuthBloc>().add(
      ResetPasswordEvent(
        email: _emailController.text.trim(),
        otp: _storedOTP ?? _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is OtpSent) {
                setState(() {
                  _isOtpSent = true;
                  _currentStep = 1;
                });
                _showSnackBar('OTP sent to your email');
              } else if (state is OtpVerified) {
                setState(() {
                  _isOtpVerified = true;
                  _storedOTP = _otpController.text.trim();
                  _currentStep = 2;
                });
                _showSnackBar('OTP verified successfully');
              } else if (state is PasswordResetSuccess) {
                _showSnackBar('Password reset successfully! Please login with your new password.');
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              } else if (state is AuthError) {
                _showSnackBar(state.message, isError: true);
              }
            },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Enter the email registered for your property or account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Step indicator
                          Row(
                            children: [
                              _buildStepIndicator(0, 'Email'),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: _currentStep > 0 ? AppTheme.primaryColor : Colors.grey[300],
                                ),
                              ),
                              _buildStepIndicator(1, 'OTP'),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: _currentStep > 1 ? AppTheme.primaryColor : Colors.grey[300],
                                ),
                              ),
                              _buildStepIndicator(2, 'Password'),
                            ],
                          ),
                          const SizedBox(height: 30),
                          
                          // Step 0: Enter Email
                          if (_currentStep == 0) ...[
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email, color: AppTheme.primaryColor),
                                hintText: 'Registered property / account email',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              enabled: !(context.watch<AuthBloc>().state is AuthLoading),
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                            ),
                            const SizedBox(height: 20),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final loading = state is AuthLoading;
                                return BrandGradientCtaButton(
                                  label: 'Send OTP',
                                  icon: Icons.mark_email_read_outlined,
                                  onPressed: loading ? null : _requestOTP,
                                  isLoading: loading,
                                );
                              },
                            ),
                          ],
                          
                          // Step 1: Enter OTP
                          if (_currentStep == 1) ...[
                            Text(
                              'OTP sent to email: ${_emailController.text}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _otpController,
                              decoration: InputDecoration(
                                labelText: 'Enter OTP',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                                hintText: 'Enter 6-digit OTP',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              enabled: !(context.watch<AuthBloc>().state is AuthLoading),
                            ),
                            const SizedBox(height: 20),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: state is AuthLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _currentStep = 0;
                                                  _otpController.clear();
                                                  _isOtpSent = false;
                                                });
                                              },
                                        child: const Text('Back'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: BrandGradientCtaButton(
                                        label: 'Verify OTP',
                                        icon: Icons.verified_user_rounded,
                                        onPressed: state is AuthLoading
                                            ? null
                                            : _verifyOTP,
                                        isLoading: state is AuthLoading,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: (context.watch<AuthBloc>().state is AuthLoading)
                                  ? null
                                  : () {
                                      setState(() {
                                        _otpController.clear();
                                      });
                                      _requestOTP();
                                    },
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                          
                          // Step 2: Enter New Password
                          if (_currentStep == 2) ...[
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword = !_obscureNewPassword;
                                    });
                                  },
                                ),
                                hintText: 'Enter new password (min 6 characters)',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                              obscureText: _obscureNewPassword,
                              enabled: !(context.watch<AuthBloc>().state is AuthLoading),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                hintText: 'Confirm new password',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              enabled: !(context.watch<AuthBloc>().state is AuthLoading),
                            ),
                            const SizedBox(height: 20),
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: state is AuthLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _currentStep = 1;
                                                  _newPasswordController.clear();
                                                  _confirmPasswordController.clear();
                                                });
                                              },
                                        child: const Text('Back'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: BrandGradientCtaButton(
                                        label: 'Reset Password',
                                        icon: Icons.lock_reset_rounded,
                                        onPressed: state is AuthLoading
                                            ? null
                                            : _resetPassword,
                                        isLoading: state is AuthLoading,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

