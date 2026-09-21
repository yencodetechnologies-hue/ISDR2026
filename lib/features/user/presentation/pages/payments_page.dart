import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

Rect? _shareOriginFromContext(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

String _sanitizeInvoiceFileName(String name, {required String defaultExt}) {
  var s = name.trim();
  if (s.isEmpty) return 'invoice$defaultExt';
  s = s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  final lower = s.toLowerCase();
  if (!lower.endsWith(defaultExt.toLowerCase())) {
    if (defaultExt == '.html' && lower.endsWith('.htm')) {
      return s;
    }
    s = '$s$defaultExt';
  }
  return s;
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<PaymentModel> _pending = [];
  List<PaymentModel> _paid = [];
  bool _isLoading = true;
  String? _filterMonth;
  int? _filterYear;
  String? _uploadingPaymentId;
  String? _downloadingInvoiceId;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _downloadStatement() async {
    final authState = context.read<AuthBloc>().state;
    final apartmentId = authState is AuthAuthenticated
        ? (authState.selectedApartmentId ?? authState.user.apartmentId)
        : null;
    final res = await _api.downloadPaymentReport(
      month: _filterMonth,
      year: _filterYear,
      apartmentId: apartmentId,
      scope: 'self',
    );
    if (!mounted) return;
    if (res['success'] == true) {
      await Share.share(res['content']?.toString() ?? '', subject: 'My payment statement');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed to download statement')),
      );
    }
  }

  Future<void> _downloadInvoice(PaymentModel payment, {Rect? sharePositionOrigin}) async {
    if (payment.status != 'paid') return;

    final authState = context.read<AuthBloc>().state;
    final apartmentId = authState is AuthAuthenticated
        ? (authState.selectedApartmentId ?? authState.user.apartmentId)
        : null;

    setState(() => _downloadingInvoiceId = payment.id);
    try {
      final res = await _api.downloadPaymentInvoice(
        payment.id,
        apartmentId: apartmentId,
      );
      if (!mounted) return;

      if (res['success'] == true && res['bytes'] is List<int>) {
        final tempDir = await getTemporaryDirectory();
        final rawName =
            (res['fileName']?.toString().trim().isNotEmpty ?? false)
                ? res['fileName'].toString().trim()
                : 'invoice_${payment.id}.html';
        final safeName = _sanitizeInvoiceFileName(rawName, defaultExt: '.html');
        final file = File('${tempDir.path}/$safeName');
        await file.writeAsBytes(List<int>.from(res['bytes'] as List<int>));
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'text/html',
              name: safeName,
            ),
          ],
          text: 'Invoice for ${payment.month} ${payment.year}',
          subject: 'Payment invoice',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['error']?.toString() ?? 'Failed to download invoice',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingInvoiceId = null);
    }
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthBloc>().state;
      final apartmentId = authState is AuthAuthenticated
          ? (authState.selectedApartmentId ?? authState.user.apartmentId)
          : null;
      final res = await _api.getMyPayments(
        month: _filterMonth,
        year: _filterYear,
        apartmentId: apartmentId,
      );
      if (mounted && res['success'] == true && res['payments'] != null) {
        final list = (res['payments'] as List)
            .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _pending = list.where((p) => p.status != 'paid').toList();
          _paid = list.where((p) => p.status == 'paid').toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadProof(PaymentModel p) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    setState(() => _uploadingPaymentId = p.id);
    try {
      final res = await _api.uploadPaymentProof(p.id, file);
      if (!mounted) return;
      setState(() => _uploadingPaymentId = null);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded. Apartment will verify.'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        _loadPayments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Upload failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPaymentId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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
              const SizedBox(height: 16),
              if (p.lineItems.isNotEmpty) ...[
                const Text(
                  'Breakdown',
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.status == 'paid'
                          ? AppTheme.secondaryColor.withOpacity(0.2)
                          : p.status == 'proof_submitted'
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : AppTheme.accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.status == 'paid'
                            ? AppTheme.secondaryColor
                            : p.status == 'proof_submitted'
                                ? AppTheme.primaryColor
                                : AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (p.status == 'paid') ...[
                const SizedBox(height: 20),
                Builder(
                  builder: (btnContext) {
                    return BrandGradientCtaButton(
                      height: 52,
                      isLoading: _downloadingInvoiceId == p.id,
                      icon: Icons.download_rounded,
                      label: 'Download invoice',
                      onPressed: () {
                        final origin = _shareOriginFromContext(btnContext);
                        Navigator.pop(ctx);
                        _downloadInvoice(p, sharePositionOrigin: origin);
                      },
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 20),
                if (p.proofImageUrl == null || p.proofImageUrl!.isEmpty)
                  BrandGradientCtaButton(
                    height: 52,
                    isLoading: _uploadingPaymentId == p.id,
                    icon: Icons.upload_file_rounded,
                    label: 'Upload payment proof',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _uploadProof(p);
                    },
                  )
                else ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 20, color: AppTheme.secondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Proof uploaded – awaiting verification',
                        style: TextStyle(fontSize: 14, color: AppTheme.secondaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploadingPaymentId == p.id
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _uploadProof(p);
                            },
                      icon: _uploadingPaymentId == p.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 20),
                      label: const Text('Replace proof'),
                    ),
                  ),
                ],
              ],
              if (p.paymentDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Paid on ${p.paymentDate.toString().split(' ').first}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _assignPaymentEnabled(AuthAuthenticated auth) {
    final apartments = auth.user.apartments;
    if (apartments == null || apartments.isEmpty) return true;
    final selectedId = auth.selectedApartmentId ?? auth.user.apartmentId;
    if (selectedId == null || selectedId.isEmpty) {
      return apartments.first.assignPaymentEnabled;
    }
    for (final apt in apartments) {
      if (apt.id == selectedId) return apt.assignPaymentEnabled;
    }
    return apartments.first.assignPaymentEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_assignPaymentEnabled(authState)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Payments'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.payment_rounded,
                      size: 56,
                      color: AppTheme.primaryColor.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payments are not enabled for this property.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _buildPaymentsScaffold(context);
      },
    );
  }

  Widget _buildPaymentsScaffold(BuildContext context) {
    final bool isEmpty = _pending.isEmpty && _paid.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Statement',
            onPressed: _downloadStatement,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPayments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: 'Month',
                      labelStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    initialValue: _filterMonth,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Months')),
                      ...List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: _monthNames[i],
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
                      labelStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    initialValue: _filterYear,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Years')),
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
          ),

          // Main List / Content Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPayments,
                    color: AppTheme.primaryColor,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (isEmpty)
                          _buildEmptyState(
                            title: 'No Payments Found',
                            subtitle: 'No payment records or invoices found for the selected period.',
                          )
                        else ...[
                          // Pending Payments Section
                          if (_pending.isNotEmpty) ...[
                            _buildSectionHeader('Pending Payments', _pending.length, Icons.pending_actions_rounded, const Color(0xFFD97706)),
                            const SizedBox(height: 10),
                            ..._pending.map((p) => _buildPaymentCard(p, isPending: true)),
                            const SizedBox(height: 24),
                          ],

                          // Paid Payments Section
                          _buildSectionHeader('Payment History', _paid.length, Icons.history_rounded, const Color(0xFF059669)),
                          const SizedBox(height: 10),
                          if (_paid.isEmpty)
                            _buildEmptyState(
                              title: 'No Paid Invoices Yet',
                              subtitle: 'Completed payment receipts and downloaded invoices will appear here.',
                            )
                          else
                            ..._paid.map((p) => _buildPaymentCard(p, isPending: false)),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(PaymentModel p, {required bool isPending}) {
    final bool isProofSubmitted = p.status == 'proof_submitted';
    final Color statusBg = isPending
        ? (isProofSubmitted ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7))
        : const Color(0xFFDCFCE7);
    final Color statusText = isPending
        ? (isProofSubmitted ? const Color(0xFF0284C7) : const Color(0xFFD97706))
        : const Color(0xFF16A34A);
    final String statusLabel = isPending
        ? (isProofSubmitted ? 'Proof Uploaded' : 'Pending')
        : 'Paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category/Payment Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPending ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPending ? Icons.receipt_long_rounded : Icons.check_circle_outline_rounded,
                    color: isPending ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Month & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${p.month} ${p.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${p.displayAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (isProofSubmitted)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Awaiting verification',
                            style: TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                          ),
                        )
                      else if (!isPending && p.paymentDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Paid on ${p.paymentDate.toString().split(' ').first}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
                // Action
                if (isPending)
                  (p.proofImageUrl == null || p.proofImageUrl!.isEmpty)
                      ? SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => _uploadProof(p),
                            icon: const Icon(Icons.upload_rounded, size: 16),
                            label: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded, color: Colors.grey)
                else
                  _downloadingInvoiceId == p.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        )
                      : Builder(
                          builder: (btnContext) {
                            return IconButton(
                              tooltip: 'Download Invoice',
                              icon: const Icon(Icons.download_rounded, color: AppTheme.primaryColor),
                              onPressed: () => _downloadInvoice(
                                p,
                                sharePositionOrigin: _shareOriginFromContext(btnContext),
                              ),
                            );
                          },
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
