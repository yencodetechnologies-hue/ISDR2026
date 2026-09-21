import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../core/models/family_member_model.dart';
import '../../../../../core/services/api_service.dart';

/// Bottom sheet for residents to report when a child is exiting the premises.
/// Notifies security for better communication and safety.
class ReportKidExitSheet extends StatefulWidget {
  const ReportKidExitSheet({super.key});

  @override
  State<ReportKidExitSheet> createState() => _ReportKidExitSheetState();
}

class _ReportKidExitSheetState extends State<ReportKidExitSheet> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  List<FamilyMemberModel> _children = [];
  bool _loading = true;
  bool _submitting = false;
  FamilyMemberModel? _selectedChild;
  bool _useCustomName = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    setState(() => _loading = true);
    try {
      final response = await _apiService.getFamilyMembers();
      if (mounted && response['success'] == true && response['familyMembers'] != null) {
        final list = (response['familyMembers'] as List)
            .map((e) => FamilyMemberModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final children = list.where((m) => m.relationType == 'child').toList();
        setState(() {
          _children = children;
          _loading = false;
          if (children.isNotEmpty && _selectedChild == null) {
            _selectedChild = children.first;
            _nameController.text = children.first.name;
          }
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the child\'s name';
    }
    
    // Security: Check for valid name format (letters, spaces, hyphens, apostrophes only)
    final nameRegex = RegExp(r"^[a-zA-Z\s\-'\.]+$");
    if (!nameRegex.hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    // Security: Check minimum and maximum length
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must not exceed 50 characters';
    }
    
    return null;
  }

  String? _validateNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Note is optional
    }
    
    // Security: Check maximum length
    if (value.trim().length > 200) {
      return 'Note must not exceed 200 characters';
    }
    
    // Security: Check for potentially harmful content
    final dangerousPatterns = ['<script', 'javascript:', 'onerror=', 'onclick='];
    final lowerValue = value.toLowerCase();
    for (final pattern in dangerousPatterns) {
      if (lowerValue.contains(pattern)) {
        return 'Note contains invalid characters';
      }
    }
    
    return null;
  }

  Future<void> _submit() async {
    // Validate form
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final name = _nameController.text.trim();
    final nameValidation = _validateName(name);
    if (nameValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(nameValidation)),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final note = _noteController.text.trim();
    final noteValidation = _validateNote(note);
    if (noteValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(noteValidation)),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await _apiService.reportKidExit(
        kidName: name,
        familyMemberId: _selectedChild?.id,
        note: note.isEmpty ? null : note,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (response['success'] == true) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    response['message'] as String? ?? 'Security notified. Kid exit reported.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(response['error']?.toString() ?? 'Failed to report'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Something went wrong: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Clean Header
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
                      Icons.child_care_rounded,
                      size: 22,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Kid Exit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Notify security when a child is leaving premises',
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
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                )
              else ...[
                const Text(
                  'Who is exiting?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                if (_children.isNotEmpty) ...[
                  DropdownButtonFormField<FamilyMemberModel?>(
                    value: _useCustomName ? null : _selectedChild,
                    decoration: InputDecoration(
                      hintText: 'Select family member',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      prefixIcon: const Icon(
                        Icons.family_restroom_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    items: [
                      ..._children.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                          )),
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Other (type name below)',
                          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedChild = v;
                        _useCustomName = v == null;
                        if (v != null) {
                          _nameController.text = v.name;
                        } else {
                          _nameController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Child\'s Name',
                    hintText: 'Enter full name',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: _validateName,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Additional Note (Optional)',
                    hintText: 'e.g., Going to school, pickup by 4 PM',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: const Icon(
                      Icons.note_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: _validateNote,
                ),
                const SizedBox(height: 22),
                BrandGradientCtaButton(
                  height: 50,
                  isLoading: _submitting,
                  icon: Icons.send_rounded,
                  label: 'Notify Security',
                  onPressed: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
