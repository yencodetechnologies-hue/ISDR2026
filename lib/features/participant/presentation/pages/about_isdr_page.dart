import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _OfficeBearer {
  final String name;
  final String role;
  final String imagePath;
  final String designation;

  const _OfficeBearer({
    required this.name,
    required this.role,
    required this.imagePath,
    required this.designation,
  });
}

class AboutISDRPage extends StatelessWidget {
  const AboutISDRPage({super.key});

  static const List<_OfficeBearer> _officeBearers = [
    _OfficeBearer(
      name: 'DR. RITU DUGGAL',
      role: 'President',
      imagePath: 'assets/DR.-RITU-DUGGAL.webp',
      designation:
          'Chief & Professor, Department of Orthodontics, CDER, AIIMS, New Delhi',
    ),
    _OfficeBearer(
      name: 'DR. MAHESH VERMA',
      role: 'President Elect',
      imagePath: 'assets/DR.-MAHESH-VERMA.webp',
      designation:
          'Vice Chancellor, Guru Gobind Singh, Indraprastha University, New Delhi',
    ),
    _OfficeBearer(
      name: 'DR. VIJAY MATHUR',
      role: 'Vice President',
      imagePath: 'assets/DR.-VIJAY-MATHUR.webp',
      designation:
          'Professor & Head, Division of Pedodontics & Preventive Dentistry, CDER, AIIMS, New Delhi',
    ),
    _OfficeBearer(
      name: 'DR. DEEPAK CHANDRA',
      role: 'Vice President',
      imagePath: 'assets/DR.-DEEPAK-CHANDRA.webp',
      designation:
          'Professor & Head, Department of Orthodontics & Dentofacial Orthopedics, SRM Kattankulathur Dental College & Hospital, Chennai',
    ),
    _OfficeBearer(
      name: 'DR. NAMITA SHANBHAG',
      role: 'Vice President',
      imagePath: 'assets/DR.-NAMITA-SHANBHAG.webp',
      designation:
          'Associate Professor, Public Health Dentistry, Government Dental College & Research Institute, Bangalore',
    ),
    _OfficeBearer(
      name: 'DR. S. M. BALAJI',
      role: 'Secretary General',
      imagePath: 'assets/DR.-S.-M.-BALAJI.webp',
      designation:
          'Director, Cranio-Maxillofacial Surgeon, Balaji Dental & Craniofacial Hospital, Chennai',
    ),
    _OfficeBearer(
      name: 'DR. PREETHA BALAJI',
      role: 'Joint Secretary',
      imagePath: 'assets/DR.-PREETHA-BALAJI.webp',
      designation:
          'Department of Oral & Maxillofacial Surgery, Balaji Dental & Craniofacial Hospital, Chennai',
    ),
    _OfficeBearer(
      name: 'DR. ANIL KOHLI',
      role: 'Editor-In-Chief - IJDR',
      imagePath: 'assets/DR.-ANIL-KOHLI.webp',
      designation: 'Former President, DCI, New Delhi',
    ),
    _OfficeBearer(
      name: 'DR. S. KISHORE KUMAR',
      role: 'Treasurer',
      imagePath: 'assets/DR.-S.-KISHORE-KUMAR.webp',
      designation:
          'Vice Principal, Sree Balaji Dental College & Hospital, Chennai',
    ),
  ];

