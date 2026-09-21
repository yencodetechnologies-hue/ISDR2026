import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../pages/admin_apartment_filter_list_page.dart';

class PropertyTypeStyle {
  const PropertyTypeStyle({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  static PropertyTypeStyle forType(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return const PropertyTypeStyle(
          icon: Icons.apartment_rounded,
          color: AppTheme.primaryColor,
          label: 'Apartment',
        );
      case PropertyType.company:
        return const PropertyTypeStyle(
          icon: Icons.business_rounded,
          color: Color(0xFF2563EB),
          label: 'Company',
        );
      case PropertyType.hostel:
        return const PropertyTypeStyle(
          icon: Icons.hotel_rounded,
          color: Color(0xFFEA580C),
          label: 'Hostel',
        );
      case PropertyType.college:
        return const PropertyTypeStyle(
          icon: Icons.school_rounded,
          color: Color(0xFF0F766E),
          label: 'College / School',
        );
      case PropertyType.events:
        return const PropertyTypeStyle(
          icon: Icons.event_rounded,
          color: Color(0xFF7C3AED),
          label: 'Events Management',
        );
    }
  }
}

class PropertyStatsRow extends StatefulWidget {
  const PropertyStatsRow({
    super.key,
    required this.propertyLabel,
    required this.headerIcon,
    required this.accentColor,
    required this.propertyType,
    required this.total,
    required this.active,
    required this.inactive,
    required this.loading,
    required this.onFilterTap,
  });

  final String propertyLabel;
  final IconData headerIcon;
  final Color accentColor;
  final PropertyType propertyType;
  final int total;
  final int active;
  final int inactive;
  final bool loading;
  final void Function(bool? showActive, PropertyType propertyType) onFilterTap;

  @override
  State<PropertyStatsRow> createState() => _PropertyStatsRowState();
}

class _PropertyStatsRowState extends State<PropertyStatsRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    Widget inlinePill({
      required String label,
      required int value,
      required Color color,
      required Color bgColor,
      required VoidCallback? onTap,
    }) {
      final display = widget.loading ? '-' : value.toString();
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                display,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget expandedStatCard({
      required String label,
      required int value,
      required Color color,
      required Color bgColor,
      required VoidCallback? onTap,
    }) {
      final display = widget.loading ? '-' : value.toString();
      final content = Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );

      return Expanded(
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: content,
              ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded
              ? widget.accentColor.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.headerIcon, size: 16, color: widget.accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.propertyLabel,
                        style: TextStyle(
                          fontSize: _isExpanded ? 15 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isExpanded) ...[
                      inlinePill(
                        label: 'tot',
                        value: widget.total,
                        color: widget.accentColor,
                        bgColor: widget.accentColor.withValues(alpha: 0.08),
                        onTap: widget.loading ? null : () => widget.onFilterTap(null, widget.propertyType),
                      ),
                      const SizedBox(width: 4),
                      inlinePill(
                        label: 'act',
                        value: widget.active,
                        color: const Color(0xFF059669),
                        bgColor: const Color(0xFFECFDF5),
                        onTap: widget.loading ? null : () => widget.onFilterTap(true, widget.propertyType),
                      ),
                      const SizedBox(width: 4),
                      inlinePill(
                        label: 'off',
                        value: widget.inactive,
                        color: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFF7ED),
                        onTap: widget.loading ? null : () => widget.onFilterTap(false, widget.propertyType),
                      ),
                    ],
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textColor.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // Smoothly Animated Expanded Body
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        expandedStatCard(
                          label: 'Total',
                          value: widget.total,
                          color: widget.accentColor,
                          bgColor: widget.accentColor.withValues(alpha: 0.08),
                          onTap: widget.loading ? null : () => widget.onFilterTap(null, widget.propertyType),
                        ),
                        const SizedBox(width: 8),
                        expandedStatCard(
                          label: 'Active',
                          value: widget.active,
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFECFDF5),
                          onTap: widget.loading ? null : () => widget.onFilterTap(true, widget.propertyType),
                        ),
                        const SizedBox(width: 8),
                        expandedStatCard(
                          label: 'Inactive',
                          value: widget.inactive,
                          color: const Color(0xFFEA580C),
                          bgColor: const Color(0xFFFFF7ED),
                          onTap: widget.loading ? null : () => widget.onFilterTap(false, widget.propertyType),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                  sizeCurve: Curves.easeInOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PropertyStatsOverviewContent extends StatelessWidget {
  const PropertyStatsOverviewContent({
    super.key,
    required this.apartments,
    required this.loading,
    required this.onFilterTap,
    this.showTitle = true,
  });

  final List<ApartmentModel> apartments;
  final bool loading;
  final void Function(bool? showActive, PropertyType propertyType) onFilterTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final apartmentList =
        apartments.where((a) => a.propertyType == PropertyType.apartment).toList();
    final companies =
        apartments.where((a) => a.propertyType == PropertyType.company).toList();
    final hostels =
        apartments.where((a) => a.propertyType == PropertyType.hostel).toList();
    final colleges =
        apartments.where((a) => a.propertyType == PropertyType.college).toList();
    final events =
        apartments.where((a) => a.propertyType == PropertyType.events).toList();

    final totalApts = apartmentList.length;
    final activeApts = apartmentList.where((a) => a.isActive).length;
    final inactiveApts = totalApts - activeApts;

    final totalCompanies = companies.length;
    final activeCompanies = companies.where((a) => a.isActive).length;
    final inactiveCompanies = totalCompanies - activeCompanies;

    final totalHostels = hostels.length;
    final activeHostels = hostels.where((a) => a.isActive).length;
    final inactiveHostels = totalHostels - activeHostels;

    final totalColleges = colleges.length;
    final activeColleges = colleges.where((a) => a.isActive).length;
    final inactiveColleges = totalColleges - activeColleges;

    final totalEvents = events.length;
    final activeEvents = events.where((a) => a.isActive).length;
    final inactiveEvents = totalEvents - activeEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
        ],
        PropertyStatsRow(
          propertyLabel: 'Apartments',
          headerIcon: Icons.apartment,
          accentColor: AppTheme.primaryColor,
          propertyType: PropertyType.apartment,
          total: totalApts,
          active: activeApts,
          inactive: inactiveApts,
          loading: loading,
          onFilterTap: onFilterTap,
        ),
        const SizedBox(height: 8),
        PropertyStatsRow(
          propertyLabel: 'Companies',
          headerIcon: Icons.business,
          accentColor: Colors.blue,
          propertyType: PropertyType.company,
          total: totalCompanies,
          active: activeCompanies,
          inactive: inactiveCompanies,
          loading: loading,
          onFilterTap: onFilterTap,
        ),
        const SizedBox(height: 8),
        PropertyStatsRow(
          propertyLabel: 'Hostels',
          headerIcon: Icons.hotel,
          accentColor: Colors.orange,
          propertyType: PropertyType.hostel,
          total: totalHostels,
          active: activeHostels,
          inactive: inactiveHostels,
          loading: loading,
          onFilterTap: onFilterTap,
        ),
        const SizedBox(height: 8),
        PropertyStatsRow(
          propertyLabel: 'Colleges / Schools',
          headerIcon: Icons.school,
          accentColor: const Color(0xFF0F766E),
          propertyType: PropertyType.college,
          total: totalColleges,
          active: activeColleges,
          inactive: inactiveColleges,
          loading: loading,
          onFilterTap: onFilterTap,
        ),
        const SizedBox(height: 8),
        PropertyStatsRow(
          propertyLabel: 'Events Management',
          headerIcon: Icons.event,
          accentColor: const Color(0xFF7C3AED),
          propertyType: PropertyType.events,
          total: totalEvents,
          active: activeEvents,
          inactive: inactiveEvents,
          loading: loading,
          onFilterTap: onFilterTap,
        ),
      ],
    );
  }
}

