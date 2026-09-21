import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/utils/current_property_context.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/admin_bloc.dart';
import 'tabs/users_tab.dart' show showAdminUserDetails;

Future<void> _launchUserPhone(BuildContext context, String mobileNumber) async {
  final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final uri = Uri.parse('tel:$digits');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place call: $e')),
      );
    }
  }
}

/// Full-screen user list opened from Overview "Total Users" stat card.
class AdminUsersListPage extends StatefulWidget {
  final PropertyType? propertyType;
  final ApartmentModel? apartment;

  const AdminUsersListPage({
    super.key,
    this.propertyType,
    this.apartment,
  });

  @override
  State<AdminUsersListPage> createState() => _AdminUsersListPageState();
}

class _AdminUsersListPageState extends State<AdminUsersListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<AdminBloc>().add(LoadAllUsersEvent());
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  bool _matchesSearch(UserModel user) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return user.name.toLowerCase().contains(q) ||
        user.email.toLowerCase().contains(q) ||
        (user.block != null && user.block!.toLowerCase().contains(q)) ||
        (user.floor != null && user.floor!.toLowerCase().contains(q)) ||
        (user.roomNumber != null && user.roomNumber!.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final viewer = authState is AuthAuthenticated ? authState.user : null;
    final showUserMobile = shouldShowUserMobileForViewer(
      showUserMobileSetting: widget.apartment?.showUserMobile ?? true,
      loginRole: viewer?.loginRole,
      isHostel: false,
      viewerUserType: viewer?.userType,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Users'),
        elevation: 0,
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (previous, current) =>
            current is AdminLoaded || previous is AdminLoaded,
        builder: (context, state) {
          if (state is! AdminLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = state.regularUsers.where(_matchesSearch).toList();
          final totalCount = state.regularUsers.length;

          return RefreshIndicator(
            onRefresh: _refresh,
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
                        Text(
                          '$totalCount ${totalCount == 1 ? 'user' : 'users'} total',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: widget.propertyType == PropertyType.events
                                ? 'Search by name or email'
                                : 'Search by name, email, block, floor, or room',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade500,
                            ),
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
                              borderSide:
                                  const BorderSide(color: AppTheme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppTheme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${users.length} result${users.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (users.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppTheme.textColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No users match your search'
                                  : 'No users yet',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textColor.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _UserOverviewCard(
                          user: users[index],
                          propertyType: widget.propertyType,
                          showUserMobile: showUserMobile,
                          onTap: () => showAdminUserDetails(
                            context,
                            users[index],
                            propertyType: widget.propertyType,
                            apartment: widget.apartment,
                          ),
                        ),
                        childCount: users.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserOverviewCard extends StatelessWidget {
  final UserModel user;
  final PropertyType? propertyType;
  final bool showUserMobile;
  final VoidCallback onTap;

  const _UserOverviewCard({
    required this.user,
    required this.propertyType,
    required this.showUserMobile,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ({String label, Color color}) _statusInfo() {
    if (!user.isActive) {
      return (label: 'Deactivated', color: AppTheme.errorColor);
    }
    switch (user.status) {
      case AccountStatus.approved:
        return (label: 'Approved', color: AppTheme.secondaryColor);
      case AccountStatus.pending:
        return (label: 'Pending', color: AppTheme.accentColor);
      case AccountStatus.rejected:
        return (label: 'Rejected', color: AppTheme.errorColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo();
    final assignment = formatUserAssignmentDisplay(
      user,
      propertyType: propertyType,
    );
    final isAssigned = assignment != 'Not assigned';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
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
            CircleAvatar(
              radius: 24,
              backgroundColor: status.color.withOpacity(0.15),
              child: Text(
                _initials(user.name),
                style: TextStyle(
                  color: status.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
                          user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusPill(label: status.label, color: status.color),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: AppTheme.textColor.withOpacity(0.4),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textColor.withOpacity(0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (propertyType != PropertyType.events) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? AppTheme.primaryColor.withOpacity(0.08)
                            : AppTheme.accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAssigned
                                ? Icons.door_front_door_outlined
                                : Icons.location_off_outlined,
                            size: 14,
                            color: isAssigned
                                ? AppTheme.primaryColor.withOpacity(0.85)
                                : AppTheme.accentColor.withOpacity(0.85),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              assignment,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAssigned
                                    ? AppTheme.primaryColor.withOpacity(0.9)
                                    : AppTheme.accentColor.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showUserMobile && user.mobileNumber.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Material(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _launchUserPhone(context, user.mobileNumber),
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.call,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
