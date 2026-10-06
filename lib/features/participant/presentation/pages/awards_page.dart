import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
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

class AwardsPage extends StatefulWidget {
  /// Admin: tapping an award opens the participant picker for its winner.
  final bool adminMode;

  const AwardsPage({super.key, this.adminMode = false});

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

  @override
  State<AwardsPage> createState() => _AwardsPageState();
}

class _AwardsPageState extends State<AwardsPage> {
  final _api = ApiService();

  /// Award number -> {registrationId, name}.
  Map<String, Map<String, dynamic>> _winners = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.getAwardWinners();
    if (!mounted || res['success'] != true || res['winners'] is! Map) return;
    setState(() {
      _winners = (res['winners'] as Map).map(
        (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
      );
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Admin: pick the winner of one award (or remove the current one).
  Future<void> _pickWinner(_AwardCategoryItem item) async {
    final current = _winners['${item.number}'];
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WinnerPickerSheet(
        award: item,
        currentId: current?['registrationId']?.toString(),
      ),
    );
    if (picked == null || !mounted) return;
    final id = picked['id']?.toString() ?? '';
    final res = await _api.setAwardWinner(item.number, id);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        if (res['winner'] is Map) {
          _winners['${item.number}'] = Map<String, dynamic>.from(
            res['winner'] as Map,
          );
        } else {
          _winners.remove('${item.number}');
        }
      });
      _toast(id.isEmpty ? 'Winner removed' : 'Winner saved');
    } else {
      _toast(res['error']?.toString() ?? 'Could not save');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: buildDarkAppBar(
        title: Text(
          widget.adminMode ? 'Award Winners' : 'Conference Awards',
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
            // Section 1: Delegates & Post Graduate Awards
            _buildSectionHeader('DELEGATES & POST GRADUATE AWARDS (CAT 1 - 8)'),
            const SizedBox(height: 10),
            for (final item in AwardsPage._delegateAndPgAwards) ...[
              _buildAwardAccordionCard(item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),

            // Section 2: Under Graduate Students Awards
            _buildSectionHeader('UNDER GRADUATE STUDENTS AWARDS (CAT 9 - 12)'),
            const SizedBox(height: 10),
            for (final item in AwardsPage._ugAwards) ...[
              _buildAwardAccordionCard(item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 22),
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
  Widget _numberBadge(int number) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: const Color(0x263B82F6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x4D3B82F6), width: 1),
    ),
    child: Center(
      child: Text(
        '$number',
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF93C5FD),
        ),
      ),
    ),
  );

  Widget _titleText(String title) => Text(
    title,
    style: GoogleFonts.outfit(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );

  /// Award heading. Participants tap it to roll open the winner (or "Yet to
  /// be announced"); the admin taps it to choose the winner.
  Widget _buildAwardAccordionCard(_AwardCategoryItem item) {
    final winner = _winners['${item.number}']?['name']?.toString();
    final decoration = BoxDecoration(
      color: const Color(0xFF14141F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: winner != null
            ? const Color(0x66F59E0B)
            : const Color(0x1AFFFFFF),
      ),
    );

    if (widget.adminMode) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pickWinner(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _numberBadge(item.number),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleText(item.title),
                        const SizedBox(height: 2),
                        Text(
                          winner == null
                              ? 'Tap to choose the winner'
                              : 'Winner: $winner',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: winner == null
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    winner == null
                        ? Icons.person_add_alt_1_rounded
                        : Icons.edit_rounded,
                    size: 20,
                    color: const Color(0xFF93C5FD),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: ThemeData(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: const Color(0xFF93C5FD),
            collapsedIconColor: const Color(0xFF9CA3AF),
            leading: _numberBadge(item.number),
            title: _titleText(item.title),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x26F59E0B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4DF59E0B)),
                ),
                child: Row(
                  children: [
                    Icon(
                      winner == null
                          ? Icons.hourglass_top_rounded
                          : Icons.emoji_events_rounded,
                      size: 18,
                      color: const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        winner ?? 'To be announced',
                        style: GoogleFonts.inter(
                          fontSize: winner == null ? 13 : 14,
                          fontWeight: winner == null
                              ? FontWeight.w600
                              : FontWeight.w700,
                          color: const Color(0xFFFBBF24),
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

/// Admin's list of participants to choose an award winner from.
class _WinnerPickerSheet extends StatefulWidget {
  final _AwardCategoryItem award;
  final String? currentId;

  const _WinnerPickerSheet({required this.award, this.currentId});

  @override
  State<_WinnerPickerSheet> createState() => _WinnerPickerSheetState();
}

class _WinnerPickerSheetState extends State<_WinnerPickerSheet> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().listCertificates();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _all = (res['participants'] as List? ?? [])
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load participants';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = _all
        .where(
          (p) =>
              q.isEmpty ||
              '${p['name']} ${p['idNumber']} ${p['mobileNumber']}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Winner — ${widget.award.title}',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.currentId != null)
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, <String, dynamic>{'id': ''}),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Color(0xFFF87171)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search name, ID or mobile',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: Colors.white60),
                        ),
                      )
                    : shown.isEmpty
                    ? Center(
                        child: Text(
                          'No participants',
                          style: GoogleFonts.inter(color: Colors.white60),
                        ),
                      )
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final p = shown[i];
                          final chosen =
                              p['id']?.toString() == widget.currentId;
                          return ListTile(
                            onTap: () => Navigator.pop(context, p),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0x263B82F6),
                              child: Text(
                                (p['name']?.toString() ?? '?')
                                    .trim()
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(
                              p['name']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              [p['idNumber'], p['mobileNumber']]
                                  .where(
                                    (v) => (v?.toString() ?? '').isNotEmpty,
                                  )
                                  .join('  •  '),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            trailing: chosen
                                ? const Icon(
                                    Icons.emoji_events_rounded,
                                    color: Color(0xFFFBBF24),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
