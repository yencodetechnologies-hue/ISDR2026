import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'ticket_chat_page.dart';

/// The four Help & Support ticket categories: api value, label, icon, colour.
const helpTicketCategories =
    <({String value, String label, IconData icon, Color color})>[
      (
        value: 'emergency',
        label: 'Emergency',
        icon: Icons.emergency_rounded,
        color: Color(0xFFEF4444),
      ),
      (
        value: 'medical',
        label: 'Medical Issues',
        icon: Icons.medical_services_rounded,
        color: Color(0xFFEC4899),
      ),
      (
        value: 'others',
        label: 'Others',
        icon: Icons.help_outline_rounded,
        color: Color(0xFF94A3B8),
      ),
      (
        value: 'app',
        label: 'App related issues',
        icon: Icons.phone_android_rounded,
        color: Color(0xFF3B82F6),
      ),
    ];

({String value, String label, IconData icon, Color color}) helpCategoryOf(
  String? value,
) => helpTicketCategories.firstWhere(
  (c) => c.value == value,
  orElse: () => helpTicketCategories[2],
);

/// Ticket list. Participants see their own tickets and can add one (Help &
/// Support); event staff and admin see every ticket (Support Tickets).
/// Tapping a ticket opens its chat.
class HelpTicketsPage extends StatefulWidget {
  final bool isParticipant;

  const HelpTicketsPage({super.key, required this.isParticipant});

  @override
  State<HelpTicketsPage> createState() => _HelpTicketsPageState();
}

class _HelpTicketsPageState extends State<HelpTicketsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tickets = [];

  /// Staff/admin filter: all, active, inactive or closed.
  String _filter = 'all';

  /// An open ticket turns inactive after this long without a participant message.
  static const _inactiveAfter = Duration(hours: 5);

  String _statusOf(Map<String, dynamic> t) {
    if (t['status'] == 'closed') return 'closed';
    final last = DateTime.tryParse(
      (t['lastParticipantAt'] ?? t['createdAt'])?.toString() ?? '',
    );
    if (last == null) return 'active';
    return DateTime.now().difference(last.toLocal()) > _inactiveAfter
        ? 'inactive'
        : 'active';
  }

  List<Map<String, dynamic>> get _shown => widget.isParticipant || _filter == 'all'
      ? _tickets
      : _tickets.where((t) => _statusOf(t) == _filter).toList();

  Widget _filters() {
    const options = [
      ('all', 'All', Icons.all_inbox_rounded, Color(0xFF3B82F6)),
      ('active', 'Active', Icons.bolt_rounded, Color(0xFF22C55E)),
      ('inactive', 'Inactive', Icons.hourglass_bottom_rounded, Color(0xFFF59E0B)),
      ('closed', 'Closed', Icons.lock_outline_rounded, Color(0xFF94A3B8)),
    ];
    int count(String key) => key == 'all'
        ? _tickets.length
        : _tickets.where((t) => _statusOf(t) == key).length;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (key, label, icon, color) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _filter = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _filter == key ? color : const Color(0xFF14141F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == key
                          ? color
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: _filter == key ? Colors.white : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _filter == key
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _filter == key
                              ? Colors.white.withValues(alpha: 0.25)
                              : color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${count(key)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _filter == key ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().listHelpTickets();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _tickets = ((res['tickets'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load tickets';
      }
    });
  }

  Future<void> _open(String ticketId) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => TicketChatPage(ticketId: ticketId)),
    );
    _load(); // new replies change the order and previews
    // "New ticket" from a closed ticket's chat.
    if (result == 'new' && mounted && widget.isParticipant) _add();
  }

  Future<void> _add() async {
    final ticketId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DarkColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddTicketSheet(),
    );
    if (ticketId == null || !mounted) return;
    await _load();
    if (mounted) _open(ticketId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          widget.isParticipant ? 'Help & Support' : 'Support Tickets',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: widget.isParticipant
          ? FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: DarkColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (!widget.isParticipant && _error == null) ...[
                    _filters(),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null || _shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(
                            _error != null
                                ? Icons.error_outline_rounded
                                : Icons.support_agent_rounded,
                            size: 44,
                            color: DarkColors.muted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error ??
                                (widget.isParticipant
                                    ? 'No tickets yet.\nTap "Add" if you need help.'
                                    : _filter == 'all'
                                    ? 'No support tickets yet'
                                    : 'No $_filter tickets'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: DarkColors.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final t in _shown) _card(t),
                ],
              ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final category = helpCategoryOf(t['category']?.toString());
    final last = t['lastMessage'] is Map
        ? Map<String, dynamic>.from(t['lastMessage'] as Map)
        : null;
    final when = DateTime.tryParse(
      t['lastMessageAt']?.toString() ?? '',
    )?.toLocal();
    final replies = ((t['messageCount'] as num?)?.toInt() ?? 1) - 1;
    final lastFromParticipant = last?['senderType'] == 'participant';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: DarkColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: category.color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(t['id'].toString()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category.icon, size: 13, color: category.color),
                          const SizedBox(width: 5),
                          Text(
                            category.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: category.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t['status'] == 'closed') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: DarkColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Closed',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: DarkColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (when != null)
                      Text(
                        DateFormat('d MMM, h:mm a').format(when),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: DarkColors.muted,
                        ),
                      ),
                  ],
                ),
                if (!widget.isParticipant) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 15,
                        color: DarkColors.accentLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        (t['participantName']?.toString() ?? '').isEmpty
                            ? 'Participant'
                            : t['participantName'].toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: DarkColors.accentLight,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  t['description']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: replies > 0
                          ? const Color(0xFF22C55E)
                          : DarkColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        replies == 0
                            ? (widget.isParticipant
                                  ? 'Waiting for a reply'
                                  : 'No reply yet')
                            : '${lastFromParticipant ? (widget.isParticipant ? 'You' : 'Participant') : 'Support'}: ${last?['text'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: replies > 0
                              ? Colors.white.withValues(alpha: 0.75)
                              : DarkColors.muted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: DarkColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Category dropdown + description, then "Add Ticket". Pops the new ticket id.
class _AddTicketSheet extends StatefulWidget {
  const _AddTicketSheet();

  @override
  State<_AddTicketSheet> createState() => _AddTicketSheetState();
}

class _AddTicketSheetState extends State<_AddTicketSheet> {
  final _description = TextEditingController();
  String? _category;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_category == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Choose a category')));
      return;
    }
    final description = _description.text.trim();
    if (description.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Describe the problem')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final res = await ApiService().createHelpTicket(
      category: _category!,
      description: description,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true && res['ticket'] is Map) {
      Navigator.pop(context, (res['ticket'] as Map)['id'].toString());
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not add the ticket'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Ticket',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: DarkColors.field,
            iconEnabledColor: DarkColors.muted,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: darkInputDecoration('Category', Icons.category_outlined),
            hint: Text(
              'Select a category',
              style: GoogleFonts.inter(fontSize: 14, color: DarkColors.muted),
            ),
            items: [
              for (final c in helpTicketCategories)
                DropdownMenuItem(
                  value: c.value,
                  child: Row(
                    children: [
                      Icon(c.icon, size: 18, color: c.color),
                      const SizedBox(width: 10),
                      Text(c.label),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: darkInputDecoration(
              'Description',
              Icons.edit_note_rounded,
            ).copyWith(
              hintText: 'Describe the problem',
              hintStyle: const TextStyle(color: DarkColors.muted),
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: DarkColors.accent,
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
                      'Add Ticket',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
