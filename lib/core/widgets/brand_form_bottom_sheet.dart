import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import 'brand_gradient_cta_button.dart';

/// Shared chrome for admin modal bottom sheets: handle, gradient header, body, footer.
class BrandFormBottomSheet extends StatelessWidget {
  const BrandFormBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.headerIcon,
    this.submitLabel = 'Save',
    this.submitIcon,
    this.onCancel,
    this.onSubmit,
    this.isSubmitLoading = false,
    this.showFooter = true,
  });

  final String title;
  final String? subtitle;
  final IconData? headerIcon;
  final Widget child;
  final String submitLabel;
  final IconData? submitIcon;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final bool isSubmitLoading;
  final bool showFooter;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
    IconData? headerIcon,
    String submitLabel = 'Save',
    IconData? submitIcon,
    VoidCallback? onSubmit,
    bool isScrollControlled = true,
    bool showFooter = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BrandFormBottomSheet(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        submitLabel: submitLabel,
        submitIcon: submitIcon,
        onCancel: () => Navigator.pop(ctx),
        onSubmit: onSubmit,
        showFooter: showFooter,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAF9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D4D0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GradientHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: headerIcon ?? Icons.edit_note_rounded,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: child,
                ),
                if (showFooter) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _FooterActions(
                      submitLabel: submitLabel,
                      submitIcon: submitIcon,
                      onCancel: onCancel,
                      onCancelFallback: () => Navigator.pop(context),
                      onSubmit: onSubmit,
                      isSubmitLoading: isSubmitLoading,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.title,
    this.subtitle,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13275D), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.06)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.7),
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
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.submitLabel,
    this.submitIcon,
    this.onCancel,
    required this.onCancelFallback,
    this.onSubmit,
    this.isSubmitLoading = false,
  });

  final String submitLabel;
  final IconData? submitIcon;
  final VoidCallback? onCancel;
  final VoidCallback onCancelFallback;
  final VoidCallback? onSubmit;
  final bool isSubmitLoading;

  VoidCallback? get _effectiveCancel =>
      isSubmitLoading ? null : (onCancel ?? onCancelFallback);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandGradientCtaButton(
                label: submitLabel,
                icon: submitIcon,
                onPressed: onSubmit,
                isLoading: isSubmitLoading,
                height: 48,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _effectiveCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: Color(0xFFECECEA)),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF13275D),
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _effectiveCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: Color(0xFFECECEA)),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF13275D),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: BrandGradientCtaButton(
                height: 48,
                label: submitLabel,
                icon: submitIcon,
                onPressed: onSubmit,
                isLoading: isSubmitLoading,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Standard filled input decoration for brand form sheets.
InputDecoration brandFormInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF13275D)),
    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8C8C90)),
    prefixIcon: Icon(icon, color: const Color(0xFF13275D), size: 20),
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
      borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}
