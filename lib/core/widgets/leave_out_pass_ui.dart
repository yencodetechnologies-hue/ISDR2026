import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/leave_request_model.dart';

class LeaveStatusStyle {
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;

  const LeaveStatusStyle({
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
  });

  static LeaveStatusStyle forStatus(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return LeaveStatusStyle(
          color: const Color(0xFFD97706),
          bg: const Color(0xFFFFF7ED),
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case LeaveRequestStatus.approved:
        return LeaveStatusStyle(
          color: AppTheme.secondaryColor,
          bg: const Color(0xFFECFDF5),
          icon: Icons.check_circle_rounded,
          label: 'Approved',
        );
      case LeaveRequestStatus.rejected:
        return LeaveStatusStyle(
          color: AppTheme.errorColor,
          bg: const Color(0xFFFEF2F2),
          icon: Icons.cancel_rounded,
          label: 'Rejected',
        );
      case LeaveRequestStatus.cancelled:
        return LeaveStatusStyle(
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF3F4F6),
          icon: Icons.block_rounded,
          label: 'Cancelled',
        );
      case LeaveRequestStatus.expired:
        return LeaveStatusStyle(
          color: const Color(0xFF9CA3AF),
          bg: const Color(0xFFF9FAFB),
          icon: Icons.event_busy_rounded,
          label: 'Expired',
        );
    }
  }
}

/// Horizontal filter pills for out-pass lists.
class LeaveOutPassFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int>? counts;

  const LeaveOutPassFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  static const filters = [
    ('pending', 'Pending', Icons.pending_actions_rounded),
    ('approved', 'Approved', Icons.verified_rounded),
    ('rejected', 'Rejected', Icons.highlight_off_rounded),
    ('all', 'All', Icons.list_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final f in filters) ...[
            _FilterPill(
              id: f.$1,
              label: f.$2,
              icon: f.$3,
              count: counts?[f.$1],
              selected: selected == f.$1,
              onTap: () => onSelected(f.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.id,
    required this.label,
    required this.icon,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: selected ? 3 : 1,
      shadowColor: AppTheme.primaryColor.withOpacityCompat(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textColor,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacityCompat(0.25)
                        : AppTheme.accentColor.withOpacityCompat(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Out-pass list card (resident + management).
class LeaveOutPassCard extends StatelessWidget {
  final LeaveRequestModel leave;
  final bool showResidentName;
  final VoidCallback? onTap;
  final Widget? trailingActions;

  const LeaveOutPassCard({
    super.key,
    required this.leave,
    this.showResidentName = false,
    this.onTap,
    this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
    final style = LeaveStatusStyle.forStatus(leave.status);
    final dateFmt = DateFormat('EEE, d MMM');
    final timeFmt = DateFormat('h:mm a');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.dividerColor.withOpacityCompat(0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacityCompat(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: style.color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showResidentName) ...[
                                _AvatarCircle(
                                  name: leave.userName ?? 'Resident',
                                  imageUrl: leave.userProfilePic,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showResidentName)
                                      Text(
                                        leave.userName ?? 'Resident',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textColor,
                                        ),
                                      ),
                                    if (showResidentName) const SizedBox(height: 4),
                                    _StatusBadge(style: style),
                                  ],
                                ),
                              ),
                              if (!showResidentName) _StatusBadge(style: style),
                            ],
                          ),
                          if (leave.hostelRoom.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                              icon: Icons.hotel_rounded,
                              text: [
                                if (leave.hostelRoom.isNotEmpty)
                                  'Room ${leave.hostelRoom}',
                                if (leave.hostelBed.isNotEmpty)
                                  'Bed ${leave.hostelBed}',
                              ].join(' • '),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _TimeLine(
                            outLabel: '${dateFmt.format(leave.outAt)} • ${timeFmt.format(leave.outAt)}',
                            inLabel:
                                '${dateFmt.format(leave.expectedInAt)} • ${timeFmt.format(leave.expectedInAt)}',
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor.withOpacityCompat(0.5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  leave.reason,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.family_restroom_rounded,
                            text: '${leave.parentName} • ${leave.parentMobile}',
                          ),
                          if (leave.status == LeaveRequestStatus.rejected &&
                              leave.rejectionReason.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacityCompat(0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      leave.rejectionReason,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.errorColor,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (trailingActions != null) ...[
                            const SizedBox(height: 14),
                            trailingActions!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LeaveStatusStyle style;

  const _StatusBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withOpacityCompat(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _AvatarCircle({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.brandHeaderGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacityCompat(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
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
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor.withOpacityCompat(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor.withOpacityCompat(0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeLine extends StatelessWidget {
  final String outLabel;
  final String inLabel;

  const _TimeLine({required this.outLabel, required this.inLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacityCompat(0.06),
            AppTheme.secondaryColor.withOpacityCompat(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacityCompat(0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeBlock(
              icon: Icons.logout_rounded,
              title: 'Going out',
              value: outLabel,
              color: AppTheme.primaryColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textColor.withOpacityCompat(0.35),
              size: 20,
            ),
          ),
          Expanded(
            child: _TimeBlock(
              icon: Icons.login_rounded,
              title: 'Return by',
              value: inLabel,
              color: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _TimeBlock({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: AppTheme.textColor,
          ),
        ),
      ],
    );
  }
}

/// Approve / reject action row for management cards.
class LeaveApprovalActions extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final bool loading;

  const LeaveApprovalActions({
    super.key,
    required this.onReject,
    required this.onApprove,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onReject,
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor.withOpacityCompat(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.brandSecondaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacityCompat(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loading ? null : onApprove,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else ...[
                        const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Approve out pass',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty state for out-pass lists.
class LeaveOutPassEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const LeaveOutPassEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.beach_access_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.brandSoftSurfaceGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppTheme.primaryColor.withOpacityCompat(0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textColor.withOpacityCompat(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Management: detail bottom sheet with approve / reject.
class LeaveOutPassReviewSheet extends StatefulWidget {
  final LeaveRequestModel leave;
  final Future<bool> Function() onApprove;
  final Future<bool> Function(String reason) onReject;

  const LeaveOutPassReviewSheet({
    super.key,
    required this.leave,
    required this.onApprove,
    required this.onReject,
  });

  static Future<void> show(
    BuildContext context, {
    required LeaveRequestModel leave,
    required Future<bool> Function() onApprove,
    required Future<bool> Function(String reason) onReject,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LeaveOutPassReviewSheet(
        leave: leave,
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }

  @override
  State<LeaveOutPassReviewSheet> createState() => _LeaveOutPassReviewSheetState();
}

class _LeaveOutPassReviewSheetState extends State<LeaveOutPassReviewSheet> {
  bool _busy = false;
  final _rejectReasonController = TextEditingController();

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    final ok = await widget.onApprove();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    final ok = await widget.onReject(_rejectReasonController.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final isPending = widget.leave.status == LeaveRequestStatus.pending;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandHeaderGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review out pass',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        'Approve or reject this request',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LeaveOutPassCard(
                leave: widget.leave,
                showResidentName: true,
              ),
            ),
          ),
          if (isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _rejectReasonController,
                decoration: InputDecoration(
                  labelText: 'Rejection note (optional)',
                  hintText: 'Shown to resident if you reject',
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
              child: LeaveApprovalActions(
                loading: _busy,
                onReject: _reject,
                onApprove: _approve,
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(bottom: bottom + 20),
            ),
        ],
      ),
    );
  }
}
