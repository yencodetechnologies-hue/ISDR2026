import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'help_tickets_page.dart' show helpCategoryOf;

/// One Help & Support ticket's chat. Participant, event staff and admin all
/// use it; new replies are fetched every few seconds while it's open. Staff
/// and admin can close the ticket, after which the participant can only read
/// it (and may start a new ticket). Pops `'new'` when they choose to.
class TicketChatPage extends StatefulWidget {
  final String ticketId;

  const TicketChatPage({super.key, required this.ticketId});

  @override
  State<TicketChatPage> createState() => _TicketChatPageState();
}

class _TicketChatPageState extends State<TicketChatPage> {
  final _api = ApiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _ticket;
  String? _error;
  bool _sending = false;
  bool _closing = false;
  Timer? _poll;

  bool get _closed => _ticket?['status'] == 'closed';
  bool get _canReply => _ticket?['canReply'] != false;
  bool get _canClose => _ticket?['canClose'] == true;

  List<Map<String, dynamic>> get _messages =>
      ((_ticket?['messages'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  void initState() {
    super.initState();
    _load(scrollToEnd: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToEnd = false}) async {
    final res = await _api.getHelpTicket(widget.ticketId);
    if (!mounted) return;
    if (res['success'] == true && res['ticket'] is Map) {
      final before = _messages.length;
      setState(() {
        _error = null;
        _ticket = Map<String, dynamic>.from(res['ticket'] as Map);
      });
      if (scrollToEnd || _messages.length != before) _scrollToEnd();
    } else if (_ticket == null) {
      setState(() => _error = res['error']?.toString() ?? 'Could not load chat');
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await _api.sendHelpMessage(widget.ticketId, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (res['success'] == true && res['ticket'] is Map) {
        _input.clear();
        _ticket = Map<String, dynamic>.from(res['ticket'] as Map);
      }
    });
    if (res['success'] == true) {
      _scrollToEnd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not send')),
      );
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text(
          'Close this ticket?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The participant will no longer be able to send messages here. '
          'They can still read it or create a new ticket.',
          style: TextStyle(color: DarkColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Close ticket',
              style: TextStyle(color: Color(0xFFF87171)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _closing = true);
    final res = await _api.closeHelpTicket(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _closing = false;
      if (res['success'] == true && res['ticket'] is Map) {
        _ticket = Map<String, dynamic>.from(res['ticket'] as Map);
      }
    });
    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not close')),
      );
    }
  }

  static String _roleLabel(String? senderType) => switch (senderType) {
    'staff' => 'Event Staff',
    'admin' => 'Admin',
    _ => 'Participant',
  };

  /// Participant's name and mobile with a Call button (staff/admin view).
  Widget _participantBar(String name, String mobile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_rounded,
            size: 20,
            color: DarkColors.accentLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                Text(
                  mobile,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3,
                    color: DarkColors.muted,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: mobile)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = helpCategoryOf(_ticket?['category']?.toString());
    final participant = (_ticket?['participantName']?.toString() ?? '').trim();
    // Sent to staff/admin only, so participants never see a call button.
    final mobile = (_ticket?['participantMobile']?.toString() ?? '').trim();

    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        centerTitle: false,
        actions: [
          if (_canClose)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _closing ? null : _close,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                ),
                icon: _closing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF87171),
                        ),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Close ticket'),
              ),
            ),
        ],
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, size: 19, color: category.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (participant.isNotEmpty)
                    Text(
                      participant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: DarkColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (mobile.isNotEmpty) _participantBar(participant, mobile),
          if (_closed) _closedBanner(),
          Expanded(
            child: _ticket == null
                ? Center(
                    child: _error != null
                        ? Text(
                            _error!,
                            style: GoogleFonts.inter(color: DarkColors.muted),
                          )
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          if (_ticket == null || _canReply) _inputBar() else _closedFooter(),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['mine'] == true;
    final when = DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toLocal();
    final name = (m['senderName']?.toString() ?? '').trim();
    final role = _roleLabel(m['senderType']?.toString());
    final roleColor = switch (m['senderType']) {
      'staff' => const Color(0xFF2DD4BF),
      'admin' || 'support' => const Color(0xFFFBBF24),
      _ => DarkColors.accentLight,
    };
    // Participants see replies as the support team (no staff/admin name).
    final label = m['senderType'] == 'support'
        ? name
        : (name.isEmpty ? role : '$name · $role');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? DarkColors.accent : DarkColors.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: mine ? null : Border.all(color: DarkColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              Text(
                m['text']?.toString() ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
              if (when != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      DateFormat('d MMM, h:mm a').format(when),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
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

  Widget _closedBanner() {
    final at = DateTime.tryParse(
      _ticket?['closedAt']?.toString() ?? '',
    )?.toLocal();
    final by = (_ticket?['closedByName']?.toString() ?? '').trim();
    final details = [
      if (by.isNotEmpty) 'by $by',
      if (at != null) DateFormat('d MMM, h:mm a').format(at),
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF2A2A33),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 16, color: DarkColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details.isEmpty
                  ? 'This ticket is closed'
                  : 'This ticket is closed $details',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Participant's view of a closed ticket: read-only, with a way to start
  /// a new one.
  Widget _closedFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          color: DarkColors.card,
          border: Border(top: BorderSide(color: DarkColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'This ticket is closed. Need more help? Create a new ticket.',
                style: GoogleFonts.inter(fontSize: 12.5, color: DarkColors.muted),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'new'),
              style: FilledButton.styleFrom(backgroundColor: DarkColors.accent),
              child: const Text('New ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: DarkColors.card,
          border: Border(top: BorderSide(color: DarkColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: _ticket != null,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: const TextStyle(color: DarkColors.muted),
                  filled: true,
                  fillColor: DarkColors.field,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending || _ticket == null ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: DarkColors.accent,
                foregroundColor: Colors.white,
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
