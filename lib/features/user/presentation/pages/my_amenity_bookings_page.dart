import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/models/amenity_booking_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/routes/app_routes.dart';

class MyAmenityBookingsPage extends StatefulWidget {
  const MyAmenityBookingsPage({super.key});

  @override
  State<MyAmenityBookingsPage> createState() => _MyAmenityBookingsPageState();
}

class _MyAmenityBookingsPageState extends State<MyAmenityBookingsPage> {
  final ApiService _apiService = ApiService();
  List<AmenityBookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getMyAmenityBookings();
      if (mounted && response['success'] == true) {
        setState(() {
          _bookings = List<AmenityBookingModel>.from(response['bookings'] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(AmenityBookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          'Cancel ${booking.amenityName} on ${booking.date} ${booking.slotStart}–${booking.slotEnd}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.errorElevatedStyle,
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final response = await _apiService.cancelAmenityBooking(booking.id);
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled')),
          );
          _loadBookings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to cancel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Amenity Bookings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No bookings yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Book slots from the Amenities screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 260,
                          height: 52,
                          child: BrandGradientCtaButton(
                            height: 52,
                            icon: Icons.spa_rounded,
                            label: 'Go to Amenities',
                            onPressed: () =>
                                Navigator.pushReplacementNamed(context, AppRoutes.amenities),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final b = _bookings[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            b.amenityName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${b.date} • ${b.slotStart} – ${b.slotEnd}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.amenityBooking,
                                    arguments: {
                                      'amenityId': b.amenityId,
                                      'amenityName': b.amenityName,
                                    },
                                  ).then((_) => _loadBookings());
                                },
                                child: const Text('View'),
                              ),
                              TextButton(
                                onPressed: () => _cancelBooking(b),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
