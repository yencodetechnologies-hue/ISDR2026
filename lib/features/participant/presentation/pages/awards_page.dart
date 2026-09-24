import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _AwardCategoryItem {
  final int number;
  final String title;
  final String? subtitle;
  final String? eligibility;
  final String? description;
  final IconData icon;

  const _AwardCategoryItem({
    required this.number,
    required this.title,
    this.subtitle,
    this.eligibility,
    this.description,
    required this.icon,
  });
}

class AwardsPage extends StatelessWidget {
  const AwardsPage({super.key});

  static const List<_AwardCategoryItem> _delegateAndPgAwards = [
    _AwardCategoryItem(
      number: 1,
      title: 'Best Poster Award',
      icon: Icons.photo_library_rounded,
      description:
          'This award recognizes the most outstanding poster presented during ISDR Conference 2026. Evaluation shall be based on originality of the work, scientific merit, clarity of presentation, methodology, visual appeal, discussion, and ability of the presenter to answer questions effectively.',
    ),
    _AwardCategoryItem(
      number: 2,
      title: 'Best Paper Award',
      icon: Icons.article_rounded,
      description:
          'Presented to the author(s) of the best oral scientific presentation at ISDR Conference 2026. The award shall consider novelty, scientific rigor, methodology, significance findings, presentation skills, and overall contribution to the respective field.',
    ),
    _AwardCategoryItem(
      number: 3,
      title: 'Best Patent Award',
      icon: Icons.lightbulb_rounded,
      eligibility: 'Patents published/granted between 2023 and 2025.',
      description:
          'Awarded to a faculty member/researcher who has demonstrated excellence in innovation through patents during 2023–2025. The applicant should possess granted or published patents with evidence of commercialization, technology transfer, licensing, or societal impact. Higher weightage will be given to granted patents and patents translated into practice.',
    ),
    _AwardCategoryItem(
      number: 4,
      title: 'Best Research Grant Award',
      icon: Icons.account_balance_rounded,
      eligibility: 'Research grants sanctioned during 2023–2025.',
      description:
          'This award recognizes researchers who have secured significant external research funding during 2023–2025 from national or international funding agencies. Selection will be based on the number of grants, total funding amount, prestige of the funding agency, interdisciplinary nature, and utilization of funds for impactful research.',
    ),
    _AwardCategoryItem(
      number: 5,
      title: 'Best Research Publication Award',
      icon: Icons.menu_book_rounded,
      eligibility: 'Publications published during 2023–2025.',
      description:
          'Awarded to researchers with exceptional scholarly publications during 2023–2025. Evaluation shall consider quality and quantity of publications, indexing in Scopus/Web of Science, journal quartile, citation impact, h-index contribution, and overall academic influence.',
    ),
    _AwardCategoryItem(
      number: 6,
      title: 'Best Research Centre Award',
      icon: Icons.domain_rounded,
      eligibility: 'Recognized research centres functioning during 2023–2025.',
      description:
          'Presented to a department, centre, or laboratory that has demonstrated outstanding research performance during 2023–2025. Assessment will include research output, funded projects, patents, consultancy, collaborations, infrastructure development, publications, student involvement, and societal/industrial impact.',
    ),
    _AwardCategoryItem(
      number: 7,
      title: 'Best Research Book Award',
      icon: Icons.auto_stories_rounded,
      eligibility: 'Books with ISBN published between 2023 and 2025.',
      description:
          'This award recognizes authors of scholarly books published during 2023–2025 that significantly contribute to education, research, or professional practice. Preference shall be given to books published by reputed national or international publishers and those demonstrating substantial academic impact.',
    ),
    _AwardCategoryItem(
      number: 8,
      title: 'Best Research Collaboration Award',
      icon: Icons.hub_rounded,
      eligibility:
          'Active collaborations evidenced by MoUs, projects, publications, or other tangible outcomes during 2023–2025.',
      description:
          'Awarded to researchers or teams that have established productive national or international collaborations during 2023–2025 leading to joint publications, funded projects, patents, student/faculty exchange, technology transfer, or significant societal impact.',
    ),
  ];

