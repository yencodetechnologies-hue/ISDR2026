import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/models/subscription_plan_model.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/utils/subscription_checkout.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';

class SubscriptionTab extends StatefulWidget {
  final String? selectedApartmentId;
  final String? apartmentName;

  const SubscriptionTab({
    super.key,
    this.selectedApartmentId,
    this.apartmentName,
  });

  @override
  State<SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<SubscriptionTab> {
  final ApiService _api = ApiService();
  List<SubscriptionPlanModel> _plans = [];
  bool _loadingPlans = true;
  bool _showPlans = false;
  Razorpay? _razorpay;
  String? _pendingOrderId;
  bool _paying = false;
  Map<String, dynamic>? _mySubscription;
  bool _loadingMySubscription = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadMySubscription();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onRazorpaySuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onRazorpayError);
  }

  String? get _apartmentId => widget.selectedApartmentId;

  Future<void> _loadMySubscription() async {
    if (_loadingMySubscription) return;
    setState(() => _loadingMySubscription = true);
    try {
      final Map<String, dynamic> res;
      if (_apartmentId != null && _apartmentId!.isNotEmpty) {
        res = await _api.getSubscriptionByApartment(_apartmentId!);
      } else {
        res = await _api.getMySubscription();
      }
      if (mounted && res['success'] == true) {
        setState(() {
          _mySubscription = res;
          _loadingMySubscription = false;
        });
      } else {
        if (mounted) setState(() => _loadingMySubscription = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMySubscription = false);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    try {
      final res = await _api.getSubscriptionPlans(apartmentId: _apartmentId);
      if (mounted && res['success'] == true && res['plans'] != null) {
        final list = (res['plans'] as List)
            .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _plans = list;
          _loadingPlans = false;
        });
      } else {
        if (mounted) setState(() => _loadingPlans = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _onRazorpaySuccess(PaymentSuccessResponse response) {
    final orderId = _pendingOrderId ?? response.orderId;
    _pendingOrderId = null;
    if (mounted) setState(() => _paying = false);
    if (orderId == null || orderId.isEmpty) return;
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    if (paymentId.isEmpty || signature.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completed but verification data was missing. Contact support.'),
            backgroundColor: Color(0xFFEF4444),
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
        _loadMySubscription();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Verification failed'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    });
  }

  void _onRazorpayError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    if (mounted) setState(() => _paying = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment failed'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _payNow(SubscriptionPlanModel plan) async {
    if (_paying) return;
    if (plan.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid plan selected'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
    setState(() => _paying = true);
    try {
      final orderRes = await _api.createSubscriptionOrder(
        plan.id,
        apartmentId: _apartmentId,
      );
      if (!mounted) return;
      if (orderRes['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderRes['error']?.toString() ?? 'Could not create order'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
      final orderId = orderRes['orderId']?.toString() ?? '';
      final amount = subscriptionAmountPaise(orderRes['amount'], plan.amount);
      final checkoutKey = resolveRazorpayCheckoutKey(orderRes['keyId']?.toString());
      if (orderId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid order returned'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      if (checkoutKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment gateway is not configured. Set ApiConfig / backend RAZORPAY_KEY_ID.',
            ),
            backgroundColor: Color(0xFFEF4444),
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
          SnackBar(
            content: Text('Could not start payment: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted && _pendingOrderId == null) {
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) => prev != curr,
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        final isAdmin = user?.userType == UserType.admin;
        final bool hasSubscription;
        final int daysLeft;
        if (_apartmentId != null && _apartmentId!.isNotEmpty) {
          hasSubscription = _mySubscription != null &&
              (_mySubscription!['subscriptionStatus'] == true);
          daysLeft = _mySubscription != null
              ? (_mySubscription!['daysLeft'] as int? ?? 0)
              : 0;
        } else {
          hasSubscription = isAdmin && (user?.subscriptionStatus == true);
          daysLeft = user?.daysLeft ?? 0;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: RefreshIndicator(
            onRefresh: () async {
              await _loadPlans();
              await _loadMySubscription();
            },
            color: const Color(0xFF13275D),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_apartmentId != null &&
                      _apartmentId!.isNotEmpty &&
                      widget.apartmentName != null &&
                      widget.apartmentName!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 20,
                            color: Color(0xFF13275D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Subscription for ${widget.apartmentName}',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // My Subscription Status Card
                  _buildMySubscriptionCard(context, hasSubscription, daysLeft, user),
                  const SizedBox(height: 18),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: _apartmentId != null && _apartmentId!.isNotEmpty ? 3 : 1,
                        child: Material(
                          elevation: 0,
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF13275D),
                          child: InkWell(
                            onTap: () {
                              setState(() => _showPlans = !_showPlans);
                              if (_showPlans && !_loadingPlans) _loadPlans();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF13275D), Color(0xFF1E3A8A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF13275D).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _showPlans ? Icons.expand_less_rounded : Icons.add_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _showPlans ? 'Hide Plans' : 'Add Subscription',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_apartmentId != null && _apartmentId!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Material(
                            elevation: 0,
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.subscriptionPurchaseHistory,
                                  arguments: {
                                    'apartmentId': _apartmentId,
                                    'apartmentName': widget.apartmentName,
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF0F172A),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Invoices',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Plans List / Toggle View
                  if (_showPlans) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13275D).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFF13275D),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Available Subscription Plans',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_loadingPlans)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF13275D),
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else if (_plans.isEmpty)
                      _buildEmptyPlansMessage(context)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _plans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          return _buildSubscriptionPlanCard(context, plan, index);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMySubscriptionCard(
    BuildContext context,
    bool hasSubscription,
    int daysLeft,
    UserModel? user,
  ) {
    final planName = _mySubscription != null && _mySubscription!['plan'] != null
        ? (_mySubscription!['plan'] as Map<String, dynamic>)['name']?.toString()
        : null;

    if (_loadingMySubscription) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF13275D),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasSubscription
              ? const [Color(0xFF0D9488), Color(0xFF059669)]
              : const [Color(0xFF475569), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (hasSubscription ? const Color(0xFF0D9488) : const Color(0xFF475569))
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background decoration circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        hasSubscription ? Icons.verified_rounded : Icons.shield_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Subscription',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasSubscription
                                ? (planName ?? 'Active Plan')
                                : 'No Active Plan',
                            style: GoogleFonts.outfit(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasSubscription)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '$daysLeft days left',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 14),
                if (hasSubscription) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Valid until ${_formatDate(
                          user?.subscriptionEndsAt ??
                              (_mySubscription != null &&
                                      _mySubscription!['subscriptionEndsAt'] != null
                                  ? DateTime.tryParse(
                                      _mySubscription!['subscriptionEndsAt'].toString())
                                  : null) ??
                              DateTime.now(),
                        )}',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Subscribe to a plan below to activate resident app features, gate security, and notice boards.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlansMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF13275D).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: Color(0xFF13275D),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Subscription Plans Available',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No active plans were returned from the server for this society.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlanCard(
    BuildContext context,
    SubscriptionPlanModel plan,
    int index,
  ) {
    final isPopular = index == 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPopular ? const Color(0xFF13275D) : const Color(0xFFE2E8F0),
          width: isPopular ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFF13275D).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF13275D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                'RECOMMENDED PLAN',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF13275D),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${plan.daysValidity} Days Validity',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${plan.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'incl. taxes',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (plan.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    plan.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                BrandGradientCtaButton(
                  label: 'Pay Now • ₹${plan.amount.toStringAsFixed(0)}',
                  icon: Icons.payment_rounded,
                  height: 48,
                  isLoading: _paying,
                  onPressed: _paying ? null : () => _payNow(plan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
