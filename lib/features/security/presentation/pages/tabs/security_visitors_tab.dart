import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/visitor_model.dart';
import '../../../../../core/models/monthly_visitor_pass_model.dart';
import '../../bloc/security_bloc.dart';
import '../security_visitor_section.dart';
import '../widgets/visitor_inside_duration.dart';

Future<void> _launchVisitorPhone(BuildContext context, String mobileNumber) async {
  final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final uri = Uri.parse('tel:$digits');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open dialer'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place call: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class SecurityVisitorsTab extends StatelessWidget {
  final SecurityLoaded state;
  final SecurityVisitorSection activeSection;
  final ValueChanged<SecurityVisitorSection> onSectionChanged;
  final Future<void> Function() onRefresh;

  const SecurityVisitorsTab({
    super.key,
    required this.state,
    required this.activeSection,
    required this.onSectionChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = activeSection == SecurityVisitorSection.monthlyVisitors
        ? []
        : filteredVisitorsForSection(state, activeSection);
    final isMonthly = activeSection == SecurityVisitorSection.monthlyVisitors;
    final displayList = isMonthly ? state.monthlyPasses : filtered;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _FilterChip(
                    label: 'Pending',
                    icon: Icons.hourglass_top_rounded,
                    selected: activeSection == SecurityVisitorSection.waitingApproval,
                    color: const Color(0xFFF59E0B),
                    onTap: () => onSectionChanged(SecurityVisitorSection.waitingApproval),
                  ),
                  _FilterChip(
                    label: 'Approved',
                    icon: Icons.verified_user_rounded,
                    selected: activeSection == SecurityVisitorSection.approved,
                    color: const Color(0xFF10B981),
                    onTap: () => onSectionChanged(SecurityVisitorSection.approved),
                  ),
                  _FilterChip(
                    label: 'Inside',
                    icon: Icons.login_rounded,
                    selected: activeSection == SecurityVisitorSection.inside,
                    color: const Color(0xFF13275D),
                    onTap: () => onSectionChanged(SecurityVisitorSection.inside),
                  ),
                  _FilterChip(
                    label: 'Exited',
                    icon: Icons.logout_rounded,
                    selected: activeSection == SecurityVisitorSection.exited,
                    color: const Color(0xFF64748B),
                    onTap: () => onSectionChanged(SecurityVisitorSection.exited),
                  ),
                  _FilterChip(
                    label: 'Today',
                    icon: Icons.today_rounded,
                    selected: activeSection == SecurityVisitorSection.today,
                    color: const Color(0xFF3B82F6),
                    onTap: () => onSectionChanged(SecurityVisitorSection.today),
                  ),
                  _FilterChip(
                    label: 'View all',
                    icon: Icons.grid_view_rounded,
                    selected: activeSection == SecurityVisitorSection.viewAll,
                    color: const Color(0xFF6366F1),
                    onTap: () => onSectionChanged(SecurityVisitorSection.viewAll),
                  ),
                  _FilterChip(
                    label: 'Monthly',
                    icon: Icons.badge_rounded,
                    selected: activeSection == SecurityVisitorSection.monthlyVisitors,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => onSectionChanged(SecurityVisitorSection.monthlyVisitors),
                  ),
                ],
              ),
            ),
          ),
          if (displayList.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13275D).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.people_alt_rounded,
                                color: Color(0xFF13275D),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${displayList.length} ${isMonthly ? "Pass" : "Visitor"}${displayList.length == 1 ? "" : "s"}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: onRefresh,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: Color(0xFF13275D),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Refresh',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF13275D),
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
              ),
            ),
          if (displayList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF13275D).withValues(alpha: 0.08),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13275D).withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: Color(0xFF13275D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      emptyMessageForSection(activeSection),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pull down to refresh list',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isMonthly) {
                      final pass = displayList[index] as MonthlyVisitorPassModel;
                      return _MonthlyPassCard(pass: pass);
                    }
                    final visitor = displayList[index] as VisitorModel;
                    final vt = visitor.visitTime.toLocal();
                    final timeStr = DateFormat('h:mm a').format(vt);
                    final dateStr = '${vt.day}/${vt.month}/${vt.year}';

                    // Status Pill Decoration Config
                    Color statusBg;
                    Color statusBorder;
                    Color statusText;
                    IconData statusIcon;

                    if (visitor.isInside) {
                      statusBg = const Color(0xFFECFDF5);
                      statusBorder = const Color(0xFFA7F3D0);
                      statusText = const Color(0xFF059669);
                      statusIcon = Icons.login_rounded;
                    } else if (visitor.isCompleted) {
                      statusBg = const Color(0xFFF1F5F9);
                      statusBorder = const Color(0xFFE2E8F0);
                      statusText = const Color(0xFF475569);
                      statusIcon = Icons.check_circle_rounded;
                    } else if (visitor.isApprovedForGate) {
                      statusBg = const Color(0xFFEFF6FF);
                      statusBorder = const Color(0xFFBFDBFE);
                      statusText = const Color(0xFF2563EB);
                      statusIcon = Icons.verified_user_rounded;
                    } else {
                      statusBg = const Color(0xFFFFFBEB);
                      statusBorder = const Color(0xFFFDE68A);
                      statusText = const Color(0xFFD97706);
                      statusIcon = Icons.hourglass_top_rounded;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top Row: Avatar + Info + Time Badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF2A437E),
                                              Color(0xFF13275D),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: (visitor.image != null &&
                                                visitor.image!.trim().isNotEmpty)
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(14),
                                                child: Image.network(
                                                  visitor.image!,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Center(
                                                    child: Text(
                                                      visitor.name.isNotEmpty
                                                          ? visitor.name[0].toUpperCase()
                                                          : '?',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  visitor.name.isNotEmpty
                                                      ? visitor.name[0].toUpperCase()
                                                      : '?',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Main Info Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Visitor Name & Status Pill Badges
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    visitor.name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF0F172A),
                                                      height: 1.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),

                                                // Status Pill Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusBg,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: statusBorder,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        statusIcon,
                                                        size: 10,
                                                        color: statusText,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        visitor.statusLabel.toUpperCase(),
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: statusText,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                if (visitor.visitMode == VisitorVisitMode.monthlyPass) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [
                                                          Color(0xFF8B5CF6),
                                                          Color(0xFF6D28D9),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'MONTHLY',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),

                                            // Subtitle: Visitor Type & Detail
                                            Text(
                                              visitor.type.displayName +
                                                  (visitor.typeDetail != null &&
                                                          visitor.typeDetail!.trim().isNotEmpty
                                                      ? ' · ${visitor.typeDetail!.trim()}'
                                                      : ''),
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),

                                            // Structured Info Chips Row (Block Unit & Vehicle Tag)
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                // Block & Room Badge (Only if assigned)
                                                if (visitor.block.trim().isNotEmpty &&
                                                    visitor.block != '—')
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF13275D)
                                                          .withValues(alpha: 0.06),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: const Color(0xFF13275D)
                                                            .withValues(alpha: 0.12),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.apartment_rounded,
                                                          size: 13,
                                                          color: Color(0xFF13275D),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            visitor.homeNumber.trim().isNotEmpty
                                                                ? 'Block ${visitor.block} · ${visitor.homeNumber}'
                                                                : 'Block ${visitor.block}',
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: const Color(0xFF13275D),
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // Vehicle tag if available
                                                if (visitor.vehicleNumber != null &&
                                                    visitor.vehicleNumber!.trim().isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: const Color(0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.directions_car_rounded,
                                                          size: 13,
                                                          color: Color(0xFF475569),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          visitor.vehicleNumber!.trim(),
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Time Badge (Top Right)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              timeStr,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF13275D),
                                              ),
                                            ),
                                            Text(
                                              dateStr,
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Divider line
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                  ),

                                  // Bottom Footer Row (Duration/Status Text on Left, Call & Action Buttons on Right)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Left: Live duration or Exited duration text
                                      Expanded(
                                        child: (visitor.exitedAt != null)
                                            ? Text(
                                                'Exited ${DateFormat('MMM d, h:mm a').format(visitor.exitedAt!)}${visitor.formattedStayDuration != null ? ' (${visitor.formattedStayDuration} stay)' : ''}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : visitor.isInside
                                                ? VisitorInsideDuration(
                                                    enteredAt: visitor.enteredAt ?? DateTime.now(),
                                                  )
                                                : const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 8),

                                      // Right: Action Buttons (Call, Entry, Exit)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (visitor.mobileNumber.trim().isNotEmpty)
                                            InkWell(
                                              onTap: () => _launchVisitorPhone(
                                                  context, visitor.mobileNumber),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF13275D)
                                                      .withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.phone_in_talk_rounded,
                                                  size: 18,
                                                  color: Color(0xFF13275D),
                                                ),
                                              ),
                                            ),
                                          if (!visitor.isInside && !visitor.isCompleted) ...[
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                context.read<SecurityBloc>().add(
                                                    MarkVisitorEntryEvent(
                                                        visitorId: visitor.id));
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFF10B981)
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.login_rounded,
                                                      size: 14,
                                                      color: Color(0xFF059669),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Entry',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF059669),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (visitor.isInside && !visitor.isCompleted) ...[
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                context.read<SecurityBloc>().add(
                                                    MarkVisitorExitEvent(
                                                        visitorId: visitor.id));
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFFEF4444)
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.logout_rounded,
                                                      size: 14,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Exit',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: displayList.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFF8FAFC),
                    ],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyPassCard extends StatelessWidget {
  final MonthlyVisitorPassModel pass;

  const _MonthlyPassCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    final validToText = DateFormat('dd MMM yyyy').format(pass.validTo);
    final isExpiringSoon = pass.validTo.difference(DateTime.now()).inDays <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2A437E),
                          Color(0xFF13275D),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: pass.image != null && pass.image!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(pass.image!, fit: BoxFit.cover),
                          )
                        : Center(
                            child: Text(
                              pass.personName.isNotEmpty
                                  ? pass.personName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pass.personName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pass.mobileNumber,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pass.isInside
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pass.isInside
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      pass.isInside ? 'INSIDE' : 'OUTSIDE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: pass.isInside
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                      label: pass.visitorType.displayName,
                      color: const Color(0xFF13275D)),
                  if (pass.category != null)
                    _Badge(
                        label: pass.category!,
                        color: const Color(0xFF059669)),
                  _Badge(
                      label: 'Valid until $validToText',
                      color: isExpiringSoon
                          ? const Color(0xFFD97706)
                          : const Color(0xFF64748B)),
                ],
              ),
              if (pass.reasonForPass != null &&
                  pass.reasonForPass!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Note: ${pass.reasonForPass}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!pass.isInside)
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<SecurityBloc>().add(MarkVisitorEntryEvent(
                            visitorId: pass.id, entryMethod: 'monthly_pass'));
                      },
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: const Text('Entry'),
                      style: AppTheme.primaryElevatedCompactStyle,
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<SecurityBloc>().add(
                            MarkVisitorExitEvent(visitorId: pass.id));
                      },
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Exit'),
                      style: AppTheme.secondaryElevatedCompactStyle,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
