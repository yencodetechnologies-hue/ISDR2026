import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../../../../core/routes/app_routes.dart';
import '../bloc/auth_bloc.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  /// Seconds before "Resend OTP" is allowed again.
  static const _resendSeconds = 60;
  static const _otpLength = 6;

  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _storedOTP;
  Timer? _resendTimer;
  int _resendLeft = 0;

  @override
  void initState() {
    super.initState();
    // Repaint so the highlighted OTP box follows keyboard focus.
    _otpFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft--);
      if (_resendLeft <= 0) t.cancel();
    });
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

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      SendOtpEvent(
        email: _emailController.text.trim(),
        isForgotPassword: true,
      ),
    );
  }

  void _verifyOTP() {
    if (_otpController.text.trim().length != _otpLength) {
      _showSnackBar('Please enter the 6-digit OTP', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      VerifyOtpEvent(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      ),
    );
  }

  bool get _passwordLongEnough => _newPasswordController.text.length >= 6;
  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  void _resetPassword() {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please enter new password and confirm password', isError: true);
      return;
    }

    if (!_passwordLongEnough) {
      _showSnackBar('Password must be at least 6 characters long', isError: true);
      return;
    }

    if (!_passwordsMatch) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
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

  bool get _busy => context.watch<AuthBloc>().state is AuthLoading;

  /// Dark text field (the logged-in screens' look).
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: DarkColors.text),
      cursorColor: DarkColors.accentLight,
      decoration: darkInputDecoration(label, icon).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: DarkColors.muted.withValues(alpha: 0.7)),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  color: DarkColors.muted,
                ),
                onPressed: onToggleObscure,
              ),
      ),
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      enabled: !_busy,
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
    );
  }

  /// Six digit boxes over one hidden text field (so paste and autofill work).
  Widget _otpBoxes() {
    final code = _otpController.text;
    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < _otpLength; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _OtpBox(
                      digit: i < code.length ? code[i] : '',
                      active: _otpFocus.hasFocus &&
                          (i == code.length ||
                              (i == _otpLength - 1 &&
                                  code.length == _otpLength)),
                    ),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocus,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: _otpLength,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordCheck(bool ok, String text) {
    final color = ok ? const Color(0xFF22C55E) : DarkColors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }

  Widget _backButton(VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: DarkColors.muted),
    child: const Text('Back'),
  );

  (String, String) get _stepText => switch (_currentStep) {
    0 => ('Forgot Password', 'Enter the email registered for your account.'),
    1 => ('Enter OTP', 'We sent a 6-digit code to ${_emailController.text.trim()}'),
    _ => ('New Password', 'Choose a new password for your account.'),
  };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _stepText;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      body: SafeArea(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is OtpSent) {
              setState(() {
                _currentStep = 1;
                _otpController.clear();
              });
              _startResendCountdown();
              _showSnackBar('OTP sent to your email');
            } else if (state is OtpVerified) {
              setState(() {
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
                        width: 84,
                        height: 84,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: DarkColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: DarkColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: darkCardDecoration(20),
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
                                color: _currentStep > 0
                                    ? DarkColors.accent
                                    : DarkColors.field,
                              ),
                            ),
                            _buildStepIndicator(1, 'OTP'),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: _currentStep > 1
                                    ? DarkColors.accent
                                    : DarkColors.field,
                              ),
                            ),
                            _buildStepIndicator(2, 'Password'),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Step 0: Enter Email
                        if (_currentStep == 0) ...[
                          _field(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email,
                            hint: 'Registered account email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          _SubmitButton(
                            label: 'Send OTP',
                            icon: Icons.mark_email_read_outlined,
                            loading: _busy,
                            onPressed: _requestOTP,
                          ),
                        ],

                        // Step 1: Enter OTP
                        if (_currentStep == 1) ...[
                          _otpBoxes(),
                          const SizedBox(height: 14),
                          Center(
                            child: _resendLeft > 0
                                ? Text(
                                    'Resend code in 0:${_resendLeft.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: DarkColors.muted,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _busy ? null : _requestOTP,
                                    child: const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: DarkColors.accentLight,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _backButton(
                                  _busy
                                      ? null
                                      : () {
                                          _resendTimer?.cancel();
                                          setState(() {
                                            _currentStep = 0;
                                            _resendLeft = 0;
                                            _otpController.clear();
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _SubmitButton(
                                  label: 'Verify OTP',
                                  icon: Icons.verified_user_rounded,
                                  loading: _busy,
                                  onPressed: _verifyOTP,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Step 2: Enter New Password
                        if (_currentStep == 2) ...[
                          _field(
                            controller: _newPasswordController,
                            label: 'New Password',
                            icon: Icons.lock,
                            obscure: _obscureNewPassword,
                            onToggleObscure: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock_outline,
                            obscure: _obscureConfirmPassword,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _passwordCheck(
                            _passwordLongEnough,
                            'At least 6 characters',
                          ),
                          _passwordCheck(_passwordsMatch, 'Passwords match'),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _backButton(
                                  _busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _currentStep = 1;
                                            _newPasswordController.clear();
                                            _confirmPasswordController.clear();
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _SubmitButton(
                                  label: 'Reset Password',
                                  icon: Icons.lock_reset_rounded,
                                  loading: _busy,
                                  onPressed: _resetPassword,
                                ),
                              ),
                            ],
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
                        color: DarkColors.accentLight,
                      ),
                    ),
                  ),
                ],
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
                ? DarkColors.accent
                : DarkColors.field,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : DarkColors.muted,
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
                ? DarkColors.accentLight
                : DarkColors.muted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// One OTP digit box; [active] marks the box the next digit goes into.
class _OtpBox extends StatelessWidget {
  final String digit;
  final bool active;

  const _OtpBox({required this.digit, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DarkColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? DarkColors.accent
              : digit.isNotEmpty
              ? DarkColors.accentLight.withValues(alpha: 0.4)
              : DarkColors.line,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: DarkColors.text,
        ),
      ),
    );
  }
}

/// Blue full-width action button with a spinner while the request runs.
class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: DarkColors.accent,
          disabledBackgroundColor: DarkColors.accent.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
