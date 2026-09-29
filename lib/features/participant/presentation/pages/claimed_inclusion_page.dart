import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _Colors {
  static const ink = Color(0xFFFFFFFF);
  static const bg = Color(0xFF0A0A12);
  static const card = Color(0xFF14141F);
  static const muted = Color(0xFF9CA3AF);
  static const line = Color(0x14FFFFFF);
  static const green = Color(0xFF22C55E);
}

/// Shows only the inclusions the logged-in participant has already claimed.
class ClaimedInclusionPage extends StatefulWidget {
  const ClaimedInclusionPage({super.key});

  @override
  State<ClaimedInclusionPage> createState() => _ClaimedInclusionPageState();
}

class _ClaimedInclusionPageState extends State<ClaimedInclusionPage> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _claimed = [];
  String _packageName = '';

  /// Re-checks every few seconds so a claim scanned at the counter shows up right away.
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final res = await _api.getMyRegistration();
    if (!mounted) return;
    if (res['success'] != true) {
      if (silent) return;
      setState(() {
        _loading = false;
        _error = res['error']?.toString() ?? 'Failed to load inclusions';
      });
      return;
    }
    final reg = Map<String, dynamic>.from(res['registration'] as Map? ?? {});
    final claimed = List<Map<String, dynamic>>.from(
      (reg['claimedInclusions'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? [],
    );
    setState(() {
      _loading = false;
      _error = null;
      _claimed = claimed;
      _packageName = reg['packageName']?.toString() ?? '';
    });
  }

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return DateFormat('d MMM, h:mm a').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Claimed Inclusion',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.error_outline_rounded, size: 40, color: _Colors.muted),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: _Colors.muted),
                        ),
                      ),
                    ],
                  )
                : _claimed.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.verified_outlined, size: 40, color: _Colors.muted),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'No inclusions claimed yet',
                              style: GoogleFonts.inter(fontSize: 13, color: _Colors.muted),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          if (_packageName.isNotEmpty) ...[
                            Text(
                              'PACKAGE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .6,
                                color: _Colors.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _packageName,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _Colors.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'CLAIMED (${_claimed.length})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: _Colors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._claimed.map((claim) {
                            final name = claim['inclusionName']?.toString() ?? '';
                            final byAdmin = claim['reclaimedByAdmin'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: _Colors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _Colors.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: _Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: _Colors.ink,
                                                  ),
                                                ),
                                              ),
                                              if (byAdmin) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    'By Admin',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Claimed ${_fmtDateTime(claim['claimedAt']?.toString())}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: _Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _Colors.green.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'CLAIMED',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: _Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}
