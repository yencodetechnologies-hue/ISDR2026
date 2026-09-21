import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/leave_request_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/widgets/leave_out_pass_ui.dart';
import 'widgets/create_leave_request_sheet.dart';
import 'widgets/leave_gate_pass_sheet.dart';

class LeaveRequestsPage extends StatefulWidget {
  final bool securityEnabled;

  const LeaveRequestsPage({super.key, this.securityEnabled = true});

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  final ApiService _api = ApiService();
  List<LeaveRequestModel> _requests = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  List<LeaveRequestModel> get _filtered {
    if (_filter == 'all') return _requests;
    final status = LeaveRequestStatus.values.firstWhere(
      (e) => e.name == _filter,
      orElse: () => LeaveRequestStatus.pending,
    );
    return _requests.where((r) => r.status == status).toList();
  }

  Map<String, int> get _counts => {
        'pending': _requests.where((r) => r.status == LeaveRequestStatus.pending).length,
        'approved': _requests.where((r) => r.status == LeaveRequestStatus.approved).length,
        'rejected': _requests.where((r) => r.status == LeaveRequestStatus.rejected).length,
        'all': _requests.length,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getMyLeaveRequests();
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['leaveRequests'] as List)
          .map((e) => LeaveRequestModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _requests = list;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['error']?.toString();
        _loading = false;
      });
    }
  }

  void _openCreate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateLeaveRequestSheet(
        onSuccess: () {
          Navigator.pop(ctx);
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Out pass request submitted'),
                ],
              ),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel(LeaveRequestModel leave) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentColor),
            SizedBox(width: 10),
            Text('Cancel request?'),
          ],
        ),
        content: const Text(
          'Your pending out pass request will be cancelled. You can submit a new one anytime.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _api.cancelLeaveRequest(leave.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed')),
      );
    }
  }

  Future<void> _showGatePass(LeaveRequestModel leave) async {
    final result = await _api.getLeaveGatePass(leave.id);
    if (!mounted) return;
    if (result['success'] == true) {
      final pass = LeaveGatePassPayload.fromJson(
        Map<String, dynamic>.from(result['gatePass'] as Map),
      );
      await LeaveGatePassSheet.show(context, pass);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My out passes'),
        centerTitle: false,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: BrandGradientCtaButton(
          height: 52,
          icon: Icons.add_rounded,
          label: 'New out pass',
          onPressed: _openCreate,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    LeaveOutPassFilterBar(
                      selected: _filter,
                      counts: _counts,
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? ListView(
                                children: const [
                                  LeaveOutPassEmptyState(
                                    title: 'No out passes yet',
                                    subtitle:
                                        'Request permission to go out.\nWarden will approve from management app.',
                                    icon: Icons.nightlife_rounded,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final leave = filtered[index];
                                  final isPending =
                                      leave.status == LeaveRequestStatus.pending;
                                  final hasPass = widget.securityEnabled &&
                                      leave.isActiveGatePass;

                                  return LeaveOutPassCard(
                                    leave: leave,
                                    trailingActions: Row(
                                      children: [
                                        if (isPending)
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _cancel(leave),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.errorColor,
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                          ),
                                        if (isPending && hasPass)
                                          const SizedBox(width: 8),
                                        if (hasPass)
                                          Expanded(
                                            flex: isPending ? 2 : 1,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: AppTheme.brandAccentGradient,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _showGatePass(leave),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(
                                                      vertical: 11,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          Icons.qr_code_2_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Gate pass QR',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