  static const List<String> _executiveCouncil = [
    'Dr. P Rajesh',
    'Dr. S. Bhuminathan',
    'Dr. S. Balagopal',
    'Dr. Cynthia Sathiasekar',
    'Dr. S. Mahalaxmi',
    'Dr. P. S. Thaha',
    'Dr. Deenadayalan .P',
    'Dr. Jacob Raja',
    'Dr. N. Gopi Chander',
    'Dr. Harsh Priya',
    'Dr. Arpit Gupta',
    'Dr. Jaideep Mahendra',
    'Dr. N. Velmurugan',
    'Dr. Puneet Batra',
    'Dr. H. Thamizhchelvan',
    'Dr. Mahesh Chawda',
    'Dr. Deepika Mishra',
    'Dr. D. Gopalakrishnan',
    'Dr. Nitika Monga',
    'Dr. Shantanu Choudhari',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: buildDarkAppBar(
        title: Text(
          'About ISDR',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conference Logo / Banner Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141F),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  height: 65,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Main Intro Card
            _buildTextCard(
              title: 'Indian Society for Dental Research',
              content:
                  'The Indian Society for Dental Research (ISDR) is India’s premier scientific organization dedicated to advancing dental, oral, and craniofacial research. As the Indian Division of the International Association for Dental, Oral and Craniofacial Research (IADR), ISDR has, since its establishment in 1986, remained committed to promoting excellence in scientific research, innovation, and evidence-based clinical practice.\n\n'
                  'The Society traces its origins to the vision of Dr. M. Rahmatulla, who conceived the idea of establishing an Indian division of the IADR after attending the 64th IADR Annual Session in Dallas, Texas, USA, in March 1984. Following two years of dedicated efforts, the inaugural convention was held in July 1986 at Hotel Connemara, Madras (Chennai), where Dr. Rahmatulla was unanimously elected as the Founder President of the IADR Indian Division. Dr. J. G. Kannapan and Dr. P. K. Baskar also played instrumental roles in establishing the organization. Initially named the Indian Association for Dental Research, the organization was subsequently renamed the Indian Society for Dental Research (ISDR) on the recommendation of its parent body, while continuing as the official Indian Division of the IADR.\n\n'
                  'Over nearly four decades, the ISDR Annual Conference has evolved into one of the country’s most prestigious scientific gatherings, attracting eminent national and international experts who present pioneering research, technological innovations, and advances in clinical practice. Through keynote lectures, scientific sessions, workshops, panel discussions, free paper presentations, and poster sessions, the conference fosters meaningful academic interactions, encourages collaborative research, and inspires the next generation of clinician-scientists.',
            ),
            const SizedBox(height: 18),

            // 36th Conference Theme Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded,
                          color: Color(0xFFFBBF24), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '36th ISDR International Conference 2026',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      '“Translational Dental Research: Bridging Science and Care”',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: const Color(0x4DF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hosted by Sree Balaji Dental College & Hospital, Bharath Institute of Higher Education and Research (BIHER), Chennai, marks another significant milestone in this remarkable journey. Bringing together distinguished scientists, clinicians, educators, industry leaders, and students from across the world.\n\n'
                    'This theme highlights the critical importance of transforming laboratory discoveries into innovative clinical solutions that improve patient outcomes and advance oral healthcare. The conference aims to promote interdisciplinary collaboration and showcase cutting-edge developments in biomaterials, regenerative dentistry, artificial intelligence, precision dentistry, public health, digital technologies, and other emerging areas that are shaping the future of dental science and practice.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.55,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // =================================================================
            // ISDR Office Bearers Section
            // =================================================================
            Center(
              child: Column(
                children: [
                  Text(
                    'ISDR Office Bearers',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFBBF24),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Office Bearer Cards
            for (final bearer in _officeBearers) ...[
              _buildBearerCard(bearer),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),

            // =================================================================
            // Executive Council Members (Expandable Accordion Card)
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14141F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Executive Council',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '20 Members • ISDR Indian Division',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  children: [
                    const Divider(height: 1, color: Color(0x1AFFFFFF)),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _executiveCouncil.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 12, color: Color(0xFF1E1E2A)),
                      itemBuilder: (context, index) {
                        final number = (index + 1).toString().padLeft(2, '0');
                        final name = _executiveCouncil[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    number,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // =================================================================
            // Webmaster Section
            // =================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14141F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEBMASTER',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dr. Sri Ganesh',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildTextCard({
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.6,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBearerCard(_OfficeBearer bearer) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Natural aspect-ratio image with no letterbox bars
          Container(
            width: 95,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                bearer.imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.person, size: 36, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Doctor details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Role Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bearer.role,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Name
                Text(
                  bearer.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),

                // Designation
                Text(
                  bearer.designation,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.35,
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
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

