import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/models/complaint_model.dart';
import '../../bloc/user_bloc.dart';
import 'raise_complaint_dialog.dart';

class ComplaintsTab extends StatelessWidget {
  final String userId;
  final bool securityEnabled;

  const ComplaintsTab({
    super.key,
    required this.userId,
    this.securityEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is UserLoaded) {
            final complaints = state.complaints
                .where((c) => c.userId == userId)
                .toList();

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(
                          iconMargin: EdgeInsets.only(bottom: 2),
                          icon: Icon(Icons.category_rounded, size: 16),
                          text: 'Categories',
                        ),
                        Tab(
                          iconMargin: EdgeInsets.only(bottom: 2),
                          icon: Icon(Icons.list_alt_rounded, size: 16),
                          text: 'My Complaints',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Categories Grid View
                        _buildCategoryGrid(context, securityEnabled: securityEnabled),
                        // Complaints List View
                        complaints.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEEF2FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.report_problem_rounded,
                                          size: 36,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'No Complaints Yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Report any maintenance or facility issues to get quick help from management.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      OutlinedButton.icon(
                                        onPressed: () => _showRaiseComplaintDialog(context, null),
                                        icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.primaryColor),
                                        label: const Text(
                                          'Raise Complaint',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: complaints.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final complaint = complaints[index];
                                  final catColor = _getCategoryColor(complaint.type);
                                  final statusBg = _getStatusBg(complaint.status);
                                  final statusFg = _getStatusFg(complaint.status);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: catColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _getCategoryIcon(complaint.type),
                                                color: catColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    complaint.type.name.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: catColor,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.schedule_rounded,
                                                        size: 12,
                                                        color: const Color(0xFF94A3B8),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        DateFormat('dd MMM, hh:mm a').format(complaint.createdAt),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(0xFF64748B),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                complaint.status.name.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusFg,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          complaint.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        },
      ),
    );
  }

  Color _getStatusBg(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const Color(0xFFFFF7ED);
      case ComplaintStatus.approved:
        return const Color(0xFFEFF6FF);
      case ComplaintStatus.completed:
        return const Color(0xFFECFDF5);
      case ComplaintStatus.cancelled:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusFg(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return const Color(0xFFD97706);
      case ComplaintStatus.approved:
        return const Color(0xFF2563EB);
      case ComplaintStatus.completed:
        return const Color(0xFF059669);
      case ComplaintStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(ComplaintType type) {
    switch (type) {
      case ComplaintType.plumbing:
        return Icons.plumbing_rounded;
      case ComplaintType.electrical:
        return Icons.electrical_services_rounded;
      case ComplaintType.cleaning:
        return Icons.cleaning_services_rounded;
      case ComplaintType.maintenance:
        return Icons.build_rounded;
      case ComplaintType.security:
        return Icons.security_rounded;
      case ComplaintType.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color _getCategoryColor(ComplaintType type) {
    switch (type) {
      case ComplaintType.plumbing:
        return AppTheme.primaryColor;
      case ComplaintType.electrical:
        return const Color(0xFFD97706);
      case ComplaintType.cleaning:
        return const Color(0xFF059669);
      case ComplaintType.maintenance:
        return const Color(0xFF0284C7);
      case ComplaintType.security:
        return const Color(0xFFDC2626);
      case ComplaintType.other:
        return const Color(0xFF475569);
    }
  }

  void _showRaiseComplaintDialog(BuildContext context, ComplaintType? type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RaiseComplaintDialog(userId: userId, initialType: type),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context, {
    required bool securityEnabled,
  }) {
    final categories = <Map<String, dynamic>>[
      {
        'type': ComplaintType.plumbing,
        'icon': Icons.plumbing_rounded,
        'label': 'Plumbing',
        'hint': 'Leaks, blockages, taps',
        'iconBg': const Color(0xFFEEF2FF),
        'iconFg': AppTheme.primaryColor,
      },
      {
        'type': ComplaintType.electrical,
        'icon': Icons.electrical_services_rounded,
        'label': 'Electrical',
        'hint': 'Wiring, switches, power',
        'iconBg': const Color(0xFFFFF7ED),
        'iconFg': const Color(0xFFD97706),
      },
      {
        'type': ComplaintType.cleaning,
        'icon': Icons.cleaning_services_rounded,
        'label': 'Cleaning',
        'hint': 'Common areas, waste',
        'iconBg': const Color(0xFFECFDF5),
        'iconFg': const Color(0xFF059669),
      },
      {
        'type': ComplaintType.maintenance,
        'icon': Icons.build_rounded,
        'label': 'Maintenance',
        'hint': 'General repairs',
        'iconBg': const Color(0xFFF0F9FF),
        'iconFg': const Color(0xFF0284C7),
      },
      if (securityEnabled)
        {
          'type': ComplaintType.security,
          'icon': Icons.security_rounded,
          'label': 'Security',
          'hint': 'Access, safety concerns',
          'iconBg': const Color(0xFFFEF2F2),
          'iconFg': const Color(0xFFDC2626),
        },
      {
        'type': ComplaintType.other,
        'icon': Icons.more_horiz_rounded,
        'label': 'Others',
        'hint': 'Any other issues',
        'iconBg': const Color(0xFFF8FAFC),
        'iconFg': const Color(0xFF475569),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact tip bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap a category to report an issue',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categories grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final iconBg = category['iconBg'] as Color;
              final iconFg = category['iconFg'] as Color;

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showRaiseComplaintDialog(context, category['type'] as ComplaintType),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              category['icon'] as IconData,
                              size: 22,
                              color: iconFg,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          category['label'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category['hint'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

