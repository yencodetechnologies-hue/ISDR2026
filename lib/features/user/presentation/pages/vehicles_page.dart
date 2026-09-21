import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/user_qr_code_frame.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/vehicle_model.dart';
import '../../../../core/services/api_service.dart';
import 'widgets/add_vehicle_dialog.dart' show AddVehicleSheet;

class VehiclesPage extends StatefulWidget {
  final UserModel user;

  const VehiclesPage({super.key, required this.user});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final ApiService _apiService = ApiService();
  List<VehicleModel> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);
    try {
      final response = await _apiService.getVehicles();
      if (mounted && response['success'] == true) {
        final list = response['vehicles'] as List? ?? [];
        setState(() {
          _vehicles = list
              .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddVehicleSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddVehicleSheet(),
      ),
    );
    if (added == true && mounted) {
      _loadVehicles();
    }
  }

  void _showVehicleQRSheet(VehicleModel vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VehicleQRSheet(vehicle: vehicle),
    );
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle'),
        content: Text(
          'Remove "${vehicle.vehicleNumber}" from your vehicle list? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final result = await _apiService.deleteVehicle(vehicle.id);
      if (!mounted) return;
      if (result['success'] == true) {
        _loadVehicles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle removed')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddVehicleSheet,
            tooltip: 'Add vehicle',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 80,
                        color: AppTheme.textColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No vehicles added yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textColor.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 280,
                        height: 52,
                        child: BrandGradientCtaButton(
                          height: 52,
                          icon: Icons.directions_car_rounded,
                          label: 'Add your first vehicle',
                          onPressed: _showAddVehicleSheet,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showVehicleQRSheet(vehicle),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: vehicle.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: vehicle.imageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                            errorWidget: (_, __, ___) => Icon(
                                              vehicle.iconData,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          vehicle.iconData,
                                          color: AppTheme.primaryColor,
                                          size: 28,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        vehicle.vehicleNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        vehicle.displayType,
                                        style: TextStyle(
                                          color: AppTheme.textColor
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2_rounded),
                                  color: AppTheme.primaryColor,
                                  onPressed: () =>
                                      _showVehicleQRSheet(vehicle),
                                  tooltip: 'View QR Code',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () => _deleteVehicle(vehicle),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _VehicleQRSheet extends StatefulWidget {
  final VehicleModel vehicle;

  const _VehicleQRSheet({required this.vehicle});

  @override
  State<_VehicleQRSheet> createState() => _VehicleQRSheetState();
}

class _VehicleQRSheetState extends State<_VehicleQRSheet> {
  final GlobalKey _qrKey = GlobalKey();

  String get _qrData => jsonEncode({'vehicleId': widget.vehicle.id});

  Future<Uint8List?> _captureQRCode() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final image = await _captureQRCode();
      if (image != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/vehicle_qr_${widget.vehicle.id}.png');
        await file.writeAsBytes(image);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Vehicle QR Code - ${widget.vehicle.vehicleNumber}',
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
        final file = File('${tempDir.path}/vehicle_qr_${widget.vehicle.id}.png');
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final v = widget.vehicle;

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
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textColor.withOpacityCompat(0.45),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.backgroundColor,
                  ),
                ),
              ),
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandSoftSurfaceGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacityCompat(0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacityCompat(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.brandHeaderGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withOpacityCompat(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'VEHICLE PASS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacityCompat(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          v.iconData,
                          color: AppTheme.primaryColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        v.vehicleNumber,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.displayType,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textColor.withOpacityCompat(0.55),
                        ),
                      ),
                      const SizedBox(height: 22),
                      UserQrCodeFrame(
                        outerRadius: 20,
                        child: QrImageView(
                          data: _qrData,
                          version: QrVersions.auto,
                          size: 190,
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_parking_rounded,
                            size: 18,
                            color:
                                AppTheme.secondaryColor.withOpacityCompat(0.9),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Scan at the gate to verify this vehicle',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color:
                                    AppTheme.textColor.withOpacityCompat(0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareQRCode,
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppTheme.primaryColor.withOpacityCompat(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandGradientCtaButton(
                      height: 48,
                      icon: Icons.download_rounded,
                      label: 'Download',
                      onPressed: _downloadQRCode,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
