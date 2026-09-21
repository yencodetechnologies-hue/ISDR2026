import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/app_theme.dart';
import '../../../../../core/config/api_config.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/models/visitor_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../bloc/admin_bloc.dart';

class VisitorsTab extends StatefulWidget {
  final AdminLoaded state;
  final ApartmentModel? apartment;
  final bool securityEnabled;
  final bool complaintsEnabled;

  const VisitorsTab({
    super.key,
    required this.state,
    this.apartment,
    this.securityEnabled = true,
    this.complaintsEnabled = true,
  });

  @override
  State<VisitorsTab> createState() => _VisitorsTabState();
}

class _VisitorsTabState extends State<VisitorsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  int _tabIndex = 0;

  List<VisitorModel> _activeVisitors = const [];
  List<VisitorModel> _historyVisitors = const [];
  List<VisitorModel> _overstayVisitors = const [];
  List<Map<String, dynamic>> _topUnits = const [];
  Map<String, dynamic> _analytics = const {};

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VisitorsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedApartmentId != widget.state.selectedApartmentId) {
      _loadVisitors();
    }
  }

  Future<void> _loadVisitors() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apartmentId = widget.state.selectedApartmentId;
      final activeResponse =
          await _apiService.getActiveVisitors(apartmentId: apartmentId);
      final historyResponse =
          await _apiService.getVisitorHistory(apartmentId: apartmentId);
      final analyticsResponse =
          await _apiService.getVisitorAnalytics(apartmentId: apartmentId);

      if (!mounted) return;

      final active = ((activeResponse['visitors'] as List<dynamic>?) ?? const [])
          .map((item) =>
              VisitorModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final history =
          ((historyResponse['visitors'] as List<dynamic>?) ?? const [])
              .map((item) =>
                  VisitorModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();

      final analytics =
          Map<String, dynamic>.from(analyticsResponse['analytics'] as Map? ?? const {});

      final overstayRaw = (analytics['overstayVisitors'] as List?) ?? const [];
      final overstay = overstayRaw
          .map((raw) =>
              VisitorModel.fromJson(Map<String, dynamic>.from(raw as Map)))
          .toList();

      final topUnitsRaw = (analytics['topUnits'] as List?) ?? const [];
      final topUnits = topUnitsRaw
          .map((u) => Map<String, dynamic>.from(u as Map))
          .toList();

      setState(() {
        _activeVisitors = active;
        _historyVisitors = history;
        _overstayVisitors = overstay;
        _topUnits = topUnits;
        _analytics = analytics;
        _loading = false;
        _error = (activeResponse['success'] == true &&
                historyResponse['success'] == true)
            ? null
            : (activeResponse['error'] ?? historyResponse['error'])?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _insideCount =>
      (_analytics['currentlyInside'] as num?)?.toInt() ?? _activeVisitors.length;

  int get _todayCount => (_analytics['visitorsToday'] as num?)?.toInt() ?? 0;

  int get _ticketsResolved =>
      ((_analytics['tickets'] as Map?)?['closed'] as num?)?.toInt() ?? 0;

  int get _complaintsDone =>
      ((_analytics['complaints'] as Map?)?['completed'] as num?)?.toInt() ?? 0;

  List<VisitorModel> _visitorsForTab() {
    switch (_tabIndex) {
      case 0:
        return _activeVisitors;
      case 1:
        return _historyVisitors;
      case 2:
        return _overstayVisitors;
      default:
        return const [];
    }
  }

  bool _matchesSearch(VisitorModel v) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return v.name.toLowerCase().contains(q) ||
        v.mobileNumber.toLowerCase().contains(q) ||
        v.block.toLowerCase().contains(q) ||
        v.homeNumber.toLowerCase().contains(q) ||
        v.typeLabelLine.toLowerCase().contains(q) ||
        v.statusLabel.toLowerCase().contains(q);
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return 'Inside';
      case 1:
        return 'History';
      case 2:
        return 'Overstay';
      case 3:
        return 'Hotspots';
      default:
        return 'Visitors';
    }
  }

  void _showVisitorDetails(BuildContext context, VisitorModel visitor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VisitorDetailsSheet(
        visitor: visitor,
        securityEnabled: widget.securityEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final hasData = _activeVisitors.isNotEmpty ||
        _historyVisitors.isNotEmpty ||
        _overstayVisitors.isNotEmpty ||
        _topUnits.isNotEmpty;

    return Column(
      children: [
        _VisitorsTabHeader(
          insideCount: _insideCount,
          todayCount: _todayCount,
          ticketsResolved: _ticketsResolved,
          complaintsDone: _complaintsDone,
          showComplaintsStat: widget.complaintsEnabled,
          onRefresh: _loadVisitors,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFC2410C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasData) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _VisitorsSearchField(
              controller: _searchController,
              searchQuery: _searchQuery,
              onChanged: (v) => setState(() => _searchQuery = v),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _VisitorsFilterChips(
              selectedIndex: _tabIndex,
              insideCount: _activeVisitors.length,
              historyCount: _historyVisitors.length,
              overstayCount: _overstayVisitors.length,
              hotspotCount: _topUnits.length,
              onSelected: (i) => setState(() => _tabIndex = i),
            ),
          ),
        ],
        Expanded(
          child: !hasData
              ? const _VisitorsEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: _loadVisitors,
                  child: _buildTabContent(),
                ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (_tabIndex == 3) {
      return _buildHotspotsList();
    }

    final visitors = _visitorsForTab().where(_matchesSearch).toList();

    if (visitors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _VisitorsNoResultsState(
            isSearch: _searchQuery.isNotEmpty,
            query: _searchQuery,
            tabLabel: _tabLabel(_tabIndex),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];
        final isOverstay = visitor.overstayAlertActive || _tabIndex == 2;
        return _VisitorListCard(
          visitor: visitor,
          highlightOverstay: isOverstay,
          onTap: () => _showVisitorDetails(context, visitor),
        );
      },
    );
  }

  Widget _buildHotspotsList() {
    final units = _topUnits.take(10).toList();

    if (units.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _VisitorsNoResultsState(
            isSearch: false,
            query: '',
            tabLabel: 'Hotspots',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      itemCount: units.length,
      itemBuilder: (context, index) {
        final item = units[index];
        return _HotspotCard(
          rank: index + 1,
          block: item['block']?.toString() ?? '—',
          homeNumber: item['homeNumber']?.toString() ?? '—',
          visitorCount: (item['visitorCount'] as num?)?.toInt() ?? 0,
        );
      },
    );
  }
}

// ——— Visitors tab UI ———

class _VisitorsTabHeader extends StatelessWidget {
  final int insideCount;
  final int todayCount;
  final int ticketsResolved;
  final int complaintsDone;
  final bool showComplaintsStat;
  final VoidCallback onRefresh;

  const _VisitorsTabHeader({
    required this.insideCount,
    required this.todayCount,
    required this.ticketsResolved,
    required this.complaintsDone,
    required this.showComplaintsStat,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFECECEA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacityCompat(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor Control',
                        style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$insideCount inside now · $todayCount visits today',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      final tabState = context.findAncestorStateOfType<_VisitorsTabState>();
                      final apartmentId = tabState?.widget.state.selectedApartmentId ?? '';
                      if (apartmentId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Apartment ID not available')),
                        );
                        return;
                      }
                      final isSchoolOrCollege = false;
                      final passUrl = isSchoolOrCollege
                          ? '${ApiConfig.publicWebBaseUrl}/visitor-pass/$apartmentId?type=college'
                          : '${ApiConfig.publicWebBaseUrl}/visitor-pass/$apartmentId';
                      Clipboard.setData(ClipboardData(text: passUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Temporary Visitor Link Copied: $passUrl'),
                          backgroundColor: const Color(0xFF059669),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Temp Link',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _VisitorsStatChip(
                    label: 'Inside now',
                    value: '$insideCount',
                    icon: Icons.login_rounded,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VisitorsStatChip(
                    label: 'Today',
                    value: '$todayCount',
                    icon: Icons.today_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _VisitorsStatChip(
                    label: 'Tickets done',
                    value: '$ticketsResolved',
                    icon: Icons.support_agent_rounded,
                    color: const Color(0xFF0D9488),
                  ),
                ),
                if (showComplaintsStat) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VisitorsStatChip(
                      label: 'Complaints done',
                      value: '$complaintsDone',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitorsStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _VisitorsStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacityCompat(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _VisitorsSearchField({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: 'Search visitor, unit, type, status…',
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF94A3B8),
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: Color(0xFF64748B),
        ),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFECECEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFECECEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _VisitorsFilterChips extends StatelessWidget {
  final int selectedIndex;
  final int insideCount;
  final int historyCount;
  final int overstayCount;
  final int hotspotCount;
  final ValueChanged<int> onSelected;

  const _VisitorsFilterChips({
    required this.selectedIndex,
    required this.insideCount,
    required this.historyCount,
    required this.overstayCount,
    required this.hotspotCount,
    required this.onSelected,
  });

  static const _filters = [
    (icon: Icons.door_front_door_rounded, label: 'Inside', color: AppTheme.secondaryColor),
    (icon: Icons.history_rounded, label: 'History', color: AppTheme.primaryColor),
    (icon: Icons.warning_amber_rounded, label: 'Overstay', color: AppTheme.errorColor),
    (icon: Icons.trending_up_rounded, label: 'Hotspots', color: AppTheme.accentColor),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = [insideCount, historyCount, overstayCount, hotspotCount];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = _filters[index];
          final selected = selectedIndex == index;
          final count = counts[index];

          return Material(
            color: selected ? f.color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: selected ? 2 : 0,
            shadowColor: f.color.withOpacityCompat(0.25),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? f.color
                        : const Color(0xFFECECEA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.icon,
                      size: 15,
                      color: selected ? Colors.white : f.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacityCompat(0.25)
                            : f.color.withOpacityCompat(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : f.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VisitorListCard extends StatelessWidget {
  final VisitorModel visitor;
  final bool highlightOverstay;
  final VoidCallback onTap;

  const _VisitorListCard({
    required this.visitor,
    required this.highlightOverstay,
    required this.onTap,
  });

  Color _statusColor() {
    if (highlightOverstay || visitor.overstayAlertActive) {
      return AppTheme.errorColor;
    }
    switch (visitor.visitStatus) {
      case VisitorVisitStatus.entered:
        return AppTheme.secondaryColor;
      case VisitorVisitStatus.pendingApproval:
        return AppTheme.accentColor;
      case VisitorVisitStatus.approved:
        return AppTheme.primaryColor;
      case VisitorVisitStatus.exited:
        return const Color(0xFF64748B);
      case VisitorVisitStatus.rejected:
      case VisitorVisitStatus.cancelled:
      case VisitorVisitStatus.expired:
        return AppTheme.errorColor;
    }
  }

  IconData _typeIcon() {
    switch (visitor.type) {
      case VisitorType.guest:
        return Icons.person_rounded;
      case VisitorType.courierDelivery:
        return Icons.local_shipping_outlined;
      case VisitorType.cabDriver:
        return Icons.local_taxi_rounded;
      case VisitorType.gasDelivery:
        return Icons.propane_tank_outlined;
      case VisitorType.groceryShop:
        return Icons.shopping_bag_outlined;
      case VisitorType.carpenter:
        return Icons.handyman_outlined;
      case VisitorType.beautician:
        return Icons.face_retouching_natural_outlined;
      case VisitorType.repairMaintenance:
        return Icons.build_circle_outlined;
      case VisitorType.pestControl:
        return Icons.bug_report_outlined;
      case VisitorType.tutor:
        return Icons.school_outlined;
      case VisitorType.otherVendors:
      case VisitorType.other:
        return Icons.storefront_outlined;
    }
  }

  String _timeLine() {
    if (visitor.exitedAt != null) {
      return 'Exited ${DateFormat('dd MMM, hh:mm a').format(visitor.exitedAt!)}';
    }
    if (visitor.enteredAt != null) {
      return 'Entered ${DateFormat('dd MMM, hh:mm a').format(visitor.enteredAt!)}';
    }
    return DateFormat('dd MMM, hh:mm a').format(visitor.visitTime);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightOverstay
              ? AppTheme.errorColor.withOpacityCompat(0.5)
              : const Color(0xFFECECEA),
          width: highlightOverstay ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (highlightOverstay ? AppTheme.errorColor : Colors.black)
                .withOpacityCompat(highlightOverstay ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacityCompat(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECECEA)),
                  ),
                  child: visitor.image != null && visitor.image!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            visitor.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _typeIcon(),
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(_typeIcon(), color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              visitor.name,
                              style: GoogleFonts.sora(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _VisitorStatusPill(
                            label: visitor.statusLabel,
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visitor.typeLabelLine,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.apartment_outlined,
                              size: 13,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Block ${visitor.block} · ${visitor.homeNumber}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _VisitorInfoRow(
                        icon: Icons.phone_outlined,
                        text: visitor.mobileNumber,
                      ),
                      const SizedBox(height: 4),
                      _VisitorInfoRow(
                        icon: Icons.schedule_rounded,
                        text: _timeLine(),
                      ),
                      if (highlightOverstay && visitor.overstayAlertCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_off_rounded,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Overstay alert · ${visitor.overstayAlertCount}×',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotspotCard extends StatelessWidget {
  final int rank;
  final String block;
  final String homeNumber;
  final int visitorCount;

  const _HotspotCard({
    required this.rank,
    required this.block,
    required this.homeNumber,
    required this.visitorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppTheme.primaryColor
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Block $block · $homeNumber',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$visitorCount ${visitorCount == 1 ? 'visitor' : 'visitors'} today',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacityCompat(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$visitorCount',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _VisitorStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacityCompat(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacityCompat(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _VisitorInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _VisitorInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VisitorsEmptyState extends StatelessWidget {
  const _VisitorsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacityCompat(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacityCompat(0.15),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  size: 36,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Visitor Activity Yet',
                style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'When residents register visitors or security logs entries, they will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorsNoResultsState extends StatelessWidget {
  final bool isSearch;
  final String query;
  final String tabLabel;

  const _VisitorsNoResultsState({
    required this.isSearch,
    required this.query,
    required this.tabLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.filter_list_off_rounded,
            size: 48,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'No matches found' : 'No $tabLabel records',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Nothing matches "$query". Try another name or unit.'
                : 'Records in this category will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorDetailsSheet extends StatelessWidget {
  final VisitorModel visitor;
  final bool securityEnabled;

  const _VisitorDetailsSheet({
    required this.visitor,
    this.securityEnabled = true,
  });

  Color _statusColor() {
    switch (visitor.visitStatus) {
      case VisitorVisitStatus.entered:
        return AppTheme.secondaryColor;
      case VisitorVisitStatus.pendingApproval:
        return AppTheme.accentColor;
      case VisitorVisitStatus.approved:
        return AppTheme.primaryColor;
      case VisitorVisitStatus.exited:
        return const Color(0xFF64748B);
      case VisitorVisitStatus.rejected:
      case VisitorVisitStatus.cancelled:
      case VisitorVisitStatus.expired:
        return AppTheme.errorColor;
    }
  }

  String? _formatDate(DateTime? d) {
    if (d == null) return null;
    return DateFormat('dd MMM yyyy, hh:mm a').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAF9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF13275D), Color(0xFF1E3A8A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacityCompat(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    visitor.name,
                                    style: GoogleFonts.sora(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacityCompat(0.15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visitor.typeLabelLine,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacityCompat(0.85),
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _DetailChip(
                                  label: visitor.statusLabel,
                                  color: statusColor,
                                ),
                                if (visitor.overstayAlertActive)
                                  const _DetailChip(
                                    label: 'Overstay',
                                    color: AppTheme.errorColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Visit Details',
                      icon: Icons.event_note_outlined,
                      rows: [
                        _DetailRow('Unit', 'Block ${visitor.block} · ${visitor.homeNumber}'),
                        _DetailRow('Mobile', visitor.mobileNumber),
                        if (visitor.vehicleNumber != null &&
                            visitor.vehicleNumber!.isNotEmpty)
                          _DetailRow('Vehicle', visitor.vehicleNumber!),
                        if (visitor.reasonForVisit != null &&
                            visitor.reasonForVisit!.isNotEmpty)
                          _DetailRow('Reason', visitor.reasonForVisit!),
                        _DetailRow('Mode', visitor.visitMode.name),
                        if (_formatDate(visitor.enteredAt) != null)
                          _DetailRow('Entered', _formatDate(visitor.enteredAt)!),
                        if (_formatDate(visitor.exitedAt) != null)
                          _DetailRow('Exited', _formatDate(visitor.exitedAt)!),
                        if (_formatDate(visitor.visitTime) != null)
                          _DetailRow('Scheduled', _formatDate(visitor.visitTime)!),
                      ],
                    ),
                    if (securityEnabled &&
                        visitor.securityNotes != null &&
                        visitor.securityNotes!.isNotEmpty)
                      _DetailSection(
                        title: 'Security Notes',
                        icon: Icons.security_rounded,
                        rows: [_DetailRow('Notes', visitor.securityNotes!)],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacityCompat(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_DetailRow> rows;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: rows
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              r.label,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.value,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);
}
