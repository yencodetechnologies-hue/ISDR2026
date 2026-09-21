import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/visitor_model.dart';
import '../../../../../../core/models/visitor_type_config.dart';
import '../../../../../../core/widgets/visitor_subtype_picker_sheet.dart';
import '../../bloc/user_bloc.dart';
import '../visitor_details_page.dart';

import '../../../../../../core/services/api_service.dart';

/// Icons for visitor type grid; order matches [VisitorType.values].
const List<IconData> _visitorTypeIcons = [
  Icons.person_outline,
  Icons.delivery_dining,
  Icons.local_taxi,
  Icons.local_fire_department,
  Icons.shopping_basket_outlined,
  Icons.carpenter_outlined,
  Icons.face_retouching_natural,
  Icons.handyman_outlined,
  Icons.pest_control_outlined,
  Icons.menu_book_outlined,
  Icons.storefront_outlined,
  Icons.more_horiz,
];

class AddVisitorSheet extends StatefulWidget {
  final String userId;
  final ScrollController? scrollController;
  final bool isSelfPass;
  final String? initialName;
  final String? initialMobile;
  final String? initialBlock;
  final String? initialRoom;
  final VisitorCategory? initialCategory;
  final RelativeType? initialRelativeType;
  final VisitorType? initialType;
  final String? initialReason;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;

  const AddVisitorSheet({
    super.key,
    required this.userId,
    this.scrollController,
    this.isSelfPass = false,
    this.initialName,
    this.initialMobile,
    this.initialBlock,
    this.initialRoom,
    this.initialCategory,
    this.initialRelativeType,
    this.initialType,
    this.initialReason,
    this.initialDate,
    this.initialTime,
  });

  @override
  State<AddVisitorSheet> createState() => _AddVisitorSheetState();
}

