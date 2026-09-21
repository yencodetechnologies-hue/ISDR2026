import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/models/subscription_plan_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/subscription_checkout.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Full-screen subscribe experience when the apartment has no active subscription.
class ApartmentSubscriptionWallPage extends StatefulWidget {
  final String apartmentId;
  final String? apartmentName;
  final VoidCallback onUnlocked;

  const ApartmentSubscriptionWallPage({
    super.key,
    required this.apartmentId,
    this.apartmentName,
    required this.onUnlocked,
  });

  @override
  State<ApartmentSubscriptionWallPage> createState() => _ApartmentSubscriptionWallPageState();
}

class _ApartmentSubscriptionWallPageState extends State<ApartmentSubscriptionWallPage> {
  final ApiService _api = ApiService();
  List<SubscriptionPlanModel> _plans = [];
  bool _loadingPlans = true;
  Razorpay? _razorpay;
  String? _pendingOrderId;
  bool _paying = false;
  String? _payingPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final res = await _api.getSubscriptionPlans(apartmentId: widget.apartmentId);
      if (!mounted) return;
      if (res['success'] == true && res['plans'] != null) {
        final list = (res['plans'] as List)
            .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _plans = list;
          _loadingPlans = false;
        });
      } else {
        setState(() => _loadingPlans = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    final orderId = _pendingOrderId ?? response.orderId;
    _pendingOrderId = null;
    if (mounted) setState(() {
      _paying = false;
      _payingPlanId = null;
    });
    if (orderId == null || orderId.isEmpty) return;
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    if (paymentId.isEmpty || signature.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completed but verification data was missing. Contact support.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }
    _api
        .verifySubscription(
          orderId: orderId,
          razorpayPaymentId: paymentId,
          signature: signature,
        )
        .then((res) {
      if (!mounted) return;
      if (res['success'] == true) {
        context.read<AuthBloc>().add(CheckAuthStatusEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated. Welcome!'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        widget.onUnlocked();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Verification failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    });
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    if (mounted) setState(() {
      _paying = false;
      _payingPlanId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment failed'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _payNow(SubscriptionPlanModel plan) async {
    if (_paying) return;
    if (plan.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid plan'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }
    setState(() {
      _paying = true;
      _payingPlanId = plan.id;
    });
    try {
      final orderRes = await _api.createSubscriptionOrder(
        plan.id,
        apartmentId: widget.apartmentId,
      );
      if (!mounted) return;
      if (orderRes['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderRes['error']?.toString() ?? 'Could not create order'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      final orderId = orderRes['orderId']?.toString() ?? '';
      final amount = subscriptionAmountPaise(orderRes['amount'], plan.amount);
      final checkoutKey = resolveRazorpayCheckoutKey(orderRes['keyId']?.toString());
      if (orderId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid order'), backgroundColor: AppTheme.errorColor),
        );
        return;
      }
      if (checkoutKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment gateway is not configured. Set ApiConfig / backend RAZORPAY_KEY_ID.',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      _pendingOrderId = orderId;
      _razorpay?.open(
        buildRazorpayCheckoutOptions(
          keyId: checkoutKey,
          amountPaise: amount,
          orderId: orderId,
          planName: plan.name,
        ),
      );
    } catch (e) {
      _pendingOrderId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start payment: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted && _pendingOrderId == null) {
        setState(() {
          _paying = false;
          _payingPlanId = null;
        });
      }
    }
  }

  Color _parseColor(String hex) {
    var s = hex.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v != null ? Color(v) : AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.apartmentName ?? 'This property';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.textColor,
            AppTheme.primaryColor.withOpacityCompat(0.92),
            AppTheme.primaryColor,
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentColor,
          onRefresh: _loadPlans,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.accentColor.withOpacityCompat(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PREMIUM ACCESS',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    letterSpacing: 0.22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentColor.withOpacityCompat(0.95),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Activate subscription',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 32,
                                    height: 1.05,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.backgroundColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '$name does not have an active subscription. Choose a plan below to unlock the full dashboard, billing, visitors, and more.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Colors.white.withOpacity(0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadingPlans)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.accentColor)),
                )
              else if (_plans.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No plans available. Please try again later.',
                      style: GoogleFonts.dmSans(color: Colors.white70),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final plan = _plans[index];
                        final accent = _parseColor(plan.color ?? '#667eea');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _paying ? null : () => _payNow(plan),
                              borderRadius: BorderRadius.circular(18),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white,
                                      AppTheme.backgroundColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor,
                                              AppTheme.secondaryColor,
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.name,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹${plan.amount.toStringAsFixed(0)} · ${plan.daysValidity} days',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 14,
                                                color: AppTheme.textColor.withOpacityCompat(0.65),
                                              ),
                                            ),
                                            if (plan.description.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                plan.description,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 12,
                                                  color: AppTheme.textColor.withOpacityCompat(0.55),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primaryColor,
                                              AppTheme.secondaryColor,
                                            ],
                                          ),
                                        ),
                                        child: _paying && _payingPlanId == plan.id
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                'Pay',
                                                style: GoogleFonts.dmSans(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _plans.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
