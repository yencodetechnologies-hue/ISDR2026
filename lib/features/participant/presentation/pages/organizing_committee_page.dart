import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _CommitteeLead {
  final String name;
  final String role;
  final String imagePath;

  const _CommitteeLead({
    required this.name,
    required this.role,
    required this.imagePath,
  });
}

class _SubCommittee {
  final String title;
  final IconData icon;
  final List<String> members;

  const _SubCommittee({
    required this.title,
    required this.icon,
    required this.members,
  });
}

class OrganizingCommitteePage extends StatelessWidget {
  const OrganizingCommitteePage({super.key});

  static const List<_CommitteeLead> _leads = [
    _CommitteeLead(
      name: 'DR. S. JAGATHRAKSHAKAN',
      role: 'Founder Chairman',
      imagePath: 'assets/DR.-S.-JAGATHRAKSHAKAN.webp',
    ),
    _CommitteeLead(
      name: 'DR. J. SRI NISHA',
      role: 'Conference Organising Chairman',
      imagePath: 'assets/DR-J.-SRI-NISHA.webp',
    ),
    _CommitteeLead(
      name: 'ER. N. ELAMARAN',
      role: 'Managing Director',
      imagePath: 'assets/ER.-N.-ELAMARAN.webp',
    ),
    _CommitteeLead(
      name: 'DR. S. M. BALAJI',
      role: 'Conference Executive Advisor',
      imagePath: 'assets/DR.-S.-M.-BALAJI-2.webp',
    ),
    _CommitteeLead(
      name: 'DR. MAHESH VERMA',
      role: 'Conference Secretary',
      imagePath: 'assets/DR.-MAHESH-VERMA-2.webp',
    ),
    _CommitteeLead(
      name: 'DR. S. BHUMINATHAN',
      role: 'Organising Secretary',
      imagePath: 'assets/DR.-S.-BHUMINATHAN.webp',
    ),
    _CommitteeLead(
      name: 'DR. M.S. KANNAN',
      role: 'Organising Co-Chairman',
      imagePath: 'assets/DR.-M.S.-KANNAN.webp',
    ),
    _CommitteeLead(
      name: 'DR. K. GNANA SHANMUGHAM',
      role: 'Chairman, Scientific Committee',
      imagePath: 'assets/DR.-K.-GNANA-SHANMUGHAM.webp',
    ),
    _CommitteeLead(
      name: 'DR. RAGAVENDRA JAYESH',
      role: 'Conference Advisor',
      imagePath: 'assets/DR.-RAGAVENDRA-JAYESH-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. PONNUDURAI ARANGANNAL',
      role: 'Conference Advisor',
      imagePath: 'assets/DR.-PONNUDURAI-ARANGANNAL-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. BADRI THIRUVENKATACHARI',
      role: 'Co-Chairman, Scientific Committee',
      imagePath: 'assets/DR.-BADRI-THIRUVENKATACHARI-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. S. KISHORE KUMAR',
      role: 'Joint Secretary',
      imagePath: 'assets/DR.-S.-KISHORE-KUMAR-Organising-Committee.jpg-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. N. ARAVINDHA BABU',
      role: 'Treasurer',
      imagePath: 'assets/DR.N.-ARAVINDHA-BABU.webp',
    ),
    _CommitteeLead(
      name: 'DR. A. VENKATESH',
      role: 'Convener, Preconference Courses',
      imagePath: 'assets/DR.-A.-VENKATESH.webp',
    ),
    _CommitteeLead(
      name: 'DR. NALINI ASWATH',
      role: 'Convener Pre Conference Course Committee',
      imagePath: 'assets/DR.-NALINI-ASWATH-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. M. N. PRABHU',
      role: 'Convener, International Relations',
      imagePath: 'assets/DR.-M.-N-PRABHU.webp',
    ),
    _CommitteeLead(
      name: 'DR. VIJAY EBENEZER',
      role: 'Convener Banquet and Cultural Night',
      imagePath: 'assets/DR.-VIJAY-EBENEZER-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. ANITHA BALAJI',
      role: 'Convener Reception Committee',
      imagePath: 'assets/DR.-ANITHA-BALAJI-2.jpg.webp',
    ),
    _CommitteeLead(
      name: 'DR. M. ANITA',
      role: 'Convener Souvenir Committee',
      imagePath: 'assets/DR.-M.-ANITA-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. MANIKANDAN',
      role: 'Convener Trade',
      imagePath: 'assets/DR.-MANIKANDAN-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. SREE DEVI V',
      role: 'Convener Hospitality Committee',
      imagePath: 'assets/DR.-SREE-DEVI-V-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. GOLD PEARLIN MARY',
      role: 'Co-Convener Student Conference',
      imagePath: 'assets/DR.-GOLD-PEARLIN-MARY-1.webp',
    ),
    _CommitteeLead(
      name: 'DR. N. GEETHA PRIYA',
      role: 'Convener Awards Committee',
      imagePath: 'assets/DR.-N.-GEETHA-PRIYA-1.webp',
    ),
  ];

