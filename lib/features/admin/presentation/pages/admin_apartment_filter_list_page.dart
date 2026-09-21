import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/services/api_service.dart';
import '../widgets/property_list/property_list_widgets.dart';
import 'create_apartment_page.dart';
import 'edit_apartment_page.dart';

/// Page showing all, active-only, or inactive-only apartments/companies/hostels. Opened from overview stat cards.
class AdminApartmentFilterListPage extends StatefulWidget {
  /// null = all, true = active only, false = inactive only.
  final bool? showActive;
  /// null = all property types, otherwise filter by apartment/company/hostel.
  final PropertyType? propertyTypeFilter;

  const AdminApartmentFilterListPage({
    super.key,
    this.showActive,
    this.propertyTypeFilter,
  });

  @override
  State<AdminApartmentFilterListPage> createState() =>
      _AdminApartmentFilterListPageState();
}

class _FilterOption {
  const _FilterOption({this.type, required this.label, required this.icon});

  final PropertyType? type;
  final String label;
  final IconData icon;
}

class _AdminApartmentFilterListPageState
    extends State<AdminApartmentFilterListPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<ApartmentModel> _apartments = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  static const _filterOptions = [
    _FilterOption(type: null, label: 'All', icon: Icons.grid_view_rounded),
    _FilterOption(
      type: PropertyType.apartment,
      label: 'Apartments',
      icon: Icons.apartment_rounded,
    ),
    _FilterOption(
      type: PropertyType.company,
      label: 'Companies',
      icon: Icons.business_rounded,
    ),
    _FilterOption(
      type: PropertyType.hostel,
      label: 'Hostels',
      icon: Icons.hotel_rounded,
    ),
    _FilterOption(
      type: PropertyType.college,
      label: 'Colleges / Schools',
      icon: Icons.school_rounded,
    ),
    _FilterOption(
      type: PropertyType.events,
      label: 'Events Management',
      icon: Icons.event_rounded,
    ),
  ];

  late PropertyType? _propertyTypeFilter;

  bool get _showTypeFilter => widget.propertyTypeFilter == null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _propertyTypeFilter = widget.propertyTypeFilter;
    _loadApartments();
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
        final all = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
        var filtered = all;
        if (widget.showActive != null) {
          filtered = filtered.where((a) => a.isActive == widget.showActive!).toList();
        }
        if (widget.propertyTypeFilter != null) {
          filtered = filtered
              .where((a) => a.propertyType == widget.propertyTypeFilter!)
              .toList();
        }
        _apartments = filtered;
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to load apartments';
      }
    });
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
          content: Text('Property ${newActive ? "activated" : "deactivated"}'),
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

  Future<void> _openEditApartment(ApartmentModel apt) async {
    final updated = await Navigator.push<ApartmentModel>(
      context,
      MaterialPageRoute(
        builder: (context) => EditApartmentPage(apartment: apt),
      ),
    );
    if (!mounted) return;
    if (updated != null) _loadApartments();
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

  String get _typeLabel {
    switch (_propertyTypeFilter ?? widget.propertyTypeFilter) {
      case PropertyType.apartment:
        return 'Apartments';
      case PropertyType.company:
        return 'Companies';
      case PropertyType.hostel:
        return 'Hostels';
      case PropertyType.college:
        return 'Colleges / Schools';
      case PropertyType.events:
        return 'Events Management';
      default:
        return 'Properties';
    }
  }

  String get _pageTitle {
    if (widget.showActive == null && widget.propertyTypeFilter == null) {
      return 'View Properties';
    }
    final type = _typeLabel;
    if (widget.showActive == null) return type;
    return widget.showActive! ? 'Active $type' : 'Inactive $type';
  }

  String get _emptyMessage {
    final type = _typeLabel.toLowerCase();
    if (widget.showActive == null) return 'No $type yet';
    return widget.showActive!
        ? 'No active $type'
        : 'No inactive $type';
  }

  List<ApartmentModel> get _filteredApartments {
    var list = _apartments;
    if (_showTypeFilter && _propertyTypeFilter != null) {
      list = list.where((a) => a.propertyType == _propertyTypeFilter).toList();
    }
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.address.toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildTypeFilterBar() {
    if (!_showTypeFilter) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final selected = _propertyTypeFilter == option.type;
          return FilterChip(
            avatar: Icon(
              option.icon,
              size: 16,
              color: selected ? Colors.white : AppTheme.primaryColor,
            ),
            label: Text(option.label),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textColor,
            ),
            selected: selected,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            selectedColor: AppTheme.primaryColor,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.dividerColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => setState(() => _propertyTypeFilter = option.type),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search by name or address',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildListHeader() {
    final count = _filteredApartments.length;
    return Row(
      children: [
        Text(
          '$count ${count == 1 ? 'property' : 'properties'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor.withOpacity(0.55),
          ),
        ),
        const Spacer(),
        if (widget.showActive != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (widget.showActive!
                      ? AppTheme.secondaryColor
                      : Colors.orange.shade700)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.showActive! ? 'Active only' : 'Inactive only',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.showActive!
                    ? AppTheme.secondaryColor
                    : Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_pageTitle),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadApartments,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showTypeFilter) ...[
                      _buildTypeFilterBar(),
                      const SizedBox(height: 12),
                    ],
                    _buildSearchField(),
                    if (!_loading && _error == null && _apartments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildListHeader(),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadApartments,
                        style: AppTheme.primaryElevatedStyle,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_apartments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else if (_filteredApartments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No results for "$_searchQuery"',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            _emptyMessage,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a property to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
