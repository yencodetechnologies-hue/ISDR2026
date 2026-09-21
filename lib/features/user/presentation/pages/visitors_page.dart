import 'dart:io';
import 'dart:async';

import 'package:isdr/core/models/visitor_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../bloc/user_bloc.dart';
import 'widgets/add_visitor_dialog.dart' show AddVisitorSheet;
import 'visitor_details_page.dart';

enum _VisitorFilter { upcoming, inside, completed, closed }

class VisitorsPage extends StatefulWidget {
  final UserModel user;

  const VisitorsPage({super.key, required this.user});

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  _VisitorFilter _activeFilter = _VisitorFilter.upcoming;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserDataEvent());
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      context.read<UserBloc>().add(LoadUserDataEvent());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  static IconData _iconForVisitorType(VisitorType type) {
    switch (type) {
      case VisitorType.guest:
        return Icons.person_rounded;
      case VisitorType.courierDelivery:
        return Icons.delivery_dining_rounded;
      case VisitorType.cabDriver:
        return Icons.local_taxi_rounded;
      case VisitorType.gasDelivery:
        return Icons.local_fire_department_rounded;
      case VisitorType.groceryShop:
        return Icons.shopping_basket_rounded;
      case VisitorType.carpenter:
        return Icons.carpenter_rounded;
      case VisitorType.beautician:
        return Icons.face_retouching_natural_rounded;
      case VisitorType.repairMaintenance:
        return Icons.handyman_rounded;
      case VisitorType.pestControl:
        return Icons.pest_control_rounded;
      case VisitorType.tutor:
        return Icons.menu_book_rounded;
      case VisitorType.otherVendors:
        return Icons.storefront_rounded;
      case VisitorType.other:
        return Icons.person_outline_rounded;
    }
  }

  Future<void> _onRefresh() async {
    context.read<UserBloc>().add(LoadUserDataEvent());
  }

  String _filterEmptyTitle(_VisitorFilter filter) {
    switch (filter) {
      case _VisitorFilter.upcoming:
        return 'No upcoming visitors';
      case _VisitorFilter.inside:
        return 'No one inside right now';
      case _VisitorFilter.completed:
        return 'No completed visits yet';
      case _VisitorFilter.closed:
        return 'No rejected or cancelled visits';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Visitors',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh list',
            onPressed: _onRefresh,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () => _showAddVisitorSheet(context),
              icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is UserLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          if (state is UserLoaded) {
            final visitors = state.visitors.where((v) {
              if (widget.user.block != null && widget.user.roomNumber != null) {
                final ub = widget.user.block!.trim();
                final ur = widget.user.roomNumber!.trim();
                return v.block.trim() == ub && v.homeNumber.trim() == ur;
              }
              return true;
            }).toList();
            final upcomingCount = visitors.where((v) => v.visitStatus == VisitorVisitStatus.pendingApproval || v.visitStatus == VisitorVisitStatus.approved).length;
            final insideCount = visitors.where((v) => v.visitStatus == VisitorVisitStatus.entered).length;
            final completedCount = visitors.where((v) => v.visitStatus == VisitorVisitStatus.exited).length;
            final closedCount = visitors.where((v) => v.visitStatus == VisitorVisitStatus.rejected || v.visitStatus == VisitorVisitStatus.cancelled || v.visitStatus == VisitorVisitStatus.expired).length;

            final filteredVisitors = visitors.where((visitor) {
              switch (_activeFilter) {
                case _VisitorFilter.upcoming:
                  return visitor.visitStatus == VisitorVisitStatus.pendingApproval ||
                      visitor.visitStatus == VisitorVisitStatus.approved;
                case _VisitorFilter.inside:
                  return visitor.visitStatus == VisitorVisitStatus.entered;
                case _VisitorFilter.completed:
                  return visitor.visitStatus == VisitorVisitStatus.exited;
                case _VisitorFilter.closed:
                  return visitor.visitStatus == VisitorVisitStatus.rejected ||
                      visitor.visitStatus == VisitorVisitStatus.cancelled ||
                      visitor.visitStatus == VisitorVisitStatus.expired;
              }
            }).toList();

            if (visitors.isEmpty) {
              return RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _onRefresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: _buildGlobalEmptyState(context),
                      ),
                    );
                  },
                ),
              );
            }

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          _buildFilterChip(_VisitorFilter.upcoming, 'Upcoming', upcomingCount, Icons.schedule_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip(_VisitorFilter.inside, 'Inside', insideCount, Icons.door_front_door_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip(_VisitorFilter.completed, 'Completed', completedCount, Icons.history_rounded),
                          const SizedBox(width: 8),
                          _buildFilterChip(_VisitorFilter.closed, 'Rejected/Cancelled', closedCount, Icons.block_rounded),
                        ],
                      ),
                    ),
                  ),
                  if (filteredVisitors.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildFilterEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final visitor = filteredVisitors[index];
                            return _buildVisitorCard(context, visitor);
                          },
                          childCount: filteredVisitors.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          return const Center(child: Text('Error loading visitors'));
        },
      ),
    );
  }

  Widget _buildFilterChip(_VisitorFilter filter, String label, int count, IconData icon) {
    final selected = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFECECEA),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No visitors yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first visitor to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              child: InkWell(
                onTap: () => _showAddVisitorSheet(context),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Add Visitor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.filter_alt_outlined,
              size: 48,
              color: AppTheme.primaryColor.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _filterEmptyTitle(_activeFilter),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing in this tab right now. Try another filter or add a visitor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorCard(BuildContext context, VisitorModel visitor) {
    final typeIcon = _iconForVisitorType(visitor.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VisitorDetailsPage(visitor: visitor),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar box matching Admin UI
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECECEA)),
                  ),
                  child: (visitor.image?.trim().isNotEmpty == true)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: (visitor.image!.trim().startsWith('http')
                              ? Image.network(
                                  visitor.image!.trim(),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarIcon(24),
                                )
                              : Image.file(
                                  File(visitor.image!.trim()),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarIcon(24),
                                )),
                        )
                      : Icon(typeIcon, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              visitor.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppTheme.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(visitor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  visitor.type.displayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (visitor.typeDetail != null && visitor.typeDetail!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.storefront_outlined, size: 14, color: AppTheme.textColor.withOpacity(0.55)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visitor.typeDetail!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textColor.withOpacity(0.75),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (visitor.vehicleNumber != null && visitor.vehicleNumber!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.directions_car_outlined, size: 14, color: AppTheme.textColor.withOpacity(0.55)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visitor.vehicleNumber!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textColor.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.home_work_outlined, size: 14, color: AppTheme.textColor.withOpacity(0.55)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Block ${visitor.block} · ${visitor.homeNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor.withOpacity(0.72),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textColor.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(visitor.visitTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textColor.withOpacity(0.3),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarIcon(double size) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, color: Colors.white, size: size),
    );
  }

  Widget _buildStatusChip(VisitorModel visitor) {
    final bool isApproved = visitor.isApprovedForGate;
    final bool isInside = visitor.isInside;
    final bool isCompleted = visitor.isCompleted;
    final bool isClosed = visitor.visitStatus == VisitorVisitStatus.rejected ||
        visitor.visitStatus == VisitorVisitStatus.cancelled ||
        visitor.visitStatus == VisitorVisitStatus.expired;

    final Color bgColor = isClosed
        ? const Color(0xFFFEE2E2)
        : (isInside || isApproved)
            ? const Color(0xFFDCFCE7)
            : isCompleted
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFEF3C7);

    final Color textColor = isClosed
        ? const Color(0xFFDC2626)
        : (isInside || isApproved)
            ? const Color(0xFF16A34A)
            : isCompleted
                ? const Color(0xFF475569)
                : const Color(0xFFD97706);

    final IconData icon = isInside
        ? Icons.login_rounded
        : isCompleted
            ? Icons.logout_rounded
            : isClosed
                ? Icons.block_rounded
                : isApproved
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            visitor.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddVisitorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Who is this pass for?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select whether you are creating a pass for yourself or a visitor.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PassTypeSelectionCard(
                      icon: Icons.person_rounded,
                      title: 'For Myself',
                      subtitle: 'Self entry pass',
                      iconColor: AppTheme.primaryColor,
                      iconBgColor: AppTheme.primaryColor.withOpacity(0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddVisitorForm(
                          context,
                          isSelfPass: true,
                          initialName: widget.user.name.isNotEmpty ? widget.user.name : widget.user.username,
                          initialMobile: widget.user.mobileNumber,
                          initialBlock: widget.user.block,
                          initialRoom: widget.user.roomNumber ?? widget.user.hostelRoom,
                          initialCategory: VisitorCategory.outsider,
                          initialType: VisitorType.guest,
                          initialReason: 'Parent / Self Entry Gate Pass',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PassTypeSelectionCard(
                      icon: Icons.people_rounded,
                      title: 'For Others',
                      subtitle: 'Guest / Delivery / Taxi',
                      iconColor: const Color(0xFF059669),
                      iconBgColor: const Color(0xFF059669).withOpacity(0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddVisitorForm(
                          context,
                          isSelfPass: false,
                          initialBlock: widget.user.block,
                          initialRoom: widget.user.roomNumber ?? widget.user.hostelRoom,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddVisitorForm(
    BuildContext context, {
    bool isSelfPass = false,
    String? initialName,
    String? initialMobile,
    String? initialBlock,
    String? initialRoom,
    VisitorCategory? initialCategory,
    RelativeType? initialRelativeType,
    VisitorType? initialType,
    String? initialReason,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          expand: false,
          builder: (context, scrollController) => AddVisitorSheet(
            userId: widget.user.id,
            scrollController: scrollController,
            isSelfPass: isSelfPass,
            initialName: initialName,
            initialMobile: initialMobile,
            initialBlock: initialBlock,
            initialRoom: initialRoom,
            initialCategory: initialCategory,
            initialRelativeType: initialRelativeType,
            initialType: initialType,
            initialReason: initialReason,
          ),
        ),
      ),
    );
  }
}

class _PassTypeSelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _PassTypeSelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

