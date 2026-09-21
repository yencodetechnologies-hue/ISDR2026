import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';

class UserTypeSelectionPage extends StatefulWidget {
  const UserTypeSelectionPage({super.key});

  @override
  State<UserTypeSelectionPage> createState() => _UserTypeSelectionPageState();
}

class _UserTypeSelectionPageState extends State<UserTypeSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin(BuildContext context, UserType userType) {
    Navigator.pushNamed(
      context,
      AppRoutes.login,
      arguments: userType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Vibrant Background Mesh Orbs for Glass Reflection
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF60A5FA),
                    Color(0xFF3B82F6),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
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
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF34D399),
                    Color(0xFF10B981),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Global Soft Backdrop Blur on Mesh
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.white.withOpacity(0.4)),
            ),
          ),

          // Main Glass Content Layer
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      // Glass Header Card
                      GestureDetector(
                        onDoubleTap: () => _navigateToLogin(context, UserType.admin),
                        child: _GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          borderRadius: 22,
                          child: Row(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
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
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConstants.appName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Access & Security Management',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Title Text
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                ),
                                children: const [
                                  TextSpan(text: 'Welcome to\n'),
                                  TextSpan(
                                    text: 'M Access',
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select your workspace role to log in.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Light Glassmorphism Cards
                      _GlassRoleCard(
                        number: '01',
                        title: 'Management',
                        description: 'Properties, Hostels, Colleges & Admin',
                        icon: Icons.business_center_rounded,
                        accentColor: const Color(0xFF2563EB),
                        onTap: () => _navigateToLogin(context, UserType.apartment),
                      ),

                      const SizedBox(height: 16),

                      _GlassRoleCard(
                        number: '02',
                        title: 'User / Resident',
                        description: 'Residents, Students & Event Members',
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF0284C7),
                        onTap: () => _navigateToLogin(context, UserType.user),
                      ),

                      const SizedBox(height: 16),

                      _GlassRoleCard(
                        number: '03',
                        title: 'Security Gate',
                        description: 'Gate Verification & Visitor Check-in',
                        icon: Icons.shield_rounded,
                        accentColor: const Color(0xFF059669),
                        onTap: () => _navigateToLogin(context, UserType.security),
                      ),

                      const Spacer(),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassRoleCard extends StatefulWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _GlassRoleCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_GlassRoleCard> createState() => _GlassRoleCardState();
}

class _GlassRoleCardState extends State<_GlassRoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isHovered ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.white.withOpacity(0.55)
                    : Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isHovered
                      ? widget.accentColor.withOpacity(0.9)
                      : Colors.white.withOpacity(0.65),
                  width: _isHovered ? 1.6 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? widget.accentColor.withOpacity(0.15)
                        : const Color(0xFF0F172A).withOpacity(0.04),
                    blurRadius: _isHovered ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Glass Icon Container
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.accentColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.number,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: widget.accentColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Glass Arrow Circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isHovered ? widget.accentColor : Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.7),
                        width: 1,
                      ),
                      boxShadow: [
                        if (_isHovered)
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _isHovered ? Colors.white : const Color(0xFF0F172A),
                      size: 18,
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
}