  static const List<_AwardCategoryItem> _ugAwards = [
    _AwardCategoryItem(
      number: 9,
      title: 'Best Poster Award',
      icon: Icons.photo_library_rounded,
      description:
          'Recognizes outstanding poster presentation by undergraduate students during the conference. Finalized on the day of presentation.',
    ),
    _AwardCategoryItem(
      number: 10,
      title: 'Best Paper Award',
      icon: Icons.article_rounded,
      description:
          'Presented for the best oral scientific paper presentation by undergraduate students during the conference. Finalized on the day of presentation.',
    ),
    _AwardCategoryItem(
      number: 11,
      title: 'Best Publication Award',
      icon: Icons.library_books_rounded,
      subtitle:
          'Postgraduate/Undergraduate student who has published his/her research (other than their dissertation) in an indexed journal of reputation.',
      description:
          'For Postgraduate or Undergraduate students who have published original research work in reputable indexed journals.',
    ),
    _AwardCategoryItem(
      number: 12,
      title: 'Best Grant Award',
      icon: Icons.monetization_on_rounded,
      subtitle:
          'Award for recipient of Government/other funding agencies for original research proposal granted for the years 2023, 2024, 2025.',
      eligibility: 'Original research proposals granted for 2023, 2024, 2025.',
      description:
          'Recognizing students who have secured research funding from Government or other recognized funding agencies for their original research proposals.',
    ),
  ];

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
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
          'Conference Awards',
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
            // Hero Callout Banner
            _buildHeroCalloutBanner(),
            const SizedBox(height: 16),

            // General Guidelines / Important Notes Card
            _buildGeneralNotesCard(),
            const SizedBox(height: 20),

            // Section 1: Delegates & Post Graduate Awards
            _buildSectionHeader('DELEGATES & POST GRADUATE AWARDS (CAT 1 - 8)'),
            const SizedBox(height: 10),
            for (final item in _delegateAndPgAwards) ...[
              _buildAwardAccordionCard(item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            // Apply Button for Cat 3 to 8
            _buildApplyButton(
              context: context,
              title: 'Apply for Categories 3 to 8',
              subtitle: 'Delegates & Post Graduate Research Awards',
              url: 'https://tinyurl.com/AWARDS-ISDR-DELIGATES-AND-PGS',
              accentColor: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 24),

            // Section 2: Under Graduate Students Awards
            _buildSectionHeader('UNDER GRADUATE STUDENTS AWARDS (CAT 9 - 12)'),
            const SizedBox(height: 10),
            for (final item in _ugAwards) ...[
              _buildAwardAccordionCard(item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            // Apply Button for Cat 11 & 12
            _buildApplyButton(
              context: context,
              title: 'Apply for Categories 11 & 12',
              subtitle: 'Undergraduate Publication & Grant Awards',
              url: 'https://tinyurl.com/AWARDS-ISDR-UG',
              accentColor: const Color(0xFF059669),
            ),
            const SizedBox(height: 32),
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

  /// Hero Banner Callout
  Widget _buildHeroCalloutBanner() {
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
              'CALLING EXPERTS FROM OUR RESEARCH COMMUNITY!',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: const Color(0xFFFBBF24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Apply & Get Nominated',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prestigious ISDR Conference Research Awards 2026',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF93C5FD),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deadline: September 15, 2026',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// General Notes and Rules Card
  Widget _buildGeneralNotesCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text(
                'GENERAL GUIDELINES',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            'Categories 1, 2, 9, and 10 will be finalized on the day of the presentation.',
          ),
          _buildBulletItem(
            'Three prizes will be awarded for each category.',
          ),
          _buildBulletItem(
            'Delegates and PGs can apply for a maximum of three award categories (only one application per award).',
          ),
          _buildBulletItem(
            'Undergraduates can apply for a maximum of two award categories (only one application per award).',
          ),
          _buildBulletItem(
            'Last date to apply for award categories: September 15, 2026.',
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isHighlight ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Expandable Accordion Card for Each Award Category
  Widget _buildAwardAccordionCard(_AwardCategoryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
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
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x263B82F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4D3B82F6), width: 1),
              ),
              child: Center(
                child: Text(
                  '${item.number}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF93C5FD),
                  ),
                ),
              ),
            ),
            title: Text(
              item.title,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            subtitle: item.subtitle != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
            children: [
              const Divider(color: Color(0xFF1E1E2A), height: 1),
              const SizedBox(height: 12),
              if (item.subtitle != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            height: 1.4,
                            color: const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (item.description != null) ...[
                Text(
                  item.description!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.55,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (item.eligibility != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x26F59E0B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4DF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Eligibility: ${item.eligibility!}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Apply Action Button
  Widget _buildApplyButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String url,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _launchUrl(context, url),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.open_in_new_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Apply Now',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}
