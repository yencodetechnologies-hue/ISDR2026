import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/ad_model.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/services/api_service.dart';

class ViewAdsPage extends StatefulWidget {
  const ViewAdsPage({super.key});

  @override
  State<ViewAdsPage> createState() => _ViewAdsPageState();
}

class _ViewAdsPageState extends State<ViewAdsPage> {
  final ApiService _apiService = ApiService();
  List<AdModel> _ads = [];
  List<ApartmentModel> _apartments = [];
  bool _isLoading = false;
  bool _loadingApartments = true;
  String? _selectedApartmentId;

  @override
  void initState() {
    super.initState();
    _loadApartments();
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
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAds(apartmentId: _selectedApartmentId);
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
            const SnackBar(
              content: Text('Ad deleted successfully'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          _loadAds();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to delete ad'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String? _getApartmentName(String? apartmentId) {
    if (apartmentId == null) return null;
    try {
      final apt = _apartments.firstWhere((a) => a.id == apartmentId);
      return apt.name;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Ads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAds,
          ),
        ],
      ),
      body: Column(
        children: [
          // Apartment Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DropdownButtonFormField<String>(
              value: _selectedApartmentId,
              decoration: const InputDecoration(
                labelText: 'Filter by Apartment',
                prefixIcon: Icon(Icons.apartment),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Apartments'),
                ),
                ..._apartments.map((apt) => DropdownMenuItem<String>(
                      value: apt.id,
                      child: Text(apt.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedApartmentId = value);
                _loadAds();
              },
            ),
          ),
          // Ads Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ads found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _ads.length,
                        itemBuilder: (context, index) {
                          final ad = _ads[index];
                          final apartmentName = _getApartmentName(ad.apartmentId);
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: ad.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    size: 48,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.7),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (apartmentName != null)
                                          Text(
                                            apartmentName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: ad.isActive
                                                    ? AppTheme.secondaryColor
                                                    : Colors.grey,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                ad.isActive ? 'Active' : 'Inactive',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () => _deleteAd(ad),
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 20,
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
        ],
      ),
    );
  }
}