  static const List<_SubCommittee> _subCommittees = [
    _SubCommittee(
      title: 'Scientific Committee',
      icon: Icons.biotech_rounded,
      members: [
        'Dr. Gnana Shanmugham',
        'Dr. Thailavathy',
        'Dr. Jayasrikrupaa',
        'Dr. Balavenkata Bharathi Chaturvedula',
        'Dr. Ram Kiran K',
        'Dr. Shalini Krishnan',
        'Dr. Amutha M.V. Soorya',
        'Dr. Badri Thiruvenkatachari',
        'Dr. Leena Shankari',
        'Dr. Sadhana K.R',
        'Dr. S. Priya Dharshini',
        'Dr. R. Savitha Lakshmi',
      ],
    ),
    _SubCommittee(
      title: 'PCC Committee',
      icon: Icons.medical_services_rounded,
      members: [
        'Dr. Nalini Aswath',
        'Dr. V. Prakash',
        'Dr. Swarna Priya',
        'Dr. Janani Vinodini N.C',
        'Dr. Revathi',
        'Dr. Jesima J',
        'Dr. Jeevarathan J',
        'Dr. J. Bhuvaneshwari',
        'Dr. Ramya Chellammal M',
        'Dr. R. Aishwarya Dhevi G.R',
        'Dr. Madhumitha M',
      ],
    ),
    _SubCommittee(
      title: 'Registration Committee',
      icon: Icons.how_to_reg_rounded,
      members: [
        'Dr. Venkatesh A',
        'Dr. Ramyaa',
        'Dr. Thulasiram',
        'Dr. Hari prasanna',
        'Dr. Vanitha',
        'Dr. Sajid Hussain',
        'Dr. Preethi',
        'Dr. Ramesh K',
        'Dr. Tharun',
      ],
    ),
    _SubCommittee(
      title: 'Reception & Hospitality Committee',
      icon: Icons.emoji_emotions_rounded,
      members: [
        'Dr. Anitha Balaji',
        'Dr. Sree Devi V',
        'Dr. Tamil selvi',
      ],
    ),
    _SubCommittee(
      title: 'Student Committee',
      icon: Icons.school_rounded,
      members: [
        'Dr. Gold Pearlin Mary',
        'Dr. E. Tulasi Ram',
        'Dr. Geeta Priya',
        'Dr. D. Ramya',
      ],
    ),
    _SubCommittee(
      title: 'Banquet and Cultural Night',
      icon: Icons.celebration_rounded,
      members: [
        'Dr. Vijay Ebenezer',
        'Dr. Balakrishnan',
        'Dr. Saravana Kumar',
        'Dr. Prakash',
      ],
    ),
    _SubCommittee(
      title: 'Awards Committee',
      icon: Icons.emoji_events_rounded,
      members: [
        'Dr. N. Geetha priya',
        'Dr. Seetha lakshmi',
        'Dr. Amudha',
        'Dr. Mathangi',
      ],
    ),
    _SubCommittee(
      title: 'Website & Media',
      icon: Icons.language_rounded,
      members: [
        'Dr. Janani Balachandran',
        'Dr. Abarna J',
      ],
    ),
    _SubCommittee(
      title: 'Student Conference',
      icon: Icons.assignment_ind_rounded,
      members: [
        'Dr. Sumathi Jones',
        'Dr. N. Gold Pearlin Mary',
        'Dr. Malathy',
        'Dr. Kavya',
        'Dr. Durga Devi',
      ],
    ),
    _SubCommittee(
      title: 'Publications & Souvenir',
      icon: Icons.menu_book_rounded,
      members: [
        'Dr. M. Anita',
        'Dr. Sankar Narayanan R',
        'Dr. Rajesh E',
        'Dr. K.R. Don',
        'Dr. N. Anitha',
        'Dr. C. Ramya',
        'Dr. Charumathy',
        'Dr. Suganya',
      ],
    ),
    _SubCommittee(
      title: 'Travel & Accommodation',
      icon: Icons.hotel_rounded,
      members: [
        'Dr. T. Puhazhendi',
        'Dr. Rajasekar K.V',
        'Dr. Gowri Shankar',
        'Dr. Abirami',
        'Dr. Aravind Vishnu',
      ],
    ),
    _SubCommittee(
      title: 'Trade Committee',
      icon: Icons.storefront_rounded,
      members: [
        'Dr. Manigandan',
        'Dr. V. Balakumar',
        'Dr. Vikram',
        'Dr. Mansoor',
        'Dr. A. Karthick',
        'Dr. Rajith Varma',
        'Dr. Nilofer Farzana',
      ],
    ),
    _SubCommittee(
      title: 'Technical Committee',
      icon: Icons.engineering_rounded,
      members: [
        'Dr. Siva Kumar',
        'Dr. Savitha',
        'Dr. Rajasekar',
        'Dr. Manoj',
        'Dr. Sadhana',
        'Mr. Vijay',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF9),
      appBar: buildBrandGradientAppBar(
        title: Text(
          'Organising Committee',
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
            // Title Banner
            Center(
              child: Column(
                children: [
                  Text(
                    'Conference Organising Committee',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 50,
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

            // Chairperson Welcome Message Card
            _buildChairpersonMessageCard(),
            const SizedBox(height: 20),

            // Section Header: Committee Leadership
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ORGANISING LEADERSHIP & CONVENERS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: const Color(0xFF8C8C90),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Leadership / Key Conveners Cards
            for (final lead in _leads) ...[
              _buildLeadCard(lead),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 18),

            // Section Header: Committee Wings
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'COMMITTEES & SUB-TEAMS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: const Color(0xFF8C8C90),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Sub-Committees Expandable Accordions
            for (final committee in _subCommittees) ...[
              _buildSubCommitteeAccordion(context, committee),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChairpersonMessageCard() {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: ThemeData(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            childrenPadding: EdgeInsets.zero,
            iconColor: const Color(0xFFFBBF24),
            collapsedIconColor: Colors.white70,
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/DR-J.-SRI-NISHA.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            title: Text(
              'From the Organising Chairperson',
              style: GoogleFonts.outfit(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'DR. J. SRI NISHA',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
                Text(
                  'Organising Chairman - 36th ISDR',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF93C5FD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            children: [
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),

              // Gold Header Tag
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
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
                      'DEAR COLLEAGUES,',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Full Photo Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/DR-J.-SRI-NISHA.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Message Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'It gives me immense pleasure to extend a warm and cordial welcome to all the distinguished delegates, eminent researchers, clinicians, academicians, students participating in the 36th ISDR International Conference. This conference represents a significant milestone in our collective pursuit of excellence in dental, oral, and craniofacial research. It provides a unique platform for the exchange of scientific knowledge, innovative ideas, and transformative research that will shape the future of oral healthcare. Bringing together experts from diverse disciplines fosters collaboration, inspires innovation, and strengthens our commitment to evidence-based practice and translational research. At Bharath Institute of Higher Education and Research (BIHER), we are committed to nurturing a culture of academic excellence, scientific inquiry, and innovation. Hosting the 36th ISDR International Conference reflects our dedication to advancing research that addresses contemporary healthcare challenges and improves the quality of life of people across the globe. The theme of this conference, “Translational Dental Research: Bridging Science and Care,” aptly emphasizes the importance of transforming scientific discoveries into meaningful clinical applications. I am confident that the scientific deliberations, keynote lectures, workshops, and interactive sessions will stimulate new ideas, encourage interdisciplinary collaborations, and inspire future research endeavors. Once again it gives me immense pleasure to welcome you all to this spectacular scientific extravaganza.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sign-off credentials
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DR. J. SRI NISHA',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vice President, BIHER\n'
                      'Chairperson - Sree Balaji Group of Institutions\n'
                      'Organising Chairman - 36th ISDR',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.4,
                        color: const Color(0xFF93C5FD),
                        fontWeight: FontWeight.w500,
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

  Widget _buildLeadCard(_CommitteeLead lead) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Natural Aspect Ratio Image with no letterbox bars
          Container(
            width: 95,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                lead.imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.person, size: 36, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Lead Details
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
                    lead.role,
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
                  lead.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCommitteeAccordion(
      BuildContext context, _SubCommittee committee) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEA)),
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              committee.icon,
              color: const Color(0xFF2563EB),
              size: 20,
            ),
          ),
          title: Text(
            committee.title,
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            '${committee.members.length} Members',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: committee.members.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 10, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final number = (index + 1).toString().padLeft(2, '0');
                final name = committee.members[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            number,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
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
    );
  }
}
