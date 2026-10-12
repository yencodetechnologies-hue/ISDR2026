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
  /// Admin: tapping an award opens a form to type its recipients.
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

  /// Award number -> {name, recipients}.
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

  /// Presentation order, so a person in several categories is listed once, first appearance first.
  static const List<int> _consolidatedOrder = [5, 4, 8, 6, 7, 3, 11, 12];

  List<({int rank, String name})> _recipientsFor(int number) {
    final row = _winners['$number'];
    if (row == null) return [];
    final raw = row['recipients'];
    if (raw is List && raw.isNotEmpty) {
      return raw.whereType<Map>().map((m) {
        final rank = int.tryParse('${m['rank']}') ?? 1;
        final name = m['name']?.toString().trim() ?? '';
        return (rank: rank, name: name);
      }).where((r) => r.name.isNotEmpty).toList();
    }
    final name = row['name']?.toString().trim() ?? '';
    if (name.isEmpty) return [];
    return [(rank: 1, name: name)];
  }

  List<String> _consolidatedNames() {
    final seen = <String>{};
    final names = <String>[];
    void addAll(Iterable<({int rank, String name})> rows) {
      for (final r in rows) {
        if (seen.add(r.name.toLowerCase())) names.add(r.name);
      }
    }

    for (final n in _consolidatedOrder) {
      addAll(_recipientsFor(n));
    }
    final known = _consolidatedOrder.map((n) => '$n').toSet();
    for (final key in _winners.keys) {
      if (known.contains(key)) continue;
      final n = int.tryParse(key);
      if (n != null) addAll(_recipientsFor(n));
    }
    return names;
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Admin: type the recipients of one award, or clear them.
  Future<void> _editRecipients(_AwardCategoryItem item) async {
    final current = _recipientsFor(item.number);
    final picked = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecipientEditorSheet(award: item, recipients: current),
    );
    if (picked == null || !mounted) return;
    final res = await _api.setAwardWinner(item.number, picked);
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
      _toast(picked.isEmpty ? 'Recipients removed' : 'Recipients saved');
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
            if (_consolidatedNames().isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildSectionHeader('AWARD RECIPIENTS'),
              const SizedBox(height: 10),
              _buildConsolidatedList(),
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

  Widget _recipientRows(List<({int rank, String name})> recipients) {
    if (recipients.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFFFBBF24)),
          const SizedBox(width: 8),
          Text(
            'To be announced',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFBBF24),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < recipients.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${recipients[i].rank}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
              const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recipients[i].name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _recipientPanel(List<({int rank, String name})> recipients) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x26F59E0B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x4DF59E0B)),
      ),
      child: _recipientRows(recipients),
    );
  }

  Widget _buildConsolidatedList() {
    final names = _consolidatedNames();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66F59E0B)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < names.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      names[i],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Award heading. Participants tap it to roll open the ranked recipients
  /// (or "To be announced"); the admin taps it to type the recipients.
  Widget _buildAwardAccordionCard(_AwardCategoryItem item) {
    final recipients = _recipientsFor(item.number);
    final announced = recipients.isNotEmpty;
    final decoration = BoxDecoration(
      color: const Color(0xFF14141F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: announced
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
            onTap: () => _editRecipients(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _numberBadge(item.number),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleText(item.title),
                        const SizedBox(height: 6),
                        if (!announced)
                          Text(
                            'Tap to enter recipients',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9CA3AF),
                            ),
                          )
                        else
                          _recipientRows(recipients),
                      ],
                    ),
                  ),
                  Icon(
                    announced ? Icons.edit_rounded : Icons.edit_note_rounded,
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
            key: ValueKey('award-${item.number}-${recipients.length}'),
            initiallyExpanded: announced,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: const Color(0xFF93C5FD),
            collapsedIconColor: const Color(0xFF9CA3AF),
            leading: _numberBadge(item.number),
            title: _titleText(item.title),
            children: [
              _recipientPanel(recipients),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameRow {
  _NameRow(String rank, String name)
    : rank = TextEditingController(text: rank),
      name = TextEditingController(text: name);

  final TextEditingController rank;
  final TextEditingController name;

  void dispose() {
    rank.dispose();
    name.dispose();
  }
}

/// Admin types ranked recipient names for one award.
class _RecipientEditorSheet extends StatefulWidget {
  final _AwardCategoryItem award;
  final List<({int rank, String name})> recipients;

  const _RecipientEditorSheet({required this.award, required this.recipients});

  @override
  State<_RecipientEditorSheet> createState() => _RecipientEditorSheetState();
}

class _RecipientEditorSheetState extends State<_RecipientEditorSheet> {
  late final List<_NameRow> _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = widget.recipients.isEmpty
        ? [_NameRow('1', '')]
        : widget.recipients.map((r) => _NameRow('${r.rank}', r.name)).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    final last = int.tryParse(_rows.last.rank.text.trim()) ?? _rows.length;
    setState(() => _rows.add(_NameRow('${last + 1}', '')));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) {
      _rows[0].rank.text = '1';
      _rows[0].name.clear();
      setState(() {});
      return;
    }
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  void _save() {
    final recipients = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final name = row.name.text.trim();
      if (name.isEmpty) continue;
      final rank = int.tryParse(row.rank.text.trim());
      if (rank == null || rank < 1) {
        setState(() => _error = 'Each recipient needs a rank of 1 or more');
        return;
      }
      if (name.length > 200) {
        setState(() => _error = 'A name is too long');
        return;
      }
      recipients.add({'rank': rank, 'name': name});
    }
    if (recipients.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    if (recipients.length > 20) {
      setState(() => _error = 'At most 20 recipients');
      return;
    }
    Navigator.pop(context, recipients);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recipients — ${widget.award.title}',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.recipients.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.pop(context, <Map<String, dynamic>>[]),
                        child: const Text('Remove', style: TextStyle(color: Color(0xFFF87171))),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Type each recipient and rank. The same rank can be shared.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _rows[i].rank,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: _fieldDecoration('Rank'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].name,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: _fieldDecoration('Recipient name'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeRow(i),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFF87171)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_rounded, color: Color(0xFF93C5FD)),
                        label: Text(
                          'Add recipient',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: const Color(0xFFF87171)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF1E1E2A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );
}
