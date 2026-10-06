import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'preconference_pdf_page.dart';

const _accent = Color(0xFF6366F1);
const _accentSoft = Color(0xFFC7D2FE);

/// Read-only pre-conference course list for participants.
class PreconferencePage extends StatefulWidget {
  const PreconferencePage({super.key});

  @override
  State<PreconferencePage> createState() => _PreconferencePageState();
}

class _PreconferencePageState extends State<PreconferencePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().listPreconference();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _courses = ((res['courses'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load courses';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Preconference',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  const _Hero(),
                  const SizedBox(height: 16),
                  if (_error != null || _courses.isEmpty)
                    _empty(_error)
                  else
                    for (final row in _courses) ...[
                      _CourseCard(row: row),
                      const SizedBox(height: 12),
                    ],
                  if (!_loading) const _ViewPdfButton(),
                ],
              ),
      ),
    );
  }

  Widget _empty(String? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            error != null ? Icons.error_outline_rounded : Icons.school_outlined,
            size: 44,
            color: DarkColors.muted.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            error ?? 'No pre-conference courses yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13.5, color: DarkColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ViewPdfButton extends StatelessWidget {
  const _ViewPdfButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PreconferencePdfPage()),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
          label: Text(
            'View PDF',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B), Color(0xFF14141F)],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withValues(alpha: 0.55),
                    _accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ISDR 2026',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: _accentSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pre Conference\nCourses',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 15, color: Color(0xFF93C5FD)),
                    const SizedBox(width: 6),
                    Text(
                      '08.10.26',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final serial = '${row['serialNo'] ?? ''}';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFA5B4FC), _accent],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'S NO  $serial',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: _accentSoft,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF93C5FD)),
                        const SizedBox(width: 5),
                        Text(
                          '${row['date'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${row['course'] ?? ''}',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: DarkColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFA5B4FC)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${row['venue'] ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.75),
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
          ],
        ),
      ),
    );
  }
}
