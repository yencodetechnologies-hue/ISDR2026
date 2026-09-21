import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../bloc/security_bloc.dart';
import '../security_visitor_section.dart';

class SecurityOperationsTab extends StatelessWidget {
  final SecurityLoaded state;
  final TabController tabController;
  final int visitorsTabIndex;
  final SecurityVisitorSection activeSection;
  final bool isSchoolOrCollege;
  final void Function(SecurityVisitorSection section) onSelectSection;
  final VoidCallback onAddVisitor;
  final VoidCallback onBulkVisit;
  final VoidCallback onVerify;
  final VoidCallback onScanQr;
  final VoidCallback onUpcomingSheet;

  const SecurityOperationsTab({
    super.key,
    required this.state,
    required this.tabController,
    required this.visitorsTabIndex,
    required this.activeSection,
    this.isSchoolOrCollege = false,
    required this.onSelectSection,
    required this.onAddVisitor,
    required this.onBulkVisit,
    required this.onVerify,
    required this.onScanQr,
    required this.onUpcomingSheet,
  });

  void _goVisitors(SecurityVisitorSection section) {
    onSelectSection(section);
    if (tabController.index != visitorsTabIndex) {
      tabController.animateTo(visitorsTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Entry & Verification
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: Color(0xFF13275D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entry & Verification',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Quick security actions',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isSchoolOrCollege ? 3 : 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  childAspectRatio: isSchoolOrCollege ? 0.98 : 0.72,
                  children: [
                    _OpActionCard(
                      icon: Icons.person_add_rounded,
                      label: 'Add Visitor',
                      color: const Color(0xFF13275D),
                      onTap: onAddVisitor,
                    ),
                    if (!isSchoolOrCollege)
                      _OpActionCard(
                        icon: Icons.groups_rounded,
                        label: 'Bulk Visit',
                        color: const Color(0xFF10B981),
                        onTap: onBulkVisit,
                      ),
                    if (!isSchoolOrCollege)
                      _OpActionCard(
                        icon: Icons.verified_user_rounded,
                        label: 'Verify',
                        color: const Color(0xFF3B82F6),
                        onTap: onVerify,
                      ),
                    if (!isSchoolOrCollege)
                      _OpActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan QR',
                        color: const Color(0xFF8B5CF6),
                        onTap: onScanQr,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Visitor List Shortcuts
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.filter_list_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visitor List Shortcuts',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Opens Visitors tab with selected filter',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                  children: [
                    _OpActionCard(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Pending',
                      color: const Color(0xFFF59E0B),
                      isSelected: activeSection == SecurityVisitorSection.waitingApproval,
                      onTap: () => _goVisitors(SecurityVisitorSection.waitingApproval),
                    ),
                    _OpActionCard(
                      icon: Icons.verified_rounded,
                      label: 'Approved',
                      color: const Color(0xFF10B981),
                      isSelected: activeSection == SecurityVisitorSection.approved,
                      onTap: () => _goVisitors(SecurityVisitorSection.approved),
                    ),
                    _OpActionCard(
                      icon: Icons.login_rounded,
                      label: 'Inside',
                      color: const Color(0xFF13275D),
                      isSelected: activeSection == SecurityVisitorSection.inside,
                      onTap: () => _goVisitors(SecurityVisitorSection.inside),
                    ),
                    _OpActionCard(
                      icon: Icons.logout_rounded,
                      label: 'Exited',
                      color: const Color(0xFF64748B),
                      isSelected: activeSection == SecurityVisitorSection.exited,
                      onTap: () => _goVisitors(SecurityVisitorSection.exited),
                    ),
                    _OpActionCard(
                      icon: Icons.today_rounded,
                      label: 'Today',
                      color: const Color(0xFF3B82F6),
                      isSelected: activeSection == SecurityVisitorSection.today,
                      onTap: () => _goVisitors(SecurityVisitorSection.today),
                    ),
                    _OpActionCard(
                      icon: Icons.upcoming_rounded,
                      label: 'Upcoming',
                      color: const Color(0xFFEC4899),
                      onTap: onUpcomingSheet,
                    ),
                    _OpActionCard(
                      icon: Icons.grid_view_rounded,
                      label: 'View All',
                      color: const Color(0xFF6366F1),
                      isSelected: activeSection == SecurityVisitorSection.viewAll,
                      onTap: () => _goVisitors(SecurityVisitorSection.viewAll),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OpActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _OpActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? color : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
