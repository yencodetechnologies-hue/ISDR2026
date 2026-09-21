import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/leave_request_model.dart';
import '../../../../../core/widgets/user_qr_code_frame.dart';

class LeaveGatePassSheet extends StatelessWidget {
  final LeaveGatePassPayload gatePass;

  const LeaveGatePassSheet({super.key, required this.gatePass});

  static Future<void> show(BuildContext context, LeaveGatePassPayload gatePass) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LeaveGatePassSheet(gatePass: gatePass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leave = gatePass.leaveRequest;
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    final validFmt = DateFormat('d MMM yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewPadding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.brandAccentGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'APPROVED OUT PASS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            gatePass.hostelName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _TimeRow(
                  icon: Icons.logout_rounded,
                  label: 'Going out',
                  value: fmt.format(leave.outAt),
                  color: AppTheme.primaryColor,
                ),
                const Divider(height: 20),
                _TimeRow(
                  icon: Icons.login_rounded,
                  label: 'Return by',
                  value: fmt.format(leave.expectedInAt),
                  color: AppTheme.secondaryColor,
                ),
              ],
            ),
          ),
          if (gatePass.validTill != null) ...[
            const SizedBox(height: 10),
            Text(
              'Valid till ${validFmt.format(gatePass.validTill!)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          UserQrCodeFrame(
            child: QrImageView(
              data: gatePass.qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Show this QR at the security gate',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
