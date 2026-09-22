import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _Colors {
  static const ink = Color(0xFF0F172A);
  static const primaryBlue = Color(0xFF2563EB);
  static const bg = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
}

/// Shows the inclusions in the participant's package that haven't been
/// claimed yet.
class AvailableInclusionPage extends StatefulWidget {
  const AvailableInclusionPage({super.key});

  @override
  State<AvailableInclusionPage> createState() => _AvailableInclusionPageState();
}

class _AvailableInclusionPageState extends State<AvailableInclusionPage> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _unclaimed = [];
  String _packageName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _api.getMyRegistration();
    if (!mounted) return;
    if (res['success'] != true) {
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
    final claimedNames = claimed
        .map((c) => (c['inclusionName']?.toString() ?? '').trim().toLowerCase())
        .toSet();
    final available = List<Map<String, dynamic>>.from(
      (res['availableInclusions'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? [],
    );
    final unclaimed = available
        .where((incl) =>
            !claimedNames.contains((incl['name']?.toString() ?? '').trim().toLowerCase()))
        .toList();
    setState(() {
      _loading = false;
      _unclaimed = unclaimed;
      _packageName = reg['packageName']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildBrandGradientAppBar(
        title: Text(
          'Available Inclusion',
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
            ? const Center(child: CircularProgressIndicator())
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
                : _unclaimed.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.inventory_2_outlined, size: 40, color: _Colors.muted),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'All your inclusions have been claimed',
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
                            'AVAILABLE (${_unclaimed.length})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: _Colors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._unclaimed.map((incl) {
                            final name = incl['name']?.toString() ?? '';
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
                                        color: _Colors.primaryBlue.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_rounded,
                                        color: _Colors.primaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: _Colors.ink,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PENDING',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: _Colors.muted,
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
