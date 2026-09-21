import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/amenity_model.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/api_service.dart';

class AmenitiesPage extends StatefulWidget {
  const AmenitiesPage({super.key});

  @override
  State<AmenitiesPage> createState() => _AmenitiesPageState();
}

class _AmenitiesPageState extends State<AmenitiesPage> {
  final ApiService _apiService = ApiService();
  List<AmenityModel> _amenities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  Future<void> _loadAmenities() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAmenities(activeOnly: true);
      if (mounted && response['success'] == true && response['amenities'] != null) {
        setState(() {
          _amenities = (response['amenities'] as List)
              .map((e) => AmenityModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getAmenityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pool') || lower.contains('swim')) return Icons.pool_rounded;
    if (lower.contains('gym') || lower.contains('fitness') || lower.contains('workout')) return Icons.fitness_center_rounded;
    if (lower.contains('tennis') || lower.contains('badminton') || lower.contains('court') || lower.contains('sport')) return Icons.sports_tennis_rounded;
    if (lower.contains('hall') || lower.contains('club') || lower.contains('party') || lower.contains('community')) return Icons.meeting_room_rounded;
    if (lower.contains('park') || lower.contains('garden')) return Icons.nature_people_rounded;
    if (lower.contains('game') || lower.contains('billiard') || lower.contains('tt')) return Icons.sports_esports_rounded;
    return Icons.spa_rounded;
  }

  Color _getAmenityColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pool') || lower.contains('swim')) return const Color(0xFF0284C7);
    if (lower.contains('gym') || lower.contains('fitness')) return const Color(0xFF7C3AED);
    if (lower.contains('tennis') || lower.contains('sport')) return const Color(0xFF16A34A);
    if (lower.contains('hall') || lower.contains('club')) return const Color(0xFFD97706);
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Amenities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAmenities,
          ),
          IconButton(
            icon: const Icon(Icons.event_note_rounded),
            tooltip: 'My Bookings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.myAmenityBookings),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadAmenities,
              color: AppTheme.primaryColor,
              child: _amenities.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEEF2FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.spa_outlined,
                                        size: 32,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No Amenities Available',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Amenities registered by your society or association will appear here.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: _amenities.length,
                      itemBuilder: (context, index) {
                        final amenity = _amenities[index];
                        final bookable = amenity.isBookable;
                        final color = _getAmenityColor(amenity.name);
                        final icon = _getAmenityIcon(amenity.name);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: bookable
                                  ? () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.amenityBooking,
                                        arguments: {
                                          'amenityId': amenity.id,
                                          'amenityName': amenity.name,
                                        },
                                      );
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 32,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      amenity.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: bookable
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bookable ? 'Tap to book' : 'Informational',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: bookable
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
