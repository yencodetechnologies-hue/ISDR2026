import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';

class CreateLeaveRequestSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const CreateLeaveRequestSheet({super.key, required this.onSuccess});

  @override
  State<CreateLeaveRequestSheet> createState() => _CreateLeaveRequestSheetState();
}

class _CreateLeaveRequestSheetState extends State<CreateLeaveRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentMobileController = TextEditingController();
  final ApiService _api = ApiService();

  DateTime? _outAt;
  DateTime? _expectedInAt;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _parentNameController.dispose();
    _parentMobileController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isOut) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isOut ? now : (_outAt ?? now),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isOut ? now : (_expectedInAt ?? now)),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isOut) {
        _outAt = dt;
      } else {
        _expectedInAt = dt;
      }
    });
  }

  String _formatDt(DateTime? dt) {
    if (dt == null) return 'Select date & time';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_outAt == null || _expectedInAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select outing and return times')),
      );
      return;
    }
    if (_expectedInAt!.isBefore(_outAt!) || _expectedInAt!.isAtSameMomentAs(_outAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return time must be after outing start')),
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await _api.createLeaveRequest(
      outAt: _outAt!,
      expectedInAt: _expectedInAt!,
      reason: _reasonController.text,
      parentName: _parentNameController.text,
      parentMobile: _parentMobileController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to submit'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Request out pass',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Warden will approve from management',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textColor.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 16),
                _DateTile(
                  label: 'Going out at',
                  value: _formatDt(_outAt),
                  onTap: () => _pickDateTime(true),
                ),
                const SizedBox(height: 10),
                _DateTile(
                  label: 'Expected return',
                  value: _formatDt(_expectedInAt),
                  onTap: () => _pickDateTime(false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Reason is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parentNameController,
                  decoration: const InputDecoration(
                    labelText: 'Parent / guardian name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parentMobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Parent / guardian mobile *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length != 10) {
                      return 'Enter 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                BrandGradientCtaButton(
                  label: _submitting ? 'Submitting...' : 'Submit request',
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