class PropertyStatsOverviewSection extends StatefulWidget {
  const PropertyStatsOverviewSection({super.key});

  @override
  State<PropertyStatsOverviewSection> createState() =>
      _PropertyStatsOverviewSectionState();
}

class _PropertyStatsOverviewSectionState extends State<PropertyStatsOverviewSection> {
  final ApiService _apiService = ApiService();
  List<ApartmentModel> _apartments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApartments();
  }

  Future<void> _loadApartments() async {
    setState(() => _loading = true);
    final result = await _apiService.getApartments();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final list = result['apartments'] as List<dynamic>? ?? [];
        _apartments = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  void _navigateToFilteredList(bool? showActive, PropertyType propertyType) {
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

  @override
  Widget build(BuildContext context) {
    return PropertyStatsOverviewContent(
      apartments: _apartments,
      loading: _loading,
      onFilterTap: _navigateToFilteredList,
    );
  }
}

class PropertyFeatureToggleGrid extends StatefulWidget {
  const PropertyFeatureToggleGrid({
    super.key,
    required this.apartment,
    required this.onSecurityChanged,
    required this.onAssignPayChanged,
    required this.onComplaintsChanged,
    required this.onBlockCreationChanged,
  });

  final ApartmentModel apartment;
  final ValueChanged<bool> onSecurityChanged;
  final ValueChanged<bool> onAssignPayChanged;
  final ValueChanged<bool> onComplaintsChanged;
  final ValueChanged<bool> onBlockCreationChanged;

  @override
  State<PropertyFeatureToggleGrid> createState() =>
      _PropertyFeatureToggleGridState();
}

class _PropertyFeatureToggleGridState
    extends State<PropertyFeatureToggleGrid> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final activeCount = (widget.apartment.securityEnabled ? 1 : 0) +
        (widget.apartment.assignPaymentEnabled ? 1 : 0) +
        (widget.apartment.complaintsEnabled ? 1 : 0) +
        (widget.apartment.blockCreationEnabled ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Feature Controls ($activeCount/4 Active)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                _MiniBadge(
                  icon: Icons.security_rounded,
                  active: widget.apartment.securityEnabled,
                  tooltip: 'Security',
                ),
                const SizedBox(width: 4),
                _MiniBadge(
                  icon: Icons.account_balance_wallet_outlined,
                  active: widget.apartment.assignPaymentEnabled,
                  tooltip: 'Assign Pay',
                ),
                const SizedBox(width: 4),
                _MiniBadge(
                  icon: Icons.report_problem_outlined,
                  active: widget.apartment.complaintsEnabled,
                  tooltip: 'Complaints',
                ),
                const SizedBox(width: 4),
                _MiniBadge(
                  icon: Icons.add_box_outlined,
                  active: widget.apartment.blockCreationEnabled,
                  tooltip: 'Block Create',
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTheme.textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: _CompactFeaturePill(
                    icon: Icons.security_rounded,
                    label: 'Security',
                    value: widget.apartment.securityEnabled,
                    onChanged: widget.onSecurityChanged,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CompactFeaturePill(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Assign Pay',
                    value: widget.apartment.assignPaymentEnabled,
                    onChanged: widget.onAssignPayChanged,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CompactFeaturePill(
                    icon: Icons.report_problem_outlined,
                    label: 'Complaints',
                    value: widget.apartment.complaintsEnabled,
                    onChanged: widget.onComplaintsChanged,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CompactFeaturePill(
                    icon: Icons.add_box_outlined,
                    label: 'Block Create',
                    value: widget.apartment.blockCreationEnabled,
                    onChanged: widget.onBlockCreationChanged,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.active,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.secondaryColor.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 11,
          color: active ? AppTheme.secondaryColor : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _CompactFeaturePill extends StatelessWidget {
  const _CompactFeaturePill({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.secondaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: value ? activeColor : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: value ? AppTheme.textColor : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Transform.scale(
            scale: 0.65,
            child: SizedBox(
              height: 20,
              width: 32,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: activeColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.apartment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetActive,
    required this.onSetInactive,
    required this.onSecurityChanged,
    required this.onAssignPayChanged,
    required this.onComplaintsChanged,
    required this.onBlockCreationChanged,
  });

  final ApartmentModel apartment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;
  final VoidCallback onSetInactive;
  final ValueChanged<bool> onSecurityChanged;
  final ValueChanged<bool> onAssignPayChanged;
  final ValueChanged<bool> onComplaintsChanged;
  final ValueChanged<bool> onBlockCreationChanged;

  @override
  Widget build(BuildContext context) {
    final style = PropertyTypeStyle.forType(apartment.propertyType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: style.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(style.icon, color: style.color, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        apartment.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _StatusDotChip(isActive: apartment.isActive),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: style.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    style.label,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: style.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              } else if (value == 'active') {
                                if (!apartment.isActive) onSetActive();
                              } else if (value == 'inactive') {
                                if (apartment.isActive) onSetInactive();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete Property',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'active',
                                child: Text('Set Active'),
                              ),
                              const PopupMenuItem(
                                value: 'inactive',
                                child: Text('Set Inactive'),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      if (apartment.address.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                apartment.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (apartment.propertyType == PropertyType.hostel) ...[
                        if (apartment.ownerName.isNotEmpty ||
                            apartment.contactPhone.isNotEmpty ||
                            apartment.wardenName.isNotEmpty ||
                            apartment.wardenContact.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (apartment.ownerName.isNotEmpty ||
                                  apartment.contactPhone.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Owner: ${apartment.ownerName.isNotEmpty ? apartment.ownerName : "N/A"}${apartment.contactPhone.isNotEmpty ? " (${apartment.contactPhone})" : ""}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              if (apartment.wardenName.isNotEmpty ||
                                  apartment.wardenContact.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.security_rounded,
                                      size: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Warden: ${apartment.wardenName.isNotEmpty ? apartment.wardenName : "N/A"}${apartment.wardenContact.isNotEmpty ? " (${apartment.wardenContact})" : ""}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ] else ...[
                        if (apartment.contactPhone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                apartment.contactPhone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: PropertyFeatureToggleGrid(
                apartment: apartment,
                onSecurityChanged: onSecurityChanged,
                onAssignPayChanged: onAssignPayChanged,
                onComplaintsChanged: onComplaintsChanged,
                onBlockCreationChanged: onBlockCreationChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDotChip extends StatelessWidget {
  const _StatusDotChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5);
    final fg = isActive ? const Color(0xFF15803D) : const Color(0xFFC2410C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
