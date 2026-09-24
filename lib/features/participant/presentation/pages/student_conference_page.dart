import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _SpeakerInfo {
  final String name;
  final String role;
  final String affiliation;
  final String imagePath;

  const _SpeakerInfo({
    required this.name,
    required this.role,
    required this.affiliation,
    required this.imagePath,
  });
}

class _CommitteePerson {
  final String name;
  final String role;
  final String? subRole;
  final String? extraRole;
  final String imagePath;

  const _CommitteePerson({
    required this.name,
    required this.role,
    this.subRole,
    this.extraRole,
    required this.imagePath,
  });
}

class StudentConferencePage extends StatelessWidget {
  const StudentConferencePage({super.key});

  static const List<_SpeakerInfo> _keynoteSpeakers = [
    _SpeakerInfo(
      name: 'DR MURUGABASKAR',
      role: 'Research Scientist',
      affiliation: 'Boston Children’s Hospital / Harvard Medical School',
      imagePath: 'assets/DR-MURUGABASKAR.webp',
    ),
    _SpeakerInfo(
      name: 'DR. PAVITHRA KRISHNASWAMI',
      role: 'Senior Scientist',
      affiliation: 'Translational Medicine Unit, Sanofi\nGreater Boston, Cambridge, Massachusetts, USA',
      imagePath: 'assets/DR.PAVITHRA KRISHNASWAMI.webp',
    ),
    _SpeakerInfo(
      name: 'DR. SYLVIA ANNABEL DASS',
      role: 'Laboratory Manager',
      affiliation: 'Allen Healthcare Products (M) Sdn. Bhd. Penang, Malaysia',
      imagePath: 'assets/DR. SYLVIA ANNABEL DASS.webp',
    ),
  ];

  static const List<_CommitteePerson> _patrons = [
    _CommitteePerson(
      name: 'DR. S. JAGATHRAKSHAKAN',
      role: 'Founder Chairman',
      subRole: 'Bharath Institute of Higher Education and Research',
      extraRole: 'Chief Patron – 36th ISDR',
      imagePath: 'assets/DR.-S.-JAGATHRAKSHAKAN.webp',
    ),
    _CommitteePerson(
      name: 'DR. J. SRI NISHA',
      role: 'Vice President',
      subRole: 'Bharath Institute of Higher Education and Research\nChairperson – Sree Balaji Group of Institutions',
      extraRole: 'Organising Chairman – 36th ISDR',
      imagePath: 'assets/DR-J.-SRI-NISHA.webp',
    ),
    _CommitteePerson(
      name: 'ER. N. ELAMARAN',
      role: 'Managing Director',
      subRole: 'Sree Balaji Group of Institutions',
      extraRole: 'Patron – 36th ISDR',
      imagePath: 'assets/ER.-N.-ELAMARAN.webp',
    ),
  ];

  static const List<_CommitteePerson> _conferenceOrganisingCommittee = [
    _CommitteePerson(
      name: 'DR. S. M. BALAJI',
      role: 'Conference Executive Advisor',
      imagePath: 'assets/DR.-S.-M.-BALAJI-2.webp',
    ),
    _CommitteePerson(
      name: 'DR. MAHESH VERMA',
      role: 'Conference Secretary',
      imagePath: 'assets/DR.-MAHESH-VERMA-2.webp',
    ),
    _CommitteePerson(
      name: 'DR. S. BHUMINATHAN',
      role: 'Organising Secretary',
      imagePath: 'assets/DR.-S.-BHUMINATHAN.webp',
    ),
    _CommitteePerson(
      name: 'DR. M. S. KANNAN',
      role: 'Organising Co-Chairman',
      imagePath: 'assets/DR.-M.S.-KANNAN.webp',
    ),
    _CommitteePerson(
      name: 'DR. K. GNANA SHANMUGHAM',
      role: 'Chairman, Scientific Committee',
      imagePath: 'assets/DR.-K.-GNANA-SHANMUGHAM.webp',
    ),
  ];

  static const List<_CommitteePerson> _studentConferenceCommittee = [
    _CommitteePerson(
      name: 'DR. SUMATHI JONES',
      role: 'Convenor',
      imagePath: 'assets/DR.-GOLD-PEARLIN-MARY-1.webp', // fallback placeholder
    ),
    _CommitteePerson(
      name: 'DR. N. GOLD PEARLIN MARY',
      role: 'Co-Convenor',
      imagePath: 'assets/DR.-GOLD-PEARLIN-MARY-1.webp',
    ),
  ];

