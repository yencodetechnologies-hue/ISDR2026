import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/services/api_service.dart';

class EditApartmentPage extends StatefulWidget {
  const EditApartmentPage({
    super.key,
    required this.apartment,
  });

  final ApartmentModel apartment;

  @override
  State<EditApartmentPage> createState() => _EditApartmentPageState();
}

class _EditApartmentPageState extends State<EditApartmentPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _ownerMobileController;
  late final TextEditingController _wardenNameController;
  late final TextEditingController _wardenContactController;
  late final TextEditingController _emailController;
  late final TextEditingController _bedCountController;

  bool _saving = false;
  String? _error;

  late PropertyType _propertyType;
  late String _hostelType;
  String _roomType = 'single';

  @override
  void initState() {
    super.initState();
    final a = widget.apartment;
    _propertyType = a.propertyType;
    _hostelType = (a.hostelType != null && a.hostelType!.trim().isNotEmpty)
        ? a.hostelType!.trim()
        : 'co-living';
    _roomType = (a.roomType != null && a.roomType!.trim().isNotEmpty)
        ? a.roomType!.trim()
        : 'single';

    _nameController = TextEditingController(text: a.name);
    _addressController = TextEditingController(text: a.address);
    _contactPhoneController = TextEditingController(text: a.contactPhone);
    _ownerNameController = TextEditingController(text: a.ownerName);
    _ownerMobileController = TextEditingController(text: a.contactPhone);
    _wardenNameController = TextEditingController(text: a.wardenName);
    _wardenContactController = TextEditingController(text: a.wardenContact);
    _emailController = TextEditingController(text: a.email);
    _bedCountController = TextEditingController(
      text: a.bedCountPerRoom == null ? '' : a.bedCountPerRoom.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _ownerNameController.dispose();
    _ownerMobileController.dispose();
    _wardenNameController.dispose();
    _wardenContactController.dispose();
    _emailController.dispose();
    _bedCountController.dispose();
    super.dispose();
  }

  String get _pageTitle {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Edit Apartment';
      case PropertyType.company:
        return 'Edit Company';
      case PropertyType.hostel:
        return 'Edit Hostel';
      case PropertyType.college:
        return 'Edit College / School';
      case PropertyType.events:
        return 'Edit Events Management';
    }
  }

  String get _nameLabel {
    switch (_propertyType) {
      case PropertyType.apartment:
        return 'Apartment name *';
      case PropertyType.company:
        return 'Company name *';
      case PropertyType.hostel:
        return 'Hostel name *';
      case PropertyType.college:
        return 'College or school name *';
      case PropertyType.events:
        return 'Event organizer name *';
    }
  }

  bool get _isHostel => _propertyType == PropertyType.hostel;

  String? _validatePhone10(String? v, {required String emptyMsg}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return emptyMsg;
    if (s.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^\d{10}$').hasMatch(s)) return 'Enter digits only';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email ID is required';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  int? _parseBedCountOrNull() {
    final raw = _bedCountController.text.trim();
    if (raw.isEmpty) return null;
    final val = int.tryParse(raw);
    return val;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _contactPhoneController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final ownerMobile = _ownerMobileController.text.trim();
    final wardenName = _wardenNameController.text.trim();
    final wardenContact = _wardenContactController.text.trim();
    final email = _emailController.text.trim();
    final bedCount = _parseBedCountOrNull();

    setState(() => _saving = true);

    final effectiveContactPhone = _isHostel ? ownerMobile : phone;

    final result = await _apiService.updateApartment(
      id: widget.apartment.id,
      name: name,
      address: address,
      contactPhone: effectiveContactPhone,
      propertyType: _propertyType.name,
      hostelType: _isHostel ? _hostelType : null,
      roomType: _isHostel ? _roomType : null,
      bedCountPerRoom: _isHostel ? bedCount : null,
      ownerName: _isHostel ? ownerName : null,
      ownerMobile: _isHostel ? ownerMobile : null,
      wardenName: _isHostel ? wardenName : '',
      wardenContact: _isHostel ? wardenContact : '',
      email: _isHostel ? email : '',
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      final aptMap = result['apartment'] as Map<String, dynamic>?;
      final updated = aptMap != null ? ApartmentModel.fromJson(aptMap) : null;
      Navigator.pop(context, updated ?? widget.apartment);
      return;
    }

    setState(() => _error = result['error'] as String? ?? 'Failed to update property');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ],
              const Text(
                'Property Type *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PropertyType>(
                    value: _propertyType,
                    isExpanded: true,
                    items: PropertyType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _propertyType = v);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _nameLabel,
                  prefixIcon: Icon(
                    _propertyType == PropertyType.company ? Icons.business : Icons.apartment,
                    color: AppTheme.primaryColor,
                  ),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              if (_isHostel) ...[
                const SizedBox(height: 16),
                const Text(
                  'Hostel Type *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _hostelType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'co-living', child: Text('Co-living')),
                        DropdownMenuItem(value: 'girls_hostel', child: Text('Girls hostel')),
                        DropdownMenuItem(value: 'boys_hostel', child: Text('Boys hostel')),
                        DropdownMenuItem(value: 'others', child: Text('Others')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _hostelType = v);
                            },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: _isHostel ? 'Hostel address *' : 'Address',
                  hintText: 'Full address',
                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (_isHostel && (v == null || v.trim().isEmpty)) {
                    return 'Hostel address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (!_isHostel)
                TextFormField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number *',
                    hintText: '10-digit number',
                    prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => _validatePhone10(v, emptyMsg: 'Mobile number is required'),
                ),
              if (_isHostel) ...[
                const Text(
                  'Owner account (management login)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ownerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Owner name *',
                    hintText: 'Full name of hostel owner',
                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Owner name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ownerMobileController,
                  decoration: const InputDecoration(
                    labelText: 'Owner mobile (login) *',
                    hintText: '10-digit number',
                    prefixIcon: Icon(Icons.phone_android, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => _validatePhone10(v, emptyMsg: 'Owner mobile number is required'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Warden details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Warden can sign in via Management login with warden mobile and the property password.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _wardenNameController,
                  decoration: const InputDecoration(
                    labelText: 'Warden name *',
                    hintText: 'Full name of warden',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Warden name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _wardenContactController,
                  decoration: const InputDecoration(
                    labelText: 'Warden mobile number *',
                    hintText: '10-digit number',
                    prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => _validatePhone10(v, emptyMsg: 'Warden mobile number is required'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email ID *',
                    hintText: 'e.g. hostel@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Room Type (optional)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roomType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'single', child: Text('Single')),
                        DropdownMenuItem(value: 'double', child: Text('Double')),
                        DropdownMenuItem(value: 'dorm', child: Text('Dorm')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _roomType = v);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bedCountController,
                  decoration: const InputDecoration(
                    labelText: 'Bed count per room (optional)',
                    hintText: 'e.g. 4',
                    prefixIcon: Icon(Icons.bed_outlined, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return null;
                    final parsed = int.tryParse(raw);
                    if (parsed == null) return 'Enter a number';
                    if (parsed <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: AppTheme.primaryElevatedStyle.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

