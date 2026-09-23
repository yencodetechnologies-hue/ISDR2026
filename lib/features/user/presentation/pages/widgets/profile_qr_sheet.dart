import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/leave_request_model.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/utils/current_property_context.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/constants/app_constants.dart';

/// Full-screen bottom sheet: resident / hostel ID QR with share & gallery save.
class ProfileQrSheet extends StatefulWidget {
  final UserModel user;
  final bool isHostel;
  final String? hostelName;

  const ProfileQrSheet({
    super.key,
    required this.user,
    this.isHostel = false,
    this.hostelName,
  });

  @override
  State<ProfileQrSheet> createState() => _ProfileQrSheetState();
}

class _ProfileQrSheetState extends State<ProfileQrSheet> {
  final ApiService _api = ApiService();

  HostelIdPayload? _hostelPayload;
  String? _backendQrData;
  bool _loadingHostel = false;
  bool _loadingStaffQr = false;
  String? _loadError;

  bool get _isStaff {
    final currentProp = resolveCurrentProperty(widget.user);
    final propType = currentProp?.propertyType ?? widget.user.propertyType ?? (widget.user.apartments != null && widget.user.apartments!.isNotEmpty ? widget.user.apartments!.first.propertyType : null);
    if (false) {
      return true;
    }

    final typeName = widget.user.userType.name.toLowerCase();
    final roleName = (widget.user.loginRole ?? '').toLowerCase();
    final name = widget.user.name.toLowerCase();
    final email = widget.user.email.toLowerCase();
    return typeName == 'staff' ||
        typeName == 'employee' ||
        roleName.contains('staff') ||
        roleName.contains('employee') ||
        name.contains('staff') ||
        email.contains('staff') ||
        (widget.user.department != null && widget.user.department!.trim().isNotEmpty) ||
        (widget.user.employeeId != null && widget.user.employeeId!.trim().isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    ScreenProtector.protectDataLeakageOn();
    if (widget.isHostel) {
      _loadHostelPayload();
    } else if (_isStaff) {
      _loadStaffQrPayload();
    }
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    ScreenProtector.protectDataLeakageOff();
    super.dispose();
  }

  Future<void> _loadHostelPayload() async {
    setState(() {
      _loadingHostel = true;
      _loadError = null;
    });
    final result = await _api.getHostelIdPayload();
    if (!mounted) return;
    if (result['success'] == true && result['payload'] != null) {
      setState(() {
        _hostelPayload = HostelIdPayload.fromJson(
          Map<String, dynamic>.from(result['payload'] as Map),
        );
        _loadingHostel = false;
      });
    } else {
      setState(() {
        _loadError = result['error']?.toString() ?? 'Failed to load hostel ID';
        _loadingHostel = false;
      });
    }
  }

  Future<void> _loadStaffQrPayload() async {
    setState(() {
      _loadingStaffQr = true;
    });
    final result = await _api.getStaffQr();
    if (!mounted) return;
    if (result['success'] == true && result['qrData'] != null) {
      setState(() {
        _backendQrData = result['qrData']?.toString();
        _loadingStaffQr = false;
      });
    } else {
      // Fallback staff payload JSON if server endpoint check fails
      final fallbackPayload = {
        'type': 'staff_entry',
        'userId': widget.user.id,
        'name': widget.user.name,
        'role': 'Staff',
        'mobileNumber': widget.user.mobileNumber,
        'apartmentId': widget.user.apartmentId ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      setState(() {
        _backendQrData = Uri.encodeComponent(fallbackPayload.toString());
        _loadingStaffQr = false;
      });
    }
  }

  String get _qrData {
    if (_backendQrData != null && _backendQrData!.isNotEmpty) {
      return _backendQrData!;
    }
    if (widget.isHostel && _hostelPayload != null) {
      return _hostelPayload!.qrData;
    }
    final id = widget.user.id;
    return id.length >= 10 ? id.substring(id.length - 10) : id;
  }

  String? get _badgeLabel {
    if (widget.isHostel) return 'HOSTEL ID';
    if (_isStaff) return 'STAFF ENTRY PASS';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final user = widget.user;
    final hostelPayload = _hostelPayload;
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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Top Action Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacityCompat(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isHostel ? 'Digital Hostel ID' : 'Digital Access Pass',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if ((widget.isHostel && _loadingHostel) || (!widget.isHostel && _loadingStaffQr))
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  )
                else if (widget.isHostel && _loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadHostelPayload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else
                  SingleChildScrollView(
                    child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F0F172A),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Card Top Decorative Header Pattern
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (_badgeLabel != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.verified_user_rounded,
                                                color: Colors.white,
                                                size: 13,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                _badgeLabel!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    AppConstants.appName,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // User Avatar
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withOpacityCompat(0.2),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacityCompat(0.1),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 40,
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      backgroundImage: user.profilePic != null &&
                                              user.profilePic!.isNotEmpty
                                          ? NetworkImage(user.profilePic!)
                                          : null,
                                      child: user.profilePic == null ||
                                              user.profilePic!.isEmpty
                                          ? const Icon(
                                              Icons.person_rounded,
                                              size: 40,
                                              color: AppTheme.primaryColor,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    user.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  if (widget.isHostel &&
                                      (widget.hostelName ?? hostelPayload?.hostelName)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.hostelName ?? hostelPayload!.hostelName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ] else if (user.email.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      user.email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _locationChips(user, hostelPayload),
                                  ),
                                  if (widget.isHostel && hostelPayload != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Valid till ${validFmt.format(hostelPayload.validTill)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  
                                  // Clean QR Card Frame
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: QrImageView(
                                      data: _qrData,
                                      version: QrVersions.auto,
                                      size: 180,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.qr_code_scanner_rounded,
                                        size: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        widget.isHostel
                                            ? 'Show code at gate for hostel entry'
                                            : 'Scan code at security gate for instant entry',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  List<Widget> _locationChips(UserModel user, HostelIdPayload? payload) {
    if (_isStaff) {
      return <Widget>[];
    }
    if (widget.isHostel) {
      final chips = <Widget>[];
      final room = user.hostelRoom?.isNotEmpty == true
          ? user.hostelRoom!
          : (payload?.hostelRoom ?? '');
      final bed = user.hostelBed?.isNotEmpty == true
          ? user.hostelBed!
          : (payload?.hostelBed ?? '');
      if (room.isNotEmpty) {
        chips.add(_UnitChip(icon: Icons.door_front_door_outlined, label: 'Room $room'));
      }
      if (bed.isNotEmpty) {
        chips.add(_UnitChip(icon: Icons.hotel_rounded, label: 'Bed $bed'));
      }
      return chips;
    }
    final chips = <Widget>[];
    if (user.block != null && user.block!.isNotEmpty) {
      chips.add(_UnitChip(icon: Icons.apartment_rounded, label: 'Block ${user.block}'));
    }
    if (user.roomNumber != null && user.roomNumber!.isNotEmpty) {
      chips.add(_UnitChip(icon: Icons.door_front_door_outlined, label: 'Door ${user.roomNumber}'));
    }
    return chips;
  }
}

class _UnitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UnitChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
