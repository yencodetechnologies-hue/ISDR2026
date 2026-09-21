import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/apartment_model.dart';
import '../../../../../../core/models/payment_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/utils/unit_labels.dart';
import '../../bloc/admin_bloc.dart';

const List<String> _paymentTypes = [
  'Maintenance',
  'Rent',
  'Parking',
  'Amenities usage',
  'Penalty',
  'Electricity',
  'Water',
];

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _AddPaymentSheetContent extends StatefulWidget {
  final List<UserModel> users;
  final ApiService api;
  final BuildContext scaffoldContext;
  final VoidCallback onSuccess;
  final String? selectedApartmentId;
  final PropertyType? propertyType;

  const _AddPaymentSheetContent({
    required this.users,
    required this.api,
    required this.scaffoldContext,
    required this.onSuccess,
    this.selectedApartmentId,
    this.propertyType,
  });

  @override
  State<_AddPaymentSheetContent> createState() => _AddPaymentSheetContentState();
}

class _AddPaymentSheetContentState extends State<_AddPaymentSheetContent> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _amounts = {};
  UserModel? _selectedUser;
  late int _selectedMonth;
  late int _selectedYear;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _selectedYear = DateTime.now().year;
    for (final t in _paymentTypes) {
      _amounts[t] = 0;
      _controllers[t] = TextEditingController();
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
    for (final v in _amounts.values) {
      total += v;
    }
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12 + (topPadding > 0 ? 4.0 : 0.0),
        bottom: 24 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF13275D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF13275D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign New Payment',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF13275D),
                      ),
                    ),
                    Text(
                      'Select resident and set line item amounts',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserModel>(
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    menuMaxHeight: 280,
                    itemHeight: 48.0,
                    decoration: InputDecoration(
                      labelText: houseCompositeLabel(widget.propertyType),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: 'Choose resident',
                      prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF13275D)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                      ),
                    ),
                    value: _selectedUser,
                    items: widget.users
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                '${u.block ?? ""} – ${u.floor ?? ""} – ${u.roomNumber ?? ""} (${u.name})',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: u == _selectedUser ? FontWeight.w700 : FontWeight.w500,
                                  color: u == _selectedUser ? const Color(0xFF13275D) : const Color(0xFF1E293B),
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedUser = v),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          menuMaxHeight: 260,
                          itemHeight: 48.0,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF13275D)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                            ),
                          ),
                          value: _selectedMonth,
                          items: List.generate(
                            12,
                            (i) {
                              final isSel = (i + 1) == _selectedMonth;
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text(
                                  _monthNames[i],
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel ? const Color(0xFF13275D) : const Color(0xFF1E293B),
                                  ),
                                ),
                              );
                            },
                          ),
                          onChanged: (v) =>
                              setState(() => _selectedMonth = v ?? _selectedMonth),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          menuMaxHeight: 260,
                          itemHeight: 48.0,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            prefixIcon: const Icon(Icons.event_rounded, size: 18, color: Color(0xFF13275D)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                            ),
                          ),
                          value: _selectedYear,
                          items: () {
                            final years = [
                              DateTime.now().year - 1,
                              DateTime.now().year,
                              DateTime.now().year + 1,
                            ];
                            if (!years.contains(_selectedYear)) years.add(_selectedYear);
                            years.sort();
                            return years
                                .map((y) {
                                  final isSel = y == _selectedYear;
                                  return DropdownMenuItem(
                                    value: y,
                                    child: Text(
                                      '$y',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                        color: isSel ? const Color(0xFF13275D) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  );
                                })
                                .toList();
                          }(),
                          onChanged: (v) =>
                              setState(() => _selectedYear = v ?? _selectedYear),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'PAYMENT BREAKDOWN',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: _paymentTypes.map((type) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  type,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 42,
                                  child: TextField(
                                    controller: _controllers[type],
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF13275D),
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      prefixStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      hintText: '0',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                                      ),
                                    ),
                                    onChanged: (v) {
                                      final n = double.tryParse(v) ?? 0;
                                      setState(() => _amounts[type] = n);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF13275D).withValues(alpha: 0.08),
                          const Color(0xFF1E3A8A).withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF13275D).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount Due',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              'Calculated total',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: const Color(0xFF13275D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: BrandGradientCtaButton(
                          height: 48,
                          isLoading: _isSubmitting,
                          icon: Icons.assignment_turned_in_rounded,
                          label: 'Assign Payment',
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a house'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final lineItems = <Map<String, dynamic>>[];
    for (final type in _paymentTypes) {
      final amt = double.tryParse(_controllers[type]?.text ?? '') ?? 0;
      if (amt > 0) {
        lineItems.add({'type': type, 'amount': amt});
      }
    }
    if (lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final totalFromItems = lineItems.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    if (totalFromItems <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await widget.api.assignPayment(
        userId: _selectedUser!.id,
        month: _monthNames[_selectedMonth - 1],
        year: _selectedYear,
        lineItems: lineItems,
        apartmentId: widget.selectedApartmentId,
      );
      if (!mounted) return;
      final success = res['success'] == true;
      final raw = res['error'] ?? res['message'];
      final message = (raw is String && raw.trim().isNotEmpty)
          ? raw
          : 'Failed to assign payment';
      if (success) {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSuccess();
          if (widget.scaffoldContext.mounted) {
            ScaffoldMessenger.of(widget.scaffoldContext).showSnackBar(
              const SnackBar(
                content: Text('Payment assigned successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final err = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNotEmpty ? err : 'Failed to assign payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class AssignPaymentsTab extends StatefulWidget {
  final AdminLoaded state;
  final PropertyType? propertyType;
  const AssignPaymentsTab({
    required this.state,
    this.propertyType,
    super.key,
  });

  @override
  State<AssignPaymentsTab> createState() => _AssignPaymentsTabState();
}

class _AssignPaymentsTabState extends State<AssignPaymentsTab> {
  final ApiService _api = ApiService();
  List<PaymentModel> _payments = [];
  List<UserModel> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _loadUsers();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final selectedApartmentId = widget.state.selectedApartmentId;
      final res = await _api.getAllPayments(apartmentId: selectedApartmentId);
      if (mounted && res['success'] == true && res['payments'] != null) {
        final list = (res['payments'] as List)
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _payments = list);
      }
    } catch (e, st) {
      debugPrint('[AssignPaymentsTab] _loadPayments error: $e\n$st');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final res = await _api.getAllUsers(apartmentId: widget.state.selectedApartmentId);
      if (mounted && res['success'] == true && res['users'] != null) {
        final list = (res['users'] as List)
            .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
            .where((u) =>
                u.status == AccountStatus.approved &&
                u.block != null &&
                u.block!.isNotEmpty &&
                u.roomNumber != null &&
                u.roomNumber!.isNotEmpty)
            .toList();
        setState(() => _users = list);
      }
    } catch (_) {}
  }

  void _showAddPaymentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPaymentSheetContent(
        users: _users,
        api: _api,
        scaffoldContext: context,
        onSuccess: _loadPayments,
        selectedApartmentId: widget.state.selectedApartmentId,
        propertyType: widget.propertyType,
      ),
    );
  }

  List<PaymentModel> get _filteredPayments {
    return _payments.where((p) {
      final statusMatch = _statusFilter == 'All' ||
          (_statusFilter == 'Paid' && p.status == 'paid') ||
          (_statusFilter == 'Pending' && p.status != 'paid');
      
      if (!statusMatch) return false;
      if (_searchQuery.trim().isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final name = p.userName?.toLowerCase() ?? '';
      final unit = '${p.userBlock ?? ""} ${p.userFloor ?? ""} ${p.userRoomNumber ?? ""}'.toLowerCase();
      final month = p.month.toLowerCase();
      final year = p.year.toString();

      return name.contains(query) || unit.contains(query) || month.contains(query) || year.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _payments.where((p) => p.status == 'paid').length;
    final pendingCount = _payments.length - paidCount;
    final totalAssignedAmount = _payments.fold<double>(0, (sum, p) => sum + p.displayAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Payments',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF13275D),
                            ),
                          ),
                          Text(
                            'Manage monthly dues and resident charges',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 135,
                      child: BrandGradientCtaButton(
                        height: 42,
                        icon: Icons.add_rounded,
                        label: 'Assign Pay',
                        onPressed: _showAddPaymentSheet,
                      ),
                    ),
                  ],
                ),
                if (_payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Metrics Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF13275D),
                          const Color(0xFF1E3A8A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF13275D).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricItem(
                          label: 'Total Assigned',
                          value: '₹${totalAssignedAmount.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _buildMetricItem(
                          label: 'Paid',
                          value: '$paidCount',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF4ADE80),
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _buildMetricItem(
                          label: 'Pending',
                          value: '$pendingCount',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFFBBF24),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Search & Filter controls
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search resident, unit, month...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF13275D)),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          icon: const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF13275D)),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF13275D),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _statusFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main list content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF13275D),
                    ),
                  )
                : _filteredPayments.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadPayments,
                        color: const Color(0xFF13275D),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13275D).withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.credit_card_off_rounded,
                                    size: 54,
                                    color: Color(0xFF13275D),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _payments.isEmpty
                                      ? 'No payments assigned yet'
                                      : 'No matching payments found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _payments.isEmpty
                                      ? 'Start by assigning maintenance dues or extra charges to property residents.'
                                      : 'Try adjusting your search terms or status filter.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPayments,
                        color: const Color(0xFF13275D),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPayments.length,
                          itemBuilder: (context, index) {
                            final p = _filteredPayments[index];
                            final unit = [
                              p.userBlock,
                              p.userFloor,
                              p.userRoomNumber,
                            ].where((e) => e != null && e.isNotEmpty).join(' – ');
                            final isPaid = p.status == 'paid';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: isPaid
                                      ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFEF3C7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPaid
                                                ? Icons.check_circle_rounded
                                                : Icons.pending_rounded,
                                            color: isPaid
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xDFA16207),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.userName ?? 'Resident',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (unit.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.home_work_rounded, size: 14, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      unit,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Status Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isPaid ? 'PAID' : 'PENDING',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isPaid
                                                  ? const Color(0xFF15803D)
                                                  : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${p.month} ${p.year}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '₹${p.displayAmount.toStringAsFixed(2)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF13275D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
