import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/amenity_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/admin_bloc.dart';
import '../widgets/add_amenity_sheet.dart';

class AmenitiesTab extends StatefulWidget {
  final AdminLoaded state;
  const AmenitiesTab({required this.state, super.key});

  @override
  State<AmenitiesTab> createState() => _AmenitiesTabState();
}

class _AmenitiesTabState extends State<AmenitiesTab> {
  final ApiService _apiService = ApiService();
  List<AmenityModel> _amenities = [];
  bool _isLoading = false;
  String _searchQuery = '';

  String? get _apartmentId {
    final sel = widget.state.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  @override
  void didUpdateWidget(covariant AmenitiesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedApartmentId != widget.state.selectedApartmentId) {
      _loadAmenities();
    }
  }

  Future<void> _loadAmenities() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAmenities(
        apartmentId: _apartmentId,
      );
      if (response['success'] == true && response['amenities'] != null) {
        setState(() {
          _amenities = (response['amenities'] as List)
              .map((e) => AmenityModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading amenities: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleEnabled(AmenityModel amenity, bool value) async {
    try {
      final response = await _apiService.updateAmenity(amenity.id, isEnabled: value);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? '${amenity.name} is now visible to residents' : '${amenity.name} is now hidden'),
              backgroundColor: const Color(0xFF13275D),
            ),
          );
          _loadAmenities();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to update'),
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

  Future<void> _showAddOrEditAmenityDialog({AmenityModel? existing}) async {
    final result = await AddAmenitySheet.show(context, existing: existing);
    if (result == null || !mounted) return;

    final isEdit = existing != null;
    setState(() => _isLoading = true);
    try {
      final response = isEdit
          ? await _apiService.updateAmenity(
              existing!.id,
              name: result['name'],
              openingTime: result['openingTime'],
              closingTime: result['closingTime'],
              slotDurationMinutes: result['slotDurationMinutes'],
              capacityPerSlot: result['capacityPerSlot'],
            )
          : await _apiService.createAmenity(
              result['name'],
              apartmentId: _apartmentId,
              openingTime: result['openingTime'],
              closingTime: result['closingTime'],
              slotDurationMinutes: result['slotDurationMinutes'],
              capacityPerSlot: result['capacityPerSlot'],
            );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    isEdit ? 'Amenity updated successfully' : 'Amenity added successfully')),
          );
          _loadAmenities();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? (isEdit ? 'Failed to update' : 'Failed to add amenity')),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAmenity() async {
    await _showAddOrEditAmenityDialog();
  }

  Future<void> _editAmenity(AmenityModel amenity) async {
    await _showAddOrEditAmenityDialog(existing: amenity);
  }

  Future<void> _deleteAmenity(AmenityModel amenity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Amenity',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${amenity.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final response = await _apiService.deleteAmenity(amenity.id);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Amenity deleted successfully')),
          );
          _loadAmenities();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to delete'),
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

  List<AmenityModel> get _filteredAmenities {
    if (_searchQuery.trim().isEmpty) return _amenities;
    return _amenities.where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isWarden = authState is AuthAuthenticated && authState.user.loginRole == 'warden';

    final totalCount = _amenities.length;
    final activeCount = _amenities.where((a) => a.isEnabled).length;
    final hiddenCount = totalCount - activeCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amenities',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF13275D),
                            ),
                          ),
                          Text(
                            'Configure property facilities & resident access',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isWarden) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: BrandGradientCtaButton(
                          height: 42,
                          icon: Icons.add_rounded,
                          label: 'Add Amenity',
                          onPressed: _addAmenity,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_amenities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Overview Stats Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF13275D),
                          Color(0xFF1E3A8A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF13275D).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricItem(
                          label: 'Total Amenities',
                          value: '$totalCount',
                          icon: Icons.pool_rounded,
                          color: Colors.white,
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _buildMetricItem(
                          label: 'Visible to Users',
                          value: '$activeCount',
                          icon: Icons.visibility_rounded,
                          color: const Color(0xFF4ADE80),
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _buildMetricItem(
                          label: 'Hidden',
                          value: '$hiddenCount',
                          icon: Icons.visibility_off_rounded,
                          color: const Color(0xFFFBBF24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search Bar
                  SizedBox(
                    height: 42,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search amenities by name...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF13275D)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Main list content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF13275D),
                    ),
                  )
                : _filteredAmenities.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadAmenities,
                        color: const Color(0xFF13275D),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.55,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13275D).withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.spa_outlined,
                                    size: 56,
                                    color: Color(0xFF13275D),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _amenities.isEmpty
                                      ? 'No amenities configured'
                                      : 'No matching amenities found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _amenities.isEmpty
                                      ? 'Add clubhouse, swimming pool, gym, or sports courts to allow resident slot bookings.'
                                      : 'Try searching with a different name.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAmenities,
                        color: const Color(0xFF13275D),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAmenities.length,
                          itemBuilder: (context, index) {
                            final amenity = _filteredAmenities[index];
                            final hasSchedule = amenity.openingTime != null &&
                                amenity.openingTime!.isNotEmpty &&
                                amenity.closingTime != null &&
                                amenity.closingTime!.isNotEmpty;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: amenity.isEnabled
                                      ? const Color(0xFF13275D).withValues(alpha: 0.12)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: amenity.isEnabled
                                                ? const Color(0xFF13275D).withValues(alpha: 0.08)
                                                : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getAmenityIcon(amenity.name),
                                            color: amenity.isEnabled
                                                ? const Color(0xFF13275D)
                                                : Colors.grey.shade400,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                amenity.name,
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: amenity.isEnabled
                                                      ? const Color(0xFF0F172A)
                                                      : Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: amenity.isEnabled
                                                          ? const Color(0xFF22C55E)
                                                          : Colors.grey.shade400,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    amenity.isEnabled ? 'Visible to residents' : 'Hidden from residents',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: amenity.isEnabled
                                                          ? const Color(0xFF15803D)
                                                          : Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isWarden)
                                          Transform.scale(
                                            scale: 0.85,
                                            child: Switch(
                                              value: amenity.isEnabled,
                                              onChanged: (value) => _toggleEnabled(amenity, value),
                                              activeColor: const Color(0xFF13275D),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (hasSchedule) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Divider(height: 1),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${amenity.openingTime} – ${amenity.closingTime}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (amenity.capacityPerSlot != null) ...[
                                            Icon(Icons.groups_rounded, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Max ${amenity.capacityPerSlot} per slot',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    if (!isWarden) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () => _editAmenity(amenity),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF13275D)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Edit',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF13275D),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          InkWell(
                                            onTap: () => _deleteAmenity(amenity),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Delete',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.red.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
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

  IconData _getAmenityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pool') || lower.contains('swim')) return Icons.pool_rounded;
    if (lower.contains('gym') || lower.contains('fitness')) return Icons.fitness_center_rounded;
    if (lower.contains('park') || lower.contains('garden')) return Icons.park_rounded;
    if (lower.contains('club') || lower.contains('hall')) return Icons.meeting_room_rounded;
    if (lower.contains('court') || lower.contains('tennis') || lower.contains('badminton')) return Icons.sports_tennis_rounded;
    return Icons.spa_rounded;
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
