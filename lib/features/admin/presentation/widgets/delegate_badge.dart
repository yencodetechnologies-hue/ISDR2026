import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Participant badge built on `assets/delegate_badge_template.png` (1200 x 1465):
/// name in the green band, ID / designation / institution below it, the QR
/// inside the template's box and the ticket code under the QR.
class DelegateBadge extends StatelessWidget {
  static const double templateWidth = 1200;
  static const double templateHeight = 1465;

  /// The framed design inside the template (the rest is a dark margin): exactly 100 x 130 mm.
  static const double cropLeft = 60;
  static const double cropTop = 25;
  static const double badgeWidth = 1080;
  static const double badgeHeight = 1404;

  final Map<String, dynamic> registration;

  const DelegateBadge({super.key, required this.registration});

  String _v(String key) => registration[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final displayName = [_v('title'), _v('name')].where((e) => e.isNotEmpty).join(' ');
    final typeLabel = (_v('participantType').isEmpty ? 'Delegate' : _v('participantType')).toUpperCase();
    final idNumber = _v('idNumber');
    final designation = _v('designation');
    final institution = _v('institution');
    final qrData = _v('qrCode');
    final ticketCode = _v('ticketCode');
    const ink = Color(0xFF0F172A);

    Widget fitted(String text, double size, FontWeight weight, Color color) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: TextStyle(fontSize: size, fontWeight: weight, color: color)),
        );

    return AspectRatio(
      aspectRatio: badgeWidth / badgeHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: badgeWidth,
          height: badgeHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -cropLeft,
                top: -cropTop,
                width: templateWidth,
                height: templateHeight,
                child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset('assets/delegate_badge_template.png', fit: BoxFit.fill),
              ),
              Positioned(
                left: 150,
                top: 422,
                width: 888,
                height: 100,
                child: Center(child: fitted(typeLabel, 64, FontWeight.w800, Colors.white)),
              ),
              Positioned(
                left: 150,
                top: 550,
                width: 888,
                child: Column(
                  children: [
                    if (displayName.isNotEmpty) ...[
                      fitted(displayName, 56, FontWeight.w800, ink),
                      const SizedBox(height: 16),
                    ],
                    if (idNumber.isNotEmpty) ...[
                      fitted('ID No: $idNumber', 46, FontWeight.w800, ink),
                      const SizedBox(height: 14),
                    ],
                    if (designation.isNotEmpty) ...[
                      fitted(designation, 42, FontWeight.w700, ink),
                      const SizedBox(height: 12),
                    ],
                    if (institution.isNotEmpty)
                      Text(
                        institution,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: ink, height: 1.25),
                      ),
                  ],
                ),
              ),
              if (qrData.isNotEmpty)
                Positioned(
                  left: 440,
                  top: 830,
                  width: 320,
                  height: 320,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(4),
                    child: QrImageView(data: qrData, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                ),
              if (ticketCode.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 1160,
                  width: templateWidth,
                  child: Center(
                    child: Text(
                      ticketCode.split('').join(' '),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
