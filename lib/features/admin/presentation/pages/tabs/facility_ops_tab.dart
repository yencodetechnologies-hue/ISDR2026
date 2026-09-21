import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/services/api_service.dart';
import '../../bloc/admin_bloc.dart';
import '../widgets/society_ops_sheets.dart';

class FacilityOpsTab extends StatefulWidget {
  final AdminLoaded state;

  const FacilityOpsTab({super.key, required this.state});

  @override
  State<FacilityOpsTab> createState() => _FacilityOpsTabState();
}

class _FacilityOpsTabState extends State<FacilityOpsTab> {
  final ApiService _api = ApiService();
  static final _dateFmt = DateFormat('dd MMM yyyy');

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = const {};

  List<Map<String, dynamic>> _furniture = const [];
  List<Map<String, dynamic>> _liftServices = const [];
  List<Map<String, dynamic>> _liftPayments = const [];
  List<Map<String, dynamic>> _assets = const [];

  String? _furnitureListError;
  String? _liftServicesListError;
  String? _liftPaymentsListError;
  String? _assetsListError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FacilityOpsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedApartmentId != widget.state.selectedApartmentId) {
      _load();
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    if (v is DateTime) return _dateFmt.format(v);
    if (v is String) {
      final d = DateTime.tryParse(v);
      return d != null ? _dateFmt.format(d.toLocal()) : v;
    }
    return v.toString();
  }

  String? get _apartmentId {
    final sel = widget.state.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  Future<void> _load() async {
    final apt = _apartmentId;
    setState(() {
      _loading = true;
      _error = null;
      _furnitureListError = null;
      _liftServicesListError = null;
      _liftPaymentsListError = null;
      _assetsListError = null;
    });

    final results = await Future.wait<Map<String, dynamic>>([
      _api.getSocietyOpsSummary(apartmentId: apt),
      _api.listSocietyOpsFurniture(apartmentId: apt),
      _api.listSocietyOpsLiftServices(apartmentId: apt),
      _api.listSocietyOpsLiftPayments(apartmentId: apt),
      _api.listSocietyOpsAssets(apartmentId: apt),
    ]);

    if (!mounted) return;

    final summaryRes = results[0];
    final furnitureRes = results[1];
    final liftSvcRes = results[2];
    final liftPayRes = results[3];
    final assetsRes = results[4];

    setState(() {
      _loading = false;
      _summary = Map<String, dynamic>.from(summaryRes['summary'] as Map? ?? const {});
      _error = summaryRes['success'] == true ? null : summaryRes['error']?.toString();

      _furniture = List<Map<String, dynamic>>.from(
        (furnitureRes['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      );
      _furnitureListError = furnitureRes['success'] == true ? null : furnitureRes['error']?.toString();

      _liftServices = List<Map<String, dynamic>>.from(
        (liftSvcRes['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      );
      _liftServicesListError = liftSvcRes['success'] == true ? null : liftSvcRes['error']?.toString();

      _liftPayments = List<Map<String, dynamic>>.from(
        (liftPayRes['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      );
      _liftPaymentsListError = liftPayRes['success'] == true ? null : liftPayRes['error']?.toString();

      _assets = List<Map<String, dynamic>>.from(
        (assetsRes['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
      );
      _assetsListError = assetsRes['success'] == true ? null : assetsRes['error']?.toString();
    });
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF13275D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _confirmDelete(String label) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Record', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF13275D))),
        content: Text('Are you sure you want to remove this $label record?', style: GoogleFonts.inter(color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _addOrEditFurniture({Map<String, dynamic>? existing}) async {
    final apt = _apartmentId;
    if (apt == null || apt.isEmpty) {
      _snack('Please select an apartment first.', err: true);
      return;
    }
    final r = await SocietyOpsFurnitureSheet.show(context, existing: existing);
    if (r == null || !mounted) return;
    final id = existing != null ? societyOpsItemId(existing) : null;
    late final Map<String, dynamic> res;
    if (id != null && id.isNotEmpty) {
      res = await _api.updateSocietyOpsFurniture(
        id: id,
        itemType: r['itemType'] as String,
        name: r['name'] as String,
        quantity: r['quantity'] as int,
        availableQuantity: r['availableQuantity'] as int,
        location: r['location'] as String,
        status: r['status'] as String,
        notes: r['notes'] as String,
        apartmentId: _apartmentId,
      );
    } else {
      res = await _api.createSocietyOpsFurniture(
        itemType: r['itemType'] as String,
        name: r['name'] as String,
        quantity: r['quantity'] as int,
        availableQuantity: r['availableQuantity'] as int,
        location: r['location'] as String,
        status: r['status'] as String,
        notes: r['notes'] as String,
        apartmentId: _apartmentId,
      );
    }
    if (!mounted) return;
    if (res['success'] == true) {
      _snack(id != null ? 'Furniture updated successfully' : 'Furniture added successfully');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to save furniture', err: true);
    }
  }

  Future<void> _deleteFurniture(Map<String, dynamic> m) async {
    final id = societyOpsItemId(m);
    if (id == null || id.isEmpty) return;
    if (!await _confirmDelete('furniture')) return;
    final res = await _api.deleteSocietyOpsFurniture(id: id, apartmentId: _apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      _snack('Furniture deleted');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to delete', err: true);
    }
  }

  Future<void> _addOrEditLiftService({Map<String, dynamic>? existing}) async {
    final apt = _apartmentId;
    if (apt == null || apt.isEmpty) {
      _snack('Please select an apartment first.', err: true);
      return;
    }
    final r = await SocietyOpsLiftServiceSheet.show(context, existing: existing);
    if (r == null || !mounted) return;
    final id = existing != null ? societyOpsItemId(existing) : null;
    late final Map<String, dynamic> res;
    final serviceDate = r['serviceDate'] as DateTime;
    final next = r['nextServiceDate'] as DateTime?;
    if (id != null && id.isNotEmpty) {
      res = await _api.updateSocietyOpsLiftService(
        id: id,
        title: r['title'] as String,
        description: r['description'] as String,
        vendorName: r['vendorName'] as String,
        serviceDate: serviceDate,
        nextServiceDate: next,
        cost: (r['cost'] as num).toDouble(),
        status: r['status'] as String,
        apartmentId: _apartmentId,
      );
    } else {
      res = await _api.createSocietyOpsLiftService(
        title: r['title'] as String,
        description: r['description'] as String,
        vendorName: r['vendorName'] as String,
        serviceDate: serviceDate,
        nextServiceDate: next,
        cost: (r['cost'] as num).toDouble(),
        status: r['status'] as String,
        apartmentId: _apartmentId,
      );
    }
    if (!mounted) return;
    if (res['success'] == true) {
      _snack(id != null ? 'Lift service updated' : 'Lift service logged');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to save lift service', err: true);
    }
  }

  Future<void> _deleteLiftService(Map<String, dynamic> m) async {
    final id = societyOpsItemId(m);
    if (id == null || id.isEmpty) return;
    if (!await _confirmDelete('lift service')) return;
    final res = await _api.deleteSocietyOpsLiftService(id: id, apartmentId: _apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      _snack('Lift service record deleted');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to delete', err: true);
    }
  }

  Future<void> _addOrEditLiftPayment({Map<String, dynamic>? existing}) async {
    final apt = _apartmentId;
    if (apt == null || apt.isEmpty) {
      _snack('Please select an apartment first.', err: true);
      return;
    }
    final r = await SocietyOpsLiftPaymentSheet.show(context, existing: existing);
    if (r == null || !mounted) return;
    final id = existing != null ? societyOpsItemId(existing) : null;
    late final Map<String, dynamic> res;
    final paid = r['paidDate'] as DateTime?;
    if (id != null && id.isNotEmpty) {
      res = await _api.updateSocietyOpsLiftPayment(
        id: id,
        vendorName: r['vendorName'] as String,
        description: r['description'] as String,
        amount: (r['amount'] as num).toDouble(),
        dueDate: r['dueDate'] as DateTime,
        paidDate: paid,
        status: r['status'] as String,
        apartmentId: _apartmentId,
      );
    } else {
      res = await _api.createSocietyOpsLiftPayment(
        vendorName: r['vendorName'] as String,
        description: r['description'] as String,
        amount: (r['amount'] as num).toDouble(),
        dueDate: r['dueDate'] as DateTime,
        paidDate: paid,
        status: r['status'] as String,
        apartmentId: _apartmentId,
      );
    }
    if (!mounted) return;
    if (res['success'] == true) {
      _snack(id != null ? 'Lift payment updated' : 'Lift payment recorded');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to save payment', err: true);
    }
  }

  Future<void> _deleteLiftPayment(Map<String, dynamic> m) async {
    final id = societyOpsItemId(m);
    if (id == null || id.isEmpty) return;
    if (!await _confirmDelete('lift payment')) return;
    final res = await _api.deleteSocietyOpsLiftPayment(id: id, apartmentId: _apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      _snack('Lift payment deleted');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to delete', err: true);
    }
  }

  Future<void> _addOrEditAsset({Map<String, dynamic>? existing}) async {
    final apt = _apartmentId;
    if (apt == null || apt.isEmpty) {
      _snack('Please select an apartment first.', err: true);
      return;
    }
    final r = await SocietyOpsAssetSheet.show(context, existing: existing);
    if (r == null || !mounted) return;
    final id = existing != null ? societyOpsItemId(existing) : null;
    late final Map<String, dynamic> res;
    final purchase = r['purchaseDate'] as DateTime?;
    if (id != null && id.isNotEmpty) {
      res = await _api.updateSocietyOpsAsset(
        id: id,
        name: r['name'] as String,
        category: r['category'] as String,
        quantity: r['quantity'] as int,
        location: r['location'] as String,
        condition: r['condition'] as String,
        purchaseDate: purchase,
        notes: r['notes'] as String,
        apartmentId: _apartmentId,
      );
    } else {
      res = await _api.createSocietyOpsAsset(
        name: r['name'] as String,
        category: r['category'] as String,
        quantity: r['quantity'] as int,
        location: r['location'] as String,
        condition: r['condition'] as String,
        purchaseDate: purchase,
        notes: r['notes'] as String,
        apartmentId: _apartmentId,
      );
    }
    if (!mounted) return;
    if (res['success'] == true) {
      _snack(id != null ? 'Asset updated' : 'Asset added');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to save asset', err: true);
    }
  }

  Future<void> _deleteAsset(Map<String, dynamic> m) async {
    final id = societyOpsItemId(m);
    if (id == null || id.isEmpty) return;
    if (!await _confirmDelete('asset')) return;
    final res = await _api.deleteSocietyOpsAsset(id: id, apartmentId: _apartmentId);
    if (!mounted) return;
    if (res['success'] == true) {
      _snack('Asset deleted');
      _load();
    } else {
      _snack(res['error']?.toString() ?? 'Failed to delete', err: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF8FAFC),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF13275D)),
        ),
      );
    }

    final furnitureMap = _summary['furniture'] as Map?;
    final liftSvcMap = _summary['liftServices'] as Map?;
    final liftPayMap = _summary['liftPayments'] as Map?;
    final assetsMap = _summary['assets'] as Map?;

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        color: const Color(0xFF13275D),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Summary Metrics Grid/Row
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cards = [
                  _MetricSummaryCard(
                    title: 'Chairs / Tables',
                    icon: Icons.chair_rounded,
                    color: const Color(0xFF13275D),
                    primaryLabel: 'Items',
                    primaryValue: '${furnitureMap?['totalItems'] ?? 0}',
                    secondaryLabel: 'Quantity',
                    secondaryValue: '${furnitureMap?['totalQuantity'] ?? 0}',
                  ),
                  _MetricSummaryCard(
                    title: 'Lift Service',
                    icon: Icons.elevator_rounded,
                    color: const Color(0xFF0D9488),
                    primaryLabel: 'Scheduled',
                    primaryValue: '${liftSvcMap?['scheduled'] ?? 0}',
                    secondaryLabel: 'Completed',
                    secondaryValue: '${liftSvcMap?['completed'] ?? 0}',
                  ),
                  _MetricSummaryCard(
                    title: 'Lift Payments',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFFD97706),
                    primaryLabel: 'Pending',
                    primaryValue: '${liftPayMap?['pending'] ?? 0}',
                    secondaryLabel: 'Overdue',
                    secondaryValue: '${liftPayMap?['overdue'] ?? 0}',
                  ),
                  _MetricSummaryCard(
                    title: 'Assets',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF7C3AED),
                    primaryLabel: 'Total',
                    primaryValue: '${assetsMap?['total'] ?? 0}',
                    secondaryLabel: 'Maintenance',
                    secondaryValue: '${assetsMap?['maintenance'] ?? 0}',
                  ),
                ];

                if (w >= 520) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        SizedBox(width: w < 360 ? 210 : 230, child: cards[i]),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Section Header Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13275D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Records for the selected apartment',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF13275D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Chairs / Tables Section
            _OpsSection(
              title: 'Chairs / Tables',
              icon: Icons.chair_rounded,
              color: const Color(0xFF13275D),
              countBadge: _furniture.length,
              error: _furnitureListError,
              onAdd: () => _addOrEditFurniture(),
              emptyMessage: 'No furniture items yet.',
              emptyHint: 'Tap + to add chairs, tables, or shared inventory.',
              child: _furniture.isEmpty && _furnitureListError == null
                  ? null
                  : Column(
                      children: [
                        for (var i = 0; i < _furniture.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _FacilityRecordRow(
                            accentColor: const Color(0xFF13275D),
                            icon: Icons.event_seat_rounded,
                            title: '${_furniture[i]['name'] ?? '—'}',
                            categoryChip: _furniture[i]['itemType']?.toString(),
                            statusChip: _furniture[i]['status']?.toString(),
                            subtitle: 'Qty: ${_furniture[i]['quantity'] ?? 0}  ·  Avail: ${_furniture[i]['availableQuantity'] ?? 0}'
                                '${(_furniture[i]['location'] != null && _furniture[i]['location'].toString().isNotEmpty) ? '  ·  ${_furniture[i]['location']}' : ''}',
                            onTap: () => _addOrEditFurniture(existing: _furniture[i]),
                            menu: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (v) {
                                final m = _furniture[i];
                                if (v == 'edit') _addOrEditFurniture(existing: m);
                                if (v == 'delete') _deleteFurniture(m);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF13275D)),
                                      const SizedBox(width: 8),
                                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 8),
                                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // 2. Lift Service Section
            _OpsSection(
              title: 'Lift Service',
              icon: Icons.elevator_rounded,
              color: const Color(0xFF0D9488),
              countBadge: _liftServices.length,
              error: _liftServicesListError,
              onAdd: () => _addOrEditLiftService(),
              emptyMessage: 'No lift service records yet.',
              emptyHint: 'Log vendor visits, service dates, and next due dates.',
              child: _liftServices.isEmpty && _liftServicesListError == null
                  ? null
                  : Column(
                      children: [
                        for (var i = 0; i < _liftServices.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _FacilityRecordRow(
                            accentColor: const Color(0xFF0D9488),
                            icon: Icons.build_circle_rounded,
                            title: _liftServices[i]['title']?.toString() ?? '—',
                            statusChip: _liftServices[i]['status']?.toString(),
                            subtitle: '${_formatDate(_liftServices[i]['serviceDate'])}'
                                '${(_liftServices[i]['vendorName'] != null && _liftServices[i]['vendorName'].toString().isNotEmpty) ? '  ·  ${_liftServices[i]['vendorName']}' : ''}',
                            onTap: () => _addOrEditLiftService(existing: _liftServices[i]),
                            menu: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (v) {
                                final m = _liftServices[i];
                                if (v == 'edit') _addOrEditLiftService(existing: m);
                                if (v == 'delete') _deleteLiftService(m);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF13275D)),
                                      const SizedBox(width: 8),
                                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 8),
                                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // 3. Lift Payments Section
            _OpsSection(
              title: 'Lift Payments',
              icon: Icons.payments_rounded,
              color: const Color(0xFFD97706),
              countBadge: _liftPayments.length,
              error: _liftPaymentsListError,
              onAdd: () => _addOrEditLiftPayment(),
              emptyMessage: 'No lift payment records yet.',
              emptyHint: 'Track amounts, due dates, and vendor payment status.',
              child: _liftPayments.isEmpty && _liftPaymentsListError == null
                  ? null
                  : Column(
                      children: [
                        for (var i = 0; i < _liftPayments.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _FacilityRecordRow(
                            accentColor: const Color(0xFFD97706),
                            icon: Icons.account_balance_wallet_rounded,
                            title: _liftPayments[i]['vendorName']?.toString() ?? '—',
                            statusChip: _liftPayments[i]['status']?.toString(),
                            subtitle: 'Amount: ₹${_liftPayments[i]['amount'] ?? 0}  ·  Due: ${_formatDate(_liftPayments[i]['dueDate'])}',
                            onTap: () => _addOrEditLiftPayment(existing: _liftPayments[i]),
                            menu: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (v) {
                                final m = _liftPayments[i];
                                if (v == 'edit') _addOrEditLiftPayment(existing: m);
                                if (v == 'delete') _deleteLiftPayment(m);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF13275D)),
                                      const SizedBox(width: 8),
                                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 8),
                                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // 4. Assets Section
            _OpsSection(
              title: 'Assets & Property',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF7C3AED),
              countBadge: _assets.length,
              error: _assetsListError,
              onAdd: () => _addOrEditAsset(),
              emptyMessage: 'No assets registered yet.',
              emptyHint: 'Register equipment, fixtures, and society property.',
              child: _assets.isEmpty && _assetsListError == null
                  ? null
                  : Column(
                      children: [
                        for (var i = 0; i < _assets.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _FacilityRecordRow(
                            accentColor: const Color(0xFF7C3AED),
                            icon: Icons.category_rounded,
                            title: _assets[i]['name']?.toString() ?? '—',
                            categoryChip: _assets[i]['category']?.toString(),
                            statusChip: _assets[i]['condition']?.toString(),
                            subtitle: 'Qty: ${_assets[i]['quantity'] ?? 1}'
                                '${(_assets[i]['location'] != null && _assets[i]['location'].toString().isNotEmpty) ? '  ·  ${_assets[i]['location']}' : ''}',
                            onTap: () => _addOrEditAsset(existing: _assets[i]),
                            menu: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              onSelected: (v) {
                                final m = _assets[i];
                                if (v == 'edit') _addOrEditAsset(existing: m);
                                if (v == 'delete') _deleteAsset(m);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF13275D)),
                                      const SizedBox(width: 8),
                                      Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 8),
                                      Text('Delete', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityRecordRow extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String? categoryChip;
  final String? statusChip;
  final String subtitle;
  final VoidCallback onTap;
  final Widget menu;

  const _FacilityRecordRow({
    required this.accentColor,
    required this.icon,
    required this.title,
    this.categoryChip,
    this.statusChip,
    required this.subtitle,
    required this.onTap,
    required this.menu,
  });

  Color _getStatusColor(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('avail') || lower.contains('good') || lower.contains('paid') || lower.contains('complete') || lower.contains('active')) {
      return const Color(0xFF16A34A);
    }
    if (lower.contains('pending') || lower.contains('due') || lower.contains('scheduled') || lower.contains('fair')) {
      return const Color(0xFFD97706);
    }
    if (lower.contains('overdue') || lower.contains('damage') || lower.contains('repair') || lower.contains('maint') || lower.contains('unavail')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.09),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (categoryChip != null && categoryChip!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryChip!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (statusChip != null && statusChip!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(statusChip!).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusChip!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(statusChip!),
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
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
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int countBadge;
  final String? error;
  final Widget? child;
  final VoidCallback? onAdd;
  final String emptyMessage;
  final String emptyHint;

  const _OpsSection({
    required this.title,
    required this.icon,
    required this.color,
    this.countBadge = 0,
    required this.error,
    required this.child,
    this.onAdd,
    required this.emptyMessage,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final hasRows = child != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF13275D).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            title: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (countBadge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$countBadge',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (onAdd != null)
                  IconButton(
                    onPressed: onAdd,
                    tooltip: 'Add new item',
                    icon: const Icon(Icons.add_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: color,
                      backgroundColor: color.withValues(alpha: 0.09),
                      minimumSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    error!,
                    style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 13),
                  ),
                ),
              if (!hasRows && error == null)
                _SectionEmptyState(message: emptyMessage, hint: emptyHint, color: color),
              if (hasRows) child!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  final String message;
  final String hint;
  final Color color;

  const _SectionEmptyState({
    required this.message,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined, size: 32, color: color.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;

  const _MetricSummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13275D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricBlock(label: primaryLabel, value: primaryValue, color: color),
              ),
              Container(
                width: 1,
                height: 28,
                color: const Color(0xFFF1F5F9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBlock(label: secondaryLabel, value: secondaryValue, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
