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
    final status = !unlocked
        ? 'Locked'
        : (p['earned'] == true ? 'Earned by scans' : 'Unlocked by admin');
    final statusColor = !unlocked
        ? const Color(0xFFEF4444)
        : (p['earned'] == true
              ? const Color(0xFF22C55E)
              : const Color(0xFFF59E0B));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: darkCardDecoration(),
      child: ListTile(
        onTap: unlocked
            ? null
            : () => setState(
                () => _selected.contains(id)
                    ? _selected.remove(id)
                    : _selected.add(id),
              ),
        leading: unlocked
            ? Icon(Icons.workspace_premium_rounded, color: statusColor)
            : Checkbox(
                value: _selected.contains(id),
                activeColor: DarkColors.accent,
                side: const BorderSide(color: DarkColors.muted),
                onChanged: (v) => setState(
                  () => v == true ? _selected.add(id) : _selected.remove(id),
                ),
              ),
        title: Text(
          p['name']?.toString() ?? '',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '${p['idNumber'] ?? ''}  •  Days scanned ${p['daysScanned']}/${p['totalDays']}',
          style: GoogleFonts.inter(fontSize: 12, color: DarkColors.muted),
        ),
        trailing: Text(
          status,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: statusColor,
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
