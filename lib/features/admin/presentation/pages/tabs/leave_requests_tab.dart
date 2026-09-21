import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/leave_request_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/widgets/leave_out_pass_ui.dart';
import '../../bloc/admin_bloc.dart';

class LeaveRequestsTab extends StatefulWidget {
  final AdminLoaded state;
  final String? selectedApartmentId;

  const LeaveRequestsTab({
    super.key,
    required this.state,
    this.selectedApartmentId,
  });

  @override
  State<LeaveRequestsTab> createState() => _LeaveRequestsTabState();
}

class _LeaveRequestsTabState extends State<LeaveRequestsTab> {
  final ApiService _api = ApiService();
  List<LeaveRequestModel> _allRequests = [];
  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  String? _actionLeaveId;

  List<LeaveRequestModel> get _filtered {
    if (_filter == 'all') return _allRequests;
    final status = LeaveRequestStatus.values.firstWhere(
      (e) => e.name == _filter,
      orElse: () => LeaveRequestStatus.pending,
    );
    return _allRequests.where((r) => r.status == status).toList();
  }

  Map<String, int> get _counts => {
        'pending': _allRequests.where((r) => r.status == LeaveRequestStatus.pending).length,
        'approved': _allRequests.where((r) => r.status == LeaveRequestStatus.approved).length,
        'rejected': _allRequests.where((r) => r.status == LeaveRequestStatus.rejected).length,
        'all': _allRequests.length,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final aptId = widget.selectedApartmentId;
    if (aptId == null || aptId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No property selected';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.listLeaveRequests(apartmentId: aptId);

    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['leaveRequests'] as List)
          .map((e) => LeaveRequestModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _allRequests = list;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _approve(LeaveRequestModel leave) async {
    setState(() => _actionLeaveId = leave.id);
    final result = await _api.updateLeaveApproval(
      leaveRequestId: leave.id,
      status: 'approved',
    );
    if (!mounted) return false;
    setState(() => _actionLeaveId = null);
    if (result['success'] == true) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Out pass approved for ${leave.userName ?? 'resident'}')),
            ],
          ),
          backgroundColor: AppTheme.secondaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error']?.toString() ?? 'Failed'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
    return false;
  }

  Future<bool> _reject(LeaveRequestModel leave, String reason) async {
    setState(() => _actionLeaveId = leave.id);
    final result = await _api.updateLeaveApproval(
      leaveRequestId: leave.id,
      status: 'rejected',
      rejectionReason: reason,
    );
    if (!mounted) return false;
    setState(() => _actionLeaveId = null);
    if (result['success'] == true) {
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Out pass rejected'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error']?.toString() ?? 'Failed')),
    );
    return false;
  }

  void _openReview(LeaveRequestModel leave) {
    LeaveOutPassReviewSheet.show(
      context,
      leave: leave,
      onApprove: () => _approve(leave),
      onReject: (reason) => _reject(leave, reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _counts['pending'] ?? 0;
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandHeaderGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacityCompat(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacityCompat(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Out pass requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount pending — tap a card to review'
                          : 'All caught up',
                      style: TextStyle(
                        color: Colors.white.withOpacityCompat(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        LeaveOutPassFilterBar(
          selected: _filter,
          counts: _counts,
          onSelected: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: filtered.isEmpty
                          ? ListView(
                              children: [
                                LeaveOutPassEmptyState(
                                  title: _filter == 'pending'
                                      ? 'No pending requests'
                                      : 'No ${_filter} out passes',
                                  subtitle: _filter == 'pending'
                                      ? 'New resident leave requests will appear here.'
                                      : 'Try another filter tab above.',
                                  icon: Icons.inbox_rounded,
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final leave = filtered[index];
                                final isPending =
                                    leave.status == LeaveRequestStatus.pending;
                                final busy = _actionLeaveId == leave.id;

                                return LeaveOutPassCard(
                                  leave: leave,
                                  showResidentName: true,
                                  onTap: isPending ? () => _openReview(leave) : null,
                                  trailingActions: isPending
                                      ? LeaveApprovalActions(
                                          loading: busy,
                                          onReject: () => _openReview(leave),
                                          onApprove: () => _approve(leave),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
