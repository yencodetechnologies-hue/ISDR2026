import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/complaint_model.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/user_bloc.dart';

class RaiseComplaintDialog extends StatefulWidget {
  final String userId;
  final ComplaintType? initialType;

  const RaiseComplaintDialog({super.key, required this.userId, this.initialType});

  @override
  State<RaiseComplaintDialog> createState() => _RaiseComplaintDialogState();
}

class _RaiseComplaintDialogState extends State<RaiseComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ComplaintType? _selectedType;
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  bool _isUrgent = false;

  static List<(ComplaintType, IconData, String, Color)> get _typeInfo => [
        (ComplaintType.plumbing, Icons.plumbing_rounded, 'Plumbing', AppTheme.primaryColor),
        (ComplaintType.electrical, Icons.electrical_services_rounded, 'Electrical', AppTheme.accentColor),
        (ComplaintType.cleaning, Icons.cleaning_services_rounded, 'Cleaning', AppTheme.secondaryColor),
        (ComplaintType.maintenance, Icons.build_rounded, 'Maintenance', AppTheme.risecolor),
        (ComplaintType.security, Icons.security_rounded, 'Security', AppTheme.errorColor),
        (ComplaintType.other, Icons.more_horiz_rounded, 'Other', AppTheme.textColor.withOpacityCompat(0.72)),
      ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _preferredTime = picked);
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate() && _selectedType != null) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        DateTime? preferredDateTime;
        if (_preferredDate != null && _preferredTime != null) {
          preferredDateTime = DateTime(
            _preferredDate!.year,
            _preferredDate!.month,
            _preferredDate!.day,
            _preferredTime!.hour,
            _preferredTime!.minute,
          );
        } else if (_preferredDate != null) {
          preferredDateTime = DateTime(
            _preferredDate!.year,
            _preferredDate!.month,
            _preferredDate!.day,
            9,
            0,
          );
        }
        context.read<UserBloc>().add(
              RaiseComplaintEvent(
                userId: widget.userId,
                type: _selectedType!,
                description: _descriptionController.text.trim(),
                block: user.block,
                floor: user.floor,
                roomNumber: user.roomNumber,
                preferredRepairDateTime: preferredDateTime,
                isUrgent: _isUrgent,
              ),
            );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isUrgent
                ? 'Urgent complaint submitted. We\'ll attend soon!'
                : 'Complaint raised successfully!'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final authUser = auth is AuthAuthenticated ? auth : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroSection(),
                      const SizedBox(height: 18),
                      if (authUser != null)
                        _buildComplaintTypeSection(authUser)
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 16),
                      _buildDescriptionSection(),
                      const SizedBox(height: 16),
                      _buildPreferredDateTimeSection(),
                      const SizedBox(height: 14),
                      _buildUrgentSection(),
                      const SizedBox(height: 20),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.report_problem_rounded,
                size: 24,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raise a Complaint',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Describe your issue and request assistance',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  bool _securityEnabledForProperty(AuthAuthenticated auth) {
    final apartments = auth.user.apartments;
    if (apartments == null || apartments.isEmpty) return true;
    final selectedId = auth.selectedApartmentId ?? auth.user.apartmentId;
    if (selectedId == null || selectedId.isEmpty) {
      return apartments.first.securityEnabled;
    }
    for (final apt in apartments) {
      if (apt.id == selectedId) return apt.securityEnabled;
    }
    return apartments.first.securityEnabled;
  }

  List<(ComplaintType, IconData, String, Color)> _availableTypes(
    AuthAuthenticated auth,
  ) {
    final securityOn = _securityEnabledForProperty(auth);
    return _typeInfo
        .where((info) => securityOn || info.$1 != ComplaintType.security)
        .toList();
  }

  Widget _buildComplaintTypeSection(AuthAuthenticated auth) {
    final types = _availableTypes(auth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complaint Type *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((info) {
            final type = info.$1;
            final icon = info.$2;
            final label = info.$3;
            final color = info.$4;
            final isSelected = _selectedType == type;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.18)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: isSelected ? color : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? color : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Describe your complaint in detail...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPreferredDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Repair Time (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateTimeChip(
                icon: Icons.calendar_today_rounded,
                label: _preferredDate == null
                    ? 'Choose date'
                    : DateFormat('MMM d, yyyy').format(_preferredDate!),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeChip(
                icon: Icons.access_time_rounded,
                label: _preferredTime == null
                    ? 'Choose time'
                    : _preferredTime!.format(context),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'ll try to schedule maintenance around this time.',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildUrgentSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isUrgent
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isUrgent ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: _isUrgent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isUrgent
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isUrgent ? Icons.priority_high_rounded : Icons.low_priority_rounded,
              size: 18,
              color: _isUrgent ? const Color(0xFFDC2626) : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark as urgent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Critical issue needing immediate attention',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isUrgent,
            onChanged: (v) => setState(() => _isUrgent = v),
            activeColor: const Color(0xFFDC2626),
            activeTrackColor: const Color(0xFFFECACA),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: const Color(0xFF475569),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: BrandGradientCtaButton(
            height: 48,
            icon: Icons.send_rounded,
            label: 'Submit',
            onPressed: _handleSubmit,
          ),
        ),
      ],
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: label.startsWith('Choose') ? FontWeight.w400 : FontWeight.w600,
                    color: label.startsWith('Choose') ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
