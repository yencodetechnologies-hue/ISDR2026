import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/models/payment_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../bloc/admin_bloc.dart';

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _paymentTypes = [
  'Maintenance', 'Rent', 'Parking', 'Amenities usage',
  'Penalty', 'Electricity', 'Water',
];

/// Edit payment sheet as StatefulWidget so controllers are disposed in [dispose].
class _EditPaymentSheetContent extends StatefulWidget {
  final PaymentModel payment;
  final ApiService api;
  final VoidCallback onSaved;

  const _EditPaymentSheetContent({
    required this.payment,
    required this.api,
    required this.onSaved,
  });

  @override
  State<_EditPaymentSheetContent> createState() => _EditPaymentSheetContentState();
}

class _EditPaymentSheetContentState extends State<_EditPaymentSheetContent> {
  late int _selectedMonth;
  late int _selectedYear;
  late String _selectedStatus;
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _monthNames.indexOf(widget.payment.month) + 1;
    if (_selectedMonth < 1) _selectedMonth = DateTime.now().month;
    _selectedYear = widget.payment.year;
    _selectedStatus = widget.payment.status;
    for (final t in _paymentTypes) {
      PaymentLineItem? item;
      for (final e in widget.payment.lineItems) {
        if (e.type == t) { item = e; break; }
      }
      final amt = item?.amount ?? 0.0;
      _controllers[t] = TextEditingController(text: amt > 0 ? amt.toStringAsFixed(0) : '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final t in _paymentTypes) {
      total += double.tryParse(_controllers[t]?.text ?? '') ?? 0;
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Edit payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                    onChanged: _saving ? null : (v) => setState(() => _selectedMonth = v ?? _selectedMonth),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                    items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1]
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: _saving ? null : (v) => setState(() => _selectedYear = v ?? _selectedYear),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
            ),
            const SizedBox(height: 12),
            const Text('Line items', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._paymentTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 130, child: Text(type, style: const TextStyle(fontSize: 13))),
                      Expanded(
                        child: TextField(
                          controller: _controllers[type],
                          keyboardType: TextInputType.number,
                          enabled: !_saving,
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                )),
            Text(
              'Total: ₹${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final lineItems = <Map<String, dynamic>>[];
    for (final type in _paymentTypes) {
      final amt = double.tryParse(_controllers[type]?.text ?? '') ?? 0;
      if (amt > 0) lineItems.add({'type': type, 'amount': amt});
    }
    if (lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one amount'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await widget.api.updatePayment(
        widget.payment.id,
        month: _monthNames[_selectedMonth - 1],
        year: _selectedYear,
        status: _selectedStatus,
        lineItems: lineItems,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          res['success'] == true
              ? const SnackBar(content: Text('Payment updated'), backgroundColor: Colors.green)
              : SnackBar(
                  content: Text(res['error']?.toString() ?? 'Failed to update'),
                  backgroundColor: Colors.red,
                ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }
}

class PaymentsTab extends StatefulWidget {
  final AdminLoaded state;
  /// When non-null, [parentTabController] and [parentTabIndex] are used to
  /// refresh payments when the user switches to this tab (so newly added
  /// payments show in the Pending list).
  final TabController? parentTabController;
  final int? parentTabIndex;

  const PaymentsTab({
    required this.state,
    this.parentTabController,
    this.parentTabIndex,
    super.key,
  });

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  int? _filterMonth;
  int? _filterYear;
  VoidCallback? _parentTabListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayments();
    final parent = widget.parentTabController;
    final index = widget.parentTabIndex;
    if (parent != null && index != null) {
      void listener() {
        if (parent.index == index && mounted) _loadPayments();
      }
      _parentTabListener = listener;
      parent.addListener(listener);
    }
  }

  @override
  void dispose() {
    if (_parentTabListener != null && widget.parentTabController != null) {
      widget.parentTabController!.removeListener(_parentTabListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      String? month;
      int? year;
      if (_filterMonth != null) month = _monthNames[_filterMonth! - 1];
      if (_filterYear != null) year = _filterYear;
      final status = _tabController.index == 0 ? 'pending' : 'paid';
      final selectedApartmentId = widget.state.selectedApartmentId;
      debugPrint('[PaymentsTab] _loadPayments: month=$month year=$year status=$status');
      final res = await _api.getAllPayments(month: month, year: year, status: status, apartmentId: selectedApartmentId);
      debugPrint('[PaymentsTab] _loadPayments: success=${res['success']}, payments count=${(res['payments'] as List?)?.length ?? 0}');
      if (mounted && res['success'] == true && res['payments'] != null) {
        final list = (res['payments'] as List)
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[PaymentsTab] parsed ${list.length} payments: ${list.map((p) => '${p.month}/${p.year} ${p.status}').join(', ')}');
        setState(() => _payments = list);
      }
    } catch (e, st) {
      debugPrint('[PaymentsTab] _loadPayments error: $e\n$st');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onFilterOrTabChanged() {
    _loadPayments();
  }

  Future<void> _downloadReport() async {
    final res = await _api.downloadPaymentReport(
      month: _filterMonth != null ? _monthNames[_filterMonth! - 1] : null,
      year: _filterYear,
      status: _tabController.index == 0 ? 'pending' : 'paid',
      apartmentId: widget.state.selectedApartmentId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      await Share.share(res['content']?.toString() ?? '', subject: 'Payment report');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed to download report')),
      );
    }
  }

  Future<void> _sendReminder(PaymentModel payment) async {
    final res = await _api.sendPaymentReminder(payment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? (res['message']?.toString() ?? 'Reminder sent')
              : (res['error']?.toString() ?? 'Failed to send reminder'),
        ),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (res['success'] == true) {
      _loadPayments();
    }
  }

  void _showDetail(PaymentModel p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '${p.month} ${p.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              if (p.userName != null)
                Text(
                  p.userName!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColor.withOpacity(0.8),
                  ),
                ),
              if (p.userBlock != null || p.userRoomNumber != null)
                Text(
                  '${p.userBlock ?? ""} – ${p.userFloor ?? ""} – ${p.userRoomNumber ?? ""}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),
              if (p.lineItems.isNotEmpty) ...[
                const Text(
                  'Line items',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                ...p.lineItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.type),
                          Text('₹${item.amount.toStringAsFixed(2)}'),
                        ],
                      ),
                    )),
                const Divider(),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  Text(
                    '₹${p.displayAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.status == 'paid'
                          ? Colors.green.withOpacity(0.2)
                          : p.status == 'proof_submitted'
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.status == 'paid'
                            ? Colors.green
                            : p.status == 'proof_submitted'
                                ? Colors.blue
                                : Colors.orange,
                      ),
                    ),
                  ),
                  if (p.proofImageUrl != null && p.proofImageUrl!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Proof uploaded',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                      ),
                    ),
                  ],
                ],
              ),
              if (p.proofImageUrl != null && p.proofImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(p.proofImageUrl!);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.image_outlined, size: 20),
                  label: const Text('View proof image'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _verifyProof(p);
                        },
                        style: AppTheme.secondaryElevatedStyle,
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('Verify'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _rejectProof(p);
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
              if (p.paymentDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Paid on: ${p.paymentDate.toString().split(' ').first}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (p.status != 'paid') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendReminder(p);
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Send reminder'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyProof(PaymentModel p) async {
    final res = await _api.verifyPaymentProof(p.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _loadPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verified'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to verify'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectProof(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject proof?'),
        content: const Text(
          'The resident will be able to upload a new proof. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final res = await _api.rejectPaymentProof(p.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _loadPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof rejected'), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to reject'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showMarkPaidDialog(PaymentModel p) async {
    String paymentMethod = 'cash';
    final transactionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mark as paid'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${p.month} ${p.year} · ₹${p.displayAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDialogState(() => paymentMethod = v ?? paymentMethod),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: transactionController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction / reference (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark as paid'),
            ),
          ],
        ),
      ),
    );
    final transactionId = transactionController.text.trim();
    transactionController.dispose();
    if (result != true || !mounted) return;
    final res = await _api.updatePayment(
      p.id,
      status: 'paid',
      paymentMethod: paymentMethod,
      transactionId: transactionId.isEmpty ? null : transactionId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      _loadPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as paid'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to update'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
          'Remove ${p.month} ${p.year} · ₹${p.displayAmount.toStringAsFixed(2)} for ${p.userName ?? "this user"}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final res = await _api.deletePayment(p.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _loadPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to delete'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditPaymentSheet(PaymentModel p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPaymentSheetContent(
        payment: p,
        api: _api,
        onSaved: _loadPayments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          onTap: (_) => _onFilterOrTabChanged(),
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Pending payments'),
            Tab(text: 'Completed payments'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _filterMonth,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_monthNames[i]),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _filterMonth = v;
                          _loadPayments();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      decoration: InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _filterYear,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        ...List.generate(
                          5,
                          (i) => DateTime.now().year - 2 + i,
                        ).map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _filterYear = v;
                          _loadPayments();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadReport,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export report'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadPayments,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _payments.isEmpty
                  ? Center(
                      child: Text(
                        _tabController.index == 0
                            ? 'No pending payments'
                            : 'No completed payments',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPayments,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final p = _payments[index];
                          final unit = [
                            p.userBlock,
                            p.userFloor,
                            p.userRoomNumber,
                          ].where((e) => e != null && e.isNotEmpty).join(' – ');
                          final isPending = _tabController.index == 0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _showDetail(p),
                              title: Text(
                                (p.userName ?? 'User') +
                                    (unit.isNotEmpty ? ' · $unit' : ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${p.month} ${p.year} · ₹${p.displayAmount.toStringAsFixed(2)}'
                                    + (p.paymentDate != null
                                        ? ' · Paid ${p.paymentDate.toString().split(' ').first}'
                                        : '')
                                    + (isPending && p.proofImageUrl != null && p.proofImageUrl!.isNotEmpty
                                        ? ' · Proof uploaded'
                                        : ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: isPending
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') _showEditPaymentSheet(p);
                                        else if (value == 'paid') _showMarkPaidDialog(p);
                                        else if (value == 'delete') _confirmDelete(p);
                                        else if (value == 'view_proof') {
                                          final uri = Uri.tryParse(p.proofImageUrl!);
                                          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } else if (value == 'verify') _verifyProof(p);
                                        else if (value == 'reject') _rejectProof(p);
                                      },
                                      itemBuilder: (ctx) {
                                        final hasProof = p.proofImageUrl != null && p.proofImageUrl!.isNotEmpty;
                                        return [
                                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          const PopupMenuItem(value: 'paid', child: Text('Mark as paid')),
                                          if (hasProof) ...[
                                            const PopupMenuItem(value: 'view_proof', child: Text('View proof')),
                                            const PopupMenuItem(value: 'verify', child: Text('Verify proof')),
                                            const PopupMenuItem(value: 'reject', child: Text('Reject proof')),
                                          ],
                                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                        ];
                                      },
                                    )
                                  : const Icon(Icons.chevron_right, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