  static const List<String> _receptionHospitality = [
    'Dr. Malathy',
    'Dr. Kavya',
    'Dr. Durga Devi',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: buildDarkAppBar(
        title: Text(
          'Student Conference',
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
            // Hero Title Card
            _buildHeroBanner(),
            const SizedBox(height: 16),

            // Keynote Speakers Section (matching user image exactly)
            _buildKeynoteSpeakersSection(),
            const SizedBox(height: 20),

            // Preamble & Theme Card
            _buildPreambleCard(),
            const SizedBox(height: 20),

            // Patrons Section
            _buildSectionHeader('PATRONS'),
            const SizedBox(height: 8),
            for (final person in _patrons) ...[
              _buildPersonCard(person),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),

            // Conference Organising Committee
            _buildSectionHeader('CONFERENCE ORGANISING COMMITTEE'),
            const SizedBox(height: 8),
            for (final person in _conferenceOrganisingCommittee) ...[
              _buildPersonCard(person),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),

            // Students Conference Organising Committee
            _buildSectionHeader('STUDENTS CONFERENCE ORGANISING COMMITTEE'),
            const SizedBox(height: 8),
            for (final person in _studentConferenceCommittee) ...[
              _buildPersonCard(person),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),

            // Reception & Hospitality Accordion
            _buildSectionHeader('RECEPTION & HOSPITALITY'),
            const SizedBox(height: 8),
            _buildHospitalityAccordion(),
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
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }

  /// Hero Banner Card
  Widget _buildHeroBanner() {
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
              '36TH ISDR INTERNATIONAL CONFERENCE 2026',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: const Color(0xFFFBBF24),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Student’s Conference',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your Research. Your Discovery. Your Global Stage.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF93C5FD),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sree Balaji Dental College & Hospital, BIHER, Chennai',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Keynote Speakers Section (matching the provided screenshot)
  Widget _buildKeynoteSpeakersSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KEYNOTE SPEAKERS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF93C5FD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal scrolling or clean column layout for the 3 speakers
          for (int i = 0; i < _keynoteSpeakers.length; i++) ...[
            _buildKeynoteSpeakerItem(_keynoteSpeakers[i]),
            if (i < _keynoteSpeakers.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Color(0xFF1E1E2A), height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeynoteSpeakerItem(_SpeakerInfo speaker) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speaker Image matching the 1.2:1 clean frame without cropping distortion
        Container(
          width: 96,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              speaker.imagePath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.person, size: 36, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                speaker.name,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: const Color(0xFF93C5FD),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                speaker.role,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                speaker.affiliation,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Preamble & Theme Card
  Widget _buildPreambleCard() {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'PREAMBLE',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The 36th ISDR International Conference 2026, Student’s Conference, hosted by Sree Balaji Dental College & Hospital, BIHER, Chennai, invites students to present innovative work through Oral and Poster Presentations.\n\n'
            'Organized by the Indian Society for Dental Research (ISDR), the Indian Division of the IADR, this premier scientific conference provides a platform to showcase research, interact with renowned national and international experts, receive valuable feedback, and build global collaborations.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.55,
              color: const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      'CONFERENCE THEME',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '“Translational Dental Research: Bridging Science and Care”',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Highlights advances in diagnostics, biomaterials, regenerative dentistry, precision dentistry, artificial intelligence, digital health, and public health.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.45,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Leadership / Person Card
  Widget _buildPersonCard(_CommitteePerson person) {
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
          // Photo
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
                person.imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1E1E2A),
                  child: const Icon(Icons.person, size: 36, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.name,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  person.role,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                if (person.subRole != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    person.subRole!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.3,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
                if (person.extraRole != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x26F59E0B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      person.extraRole!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reception & Hospitality Expandable Accordion
  Widget _buildHospitalityAccordion() {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: ThemeData(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x263B82F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.room_service_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            title: Text(
              'Reception & Hospitality',
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              '${_receptionHospitality.length} Committee Members',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              const Divider(color: Color(0xFF1E1E2A), height: 1),
              const SizedBox(height: 12),
              Column(
                children: _receptionHospitality.map((name) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
