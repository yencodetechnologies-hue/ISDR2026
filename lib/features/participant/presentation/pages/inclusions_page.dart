import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../widgets/inclusions_section.dart';

/// Every inclusion in the participant's package, day by day. An inclusion can
/// be claimed once per day, so each day shows its own "Claimed" banner.
class InclusionsPage extends StatelessWidget {
  const InclusionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: buildDarkAppBar(
        title: Text(
          'Inclusions',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: InclusionsSection(showHeader: true),
      ),
    );
  }
}
