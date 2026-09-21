import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/models/subscription_purchase_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';

String _sanitizeFileName(String name) {
  var s = name.trim();
  if (s.isEmpty) return 'document.pdf';
  s = s.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  if (!s.toLowerCase().endsWith('.pdf')) {
    s = '$s.pdf';
  }
  return s;
}

Rect? _shareOriginFromContext(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class SubscriptionPurchaseHistoryPage extends StatefulWidget {
  final String apartmentId;
  final String? apartmentName;

  const SubscriptionPurchaseHistoryPage({
    super.key,
    required this.apartmentId,
    this.apartmentName,
  });

  @override
  State<SubscriptionPurchaseHistoryPage> createState() => _SubscriptionPurchaseHistoryPageState();
}

class _SubscriptionPurchaseHistoryPageState extends State<SubscriptionPurchaseHistoryPage> {
  final ApiService _api = ApiService();
  List<SubscriptionPurchaseModel> _items = [];
  bool _loading = true;
  String? _error;
  String? _downloadingId;
  String? _viewingId;

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
    final res = await _api.getSubscriptionPurchases(apartmentId: widget.apartmentId);
    if (!mounted) return;
    if (res['success'] == true && res['purchases'] is List) {
      final list = (res['purchases'] as List)
          .map((e) => SubscriptionPurchaseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = list;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = res['error']?.toString() ?? 'Failed to load';
      });
    }
  }

  Future<void> _downloadInvoice(SubscriptionPurchaseModel p, Rect? sharePositionOrigin) async {
    setState(() => _downloadingId = p.id);
    try {
      final res = await _api.downloadSubscriptionPurchaseInvoice(
        p.id,
        apartmentId: widget.apartmentId,
      );
      if (!mounted) return;
      if (res['success'] == true && res['bytes'] is List<int>) {
        final tempDir = await getTemporaryDirectory();
        final rawName = (res['fileName']?.toString().trim().isNotEmpty ?? false)
            ? res['fileName'].toString().trim()
            : 'subscription_invoice_${p.id}.pdf';
        final safeName = _sanitizeFileName(rawName);
        final file = File('${tempDir.path}/$safeName');
        await file.writeAsBytes(List<int>.from(res['bytes'] as List<int>));
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: safeName,
            ),
          ],
          text: 'Subscription invoice · ${p.planName}',
          subject: 'Subscription receipt',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Download failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _viewInvoice(SubscriptionPurchaseModel p) async {
    setState(() => _viewingId = p.id);
    try {
      final res = await _api.downloadSubscriptionPurchaseInvoice(
        p.id,
        apartmentId: widget.apartmentId,
      );
      if (!mounted) return;
      if (res['success'] == true && res['bytes'] is List<int>) {
        final tempDir = await getTemporaryDirectory();
        final rawName = (res['fileName']?.toString().trim().isNotEmpty ?? false)
            ? res['fileName'].toString().trim()
            : 'subscription_invoice_${p.id}.pdf';
        final safeName = _sanitizeFileName(rawName);
        final file = File('${tempDir.path}/$safeName');
        await file.writeAsBytes(List<int>.from(res['bytes'] as List<int>));
        final result = await OpenFile.open(file.path, type: 'application/pdf');
        if (mounted && result.type != ResultType.done && result.message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Could not open invoice')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _viewingId = null);
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('d MMM yyyy').format(d.toLocal());
  }

  Widget _brandedHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandHeaderGradient,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Colors.white.withValues(alpha: 0.95), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Receipts & invoices',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.apartmentName != null && widget.apartmentName!.isNotEmpty
                ? 'PDF receipts for ${widget.apartmentName}'
                : 'Download or share subscription payment receipts',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.42,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: AppTheme.primaryColor.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No receipts yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete a subscription payment to see your\npaid receipts and PDF invoices here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppTheme.textColor.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pull down to refresh',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.textColor.withValues(alpha: 0.45),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.42,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 15, color: AppTheme.textColor, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.apartmentName != null && widget.apartmentName!.isNotEmpty
        ? 'Purchases · ${widget.apartmentName}'
        : 'Subscription purchases';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brandedHeader(context),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorState()
                      : _items.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final p = _items[index];
                                final busyDl = _downloadingId == p.id;
                                final busyView = _viewingId == p.id;
                                final disabled = busyView || busyDl;
                                return Material(
                  elevation: 3,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          AppTheme.primaryColor.withValues(alpha: 0.04),
                                          AppTheme.secondaryColor.withValues(alpha: 0.06),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 5,
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.horizontal(
                                              left: Radius.circular(18),
                                            ),
                                            gradient: AppTheme.brandHeaderGradient,
                                          ),
                                        ),
                                        Expanded(
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
                                                  borderRadius: BorderRadius.circular(12),
                                                  gradient: AppTheme.brandHeaderGradient,
                                                ),
                                                child: const Icon(
                                                  Icons.receipt_long_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
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
                                                            p.planName.isNotEmpty ? p.planName : 'Subscription',
                                                            style: GoogleFonts.dmSans(
                                                              fontSize: 17,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.textColor,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: AppTheme.secondaryColor.withValues(alpha: 0.35),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'PAID',
                                                            style: GoogleFonts.dmSans(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w800,
                                                              color: AppTheme.secondaryColor,
                                                              letterSpacing: 0.6,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '${_fmt(p.periodStart)} → ${_fmt(p.periodEnd)}',
                                                      style: GoogleFonts.dmSans(
                                                        fontSize: 13,
                                                        color: AppTheme.textColor.withValues(alpha: 0.62),
                                                      ),
                                                    ),
                                                    if (p.createdAt != null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Purchased ${_fmt(p.createdAt)}',
                                                        style: GoogleFonts.dmSans(
                                                          fontSize: 12,
                                                          color: AppTheme.textColor.withValues(alpha: 0.5),
                                                        ),
                                                      ),
                                                    ],
                                                    if (p.razorpayPaymentId.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Ref ${p.razorpayPaymentId.length > 18 ? '${p.razorpayPaymentId.substring(0, 18)}…' : p.razorpayPaymentId}',
                                                        style: GoogleFonts.dmSans(
                                                          fontSize: 11,
                                                          color: AppTheme.textColor.withValues(alpha: 0.5),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '₹${p.amountInr.toStringAsFixed(0)}',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          BrandGradientCtaButton(
                                            height: 48,
                                            isLoading: busyView,
                                            icon: Icons.picture_as_pdf_rounded,
                                            label: busyView ? 'Opening PDF…' : 'View PDF invoice',
                                            onPressed: disabled ? null : () => _viewInvoice(p),
                                          ),
                                          const SizedBox(height: 10),
                                          Builder(
                                            builder: (btnContext) {
                                              return OutlinedButton.icon(
                                                onPressed: disabled
                                                    ? null
                                                    : () => _downloadInvoice(
                                                          p,
                                                          _shareOriginFromContext(btnContext),
                                                        ),
                                                icon: busyDl
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : Icon(
                                                        Icons.ios_share_rounded,
                                                        size: 20,
                                                        color: AppTheme.secondaryColor,
                                                      ),
                                                label: Text(
                                                  busyDl ? 'Preparing…' : 'Share receipt',
                                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppTheme.secondaryColor,
                                                  side: BorderSide(
                                                    color: AppTheme.secondaryColor.withValues(alpha: 0.65),
                                                    width: 1.5,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
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
}
