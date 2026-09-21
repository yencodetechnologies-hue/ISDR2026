import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/services/api_service.dart';
import 'support_chat_page.dart';

class SupportPage extends StatefulWidget {
  final bool isHostel;

  const SupportPage({super.key, this.isHostel = false});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final ApiService _api = ApiService();

  static const _apartmentIssueTypes = [
    '🛡️ Issue with Security',
    '🏠 Issue with Rent / Tenancy',
    '💳 Issue with Payment',
    '🔧 Issue with Maintenance',
    '🚗 Issue with Parking',
    '📦 Issue with Delivery / Visitors',
    '🏊 Issue with Amenities',
    '📢 Issue with Noise / Neighbours',
    '📱 Issue with App / System',
    '📝 Other Issues / General Support',
  ];

  static const _hostelIssueTypes = [
    '🛏️ Room / Bed issue',
    '🍽️ Food / Mess',
    '👤 Warden / Staff',
    '🚪 Security / Out pass',
    '💳 Payment / Fees',
    '🔧 Maintenance / Facilities',
    '📶 WiFi / Utilities',
    '📢 Roommate / Noise',
    '📱 App / System',
    '📝 Other hostel support',
  ];

  List<String> get _issueTypes =>
      widget.isHostel ? _hostelIssueTypes : _apartmentIssueTypes;
  String? _selectedIssueType;
  final TextEditingController _descriptionController = TextEditingController();
  List<TicketModel> _tickets = [];
  bool _loading = false;
  bool _loadingTickets = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final res = await _api.getTickets();
      if (mounted && res['success'] == true) {
        final list = (res['tickets'] as List?)
            ?.map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        setState(() {
          _tickets = list;
          _loadingTickets = false;
        });
      } else {
        if (mounted) {
          setState(() => _loadingTickets = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to load tickets'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTickets = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _submitTicket() async {
    if (_selectedIssueType == null || _selectedIssueType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an issue type'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _api.createTicket(
        issueType: _selectedIssueType!,
        description: desc,
      );
      if (mounted) {
        setState(() => _loading = false);
        if (res['success'] == true) {
          _descriptionController.clear();
          setState(() => _selectedIssueType = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket submitted successfully'),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadTickets();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Submission failed'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  static InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isHostel ? 'Hostel Help & Support' : 'Help & Support'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isHostel ? 'Raise a hostel support request' : 'Create ticket',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _selectedIssueType,
                      decoration: _inputDecoration(labelText: 'Issue type'),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      items: _issueTypes
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedIssueType = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _inputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your issue...',
                      ).copyWith(alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 18),
                    BrandGradientCtaButton(
                      height: 50,
                      isLoading: _loading,
                      icon: Icons.support_agent_rounded,
                      label: 'Submit ticket',
                      onPressed: _submitTicket,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'Your tickets',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingTickets)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                )
              else if (_tickets.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 36,
                        color: AppTheme.primaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No requests found. Create one above.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    return _TicketCard(
                      ticket: ticket,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => SupportChatPage(
                            ticketId: ticket.id,
                            isAdmin: false,
                          ),
                        ),
                      ).then((_) => _loadTickets()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final created = ticket.createdAt;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(created);
    final shortDesc = ticket.description.length > 60
        ? '${ticket.description.substring(0, 60)}...'
        : ticket.description;

    final Color badgeBg;
    final Color badgeText;
    final String statusLabel;

    switch (ticket.status) {
      case TicketStatus.open:
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF059669);
        statusLabel = 'Open';
        break;
      case TicketStatus.inProgress:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        statusLabel = 'In progress';
        break;
      case TicketStatus.closed:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        statusLabel = 'Closed';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.issueType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (shortDesc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          shortDesc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