class _AddVisitorSheetState extends State<AddVisitorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _blockController;
  late final TextEditingController _roomController;
  late final TextEditingController _reasonController;

  File? _visitorImage;
  VisitorCategory? _selectedCategory;
  RelativeType? _selectedRelativeType;
  VisitorType? _selectedType;
  String? _selectedTypeDetail;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<Map<String, dynamic>> _blocksList = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _mobileController = TextEditingController(text: widget.initialMobile ?? '');
    _blockController = TextEditingController(text: widget.initialBlock ?? '');
    _roomController = TextEditingController(text: widget.initialRoom ?? '');
    _reasonController = TextEditingController(text: widget.initialReason ?? '');
    _selectedCategory = widget.initialCategory ?? VisitorCategory.outsider;
    _selectedRelativeType = widget.initialRelativeType;
    _selectedType = widget.initialType ?? VisitorType.guest;
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
    _fetchBlocks();
  }

  Future<void> _fetchBlocks() async {
    try {
      final res = await ApiService().getBlocks();
      if (mounted && res['success'] == true && res['blocks'] != null) {
        final list = List<Map<String, dynamic>>.from(res['blocks']);
        setState(() {
          _blocksList = list;
        });
      }
    } catch (_) {}
  }

  List<String> _getAvailableRoomsForBlock(String? blockName) {
    if (blockName == null || blockName.trim().isEmpty || _blocksList.isEmpty) return [];
    final match = _blocksList.firstWhere(
      (b) => (b['name'] ?? b['block'] ?? '').toString().trim().toLowerCase() == blockName.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty || match['floors'] is! List) return [];
    final result = <String>[];
    for (final fl in (match['floors'] as List)) {
      if (fl['rooms'] is List) {
        for (final r in (fl['rooms'] as List)) {
          final numStr = r['number']?.toString() ?? r['roomNumber']?.toString();
          if (numStr != null && numStr.isNotEmpty && !result.contains(numStr)) {
            result.add(numStr);
          }
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _blockController.dispose();
    _roomController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _visitorImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textColor,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textColor,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _onOutsiderTypeTapped(VisitorType type) async {
    final wasSelected = _selectedType == type;
    if (wasSelected) {
      setState(() {
        _selectedType = null;
        _selectedTypeDetail = null;
      });
      return;
    }
    if (visitorTypeRequiresSubtype(type)) {
      final picked = await VisitorSubtypePickerSheet.show(context, type);
      if (!mounted || picked == null) return;
      setState(() {
        _selectedType = type;
        _selectedTypeDetail = picked;
      });
    } else {
      setState(() {
        _selectedType = type;
        _selectedTypeDetail = null;
      });
    }
  }

  Future<void> _handleAdd() async {
    if (_formKey.currentState!.validate() &&
        _selectedCategory != null &&
        _selectedDate != null &&
        _selectedTime != null) {
      if (_selectedCategory == VisitorCategory.relative &&
          _selectedRelativeType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select relative type')),
        );
        return;
      }


      final visitDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final navigator = Navigator.of(context);
      context.read<UserBloc>().add(
            AddVisitorEvent(
              userId: widget.userId,
              name: _nameController.text.trim(),
              mobileNumber: _mobileController.text.trim(),
              category: _selectedCategory!,
              relativeType: _selectedRelativeType,
              type: _selectedType,
              typeDetail: _selectedTypeDetail?.trim().isNotEmpty == true ? _selectedTypeDetail!.trim() : null,
              block: _blockController.text.trim().isNotEmpty ? _blockController.text.trim() : null,
              homeNumber: _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
              reasonForVisit: _reasonController.text.trim(),
              visitDateTime: visitDateTime,
              image: _visitorImage,
            ),
          );

      navigator.pop();

      await Future.delayed(const Duration(milliseconds: 300));

      final state = context.read<UserBloc>().state;
      if (state is UserLoaded && state.visitors.isNotEmpty) {
        // Backend returns newest first, so the just-added visitor is first
        final latestVisitor = state.visitors.first;
        if (mounted) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) =>
                  VisitorDetailsPage(visitor: latestVisitor),
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionLabel(String text) {
    return _buildFieldLabel(text);
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildDateTimeChip({
    required IconData icon,
    required String label,
    String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    final isSelected = value != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.5)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? hint,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTypeLabel(RelativeType type) {
    final name = type.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isSelfPass ? 'Pre-Register Guest Pass' : 'Add Visitor',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: widget.isSelfPass
                    ? _buildWebStyleForm()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    _buildFieldLabel('Visitor details', isRequired: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                          'Enter 10-digit mobile', Icons.phone_android),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter mobile number';
                        }
                        if (value.length != 10) {
                          return 'Please enter valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          _inputDecoration('Enter full name', Icons.person_outline),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _blockController,
                            decoration: _inputDecoration('Select Block', Icons.apartment),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter block';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _roomController,
                            decoration: _inputDecoration('Select Room / Flat', Icons.home),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter room/flat';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('Photo (optional)'),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.25),
                                AppTheme.primaryColor.withOpacity(0.12),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(0.08),
                            ),
                            child: _visitorImage != null
                                ? ClipOval(
                                    child: Image.file(
                                      _visitorImage!,
                                      fit: BoxFit.cover,
                                      width: 102,
                                      height: 102,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        color: AppTheme.primaryColor,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to add photo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textColor
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Who is visiting?'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CategoryCard(
                            icon: Icons.family_restroom,
                            label: 'Relative',
                            selected:
                                _selectedCategory == VisitorCategory.relative,
                            onTap: () {
                              setState(() {
                                _selectedCategory = VisitorCategory.relative;
                                _selectedRelativeType = null;
                                _selectedType = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CategoryCard(
                            icon: Icons.person_outline,
                            label: 'Outsider',
                            selected:
                                _selectedCategory == VisitorCategory.outsider,
                            onTap: () {
                              setState(() {
                                _selectedCategory =
                                    VisitorCategory.outsider;
                                _selectedRelativeType = null;
                                _selectedType = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCategory == VisitorCategory.relative) ...[
                      const SizedBox(height: 16),
                      _buildSectionLabel('Relative type'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            RelativeType.values.map((RelativeType type) {
                          final selected = _selectedRelativeType == type;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRelativeType =
                                    selected ? null : type;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: selected
                                    ? AppTheme.primaryColor
                                        .withOpacity(0.15)
                                    : AppTheme.dividerColor.withOpacity(0.5),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : AppTheme.dividerColor,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                _relativeTypeLabel(type),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textColor.withOpacity(0.85),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _buildSectionLabel('Reason for visit'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: _inputDecoration(
                          'Reason for Visit *', Icons.edit_note),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter reason for visit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Visit schedule'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimeChip(
                            icon: Icons.calendar_month_rounded,
                            label: 'Date',
                            value: _selectedDate != null
                                ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                                : null,
                            hint: 'Select date',
                            onTap: _selectDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTimeChip(
                            icon: Icons.schedule_rounded,
                            label: 'Time',
                            value: _selectedTime != null
                                ? DateFormat('hh:mm a').format(DateTime(2000, 1, 1, _selectedTime!.hour, _selectedTime!.minute))
                                : null,
                            hint: 'Select time',
                            onTap: _selectTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BrandGradientCtaButton(
                      icon: Icons.person_add_rounded,
                      label: 'Add Visitor',
                      onPressed: _handleAdd,
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebStyleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fill in visitor details to grant express entry approval at the security gate.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Visitor Full Name', isRequired: true),
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration('Enter full name', Icons.person_outline),
          validator: (v) => (v == null || v.isEmpty) ? 'Please enter full name' : null,
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Mobile Number', isRequired: true),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Enter 10-digit mobile', Icons.phone_android),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter mobile number';
            if (v.length != 10) return 'Please enter valid 10-digit mobile number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Category'),
                  DropdownButtonFormField<VisitorCategory>(
                    value: _selectedCategory ?? VisitorCategory.outsider,
                    isExpanded: true,
                    decoration: _inputDecoration('Select category', Icons.category_outlined),
                    items: const [
                      DropdownMenuItem(
                        value: VisitorCategory.outsider,
                        child: Text('Outsider / Delivery / Cab', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorCategory.relative,
                        child: Text('Relative / Family', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Block / Building', isRequired: true),
                  _buildBlockDropdown(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Room / Class / Flat', isRequired: true),
                  _buildRoomDropdown(),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Visitor Type'),
                  DropdownButtonFormField<VisitorType>(
                    value: _selectedType ?? VisitorType.guest,
                    isExpanded: true,
                    decoration: _inputDecoration('Select type', Icons.badge_outlined),
                    items: const [
                      DropdownMenuItem(
                        value: VisitorType.guest,
                        child: Text('Parent / Guest', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.courierDelivery,
                        child: Text('Courier / Delivery', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.cabDriver,
                        child: Text('Cab / Auto', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.gasDelivery,
                        child: Text('Gas Delivery', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.groceryShop,
                        child: Text('Grocery Shop', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.otherVendors,
                        child: Text('Other Vendors', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: VisitorType.other,
                        child: Text('Other', style: TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Expected Visit Time', isRequired: true),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeChip(
                icon: Icons.calendar_month_rounded,
                label: 'Date',
                value: _selectedDate != null
                    ? DateFormat('dd-MM-yyyy').format(_selectedDate!)
                    : null,
                hint: 'Select date',
                onTap: _selectDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateTimeChip(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: _selectedTime != null
                    ? DateFormat('HH:mm').format(DateTime(2000, 1, 1, _selectedTime!.hour, _selectedTime!.minute))
                    : null,
                hint: 'Select time',
                onTap: _selectTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Reason for Visit', isRequired: true),
        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          decoration: _inputDecoration(
              'Personal visit, package delivery, repair service...', Icons.edit_note),
          validator: (v) => (v == null || v.isEmpty) ? 'Please enter reason for visit' : null,
        ),
        const SizedBox(height: 24),
        BrandGradientCtaButton(
          icon: Icons.send_rounded,
          label: 'Submit & Create Pass',
          onPressed: _handleAdd,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
      ],
    );
  }

  Widget _buildBlockDropdown() {
    final blockOptions = <String>[];
    for (final b in _blocksList) {
      final name = (b['name'] ?? b['block'] ?? '').toString().trim();
      if (name.isNotEmpty && !blockOptions.contains(name)) {
        blockOptions.add(name);
      }
    }
    final currentBlock = _blockController.text.trim();
    if (currentBlock.isNotEmpty && !blockOptions.contains(currentBlock)) {
      blockOptions.insert(0, currentBlock);
    }

    if (blockOptions.isEmpty) {
      return TextFormField(
        controller: _blockController,
        decoration: _inputDecoration('Select Block', Icons.apartment),
        validator: (v) => (v == null || v.isEmpty) ? 'Enter block' : null,
      );
    }

    final selectedValue = blockOptions.contains(currentBlock) ? currentBlock : blockOptions.first;
    if (_blockController.text != selectedValue) {
      _blockController.text = selectedValue;
    }

    return DropdownButtonFormField<String>(
      value: selectedValue,
      isExpanded: true,
      decoration: _inputDecoration('Select Block', Icons.apartment),
      items: blockOptions
          .map((b) => DropdownMenuItem<String>(
                value: b,
                child: Text(b, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _blockController.text = val;
            final availableRooms = _getAvailableRoomsForBlock(val);
            if (availableRooms.isNotEmpty) {
              _roomController.text = availableRooms.first;
            }
          });
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Select block' : null,
    );
  }

  Widget _buildRoomDropdown() {
    final currentBlock = _blockController.text.trim();
    final availableRooms = _getAvailableRoomsForBlock(currentBlock);
    final currentRoom = _roomController.text.trim();
    if (currentRoom.isNotEmpty && !availableRooms.contains(currentRoom)) {
      availableRooms.insert(0, currentRoom);
    }

    if (availableRooms.isEmpty) {
      return TextFormField(
        controller: _roomController,
        decoration: _inputDecoration('e.g. Class 10A / Room 101', Icons.home),
        validator: (v) => (v == null || v.isEmpty) ? 'Enter room/flat' : null,
      );
    }

    final selectedValue = availableRooms.contains(currentRoom) ? currentRoom : availableRooms.first;
    if (_roomController.text != selectedValue) {
      _roomController.text = selectedValue;
    }

    return DropdownButtonFormField<String>(
      value: selectedValue,
      isExpanded: true,
      decoration: _inputDecoration('Select Room / Flat', Icons.home),
      items: availableRooms
          .map((r) => DropdownMenuItem<String>(
                value: r,
                child: Text(r, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _roomController.text = val;
          });
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Select room/flat' : null,
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : const Color(0xFFF8FAFC),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppTheme.primaryColor
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryColor
                      : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorTypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisitorTypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : const Color(0xFFF8FAFC),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.primaryColor
                    : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryColor
                      : const Color(0xFF334155),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
