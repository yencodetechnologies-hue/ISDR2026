import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/widgets/brand_gradient_extended_fab.dart';
import '../../../../core/models/monthly_visitor_pass_model.dart';
import '../../../../core/models/visitor_model.dart';
import '../bloc/user_bloc.dart';

class MonthlyAccessPage extends StatefulWidget {
  const MonthlyAccessPage({super.key});

  @override
  State<MonthlyAccessPage> createState() => _MonthlyAccessPageState();
}

class _MonthlyAccessPageState extends State<MonthlyAccessPage> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _reasonController = TextEditingController();

  VisitorType _selectedVisitorType = VisitorType.guest;

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadMyMonthlyVisitorPassesEvent());
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _mobileController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  int _remainingDays(MonthlyVisitorPassModel pass) {
    final diff = pass.validTo.difference(DateTime.now());
    return diff.inDays;
  }

  static InputDecoration _sheetFieldDecoration({
    required String labelText,
    required IconData icon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppTheme.dividerColor.withOpacity(0.9)),
    );
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryColor.withOpacity(0.85)),
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }

  void _showAddPassSheet() {
    _personNameController.clear();
    _mobileController.clear();
    _reasonController.clear();
    _selectedVisitorType = VisitorType.guest;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Monthly Access',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Register once, then toggle approval monthly and share OTP at the gate.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(sheetCtx),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visitor type',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor.withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<VisitorType>(
                              value: _selectedVisitorType,
                              decoration: _sheetFieldDecoration(
                                labelText: 'Select type',
                                icon: Icons.category_rounded,
                              ),
                              items: VisitorType.values.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() => _selectedVisitorType = v ?? VisitorType.guest);
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Person details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor.withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _personNameController,
                              decoration: _sheetFieldDecoration(
                                labelText: 'Full name',
                                icon: Icons.person_rounded,
                              ),
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                final txt = (v ?? '').trim();
                                if (txt.isEmpty) return 'Enter person name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _mobileController,
                              decoration: _sheetFieldDecoration(
                                labelText: 'Mobile (10 digits)',
                                icon: Icons.phone_rounded,
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                if (digits.length != 10) return 'Enter valid 10-digit number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Note (optional)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor.withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reasonController,
                              decoration: _sheetFieldDecoration(
                                labelText: 'Reason or note',
                                icon: Icons.note_rounded,
                              ),
                              textInputAction: TextInputAction.done,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 22),
                            BrandGradientCtaButton(
                              height: 50,
                              icon: Icons.verified_user_rounded,
                              label: 'Add & enable',
                              onPressed: () {
                                if (!_formKey.currentState!.validate()) return;

                                final digits = _mobileController.text.replaceAll(RegExp(r'\D'), '');

                                context.read<UserBloc>().add(
                                      CreateMonthlyVisitorPassEvent(
                                        visitorType: _selectedVisitorType,
                                        personName: _personNameController.text.trim(),
                                        mobileNumber: digits,
                                        reasonForPass: _reasonController.text.trim().isEmpty
                                            ? null
                                            : _reasonController.text.trim(),
                                      ),
                                    );

                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Monthly access added/activated'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
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
    );
  }

  void _shareOtp(MonthlyVisitorPassModel pass) {
    final otp = pass.otp;
    if (otp == null || otp.isEmpty) return;
    final validTo = _formatDate(pass.validTo);
    Share.share(
      'Monthly access OTP for ${pass.personName}: $otp\nValid until: $validTo',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: buildBrandGradientAppBar(
        title: const Text('Monthly Access'),
      ),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is! UserLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final passes = state.monthlyVisitorPasses;

          if (passes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.brandSoftSurfaceGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 52,
                            color: AppTheme.primaryColor.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'No monthly passes yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add help or a regular visitor once, then keep approval ON/OFF updated each month.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textColor.withOpacity(0.62),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: BrandGradientCtaButton(
                        height: 52,
                        icon: Icons.add_rounded,
                        label: 'Add your first pass',
                        onPressed: _showAddPassSheet,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<UserBloc>().add(LoadMyMonthlyVisitorPassesEvent());
            },
            color: AppTheme.primaryColor,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: passes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final pass = passes[index];
                final isExpiringSoon = _remainingDays(pass) <= 3;

                return _MonthlyPassCard(
                  pass: pass,
                  isExpiringSoon: isExpiringSoon,
                  onToggle: (v) {
                    context.read<UserBloc>().add(
                          ToggleMonthlyVisitorPassEvent(passId: pass.id, enabled: v),
                        );
                  },
                  onShareOtp: () => _shareOtp(pass),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: BrandGradientExtendedFab(
        onPressed: _showAddPassSheet,
        icon: Icons.add_rounded,
        label: 'Add',
      ),
    );
  }
}

String _initialFromName(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return t[0].toUpperCase();
}

class _MonthlyPassCard extends StatelessWidget {
  final MonthlyVisitorPassModel pass;
  final bool isExpiringSoon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onShareOtp;

  const _MonthlyPassCard({
    required this.pass,
    required this.isExpiringSoon,
    required this.onToggle,
    required this.onShareOtp,
  });

  @override
  Widget build(BuildContext context) {
    final otpVisible = pass.enabledByMe && pass.otp != null && pass.otp!.isNotEmpty;
    final validToText = DateFormat('dd MMM yyyy').format(pass.validTo);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpiringSoon ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isExpiringSoon ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _initialFromName(pass.personName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pass.personName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pass.visitorType.displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pass.mobileNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: pass.enabledByMe,
                        onChanged: onToggle,
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFFD1FAE5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: pass.isInside ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: pass.isInside ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        pass.isInside ? '• Inside' : '• Outside',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pass.isInside ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    _miniBadge(
                      label: 'Entries: ${pass.attendanceSummary.totalEntries}',
                      color: const Color(0xFF475569),
                    ),
                    _miniBadge(
                      label: 'Exits: ${pass.attendanceSummary.totalExits}',
                      color: const Color(0xFF475569),
                    ),
                    if (isExpiringSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Renew soon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: pass.effectiveEnabled ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pass.effectiveEnabled ? 'ACCESS ON' : 'ACCESS OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: pass.effectiveEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Valid until $validToText',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (pass.reasonForPass != null && pass.reasonForPass!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Text(
                      'Note: ${pass.reasonForPass}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (!otpVisible) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Text(
                pass.effectiveEnabled && !pass.enabledByMe
                    ? 'Enabled by another account. OTP is hidden.'
                    : 'Turn ON to view and share OTP.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GATE OTP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        pass.otp!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: onShareOtp,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text(
                        'Share OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

