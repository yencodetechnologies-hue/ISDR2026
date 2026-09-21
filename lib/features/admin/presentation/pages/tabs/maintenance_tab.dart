import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/models/maintenance_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../bloc/admin_bloc.dart';

class MaintenanceTab extends StatefulWidget {
  final AdminLoaded state;
  const MaintenanceTab({super.key, required this.state});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  List<MaintenanceModel> _maintenanceList = [];
  bool _isLoading = false;

  String? get _apartmentId {
    final sel = widget.state.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadMaintenance();
  }

  @override
  void didUpdateWidget(covariant MaintenanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedApartmentId != widget.state.selectedApartmentId) {
      _loadMaintenance();
    }
  }

  Future<void> _loadMaintenance() async {
    setState(() => _isLoading = true);
    final apiService = ApiService();
    final response = await apiService.getAllMaintenance(apartmentId: _apartmentId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response['success'] == true && response['maintenance'] != null) {
          final List<dynamic> maintenanceData = response['maintenance'];
          _maintenanceList = maintenanceData
              .map((item) => MaintenanceModel.fromJson(item))
              .toList();
        }
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.8),
      ),
    );
  }

  void _showAddMaintenanceDialog(BuildContext context) {
    final amountController = TextEditingController();
    final monthController = TextEditingController();
    final yearController = TextEditingController();
    final apiService = ApiService();

    // Set current month and year as defaults
    final now = DateTime.now();
    monthController.text = now.month.toString();
    yearController.text = now.year.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Integrated Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF13275D), const Color(0xFF13275D).withValues(alpha: 0.88)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Maintenance',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Set monthly maintenance amount',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: amountController,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: _inputDecoration(label: 'Amount (₹)', hint: 'e.g. 2500', prefixIcon: Icons.currency_rupee_rounded),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: monthController,
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                decoration: _inputDecoration(label: 'Month (1-12)', prefixIcon: Icons.calendar_month_rounded),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: yearController,
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                decoration: _inputDecoration(label: 'Year', prefixIcon: Icons.calendar_today_rounded),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (amountController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter amount', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final amount = double.tryParse(amountController.text.trim());
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a valid amount', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final monthNum = int.tryParse(monthController.text.trim());
                            if (monthNum == null || monthNum < 1 || monthNum > 12) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a valid month (1-12)', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final year = int.tryParse(yearController.text.trim());
                            if (year == null || year < 2000 || year > 2100) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a valid year', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final monthNames = [
                              'January', 'February', 'March', 'April', 'May', 'June',
                              'July', 'August', 'September', 'October', 'November', 'December'
                            ];

                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Adding maintenance...', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                backgroundColor: const Color(0xFF13275D),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            final response = await apiService.setMaintenance(
                              amount: amount,
                              month: monthNames[monthNum - 1],
                              year: year,
                              apartmentId: _apartmentId,
                            );

                            amountController.dispose();
                            monthController.dispose();
                            yearController.dispose();

                            if (mounted) {
                              if (response['success'] == true) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Maintenance added successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                    backgroundColor: const Color(0xFF16A34A),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadMaintenance();
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(response['error'] ?? 'Failed to add maintenance', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                    backgroundColor: const Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF13275D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Add Maintenance',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
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
                            'Maintenance Records',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _maintenanceList.isEmpty
                                ? 'Set monthly maintenance amounts for residents'
                                : '${_maintenanceList.length} record${_maintenanceList.length == 1 ? '' : 's'} configured',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _loadMaintenance,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF13275D),
                        backgroundColor: const Color(0xFF13275D).withValues(alpha: 0.08),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ],
                ),
                if (_maintenanceList.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _showAddMaintenanceDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text('Add Maintenance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13275D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Maintenance List Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF13275D)),
                  )
                : _maintenanceList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13275D).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 40,
                                  color: Color(0xFF13275D),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No maintenance records yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create monthly maintenance rules to automatically assign payments to residents.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddMaintenanceDialog(context),
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: Text('Add First Maintenance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF13275D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF13275D),
                        onRefresh: _loadMaintenance,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _maintenanceList.length,
                          itemBuilder: (context, index) {
                            final maintenance = _maintenanceList[index];
                            final isActive = maintenance.isActive;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
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
                                  border: Border.all(
                                    color: isActive ? const Color(0xFF13275D).withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFF13275D).withValues(alpha: 0.09) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.currency_rupee_rounded,
                                          color: isActive ? const Color(0xFF13275D) : const Color(0xFF94A3B8),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '₹${maintenance.amount.toStringAsFixed(2)}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 19,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 14,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${maintenance.month} ${maintenance.year}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFF16A34A).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
}
