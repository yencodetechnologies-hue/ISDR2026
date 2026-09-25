import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin's YouTube Live page: paste a YouTube link to show the red LIVE
/// capsule on the participant home, or remove it.
class ManageYoutubeLivePage extends StatefulWidget {
  const ManageYoutubeLivePage({super.key});

  @override
  State<ManageYoutubeLivePage> createState() => _ManageYoutubeLivePageState();
}

class _ManageYoutubeLivePageState extends State<ManageYoutubeLivePage> {
  final _api = ApiService();
  final _link = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _saved = '';

  @override
  void initState() {
    super.initState();
    _link.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    final res = await _api.getYoutubeLive();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _saved = res['url']?.toString() ?? '';
      _link.text = _saved;
    });
    if (res['success'] != true) {
      _toast(res['error']?.toString() ?? 'Could not load the link');
    }
  }

  Future<void> _save(String url) async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final res = await _api.setYoutubeLive(url);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      setState(() {
        _saved = res['url']?.toString() ?? '';
        _link.text = _saved;
      });
      _toast(_saved.isEmpty ? 'YouTube live removed' : 'YouTube live link saved');
    } else {
      _toast(res['error']?.toString() ?? 'Could not save');
    }
  }

  @override
  Widget build(BuildContext context) {
    final changed = _link.text.trim() != _saved;
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'YouTube Live',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: darkCardDecoration(),
                  child: Row(
                    children: [
                      Icon(
                        _saved.isEmpty
                            ? Icons.live_tv_outlined
                            : Icons.live_tv_rounded,
                        color: _saved.isEmpty
                            ? DarkColors.muted
                            : const Color(0xFFFF0000),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _saved.isEmpty
                              ? 'Not showing — no link set'
                              : 'Showing on the participant home',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'YOUTUBE LINK',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: DarkColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  decoration: darkInputDecoration(
                    'Paste the YouTube link',
                    Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving || !changed || _link.text.trim().isEmpty
                        ? null
                        : () => _save(_link.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: DarkColors.accent,
                      disabledBackgroundColor: DarkColors.accent.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Link',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                if (_saved.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _saving ? null : () => _save(''),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFF87171),
                    ),
                    label: Text(
                      'Remove YouTube Live',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF87171),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
