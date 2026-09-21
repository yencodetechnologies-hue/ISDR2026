import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/user_property_document_model.dart';
import '../services/api_service.dart';
import 'brand_gradient_cta_button.dart';
import 'identity_document_card.dart';

/// Loads property document requirements and renders upload cards for residents.
class PropertyDocumentsSection extends StatefulWidget {
  final String? apartmentId;

  const PropertyDocumentsSection({
    super.key,
    this.apartmentId,
  });

  @override
  State<PropertyDocumentsSection> createState() =>
      _PropertyDocumentsSectionState();
}

class _PropertyDocumentsSectionState extends State<PropertyDocumentsSection> {
  final ApiService _apiService = ApiService();
  List<UserPropertyDocumentItemModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void didUpdateWidget(PropertyDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apartmentId != widget.apartmentId) {
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    final apartmentId = widget.apartmentId;
    if (apartmentId == null || apartmentId.isEmpty) {
      setState(() {
        _isLoading = false;
        _documents = [];
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getMyPropertyDocuments(
        apartmentId: apartmentId,
      );
      if (response['success'] == true && mounted) {
        setState(() {
          _documents = (response['documents'] as List? ?? [])
              .map(
                (e) => UserPropertyDocumentItemModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_documents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder_copy_outlined,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Property Documents',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final doc in _documents) ...[
          PropertyDocumentUploadCard(
            item: doc,
            onUploaded: _loadDocuments,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class PropertyDocumentUploadCard extends StatefulWidget {
  final UserPropertyDocumentItemModel item;
  final VoidCallback? onUploaded;

  const PropertyDocumentUploadCard({
    super.key,
    required this.item,
    this.onUploaded,
  });

  @override
  State<PropertyDocumentUploadCard> createState() =>
      _PropertyDocumentUploadCardState();
}

class _PropertyDocumentUploadCardState extends State<PropertyDocumentUploadCard> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  UserPropertyDocumentItemModel get item => widget.item;

  bool get _uploaded => item.isUploaded;
  Color get _accent =>
      item.isPdf ? AppTheme.secondaryColor : AppTheme.primaryColor;

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
    }
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;

    File? file;
    if (item.isImage) {
      file = await _pickImageFile();
    } else {
      file = await _pickPdfFile();
    }

    if (file == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final response = await _apiService.uploadPropertyDocument(
        requirementId: item.requirementId,
        file: file,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
          widget.onUploaded?.call();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Upload failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<File?> _pickImageFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose image source',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    final xFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return null;
    return File(xFile.path);
  }

  Future<File?> _pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withAlpha(45),
            _accent.withAlpha(15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withAlpha(22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_outlined,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.requirementName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.isPdf ? 'PDF required' : 'Image required',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textColor.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _uploaded
                        ? AppTheme.secondaryColor.withAlpha(25)
                        : AppTheme.accentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _uploaded ? 'Uploaded' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _uploaded
                          ? AppTheme.secondaryColor
                          : AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            if (_uploaded) ...[
              const SizedBox(height: 12),
              if (item.isImage)
                GestureDetector(
                  onTap: () => showIdentityDocumentFullscreen(
                    context,
                    label: item.requirementName,
                    imageUrl: item.submission!.fileUrl,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item.submission!.fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Material(
                  color: AppTheme.primaryColor.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _openUrl(item.submission!.fileUrl),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: _accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.submission!.fileName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: _accent.withAlpha(180),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            BrandGradientCtaButton(
              label: _isUploading
                  ? 'Uploading...'
                  : (_uploaded ? 'Replace' : 'Upload'),
              icon: _uploaded
                  ? Icons.sync_rounded
                  : Icons.cloud_upload_outlined,
              height: 44,
              isLoading: _isUploading,
              onPressed: _isUploading ? null : _pickAndUpload,
            ),
          ],
        ),
      ),
    );
  }
}
