import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/amenity_model.dart';

class AddAmenitySheet extends StatefulWidget {
  final AmenityModel? existing;

  const AddAmenitySheet({super.key, this.existing});

  /// Shows the add/edit amenity bottom sheet. Returns a map with keys:
  /// name, openingTime, closingTime, slotDurationMinutes, capacityPerSlot
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    AmenityModel? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddAmenitySheet(existing: existing),
      ),
    );
  }

  @override
  State<AddAmenitySheet> createState() => _AddAmenitySheetState();
}

class _AddAmenitySheetState extends State<AddAmenitySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingController;
  late final TextEditingController _closingController;
  late final TextEditingController _durationController;
  late final TextEditingController _capacityController;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _openingController = TextEditingController(text: e?.openingTime ?? '06:00 AM');
    _closingController = TextEditingController(text: e?.closingTime ?? '10:00 PM');
    _durationController = TextEditingController(
      text: (e?.slotDurationMinutes ?? 60).toString(),
    );
    _capacityController = TextEditingController(
      text: (e?.capacityPerSlot ?? 1).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    _closingController.dispose();
    _durationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF13275D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      final formatted = picked.format(context);
      controller.text = formatted;
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final opening = _openingController.text.trim();
    final closing = _closingController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 60;
    final capacity =
        (int.tryParse(_capacityController.text.trim()) ?? 1).clamp(1, 999);

    Navigator.pop(context, {
      'name': name,
      'openingTime': opening.isEmpty ? null : opening,
      'closingTime': closing.isEmpty ? null : closing,
      'slotDurationMinutes': duration,
      'capacityPerSlot': capacity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header with Navy Branding
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13275D).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: Color(0xFF13275D),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit Amenity' : 'Add New Amenity',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF13275D),
                        ),
                      ),
                      Text(
                        'Set operating hours and booking slot limits',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Form Content
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _buildSectionHeader('GENERAL INFO'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Amenity Name',
                    hint: 'e.g. Swimming Pool, Gym, Tennis Court',
                    icon: Icons.label_important_rounded,
                    isRequired: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Amenity name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('TIMINGS & OPERATING HOURS'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerField(
                          controller: _openingController,
                          label: 'Opening Time',
                          icon: Icons.wb_sunny_rounded,
                          onTap: () => _selectTime(_openingController),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePickerField(
                          controller: _closingController,
                          label: 'Closing Time',
                          icon: Icons.nights_stay_rounded,
                          onTap: () => _selectTime(_closingController),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('SLOT BOOKING CONFIGURATION'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _durationController,
                          label: 'Slot Duration (Mins)',
                          hint: '60',
                          icon: Icons.timer_rounded,
                          keyboardType: TextInputType.number,
                          isRequired: false,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final parsed = int.tryParse(value.trim());
                              if (parsed == null || parsed < 1) {
                                return 'Enter valid minutes';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _capacityController,
                          label: 'Max Capacity / Slot',
                          hint: '10',
                          icon: Icons.groups_rounded,
                          keyboardType: TextInputType.number,
                          isRequired: false,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final parsed = int.tryParse(value.trim());
                              if (parsed == null || parsed < 1 || parsed > 999) {
                                return 'Enter valid number';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
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
                          icon: _isEdit ? Icons.check_circle_rounded : Icons.add_circle_rounded,
                          label: _isEdit ? 'Save Changes' : 'Add Amenity',
                          onPressed: _handleSubmit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ));
}

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildTimePickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: IgnorePointer(
            child: TextFormField(
              controller: controller,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF13275D),
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 18, color: const Color(0xFF13275D)),
                suffixIcon: const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF13275D)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
