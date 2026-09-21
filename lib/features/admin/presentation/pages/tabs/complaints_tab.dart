import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/models/complaint_model.dart';
import '../../../../../../core/services/api_service.dart';

class AdminComplaintsTab extends StatefulWidget {
  final String? selectedApartmentId;
  const AdminComplaintsTab({super.key, this.selectedApartmentId});

  @override
  State<AdminComplaintsTab> createState() => _AdminComplaintsTabState();
}

class _AdminComplaintsTabState extends State<AdminComplaintsTab>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  List<ComplaintModel> _complaints = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadComplaints();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      _loadComplaints();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatusFilter =>
      _tabController.index == 0 ? 'pending' : 'completed';

  Future<void> _loadComplaints() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getComplaints(
        status: _currentStatusFilter,
        apartmentId: widget.selectedApartmentId,
      );
      if (mounted) {
        if (res['success'] == true) {
          final list = (res['complaints'] as List?)
                  ?.map((e) =>
                      ComplaintModel.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList() ??
              [];
          setState(() {
            _complaints = list;
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['error']?.toString() ?? 'Failed to load complaints';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacityCompat(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(height: 38, text: 'Pending'),
              Tab(height: 38, text: 'Completed'),
            ],
          ),
        ),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _complaints.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_error != null && _complaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadComplaints,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_complaints.isEmpty) {
      final isPending = _tabController.index == 0;
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacityCompat(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacityCompat(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isPending
                        ? Icons.assignment_turned_in_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 36,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPending ? 'No Pending Complaints' : 'No Completed Complaints',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isPending
                      ? 'Great news! There are currently no pending resident complaints.'
                      : 'Resolved and completed complaints for this property will appear here.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          final complaint = _complaints[index];
          final isPendingTab = _tabController.index == 0;
          return _AdminComplaintCard(
            complaint: complaint,
            showUpdateButton: isPendingTab,
            onStatusUpdated: _loadComplaints,
          );
        },
      ),
    );
  }
}

class _AdminComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  final bool showUpdateButton;
  final VoidCallback onStatusUpdated;

  const _AdminComplaintCard({
    required this.complaint,
    required this.showUpdateButton,
    required this.onStatusUpdated,
  });

  Color _statusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const Color(0xFFD97706);
      case ComplaintStatus.approved:
        return AppTheme.primaryColor;
      case ComplaintStatus.completed:
        return const Color(0xFF059669);
      case ComplaintStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Color _statusBgColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const Color(0xFFFFFBEB);
      case ComplaintStatus.approved:
        return const Color(0xFFEFF6FF);
      case ComplaintStatus.completed:
        return const Color(0xFFECFDF5);
      case ComplaintStatus.cancelled:
        return const Color(0xFFFEF2F2);
    }
  }

  Color _statusBorderColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const Color(0xFFFDE68A);
      case ComplaintStatus.approved:
        return const Color(0xFFBFDBFE);
      case ComplaintStatus.completed:
        return const Color(0xFFA7F3D0);
      case ComplaintStatus.cancelled:
        return const Color(0xFFFCA5A5);
    }
  }

  String _roomDetails() {
    final parts = <String>[];
    if (complaint.block != null && complaint.block!.isNotEmpty) {
      parts.add('Block ${complaint.block}');
    }
    if (complaint.floor != null && complaint.floor!.isNotEmpty) {
      parts.add('Floor ${complaint.floor}');
    }
    if (complaint.roomNumber != null && complaint.roomNumber!.isNotEmpty) {
      parts.add('Room ${complaint.roomNumber}');
    }
    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  Future<void> _showUpdateStatusDialog(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Update Complaint Status',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose new status for this resident complaint',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                ...ComplaintStatus.values.map((status) {
                  final isCurrent = status == complaint.status;
                  final statusCol = _statusColor(status);
                  final statusBg = _statusBgColor(status);
                  final statusBorder = _statusBorderColor(status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: statusCol.withOpacityCompat(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          status == ComplaintStatus.completed
                              ? Icons.check_circle_rounded
                              : status == ComplaintStatus.approved
                                  ? Icons.thumb_up_rounded
                                  : status == ComplaintStatus.pending
                                      ? Icons.hourglass_bottom_rounded
                                      : Icons.cancel_rounded,
                          color: statusCol,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        status.name[0].toUpperCase() + status.name.substring(1),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusCol,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Current',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                      onTap: () => Navigator.pop(ctx, status.name),
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    final api = ApiService();
    final res = await api.updateComplaintStatus(complaint.id, chosen);
    if (context.mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $chosen'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        onStatusUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to update status'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(complaint.createdAt);
    final shortDesc = complaint.description.length > 100
        ? '${complaint.description.substring(0, 100)}...'
        : complaint.description;
    final statusColor = _statusColor(complaint.status);
    final statusBg = _statusBgColor(complaint.status);
    final statusBorder = _statusBorderColor(complaint.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFECECEA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Initials
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacityCompat(0.08),
                    border: Border.all(color: const Color(0xFFECECEA)),
                  ),
                  child: Center(
                    child: Text(
                      (complaint.userName.isNotEmpty ? complaint.userName[0] : 'C').toUpperCase(),
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
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
                        complaint.userName.isNotEmpty ? complaint.userName : 'Resident',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _roomDetails(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusBorder),
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
                      const SizedBox(width: 5),
                      Text(
                        complaint.status.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacityCompat(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          complaint.type.name.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shortDesc,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (showUpdateButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateStatusDialog(context),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(
                    'Update Status',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: Color(0xFFECECEA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

