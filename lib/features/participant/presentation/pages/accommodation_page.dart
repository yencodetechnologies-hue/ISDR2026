import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _NearbyResort {
  final String name;
  final String phone;

  const _NearbyResort({
    required this.name,
    required this.phone,
  });
}

class AccommodationPage extends StatelessWidget {
  const AccommodationPage({super.key});

  static const List<_NearbyResort> _nearbyResorts = [
    _NearbyResort(name: 'Ideal Beach Resort', phone: '044-24495161'),
    _NearbyResort(name: 'Coral Beach Resort', phone: '9444333333'),
    _NearbyResort(name: 'Hotel Mahabs', phone: '044-27442643'),
    _NearbyResort(name: 'Golden Sun Beach Resort', phone: '7845732245'),
    _NearbyResort(name: 'Hotel Mamallaa Heritage', phone: '044-46270563'),
    _NearbyResort(name: 'Landmark Pallavaa Beach Resort', phone: '8939944400'),
    _NearbyResort(name: 'Four Points by Sheraton', phone: '044-71513636'),
    _NearbyResort(name: 'Chariot Beach Resort', phone: '9444992727'),
    _NearbyResort(name: 'Radisson Blu Resort Temple Bay', phone: '8062210102'),
    _NearbyResort(name: 'Welcome Hotel by ITC Hotels', phone: '044-26421534'),
    _NearbyResort(name: 'Grande Bay Resort & Spa', phone: '044-48133853'),
    _NearbyResort(name: 'Shelter Beach Resort', phone: '9840333114'),
    _NearbyResort(name: 'La Villa Beach Paradise', phone: '9840032297'),
    _NearbyResort(name: 'IZI Beach Stay', phone: '9940130775'),
    _NearbyResort(name: 'Bay Inn', phone: '8754413030'),
    _NearbyResort(name: 'Sea Breeze', phone: '9962047297'),
  ];

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not dial: $phoneNumber')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: buildDarkAppBar(
        title: Text(
          'Accommodation',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. IN-HOUSE ACCOMMODATION HERO CARD
            _buildInHouseCard(context),
            const SizedBox(height: 14),

            // 2. PAYMENT WARNING & CONTACT CARD
            _buildPaymentWarningCard(context),
            const SizedBox(height: 14),

            // 3. CHECK-IN / CHECK-OUT SCHEDULE
            _buildScheduleCard(),
            const SizedBox(height: 20),

            // 4. OTHER NEARBY RESORTS SECTION
            _buildSectionHeader('OTHER NEARBY RESORTS & HOTELS'),
            const SizedBox(height: 10),
            _buildNearbyResortsList(context),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }

  /// In-house Palace Accommodation Card
  Widget _buildInHouseCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  'VENUE STAY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.castle_rounded, color: Color(0xFFFBBF24), size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'In-House Accommodation',
            style: GoogleFonts.outfit(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 14, color: Color(0xFF93C5FD)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Kaldan Samudhra Palace Resort, Mahabalipuram',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF93C5FD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pricing Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FULL ROOM',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹20,000/-',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'per day',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHARED ROOM',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: const Color(0xFF67E8F9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹10,000/-',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'twin sharing / day',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'The registered delegates are requested to contact for in-house accommodation @ Kaldan Samudhra Palace.',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  /// Warning & Direct Contact Action Card
  Widget _buildPaymentWarningCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1AF59E0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DF59E0B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IMPORTANT PAYMENT NOTICE',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFFFCD34D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please do not make accommodation payments to the registration QR code or conference bank account.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFCD34D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x4DF59E0B), height: 1),
          const SizedBox(height: 12),

          // Contact Representative Pill Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14141F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x26F59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFFFBBF24), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ms. Radhika',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Accommodation & Details',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: Text(
                    '9940211202',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _makePhoneCall(context, '9940211202'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Dr. Pugazendhi Highlighted Contact (without any title)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1C18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x33F59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFFBBF24), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dr. Pugazendhi',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: Text(
                    '9841063742',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _makePhoneCall(context, '9841063742'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Check-In / Check-Out Schedule Card
  Widget _buildScheduleCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x263B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.login_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK-IN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        '12:00 Noon',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '9 October 2026',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: const Color(0x1AFFFFFF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x26EF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK-OUT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        '12:00 Noon',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '11 October 2026',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
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

  /// Nearby Resorts List
  Widget _buildNearbyResortsList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _nearbyResorts.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: const Icon(Icons.hotel_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              title: Text(
                _nearbyResorts[i].name,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                _nearbyResorts[i].phone,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2563EB), size: 20),
                onPressed: () => _makePhoneCall(context, _nearbyResorts[i].phone),
              ),
            ),
            if (i < _nearbyResorts.length - 1)
              const Divider(color: Color(0xFF1E1E2A), height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}
