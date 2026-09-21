import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/models/ticket_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../user/presentation/pages/support_chat_page.dart';

class SupportTab extends StatefulWidget {
  final String? selectedApartmentId;
  const SupportTab({super.key, this.selectedApartmentId});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  List<TicketModel> _tickets = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadTickets();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      _loadTickets();
    }
  }

  @override
  void didUpdateWidget(covariant SupportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedApartmentId != widget.selectedApartmentId) {
      _loadTickets();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatusFilter =>
      _tabController.index == 0 ? 'active' : 'closed';

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTickets(
        status: _currentStatusFilter,
        apartmentId: widget.selectedApartmentId,
      );
      if (mounted) {
        if (res['success'] == true) {
          final list = (res['tickets'] as List?)
              ?.map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];
          setState(() {
            _tickets = list;
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['error']?.toString() ?? 'Failed to load tickets';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<TicketModel> get _filteredTickets {
    if (_searchQuery.isEmpty) return _tickets;
    final q = _searchQuery.toLowerCase();
    return _tickets.where((t) {
      final name = t.userName?.toLowerCase() ?? '';
      final desc = t.description.toLowerCase();
      final issue = t.issueType.toLowerCase();
      final room = t.roomNumber?.toLowerCase() ?? '';
      final block = t.block?.toLowerCase() ?? '';
      return name.contains(q) || desc.contains(q) || issue.contains(q) || room.contains(q) || block.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTickets;

    return Column(
      children: [
        // Top Custom Tab Selector
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: const Color(0xFF13275D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(height: 38, text: 'Active'),
              Tab(height: 38, text: 'Closed'),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search by resident, issue, or unit...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF13275D)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
              ),
            ),
          ),
        ),

        Expanded(
          child: _buildBody(filtered),
        ),
      ],
    );
  }

  Widget _buildBody(List<TicketModel> list) {
    if (_loading && _tickets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF13275D)),
      );
    }

    if (_error != null && _tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTickets,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13275D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTickets,
        color: const Color(0xFF13275D),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF13275D).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF13275D).withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 40,
                  color: Color(0xFF13275D),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tabController.index == 0 ? 'No Active Support Tickets' : 'No Closed Support History',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tabController.index == 0
                  ? 'When residents submit support or help queries, they will appear here.'
                  : 'Closed support requests and resolved inquiries will be archived here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No support requests match "$_searchQuery"',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: const Color(0xFF13275D),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final ticket = list[index];
          return _AdminTicketCard(
            ticket: ticket,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => SupportChatPage(
                    ticketId: ticket.id,
                    isAdmin: true,
                  ),
                ),
              );
              _loadTickets();
            },
          );
        },
      ),
    );
  }
}

class _AdminTicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;

  const _AdminTicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy · hh:mm a').format(ticket.createdAt);
    final shortDesc = ticket.description.length > 80
        ? '${ticket.description.substring(0, 80)}...'
        : ticket.description;
    
    final residentName = ticket.userName ?? 'Resident';
    final unitInfo = [
      if (ticket.block != null && ticket.block!.isNotEmpty) 'Block ${ticket.block}',
      if (ticket.roomNumber != null && ticket.roomNumber!.isNotEmpty) 'Flat ${ticket.roomNumber}',
    ].join(' · ');

    final Color statusColor;
    final Color statusBg;
    final String statusLabel;

    switch (ticket.status) {
      case TicketStatus.closed:
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFFECFDF5);
        statusLabel = 'Closed';
        break;
      case TicketStatus.inProgress:
        statusColor = const Color(0xFF3B82F6);
        statusBg = const Color(0xFFEFF6FF);
        statusLabel = 'In Progress';
        break;
      case TicketStatus.open:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
        statusLabel = 'Open';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Resident & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          residentName.isNotEmpty ? residentName[0].toUpperCase() : 'R',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF13275D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            residentName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (unitInfo.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              unitInfo,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                // Issue Tag & Description
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket.issueType,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF13275D),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shortDesc,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Chat',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF13275D),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF13275D),
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
