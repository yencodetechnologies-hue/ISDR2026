import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

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
          'PRE CONFERENCE COURSES- ISDR 2026',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || _courses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                        child: Column(
                          children: [
                            Icon(
                              _error != null
                                  ? Icons.error_outline_rounded
                                  : Icons.school_outlined,
                              size: 44,
                              color: DarkColors.muted.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error ?? 'No pre-conference courses yet',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: DarkColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _table(_courses),
                      ),
                    ],
                  ),
      ),
    );
  }
}

Widget _table(List<Map<String, dynamic>> courses) {
  const header = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: DarkColors.muted,
  );
  const cell = TextStyle(fontSize: 13, height: 1.35, color: Colors.white);
  Widget head(String text, double width) => SizedBox(
        width: width,
        child: Text(text, style: header),
      );
  return Container(
    decoration: darkCardDecoration(14),
    clipBehavior: Clip.antiAlias,
    child: Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FixedColumnWidth(88),
        2: FixedColumnWidth(320),
        3: FixedColumnWidth(220),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0x08FFFFFF)),
          children: [
            _pad(head('S NO', 52)),
            _pad(head('DATE', 88)),
            _pad(head('PRE CONFERENCE COURSE', 320)),
            _pad(head('VENUE', 220)),
          ],
        ),
        for (final row in courses)
          TableRow(
            children: [
              _pad(Text('${row['serialNo'] ?? ''}', style: cell)),
              _pad(Text('${row['date'] ?? ''}', style: cell)),
              _pad(Text('${row['course'] ?? ''}', style: cell)),
              _pad(Text('${row['venue'] ?? ''}', style: cell)),
            ],
          ),
      ],
    ),
  );
}

Widget _pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
