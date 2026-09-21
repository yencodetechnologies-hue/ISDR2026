import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/user_qr_code_frame.dart';
import '../../../../core/models/visitor_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VisitorDetailsPage extends StatefulWidget {
  final VisitorModel visitor;

  const VisitorDetailsPage({super.key, required this.visitor});

  @override
  State<VisitorDetailsPage> createState() => _VisitorDetailsPageState();
}

class _VisitorDetailsPageState extends State<VisitorDetailsPage> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _callVisitor() async {
    final digits = widget.visitor.mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
        );
      }
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final image = await _captureQRCode();
      if (image != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/qr_code_${widget.visitor.id}.png');
        await file.writeAsBytes(image);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Visitor QR Code for ${widget.visitor.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR code: $e')),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      final image = await _captureQRCode();
      if (image != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/qr_code_${widget.visitor.id}.png');
        await file.writeAsBytes(image);
        await Gal.putImage(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code saved to gallery'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving QR code: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _captureQRCode() async {
    try {
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Visitor Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  // Profile Image with enhanced styling
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (widget.visitor.image?.trim().isNotEmpty == true)
                          ? (widget.visitor.image!.trim().startsWith('http')
                              ? Image.network(
                                  widget.visitor.image!.trim(),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar(70);
                                  },
                                )
                              : Image.file(
                                  File(widget.visitor.image!.trim()),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar(70);
                                  },
                                ))
                          : _buildDefaultAvatar(70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.visitor.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _callVisitor,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Call',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Visitor Information Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildInfoCard(
                context,
                'Visitor Information',
                [
                  _buildInfoRow(
                    'Name',
                    widget.visitor.name,
                    Icons.person_rounded,
                    AppTheme.primaryColor,
                  ),
                  _buildInfoRow(
                    'Category',
                    widget.visitor.category.name.toUpperCase(),
                    Icons.category_rounded,
                    AppTheme.accentColor,
                  ),
                  if (widget.visitor.category == VisitorCategory.relative &&
                      widget.visitor.relativeType != null)
                    _buildInfoRow(
                      'Relative Type',
                      widget.visitor.relativeType!.name.toUpperCase(),
                      Icons.family_restroom_rounded,
                      AppTheme.primaryColor,
                    ),
                  if (widget.visitor.category == VisitorCategory.outsider)
                    _buildInfoRow(
                      'Visitor Type',
                      widget.visitor.typeLabelLine.toUpperCase(),
                      Icons.person_outline_rounded,
                      AppTheme.secondaryColor,
                    ),
                  if (widget.visitor.reasonForVisit != null)
                    _buildInfoRow(
                      'Reason',
                      widget.visitor.reasonForVisit!,
                      Icons.description_rounded,
                      AppTheme.accentColor,
                    ),
                  _buildInfoRow(
                    'Block',
                    widget.visitor.block,
                    Icons.apartment_rounded,
                    AppTheme.primaryColor,
                  ),
                  _buildInfoRow(
                    'Room',
                    widget.visitor.homeNumber,
                    Icons.home_rounded,
                    AppTheme.secondaryColor,
                  ),
                  _buildInfoRow(
                    'Visit Date & Time',
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(widget.visitor.visitTime),
                    Icons.calendar_today_rounded,
                    AppTheme.accentColor,
                  ),
                  _buildInfoRow(
                    'Status',
                    widget.visitor.statusLabel,
                    Icons.timeline_rounded,
                    AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildTimelineCard(),
            ),
            const SizedBox(height: 12),
            // QR Code and OTP only shown when visitor is approved or inside
            if (widget.visitor.isRegistered &&
                (widget.visitor.isApprovedForGate || widget.visitor.isInside) &&
                widget.visitor.qrCode != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildQRCodeCard(context, widget.visitor.qrCode!),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.visitor.isRegistered &&
                (widget.visitor.isApprovedForGate || widget.visitor.isInside) &&
                widget.visitor.otp != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildOTPCard(context, widget.visitor.otp!),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    final steps = <({String label, DateTime? value, bool completed})>[
      (label: 'Requested', value: widget.visitor.visitTime, completed: true),
      (
        label: 'Approved',
        value: widget.visitor.approvedAt,
        completed: widget.visitor.approvedAt != null || widget.visitor.isApprovedForGate || widget.visitor.isInside || widget.visitor.isCompleted
      ),
      (
        label: 'Entered',
        value: widget.visitor.enteredAt,
        completed: widget.visitor.enteredAt != null || widget.visitor.isInside || widget.visitor.isCompleted
      ),
      (
        label: 'Exited',
        value: widget.visitor.exitedAt,
        completed: widget.visitor.exitedAt != null || widget.visitor.isCompleted
      ),
    ];

    return _buildInfoCard(
      context,
      'Visit Timeline',
      steps
          .map(
            (step) => _buildInfoRow(
              step.label,
              step.value != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(step.value!)
                  : (step.completed ? widget.visitor.statusLabel : 'Not yet'),
              step.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              step.completed ? AppTheme.secondaryColor : AppTheme.dividerColor,
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildQRCodeCard(BuildContext context, String qrData) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.primaryColor.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Visitor QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrKey,
              child: UserQrCodeFrame(
                outerRadius: 20,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.nfc_rounded,
                  size: 18,
                  color: AppTheme.secondaryColor.withOpacityCompat(0.9),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Scan this QR at the gate for visitor entry',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.textColor.withOpacityCompat(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Share and Download Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: AppTheme.secondaryColor,
                    onTap: _shareQRCode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    color: AppTheme.primaryColor,
                    onTap: _downloadQRCode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPCard(BuildContext context, String otp) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Visitor OTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                otp,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this OTP with the visitor',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
