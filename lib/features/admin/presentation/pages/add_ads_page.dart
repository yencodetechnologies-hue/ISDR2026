import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../core/services/api_service.dart';

class AddAdsPage extends StatefulWidget {
  const AddAdsPage({super.key});

  @override
  State<AddAdsPage> createState() => _AddAdsPageState();
}

class _AddAdsPageState extends State<AddAdsPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayOrderController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _selectedApartmentId;
  List<ApartmentModel> _apartments = [];
  bool _loadingApartments = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApartments();
  }

  @override
  void dispose() {
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadApartments() async {
    setState(() => _loadingApartments = true);
    final result = await _apiService.getApartments();
    if (!mounted) return;
    setState(() {
      _loadingApartments = false;
      if (result['success'] == true) {
        final list = result['apartments'] as List<dynamic>? ?? [];
        _apartments = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submit() async {
    _error = null;
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImage == null) {
      setState(() => _error = 'Please select an image');
      return;
    }
    
    if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
      setState(() => _error = 'Please select an apartment');
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      final displayOrder = _displayOrderController.text.trim().isEmpty
          ? null
          : int.tryParse(_displayOrderController.text.trim());
      
      final response = await _apiService.createAd(
        _selectedImage!,
        apartmentId: _selectedApartmentId!,
        displayOrder: displayOrder,
      );
      
      if (!mounted) return;
      
      setState(() => _isUploading = false);
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad added successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = response['error'] as String? ?? 'Failed to add ad');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Ad'),
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
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedImage == null
                          ? Colors.grey[400]!
                          : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Apartment Selector
              DropdownButtonFormField<String>(
                value: _selectedApartmentId,
                decoration: const InputDecoration(
                  labelText: 'Apartment *',
                  hintText: 'Select apartment',
                  prefixIcon: Icon(Icons.apartment, color: AppTheme.primaryColor),
                ),
                items: _apartments.map((apt) => DropdownMenuItem<String>(
                      value: apt.id,
                      child: Text(apt.name),
                    )).toList(),
                onChanged: _loadingApartments
                    ? null
                    : (value) {
                        setState(() => _selectedApartmentId = value);
                      },
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Apartment is required';
                  }
                  return null;
                },
              ),
              if (_loadingApartments)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              // Display Order
              TextFormField(
                controller: _displayOrderController,
                decoration: const InputDecoration(
                  labelText: 'Display Order (Optional)',
                  hintText: '0, 1, 2...',
                  prefixIcon: Icon(Icons.sort, color: AppTheme.primaryColor),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final order = int.tryParse(v.trim());
                    if (order == null || order < 0) {
                      return 'Must be a valid positive number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              BrandGradientCtaButton(
                label: 'Upload Ad',
                icon: Icons.cloud_upload_outlined,
                isLoading: _isUploading,
                onPressed: _isUploading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
