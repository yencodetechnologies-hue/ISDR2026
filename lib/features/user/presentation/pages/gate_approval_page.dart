import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/visitor_model.dart';
import '../bloc/user_bloc.dart';
import 'visitor_details_page.dart';

class GateApprovalPage extends StatefulWidget {
  const GateApprovalPage({super.key});

  @override
  State<GateApprovalPage> createState() => _GateApprovalPageState();
}

class _GateApprovalPageState extends State<GateApprovalPage> {
  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gate Approval',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is! UserLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }
          final pending = state.myUnitVisitors
              .where((v) => v.visitStatus == VisitorVisitStatus.pendingApproval)
              .toList();
          final recent = state.myUnitVisitors
              .where((v) => v.visitStatus != VisitorVisitStatus.pendingApproval)
              .take(5)
              .toList();

          if (pending.isEmpty && recent.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
              },
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: _EmptyState(onRefresh: () {
                          context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
            },
            color: AppTheme.primaryColor,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isEmpty)
                  _EmptyState(onRefresh: () {
                    context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
                  })
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pending_actions_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${pending.length} Waiting Approval',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...pending.map((visitor) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GateApprovalCard(
                          visitor: visitor,
                          formatDateTime: _formatDateTime,
                          formatTimeAgo: _formatTimeAgo,
                          onApprove: () => _approve(context, visitor),
                          onReject: () => _reject(context, visitor),
                          onViewDetails: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VisitorDetailsPage(visitor: visitor),
                              ),
                            );
                          },
                        ),
                      )),
                ],

                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      const Text(
                        'Recent Gate Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...recent.map((visitor) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF1F5F9),
                            child: Icon(
                              visitor.visitStatus == VisitorVisitStatus.entered
                                  ? Icons.login_rounded
                                  : visitor.visitStatus == VisitorVisitStatus.exited
                                      ? Icons.logout_rounded
                                      : Icons.verified_user_rounded,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            visitor.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            '${visitor.typeLabelLine} • ${visitor.statusLabel}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: visitor.enteredAt != null
                              ? Text(
                                  DateFormat('hh:mm a').format(visitor.enteredAt!),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                )
                              : null,
                        ),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _approve(BuildContext context, VisitorModel visitor) {
    context.read<UserBloc>().add(
          UpdateVisitorApprovalEvent(visitorId: visitor.id, status: 'approved'),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text('${visitor.name} approved'),
          ],
        ),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
  }

  void _reject(BuildContext context, VisitorModel visitor) {
    context.read<UserBloc>().add(
          UpdateVisitorApprovalEvent(visitorId: visitor.id, status: 'rejected'),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text('${visitor.name} rejected'),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.read<UserBloc>().add(LoadMyUnitVisitorsEvent());
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              size: 36,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No visitors are waiting for your approval right now. Approved, entered, and exited records will appear in your gate activity.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GateApprovalCard extends StatelessWidget {
  final VisitorModel visitor;
  final String Function(DateTime) formatDateTime;
  final String Function(DateTime) formatTimeAgo;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;

  const _GateApprovalCard({
    required this.visitor,
    required this.formatDateTime,
    required this.formatTimeAgo,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.06),
                    AppTheme.primaryColor.withOpacity(0.02),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: visitor.image != null && visitor.image!.isNotEmpty
                          ? ClipOval(
                              child: visitor.image!.startsWith('http')
                                  ? Image.network(
                                      visitor.image!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _avatarIcon(),
                                    )
                                  : _avatarIcon(),
                            )
                          : _avatarIcon(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                visitor.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textColor,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                formatTimeAgo(visitor.visitTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 14, color: AppTheme.textColor.withOpacity(0.55)),
                            const SizedBox(width: 4),
                            Text(
                              visitor.typeLabelLine,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textColor.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textColor.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              formatDateTime(visitor.visitTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textColor.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                        if (visitor.reasonForVisit != null && visitor.reasonForVisit!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          // Container(
                          //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          //   decoration: BoxDecoration(
                          //     color: AppTheme.backgroundColor,
                          //     borderRadius: BorderRadius.circular(10),
                          //   ),
                          //   child: Row(
                          //     crossAxisAlignment: CrossAxisAlignment.start,
                          //     children: [
                          //       Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textColor.withOpacity(0.5)),
                          //       const SizedBox(width: 6),
                          //       Expanded(
                          //         child: Text(
                          //           visitor.reasonForVisit!,
                          //           style: TextStyle(
                          //             fontSize: 12,
                          //             color: AppTheme.textColor.withOpacity(0.7),
                          //           ),
                          //           maxLines: 2,
                          //           overflow: TextOverflow.ellipsis,
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        // ],
                        // if (visitor.vehicleNumber != null && visitor.vehicleNumber!.isNotEmpty) ...[
                        //   const SizedBox(height: 4),
                        //   Row(
                        //     children: [
                        //       Icon(Icons.directions_car_outlined, size: 14, color: AppTheme.textColor.withOpacity(0.5)),
                        //       const SizedBox(width: 4),
                        //       Text(
                        //         visitor.vehicleNumber!,
                        //         style: TextStyle(
                        //           fontSize: 12,
                        //           color: AppTheme.textColor.withOpacity(0.6),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.dividerColor.withOpacity(0.8)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Details',
                      color: AppTheme.primaryColor,
                      onTap: onViewDetails,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.close_rounded,
                      label: 'Deny',
                      color: const Color(0xFFEF4444),
                      onTap: onReject,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _ActionButton(
                      icon: Icons.check_circle_rounded,
                      label: 'Approve',
                      color: const Color(0xFF10B981),
                      onTap: onApprove,
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarIcon() {
    return Icon(Icons.person_rounded, size: 32, color: AppTheme.primaryColor.withOpacity(0.7));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: outlined ? Border.all(color: color.withOpacity(0.5)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
