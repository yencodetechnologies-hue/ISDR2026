import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/ad_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/admin_bloc.dart';

class AdsTab extends StatefulWidget {
  final AdminLoaded state;
  final String? selectedApartmentId;
  const AdsTab({
    required this.state,
    this.selectedApartmentId,
    super.key,
  });

  @override
  State<AdsTab> createState() => _AdsTabState();
}

class _AdsTabState extends State<AdsTab> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<AdModel> _ads = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAds();
    });
  }

  @override
  void didUpdateWidget(AdsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload ads if apartment selection changed
    if (oldWidget.selectedApartmentId != widget.selectedApartmentId) {
      _loadAds();
    }
  }

  String? _getApartmentId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final userType = authState.user.userType;
      // For apartment users, use their apartmentId
      if (userType == UserType.apartment) {
        return authState.user.apartmentId;
      }
      // For admin users, use selectedApartmentId from dashboard
      if (userType == UserType.admin) {
        final sel = widget.selectedApartmentId;
        if (sel != null && sel.isNotEmpty) return sel;
        if (widget.state.blocks.isNotEmpty) {
          final bApt = widget.state.blocks.first.apartmentId;
          if (bApt != null && bApt.isNotEmpty) return bApt;
        }
      }
      // For regular users, use their apartmentId
      return authState.user.apartmentId;
    }
    final sel = widget.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final apartmentId = _getApartmentId();
      final response = await _apiService.getAds(apartmentId: apartmentId);
      if (response['success'] == true && response['ads'] != null) {
        setState(() {
          _ads = (response['ads'] as List)
              .map((e) => AdModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ads: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addAd() async {
    final apartmentId = _getApartmentId();
    if (apartmentId == null || apartmentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apartment ID is required to create an ad'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final file = File(image.path);
      final response = await _apiService.createAd(
        file,
        apartmentId: apartmentId,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad added successfully')),
          );
          _loadAds();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to add ad'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteAd(AdModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad'),
        content: const Text(
          'Are you sure you want to delete this ad? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.errorElevatedStyle,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final response = await _apiService.deleteAd(ad.id);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad deleted successfully')),
          );
          _loadAds();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to delete ad'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading && _ads.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF13275D)))
          : Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13275D).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFF13275D),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Property Advertisements',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  _ads.isEmpty
                                      ? 'Upload carousel images for residents'
                                      : '${_ads.length} active banner${_ads.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: _isLoading || _isUploading ? null : _loadAds,
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(9),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: Color(0xFF13275D),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_ads.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        BrandGradientCtaButton(
                          label: _isUploading ? 'Uploading Banner...' : 'Add New Ad Banner',
                          icon: Icons.add_photo_alternate_rounded,
                          height: 48,
                          isLoading: _isUploading,
                          onPressed: _isUploading ? null : _addAd,
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _ads.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadAds,
                          color: const Color(0xFF13275D),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            children: [
                              const SizedBox(height: 60),
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13275D).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF13275D).withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    size: 40,
                                    color: Color(0xFF13275D),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Advertisements Yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload promo banners to display announcements or sponsorship ads on the resident app homepage carousel.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF64748B),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: BrandGradientCtaButton(
                                  label: _isUploading ? 'Uploading...' : 'Upload Ad Banner',
                                  icon: Icons.add_photo_alternate_rounded,
                                  height: 50,
                                  isLoading: _isUploading,
                                  onPressed: _isUploading ? null : _addAd,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAds,
                          color: const Color(0xFF13275D),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: _ads.length,
                            itemBuilder: (context, index) {
                              final ad = _ads[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: ad.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF13275D),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          size: 40,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    // Gradient Overlay at bottom for slot index
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          'Banner #${index + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Delete Action Badge
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Material(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        shape: const CircleBorder(),
                                        elevation: 2,
                                        child: InkWell(
                                          onTap: () => _deleteAd(ad),
                                          customBorder: const CircleBorder(),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFFEF4444),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
