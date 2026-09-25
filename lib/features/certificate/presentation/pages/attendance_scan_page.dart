import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../../../user/presentation/pages/user_events_page.dart';

/// Event staff / admin: scan a participant's entry or exit for today.
/// Each is allowed once per participant per event day.
class AttendanceScanPage extends StatelessWidget {
  const AttendanceScanPage({super.key});

  void _open(BuildContext context, String type) {
    final api = ApiService();
    final label = type == 'entry' ? 'Entry' : 'Exit';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimInclusionScannerPage(
          inclusionName: '$label Scan',
          packageId: '',
          event: const {},
          apartmentId: null,
          api: api,
          onClaimed: () {},
          heading: 'Attendance',
          itemLabel: 'Scan',
          successText: '$label recorded for today.',
          submit: ({String? qrData, String? idNumber}) => api.scanAttendance(
            type: type,
            qrData: qrData,
            idNumber: idNumber,
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _open(context, type),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: darkCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: DarkColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: DarkColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Entry / Exit Scan',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context,
            type: 'entry',
            title: 'Entry Scan',
            subtitle: 'Scan the participant QR when they arrive',
            icon: Icons.login_rounded,
            color: const Color(0xFF22C55E),
          ),
          const SizedBox(height: 14),
          _card(
            context,
            type: 'exit',
            title: 'Exit Scan',
            subtitle: 'Scan the participant QR when they leave',
            icon: Icons.logout_rounded,
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 18),
          Text(
            'Entry and exit can each be scanned once per participant per day. '
            'Both are needed every day for the attendance certificate.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: DarkColors.muted),
          ),
        ],
      ),
    );
  }
}
