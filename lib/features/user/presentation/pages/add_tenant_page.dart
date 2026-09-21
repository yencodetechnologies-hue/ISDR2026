import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class AddTenantPage extends StatefulWidget {
  final UserModel currentUser;

  const AddTenantPage({super.key, required this.currentUser});

  @override
  State<AddTenantPage> createState() => _AddTenantPageState();
}

class _AddTenantPageState extends State<AddTenantPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;
  Gender? _gender;
  File? _profilePic;
  File? _idProof;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isProfilePic) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        if (isProfilePic) {
          _profilePic = File(image.path);
        } else {
          _idProof = File(image.path);
        }
      });
    }
  }

  Future<void> _submit() async {
    _error = null;
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      setState(() => _error = 'Please select gender');
      return;
    }

    setState(() => _saving = true);

    final authState = context.read<AuthBloc>().state;
    final selectedApartmentId = authState is AuthAuthenticated
        ? authState.selectedApartmentId
        : null;
    final apartmentId = selectedApartmentId ?? widget.currentUser.apartmentId;

    final result = await _apiService.registerTenant(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      password: _passwordController.text,
      gender: _gender!.name,
      apartmentId: apartmentId,
      block: widget.currentUser.block,
      floor: widget.currentUser.floor,
      roomNumber: widget.currentUser.roomNumber,
      profilePic: _profilePic,
      idProof: _idProof,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant created successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['error'] as String? ?? 'Failed to create tenant');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tenant'),
      ),
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
              Center(
                child: GestureDetector(
                  onTap: () => _showImageSourceSheet(true),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _profilePic != null
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      color: Colors.grey.shade100,
                    ),
                    child: _profilePic != null
                        ? ClipOval(
                            child: Image.file(_profilePic!, fit: BoxFit.cover),
                          )
                        : Icon(
                            Icons.person_add,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tenant Image',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name *',
                  prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  prefixIcon: Icon(Icons.phone, color: AppTheme.primaryColor),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                  if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Gender *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<Gender>(
                      title: const Text('Male'),
                      value: Gender.male,
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<Gender>(
                      title: const Text('Female'),
                      value: Gender.female,
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showImageSourceSheet(false),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _idProof != null
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: _idProof != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _idProof!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(Icons.check_circle,
                                  color: AppTheme.primaryColor, size: 24),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to upload Tenant ID Proof',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tenant ID Proof',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              BrandGradientCtaButton(
                height: 52,
                isLoading: _saving,
                icon: Icons.person_add_rounded,
                label: 'Create Tenant',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet(bool isProfilePic) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isProfilePic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isProfilePic);
              },
            ),
          ],
        ),
      ),
    );
  }
}
