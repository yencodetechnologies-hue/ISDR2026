import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/navigation/app_navigation.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../pages/admin_dashboard_page.dart';
import 'admin_apartment_filter_list_page.dart';
import 'create_apartment_page.dart';
import 'edit_apartment_page.dart';
import '../widgets/property_list/property_list_widgets.dart';

/// Shown after admin login. List of apartments; tap one to open dashboard scoped to that apartment.
class AdminApartmentListPage extends StatefulWidget {
  const AdminApartmentListPage({super.key});

  @override
  State<AdminApartmentListPage> createState() => _AdminApartmentListPageState();
}

class _AdminApartmentListPageState extends State<AdminApartmentListPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<ApartmentModel> _apartments = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApartments();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PropertyType? _propertyTypeFilter;

  List<ApartmentModel> get _filteredApartments {
    var list = _apartments;
    if (_propertyTypeFilter != null) {
      list = list.where((a) => a.propertyType == _propertyTypeFilter).toList();
    }
    if (_searchQuery.isEmpty) return list;
    return list.where((a) {
      return a.name.toLowerCase().contains(_searchQuery) ||
          a.address.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _toggleApartmentActive(ApartmentModel apt) async {
    final newActive = !apt.isActive;
    final result = await _apiService.updateApartment(
      id: apt.id,
      isActive: newActive,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      _loadApartments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apartment ${newActive ? "activated" : "deactivated"}'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Failed to update'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _toggleFeature(
    ApartmentModel apt, {
    bool? securityEnabled,
    bool? assignPaymentEnabled,
    bool? complaintsEnabled,
    bool? blockCreationEnabled,
  }) async {
    final result = await _apiService.updateApartment(
      id: apt.id,
      securityEnabled: securityEnabled,
      assignPaymentEnabled: assignPaymentEnabled,
      complaintsEnabled: complaintsEnabled,
      blockCreationEnabled: blockCreationEnabled,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      _loadApartments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feature updated'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Failed to update'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _loadApartments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _apiService.getApartments();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final list = result['apartments'] as List<dynamic>? ?? [];
        _apartments = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to load apartments';
      }
    });
  }

  void _openCreateApartment() async {
    final created = await Navigator.push<ApartmentModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateApartmentPage(),
      ),
    );
    if (!mounted) return;
    if (created != null) {
      _loadApartments();
      _openDashboard(created);
    }
  }

  void _openDashboard(ApartmentModel apartment) {
    Navigator.pushNamed(
      context,
      AppRoutes.adminDashboard,
      arguments: {
        'selectedApartmentId': apartment.id,
        'apartment': apartment,
      },
    );
  }

  void _navigateToFilteredList(bool? showActive, {PropertyType? propertyType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminApartmentFilterListPage(
          showActive: showActive,
          propertyTypeFilter: propertyType,
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PropertyStatsOverviewContent(
            apartments: _apartments,
            loading: _loading,
            onFilterTap: (showActive, propertyType) =>
                _navigateToFilteredList(showActive, propertyType: propertyType),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionsGrid(),
          const SizedBox(height: 24),
          const Text(
            'Property List',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildListTypeChip('All', Icons.grid_view_rounded, null),
                const SizedBox(width: 8),
                _buildListTypeChip('Apartments', Icons.apartment_rounded, PropertyType.apartment),
                const SizedBox(width: 8),
                _buildListTypeChip('Companies', Icons.business_rounded, PropertyType.company),
                const SizedBox(width: 8),
                _buildListTypeChip('Hostels', Icons.hotel_rounded, PropertyType.hostel),
                const SizedBox(width: 8),
                _buildListTypeChip('Colleges', Icons.school_rounded, PropertyType.college),
                const SizedBox(width: 8),
                _buildListTypeChip('Events', Icons.event_rounded, PropertyType.events),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or address...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditApartment(ApartmentModel apt) async {
    final updated = await Navigator.push<ApartmentModel>(
      context,
      MaterialPageRoute(
        builder: (context) => EditApartmentPage(apartment: apt),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      _loadApartments();
    }
  }

  Future<void> _deleteApartment(ApartmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text(
          'Are you sure you want to delete the property? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    final result = await _apiService.deleteApartment(apt.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _loadApartments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Property deleted successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Failed to delete property'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildListTypeChip(String label, IconData icon, PropertyType? type) {
    final selected = _propertyTypeFilter == type;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.textColor,
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _propertyTypeFilter = type),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildQuickActionCard(
          'Create Property',
          Icons.add_home_work,
          AppTheme.primaryColor,
          () => _openCreateApartment(),
        ),
        _buildQuickActionCard(
          'View Property',
          Icons.list_alt,
          AppTheme.secondaryColor,
          () => _navigateToFilteredList(null),
        ),
        _buildQuickActionCard(
          'Add Subscription Plans',
          Icons.add_card,
          Colors.purple,
          () => Navigator.pushNamed(context, AppRoutes.createSubscriptionPlan),
        ),
        _buildQuickActionCard(
          'View Subscription Plans',
          Icons.card_membership,
          Colors.blue,
          () => Navigator.pushNamed(context, AppRoutes.subscriptionPlansList),
        ),
        _buildQuickActionCard(
          'View Ads',
          Icons.campaign,
          AppTheme.primaryColor,
          () => Navigator.pushNamed(context, AppRoutes.viewAds),
        ),
        _buildQuickActionCard(
          'Add Ads',
          Icons.add_photo_alternate_outlined,
          AppTheme.secondaryColor,
          () => Navigator.pushNamed(context, AppRoutes.addAds),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'logout') {
                LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                  context.read<AuthBloc>().add(LogoutEvent());
                  AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadApartments();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildOverviewSection()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadApartments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_apartments.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No apartments yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first apartment to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredApartments.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No apartments match your search',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _searchController.clear(),
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final apt = _filteredApartments[index];
                      return PropertyCard(
                        apartment: apt,
                        onTap: () => _openDashboard(apt),
                        onEdit: () => _openEditApartment(apt),
                        onDelete: () => _deleteApartment(apt),
                        onSetActive: () => _toggleApartmentActive(apt),
                        onSetInactive: () => _toggleApartmentActive(apt),
                        onSecurityChanged: (v) =>
                            _toggleFeature(apt, securityEnabled: v),
                        onAssignPayChanged: (v) =>
                            _toggleFeature(apt, assignPaymentEnabled: v),
                        onComplaintsChanged: (v) =>
                            _toggleFeature(apt, complaintsEnabled: v),
                        onBlockCreationChanged: (v) =>
                            _toggleFeature(apt, blockCreationEnabled: v),
                      );
                    },
                    childCount: _filteredApartments.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateApartment,
        icon: const Icon(Icons.add),
        label: const Text('Create Property'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
