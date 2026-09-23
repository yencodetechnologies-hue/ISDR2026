import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
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
  bool _rememberMe = true;
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
      if (args is UserType) {
        setState(() {
          _selectedUserType = args;
        });
      }
    }
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

      // No role is picked up-front any more — the backend tries management,
      // then staff, then participant accounts against whatever was typed.
      final userType = _selectedUserType;

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
    String route = AppRoutes.login;
    switch (user.userType) {
      case UserType.admin:
        route = AppRoutes.userTypeSelection;
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
      case UserType.participant:
        route = AppRoutes.participantHome;
        break;
      case UserType.speaker:
        route = AppRoutes.speakerHome;
        break;
    }
    AppNavigation.resetTo(context, route);
  }

  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
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
        // No SafeArea here on purpose — the hero photo and footer are meant
        // to run edge-to-edge, behind the status bar and home indicator.
        child: SizedBox.expand(
          // Scales the whole page (never scrolls) to fill the screen edge
          // to edge, preserving proportions (no stretch) — any excess is
          // cropped off rather than left as a gap.
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.4),
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              // Fixed canvas size — this, not the card's own content, sets
              // the page's scale. Shrinking the card just leaves more room
              // above the footer; it no longer changes how wide the whole
              // page renders.
              width: 400,
              height: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroSection(),
                  const SizedBox(height: 20),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _buildLoginCard(),
                    ),
                  ),
                  const Spacer(),
                  const _FooterWave(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 26, height: 1, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 10),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF2563EB), size: 25),
                ),
                const SizedBox(width: 10),
                Container(width: 26, height: 1, color: const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome Back',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Sign in to access your portal',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              icon: Icons.mail_outline_rounded,
              hint: 'Email or mobile number',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocusNode),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email or mobile number';
                }
                final trimmed = value.trim();
                if (RegExp(r'^\d{10}$').hasMatch(trimmed)) return null;
                final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (emailRegex.hasMatch(trimmed)) return null;
                return 'Please enter a valid email or 10-digit mobile number';
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              icon: Icons.lock_outline_rounded,
              hint: 'Password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleLogin(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                ),
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _obscurePassword = !_obscurePassword),
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
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'Remember me',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isLoading ? null : _navigateToForgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isLoading = state is AuthLoading || _isLoading;
                return _GradientLoginButton(
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _handleLogin,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      style: GoogleFonts.inter(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF94A3B8),
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(9),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF2563EB)),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
      ),
      validator: validator,
    );
  }
}

/// Gradient blue Login button with stadium pill shape matching the design.
class _GradientLoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientLoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF1D6BE8), Color(0xFF1550D0)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D6BE8).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Login',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conference hero: background photo + 3 logo badges are placeholders until
/// the real assets are supplied — swap the gradient/_LogoBadge icons for
/// Image widgets once available.
/// The full conference hero graphic (logos, "36th ISDR…" title, dates,
/// tagline) is one supplied image — nothing is drawn on top of it.
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1024 / 933,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.94, 0.99],
            colors: [Colors.black, Colors.black, Colors.transparent],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'assets/WhatsApp Image 2026-09-22 at 11.46.04 AM.jpeg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

/// Blue multi-layered wavy footer matching the conference design:
/// - Layer 1 (back): Light ice-blue wave with a glowing 4-point sparkle highlight on the right.
/// - Layer 2 (mid): Azure cyan-blue wave.
/// - Layer 3 (front): Deep conference royal blue wave with "IADR • INDIAN DIVISION" and a rounded indicator pill.
class _FooterWave extends StatelessWidget {
  const _FooterWave();

  @override
  Widget build(BuildContext context) {
    const double footerHeight = 100;

    return SizedBox(
      width: double.infinity,
      height: footerHeight,
      child: Stack(
        children: [
          // The layered background & wave graphics
          Positioned.fill(
            child: CustomPaint(
              painter: _FooterWavesPainter(),
            ),
          ),
          // Content: Bottom rounded indicator pill
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: Container(
                width: 115,
                height: 3.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // =========================================================================
    // LAYER 1 (BACK): Light Ice / Sky Cyan Wave + Sparkle
    // =========================================================================
    final path1 = Path();
    path1.moveTo(0, h * 0.20);
    // Gentle trough on left then high sweep across to right
    path1.cubicTo(
      w * 0.14, h * 0.34,
      w * 0.32, h * 0.20,
      w * 0.60, h * 0.04,
    );
    path1.cubicTo(
      w * 0.76, -h * 0.04,
      w * 0.88, h * 0.06,
      w, h * 0.22,
    );
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();

    final paint1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD6EBFE),
          Color(0xFFA5D2FD),
          Color(0xFF70B8F8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path1, paint1);

    // Sparkle / Star Highlight on Layer 1 (Top Right)
    _drawSparkle(canvas, Offset(w * 0.80, h * 0.09), 11);

    // =========================================================================
    // LAYER 2 (MID): Vibrant Azure / Electric Blue Wave
    // =========================================================================
    final path2 = Path();
    path2.moveTo(0, h * 0.44);
    // Smooth trough on left and rise under Layer 1
    path2.cubicTo(
      w * 0.16, h * 0.52,
      w * 0.34, h * 0.32,
      w * 0.62, h * 0.16,
    );
    path2.cubicTo(
      w * 0.78, h * 0.08,
      w * 0.90, h * 0.22,
      w, h * 0.40,
    );
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();

    final paint2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF0284C7),
          Color(0xFF1D70D8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path2, paint2);

    // =========================================================================
    // LAYER 3 (FOREGROUND): Conference Deep Royal Blue Wave
    // =========================================================================
    final path3 = Path();
    // Starts lower on the left so Layer 1 & Layer 2 are clearly visible
    path3.moveTo(0, h * 0.66);
    path3.cubicTo(
      w * 0.20, h * 0.64,
      w * 0.36, h * 0.34,
      w * 0.52, h * 0.28,
    );
    path3.cubicTo(
      w * 0.72, h * 0.22,
      w * 0.86, h * 0.44,
      w, h * 0.62,
    );
    path3.lineTo(w, h);
    path3.lineTo(0, h);
    path3.close();

    final paint3 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1565C0),
          Color(0xFF0D47A1),
          Color(0xFF0A3470),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path3, paint3);
  }

  /// Draws a soft 4-point star / sparkle with a radial glow.
  void _drawSparkle(Canvas canvas, Offset center, double radius) {
    // Soft outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.2));
    canvas.drawCircle(center, radius * 2.2, glowPaint);

    // 4-point diamond star
    final starPath = Path();
    starPath.moveTo(center.dx, center.dy - radius);
    starPath.quadraticBezierTo(
        center.dx, center.dy, center.dx + radius, center.dy);
    starPath.quadraticBezierTo(
        center.dx, center.dy, center.dx, center.dy + radius);
    starPath.quadraticBezierTo(
        center.dx, center.dy, center.dx - radius, center.dy);
    starPath.quadraticBezierTo(
        center.dx, center.dy, center.dx, center.dy - radius);
    starPath.close();

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
