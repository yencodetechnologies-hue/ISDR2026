import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin: which participants have their certificate and which do not, with
/// the option to unlock the certificates of selected participants.
class AdminCertificatesPage extends StatefulWidget {
  const AdminCertificatesPage({super.key});

  @override
  State<AdminCertificatesPage> createState() => _AdminCertificatesPageState();
}

class _AdminCertificatesPageState extends State<AdminCertificatesPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  bool _showUnlocked = false; // tab: false = not yet, true = got certificate
  String _query = '';
  final Set<String> _selected = {};
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.listCertificates();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _all = (res['participants'] as List? ?? [])
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        _error = null;
      } else {
        _error = res['error']?.toString() ?? 'Could not load participants';
      }
    });
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((p) {
      if ((p['unlocked'] == true) != _showUnlocked) return false;
      if (q.isEmpty) return true;
      return '${p['name']} ${p['idNumber']} ${p['mobileNumber']}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _unlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock certificates'),
        content: Text(
          'Unlock the certificate for ${_selected.length} participant(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _unlocking = true);
    final res = await _api.unlockCertificates(_selected.toList());
    if (!mounted) return;
    setState(() => _unlocking = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? 'Certificates unlocked'
              : res['error']?.toString() ?? 'Could not unlock',
        ),
      ),
    );
    if (res['success'] == true) {
      _selected.clear();
      _load();
    }
  }

  /// Locks one participant's certificate again.
  Future<void> _revert(Map<String, dynamic> p) async {
    final earned = p['earned'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert certificate'),
        content: Text(
          earned
              ? 'Lock the certificate of ${p['name']}? It stays locked even though their scans earned it, until you unlock it again.'
              : 'Lock the certificate of ${p['name']} again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.revertCertificates([p['id'].toString()]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? 'Certificate reverted'
              : res['error']?.toString() ?? 'Could not revert',
        ),
      ),
    );
    if (res['success'] == true) _load();
  }

  Widget _tab(String label, bool value, int count) {
    final active = _showUnlocked == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _showUnlocked = value;
          _selected.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? DarkColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : DarkColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final id = p['id'].toString();
    final unlocked = p['unlocked'] == true;
    final earned = p['earned'] == true;
    final selected = _selected.contains(id);
    final name = p['name']?.toString() ?? '';
    final scanned = (p['daysScanned'] as num?)?.toInt() ?? 0;
    final total = (p['totalDays'] as num?)?.toInt() ?? 0;

    final (String status, Color color, IconData icon) = !unlocked
        ? (p['revoked'] == true
              ? ('Reverted', const Color(0xFFF87171), Icons.undo_rounded)
              : ('Locked', const Color(0xFF94A3B8), Icons.lock_rounded))
        : earned
        ? ('Earned by scans', const Color(0xFF22C55E), Icons.qr_code_scanner_rounded)
        : ('Unlocked by admin', const Color(0xFFF59E0B), Icons.admin_panel_settings_rounded);

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? DarkColors.accent
              : Colors.white.withValues(alpha: 0.07),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: unlocked
              ? null
              : () => setState(
                  () => selected ? _selected.remove(id) : _selected.add(id),
                ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with initials (a tick when selected).
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? DarkColors.accent
                            : color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: selected
                              ? DarkColors.accent
                              : color.withValues(alpha: 0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : Text(
                              initials.isEmpty ? '?' : initials,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p['idNumber']?.toString() ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DarkColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status pill.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Days scanned progress.
                Row(
                  children: [
                    Text(
                      'Days scanned',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: DarkColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$scanned / $total',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : scanned / total,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation(
                      scanned >= total && total > 0
                          ? const Color(0xFF22C55E)
                          : DarkColors.accent,
                    ),
                  ),
                ),
                if (unlocked) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _revert(p),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: Text(
                        'Revert certificate',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final unlockedCount = _all.where((p) => p['unlocked'] == true).length;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Certificate',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: _showUnlocked || _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _unlocking ? null : _unlock,
                    style: FilledButton.styleFrom(
                      backgroundColor: DarkColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(
                      'Unlock certificate (${_selected.length})',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: GoogleFonts.inter(color: DarkColors.muted),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: darkCardDecoration(),
                    child: Row(
                      children: [
                        _tab('Not yet', false, _all.length - unlockedCount),
                        _tab('Got certificate', true, unlockedCount),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search name, ID or mobile',
                      hintStyle: const TextStyle(color: DarkColors.muted),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: DarkColors.muted,
                      ),
                      filled: true,
                      fillColor: DarkColors.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (!_showUnlocked && visible.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          final ids = visible.map((p) => p['id'].toString());
                          if (ids.every(_selected.contains)) {
                            _selected.removeAll(ids);
                          } else {
                            _selected.addAll(ids);
                          }
                        }),
                        child: const Text('Select all'),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'No participants',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: DarkColors.muted),
                      ),
                    )
                  else
                    ...visible.map(_row),
                ],
              ),
            ),
    );
  }
}
