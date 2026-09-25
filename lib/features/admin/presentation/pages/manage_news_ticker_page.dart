import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../../../participant/presentation/widgets/news_ticker_strap.dart';

/// Admin's News Ticker page: switch the scrolling ticker (participant and
/// event staff homes) on or off, and edit its text — one message per line.
class ManageNewsTickerPage extends StatefulWidget {
  const ManageNewsTickerPage({super.key});

  @override
  State<ManageNewsTickerPage> createState() => _ManageNewsTickerPageState();
}

class _ManageNewsTickerPageState extends State<ManageNewsTickerPage> {
  final _api = ApiService();
  final _text = TextEditingController();
  bool _loading = true;
  String? _error;
  bool _enabled = true;
  String _savedText = '';
  bool _switching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {})); // live preview
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Applies a {success, ticker} response; returns whether it succeeded.
  bool _apply(Map<String, dynamic> res, {bool setText = false}) {
    if (res['success'] != true || res['ticker'] is! Map) return false;
    final ticker = Map<String, dynamic>.from(res['ticker'] as Map);
    _enabled = ticker['enabled'] != false;
    _savedText = ticker['text']?.toString() ?? '';
    if (setText) _text.text = _savedText;
    return true;
  }

  Future<void> _load() async {
    final res = await _api.getNewsTicker();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = _apply(res, setText: true)
          ? null
          : res['error']?.toString() ?? 'Could not load the news ticker';
    });
  }

  Future<void> _toggle(bool value) async {
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _switching = true;
    });
    final res = await _api.updateNewsTicker(enabled: value);
    if (!mounted) return;
    setState(() {
      _switching = false;
      if (!_apply(res)) {
        _enabled = previous;
        _toast(res['error']?.toString() ?? 'Could not update');
      }
    });
  }

  Future<void> _save() async {
    if (tickerTextFromLines(_text.text).isEmpty) {
      _toast('Enter the ticker text');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final res = await _api.updateNewsTicker(text: _text.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (_apply(res, setText: true)) {
        _toast('News ticker updated');
      } else {
        _toast(res['error']?.toString() ?? 'Could not save');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = tickerTextFromLines(_text.text);
    final changed = _text.text.trim() != _savedText.trim();

    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'News Ticker',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: DarkColors.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: darkCardDecoration(),
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: _switching ? null : _toggle,
                    activeThumbColor: Colors.white,
                    activeTrackColor: DarkColors.accent,
                    title: Text(
                      'Show news ticker',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'On — scrolling on the participant and event staff homes'
                          : 'Off — hidden from everyone',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: DarkColors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'TICKER TEXT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: DarkColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'One message per line',
                    hintStyle: const TextStyle(color: DarkColors.muted),
                    helperText:
                        'Each line is shown as a separate message, divided by •',
                    helperStyle: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: DarkColors.muted,
                    ),
                    filled: true,
                    fillColor: DarkColors.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: DarkColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: DarkColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: DarkColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PREVIEW',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: DarkColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                if (preview.isEmpty)
                  Text(
                    'Nothing to show yet',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: DarkColors.muted,
                    ),
                  )
                else
                  NewsTickerStrap(key: ValueKey(preview), text: preview),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving || !changed ? null : _save,
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
                            changed ? 'Save Text' : 'Saved',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
