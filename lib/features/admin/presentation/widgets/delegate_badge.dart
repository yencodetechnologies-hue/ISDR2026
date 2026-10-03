import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Participant badge built on `assets/qr_pass_template.jpg` (591 x 768, the whole 100 x 130 mm card,
/// drawn at 1080 x 1404): participant type on a coloured banner (participantTypeColor, default #167E5D),
/// name, designation / institution below it and the QR. No ID code is shown.
class DelegateBadge extends StatelessWidget {
  static const double badgeWidth = 1080;
  static const double badgeHeight = 1404;

  /// Banner behind the participant type when none was chosen.
  static const String defaultTypeColorHex = '#167E5D';
  static const Color defaultTypeColor = Color(0xFF167E5D);
  static const Color speakerTypeColor = Color(0xFF9E0A0F);
  static const Color committeeTypeColor = Color(0xFF9E0A0F);
  static const Color organizerTypeColor = Color(0xFF1D4ED8);

  /// '#RRGGBB' or 'RRGGBB' → colour; null when it isn't a valid 6-digit hex.
  static Color? parseHex(String? hex) {
    final h = (hex ?? '').trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
    return Color(int.parse('FF$h', radix: 16));
  }

  final Map<String, dynamic> registration;

  const DelegateBadge({super.key, required this.registration});

  String _v(String key) => registration[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final displayName = [_v('title'), _v('name')].where((e) => e.isNotEmpty).join(' ');
    final rawType = RegExp(r'^spot register$', caseSensitive: false).hasMatch(_v('packageName'))
        ? ''
        : _v('participantType');
    final hasType = rawType.isNotEmpty;
    final storedColor = parseHex(_v('participantTypeColor'));
    // Speakers' passes read "INVITED SPEAKER" on #9E0A0F.
    final isSpeaker = RegExp(r'^(invited\s+)?speaker$', caseSensitive: false).hasMatch(rawType);
    final isCommittee = RegExp(
      r'^(organis(?:ing|zing)\s+committee|executive council members|isdr office bearers|iadr office bearer|invited dignitary)$',
      caseSensitive: false,
    ).hasMatch(rawType);
    // Event Organizer and Trade cards show the blue banner and QR only.
    final isOrganizer = RegExp(r'^(event\s+organizers?|trade)$', caseSensitive: false).hasMatch(rawType);
    final typeLabel = (isSpeaker ? 'Invited Speaker' : rawType).toUpperCase();
    final typeColor = parseHex(_v('participantTypeColor')) ??
        (isOrganizer
            ? organizerTypeColor
            : isSpeaker
                ? speakerTypeColor
                : isCommittee
                    ? committeeTypeColor
                    : defaultTypeColor);
    final designation = isOrganizer ? '' : _v('designation');
    final institution = isOrganizer ? '' : _v('institution');
    final shownName = isOrganizer ? '' : displayName;
    final qrData = _v('qrCode');
    const ink = Color(0xFF0F172A);
    // Name and the institution line (ISDR26-####) on every pass.
    const nameInk = Color(0xFF2E3192);

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
              Positioned.fill(
                child: Image.asset('assets/qr_pass_template.jpg', fit: BoxFit.fill),
              ),
              if (hasType || storedColor != null)
                Positioned(
                  left: 61,
                  top: 440,
                  width: 949,
                  height: 96,
                  child: ColoredBox(color: hasType ? typeColor : storedColor!),
                ),
              if (hasType)
                Positioned(
                  left: 120,
                  top: 440,
                  width: 840,
                  height: 96,
                  child: Center(child: fitted(typeLabel, 60, FontWeight.w800, Colors.white)),
                ),
              Positioned(
                left: 110,
                top: 562,
                width: 860,
                child: Column(
                  children: [
                    if (shownName.isNotEmpty) ...[
                      fitted(shownName, 56, FontWeight.w800, nameInk),
                      const SizedBox(height: 16),
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
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: nameInk, height: 1.25),
                      ),
                  ],
                ),
              ),
              if (qrData.isNotEmpty)
                Positioned(
                  left: 400,
                  top: 740,
                  width: 280,
                  height: 280,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(4),
                    child: QrImageView(data: qrData, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
