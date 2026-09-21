import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/config/api_config.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../core/widgets/identity_document_card.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/models/user_property_document_model.dart';
import '../../../../../core/models/block_model.dart';
import '../../../../../core/hostel_sharing.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/utils/current_property_context.dart';
import '../../../../../core/utils/room_occupants.dart';
import '../../../../../core/utils/unit_labels.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/admin_bloc.dart';

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

class UsersTab extends StatefulWidget {
  final AdminLoaded state;
  final ApartmentModel? apartment;

  const UsersTab({required this.state, this.apartment});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0;
  final Set<String> _expandedAssignedKeys = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _resolveShowUserMobile() {
    final authState = context.read<AuthBloc>().state;
    final viewer = authState is AuthAuthenticated ? authState.user : null;
    return shouldShowUserMobileForViewer(
      showUserMobileSetting: widget.apartment?.showUserMobile ?? true,
      loginRole: viewer?.loginRole,
      isHostel: widget.apartment?.propertyType == PropertyType.hostel,
      viewerUserType: viewer?.userType,
    );
  }

  List<UserModel> _getSortedUsers(List<UserModel> users) {
    if (_searchQuery.isEmpty) {
      return users;
    }
    
    final query = _searchQuery.toLowerCase();
    final matchingUsers = <UserModel>[];
    final nonMatchingUsers = <UserModel>[];
    
    for (final user in users) {
      final matches = user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.mobileNumber.toLowerCase().contains(query) ||
          (user.username.isNotEmpty && user.username.toLowerCase().contains(query)) ||
          (user.block != null && user.block!.toLowerCase().contains(query)) ||
          (user.roomNumber != null && user.roomNumber!.toLowerCase().contains(query));
      
      if (matches) {
        matchingUsers.add(user);
      } else {
        nonMatchingUsers.add(user);
      }
    }
    
    return [...matchingUsers, ...nonMatchingUsers];
  }

  bool _isUserApprovedOrAssigned(UserModel u) {
    if (widget.apartment?.propertyType == PropertyType.college ||
        widget.apartment?.propertyType == PropertyType.events) {
      return u.status == AccountStatus.approved && u.isActive;
    }
    return isUserAssigned(u);
  }

  List<UserModel> _usersForTab(List<UserModel> allUsers) {
    switch (_tabIndex) {
      case 0:
        return allUsers.where(_isUserApprovedOrAssigned).toList();
      case 1:
        return allUsers.where((u) => u.status == AccountStatus.pending).toList();
      case 2:
        return allUsers.where((u) => !u.isActive).toList();
      default:
        return allUsers;
    }
  }

  void _openAddUser(BuildContext context) {
    final blocState = context.read<AdminBloc>().state;
    final apartmentId =
        blocState is AdminLoaded ? blocState.selectedApartmentId : null;
    final propertyType = widget.apartment?.propertyType.name;
    Navigator.pushNamed(
      context,
      AppRoutes.userRegistration,
      arguments: {
        'fromAdmin': true,
        if (apartmentId != null) 'apartmentId': apartmentId,
        if (propertyType != null) 'propertyType': propertyType,
      },
    ).then((_) {
      if (context.mounted) {
        context.read<AdminBloc>().add(LoadAllUsersEvent());
      }
    });
  }

  bool _userMatchesSearch(UserModel user) {
    if (_searchQuery.isEmpty) return false;
    final q = _searchQuery.toLowerCase();
    return user.name.toLowerCase().contains(q) ||
        user.email.toLowerCase().contains(q) ||
        user.mobileNumber.toLowerCase().contains(q) ||
        (user.username.isNotEmpty && user.username.toLowerCase().contains(q)) ||
        (user.block != null && user.block!.toLowerCase().contains(q)) ||
        (user.floor != null && user.floor!.toLowerCase().contains(q)) ||
        (user.roomNumber != null && user.roomNumber!.toLowerCase().contains(q));
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (_tabIndex == 0 && value.isNotEmpty) {
        final isHostel =
            widget.apartment?.propertyType == PropertyType.hostel;
        final tree = buildAssignedUsersTree(
          users: widget.state.regularUsers.where(isUserAssigned).where(_userMatchesSearch).toList(),
          blocks: widget.state.blocks,
          isHostel: isHostel,
        );
        _expandedAssignedKeys
          ..clear()
          ..addAll(collectAssignedExpansionKeys(tree));
      } else if (value.isEmpty) {
        _expandedAssignedKeys.clear();
      }
    });
  }

  void _onAssignedExpansionChanged(String key, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedAssignedKeys.add(key);
      } else {
        _expandedAssignedKeys.remove(key);
      }
    });
  }

  Widget _buildUserListCard({
    required UserModel user,
    required List<UserModel> allRegularUsers,
    required bool isWarden,
    bool showRoomBadge = true,
  }) {
    return _UserListCard(
      user: user,
      isSearchHighlight: _userMatchesSearch(user),
      hasRoom: user.block != null &&
          user.floor != null &&
          user.roomNumber != null,
      showRoomBadge: showRoomBadge,
      showUserMobile: _resolveShowUserMobile(),
      propertyType: widget.apartment?.propertyType,
      onTap: () => _showUserDetails(
        context,
        user,
        propertyType: widget.apartment?.propertyType,
        apartment: widget.apartment,
      ),
      onMenuSelected: (value) => _onUserMenuSelected(
        context,
        user,
        value,
        allRegularUsers: allRegularUsers,
      ),
    );
  }

  void _onUserMenuSelected(
    BuildContext context,
    UserModel user,
    String value, {
    required List<UserModel> allRegularUsers,
  }) {
    if (value == 'details') {
      _showUserDetails(
        context,
        user,
        propertyType: widget.apartment?.propertyType,
        apartment: widget.apartment,
      );
    } else if (value == 'edit') {
      _openEditUser(
        context,
        user,
        propertyType: widget.apartment?.propertyType,
        apartment: widget.apartment,
      );
    } else if (value == 'approve') {
      if (widget.apartment?.propertyType == PropertyType.college ||
          widget.apartment?.propertyType == PropertyType.events) {
        _approveStaffDirectly(context, user);
      } else {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ApprovalBottomSheet(
            tenant: user,
            initialBlocks: widget.state.blocks,
            assignedUsers: allRegularUsers,
            scopedApartmentId: widget.state.selectedApartmentId ?? widget.apartment?.id,
            propertyType: widget.apartment?.propertyType,
          ),
        );
      }
    } else if (value == 'reassign') {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ReassignBottomSheet(
          tenant: user,
          initialBlocks: widget.state.blocks,
          assignedUsers: allRegularUsers,
          scopedApartmentId: widget.state.selectedApartmentId ?? widget.apartment?.id,
          propertyType: widget.apartment?.propertyType,
        ),
      );
    } else if (value == 'toggle_active') {
      context.read<AdminBloc>().add(ToggleUserActiveEvent(user.id));
    } else if (value == 'delete') {
      _showDeleteUserDialog(context, user);
    }
  }

  Future<void> _approveStaffDirectly(BuildContext context, UserModel user) async {
    final apartmentId = widget.state.selectedApartmentId ?? widget.apartment?.id;
    final api = ApiService();
    try {
      final res = await api.updateUserStatus(
        user.id,
        AccountStatus.approved.name,
        apartmentId: apartmentId,
      );
      if (!context.mounted) return;
      if (res['success'] == true) {
        context.read<AdminBloc>().add(LoadAllUsersEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff approved successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to approve staff'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve staff: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showDeleteUserDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textColor),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminBloc>().add(DeleteUserEvent(user.id));
              Navigator.pop(ctx);
            },
            style: AppTheme.errorElevatedStyle,
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final isWarden = authState is AuthAuthenticated && authState.user.loginRole == 'warden';

    final addLabel = widget.apartment?.propertyType == PropertyType.company
        ? 'Create Company'
        : widget.apartment?.propertyType == PropertyType.events
            ? 'Add Event Staff'
            : 'Add User';

    final currentState = widget.state;
    final allRegularUsers = currentState.regularUsers;
        final pendingCount = allRegularUsers
            .where((u) => u.status == AccountStatus.pending)
            .length;
        final assignedCount = allRegularUsers.where(_isUserApprovedOrAssigned).length;
        final deactiveCount = allRegularUsers.where((u) => !u.isActive).length;
        final totalCount = allRegularUsers.length;

        final tabUsers = _usersForTab(allRegularUsers);
        final sortedUsers = _getSortedUsers(tabUsers);
        final visibleUsers = _searchQuery.isEmpty
            ? sortedUsers
            : sortedUsers.where(_userMatchesSearch).toList();
        final isHostel =
            widget.apartment?.propertyType == PropertyType.hostel;
        final isSchoolOrCollege = widget.apartment?.propertyType == PropertyType.college ||
            widget.apartment?.propertyType == PropertyType.events;
        final assignedTree = (_tabIndex == 0 && !isSchoolOrCollege)
            ? buildAssignedUsersTree(
                users: visibleUsers,
                blocks: currentState.blocks,
                isHostel: isHostel,
              )
            : null;
        final showAssignedHierarchy =
            _tabIndex == 0 && !isSchoolOrCollege && assignedTree != null && !assignedTree.isEmpty;

        return Container(
          color: const Color(0xFFFAFAF9),
          child: Column(
            children: [
              // Header with stats and create button (identical to Blocks tab)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                color: const Color(0xFFFAFAF9),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildUsersStatCard(
                            icon: Icons.hourglass_top_rounded,
                            label: 'Pending',
                            value: '$pendingCount',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUsersStatCard(
                            icon: Icons.home_work_rounded,
                            label: widget.apartment?.propertyType == PropertyType.college ||
                                    widget.apartment?.propertyType == PropertyType.events
                                ? 'Approved'
                                : 'Assigned',
                            value: '$assignedCount',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUsersStatCard(
                            icon: Icons.person_off_outlined,
                            label: 'Inactive',
                            value: '$deactiveCount',
                          ),
                        ),
                      ],
                    ),
                    if (widget.apartment?.addUserEnabled ?? false) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final apartmentId = widget.state.selectedApartmentId ?? widget.apartment?.id;
                                if (apartmentId == null || apartmentId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Apartment ID not available')),
                                  );
                                  return;
                                }
                                final aptPropType = widget.apartment?.propertyType;
                                final joinUrl = aptPropType == PropertyType.college
                                    ? '${ApiConfig.publicWebBaseUrl}/join/$apartmentId?propertyType=college&type=college'
                                    : aptPropType == PropertyType.events
                                        ? '${ApiConfig.publicWebBaseUrl}/join/$apartmentId?propertyType=events'
                                        : '${ApiConfig.publicWebBaseUrl}/join/$apartmentId';
                                Clipboard.setData(ClipboardData(text: joinUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Public Registration Link Copied: $joinUrl'),
                                    backgroundColor: const Color(0xFF13275D),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF13275D), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.link_rounded,
                                      color: Color(0xFF13275D),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Copy Link',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF13275D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openAddUser(context),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF13275D), Color(0xFF1E3A8A)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF13275D).withOpacity(0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '＋ ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      addLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (totalCount > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search name, email, mobile, room...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8C8C90),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF8C8C90),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: Color(0xFF8C8C90),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECECEA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFECECEA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _UsersFilterChips(
                  selectedIndex: _tabIndex,
                  pendingCount: pendingCount,
                  assignedCount: assignedCount,
                  deactiveCount: deactiveCount,
                  propertyType: widget.apartment?.propertyType,
                  onSelected: (index) {
                    setState(() {
                      _tabIndex = index;
                      if (index != 0) {
                        _expandedAssignedKeys.clear();
                      } else if (_searchQuery.isNotEmpty) {
                        final tree = buildAssignedUsersTree(
                          users: allRegularUsers
                              .where(isUserAssigned)
                              .where(_userMatchesSearch)
                              .toList(),
                          blocks: currentState.blocks,
                          isHostel: isHostel,
                        );
                        _expandedAssignedKeys
                          ..clear()
                          ..addAll(collectAssignedExpansionKeys(tree));
                      }
                    });
                  },
                ),
              ),
            ],
            Expanded(
              child: totalCount == 0
                  ? _UsersEmptyState(
                      addLabel: addLabel == 'Add User'
                          ? 'Add First User'
                          : addLabel,
                      onAdd: () => _openAddUser(context),
                      showAddButton: widget.apartment?.addUserEnabled ?? false,
                    )
                  : visibleUsers.isEmpty
                      ? _UsersNoResultsState(
                          isSearch: _searchQuery.isNotEmpty,
                          query: _searchQuery,
                          tabLabel: _tabLabel(_tabIndex),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryColor,
                          onRefresh: () async {
                            context.read<AdminBloc>().add(LoadAllUsersEvent());
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                          },
                          child: showAssignedHierarchy
                              ? _AssignedUsersHierarchyList(
                                  tree: assignedTree,
                                  showBlockLevel: assignedTree.blocks.length > 1,
                                  expandedKeys: _expandedAssignedKeys,
                                  onExpansionChanged: _onAssignedExpansionChanged,
                                  isHostel: isHostel,
                                  propertyType: widget.apartment?.propertyType,
                                  buildUserCard: (user) => _buildUserListCard(
                                    user: user,
                                    allRegularUsers: allRegularUsers,
                                    isWarden: isWarden,
                                    showRoomBadge: false,
                                  ),
                                  buildOtherUserCard: (user) => _buildUserListCard(
                                    user: user,
                                    allRegularUsers: allRegularUsers,
                                    isWarden: isWarden,
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                  itemCount: visibleUsers.length,
                                  itemBuilder: (context, index) {
                                    return _buildUserListCard(
                                      user: visibleUsers[index],
                                      allRegularUsers: allRegularUsers,
                                      isWarden: isWarden,
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      );
  }

  String _tabLabel(int index) {
    switch (index) {
      case 0:
        return widget.apartment?.propertyType == PropertyType.college ||
                widget.apartment?.propertyType == PropertyType.events
            ? 'Approved'
            : 'Assigned';
      case 1:
        return 'Pending';
      case 2:
        return 'Inactive';
      default:
        return 'All';
    }
  }
}

// ——— Users tab UI components ———

  Widget _buildUsersStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF13275D).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF13275D), size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF8C8C90),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

class _UsersStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _UsersStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
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

class _UsersSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _UsersSearchField({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEA)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search name, email, mobile, room…',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF13275D),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _UsersFilterChips extends StatelessWidget {
  final int selectedIndex;
  final int pendingCount;
  final int assignedCount;
  final int deactiveCount;
  final ValueChanged<int> onSelected;

  final PropertyType? propertyType;

  const _UsersFilterChips({
    required this.selectedIndex,
    required this.pendingCount,
    required this.assignedCount,
    required this.deactiveCount,
    required this.onSelected,
    this.propertyType,
  });

  static const _filters = [
    (icon: Icons.home_work_rounded, label: 'Assigned', color: Color(0xFF13275D)),
    (icon: Icons.hourglass_top_rounded, label: 'Pending', color: Color(0xFF13275D)),
    (icon: Icons.person_off_outlined, label: 'Inactive', color: Color(0xFF13275D)),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = [assignedCount, pendingCount, deactiveCount];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
            shadowColor: f.color.withOpacityCompat(0.35),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? f.color
                        : AppTheme.dividerColor.withOpacityCompat(0.8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.icon,
                      size: 16,
                      color: selected ? Colors.white : f.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      index == 0 &&
                              (propertyType == PropertyType.college ||
                                  propertyType == PropertyType.events)
                          ? 'Approved'
                          : f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : AppTheme.textColor.withOpacityCompat(0.75),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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

class _AssignedUsersHierarchyList extends StatelessWidget {
  final AssignedUsersTreeResult tree;
  final bool showBlockLevel;
  final Set<String> expandedKeys;
  final void Function(String key, bool expanded) onExpansionChanged;
  final bool isHostel;
  final PropertyType? propertyType;
  final Widget Function(UserModel user) buildUserCard;
  final Widget Function(UserModel user) buildOtherUserCard;

  const _AssignedUsersHierarchyList({
    required this.tree,
    required this.showBlockLevel,
    required this.expandedKeys,
    required this.onExpansionChanged,
    required this.isHostel,
    this.propertyType,
    required this.buildUserCard,
    required this.buildOtherUserCard,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showBlockLevel) {
      for (final blockNode in tree.blocks) {
        children.add(
          _AssignedBlockExpansion(
            blockNode: blockNode,
            expandedKeys: expandedKeys,
            onExpansionChanged: onExpansionChanged,
            isHostel: isHostel,
            propertyType: propertyType,
            buildUserCard: buildUserCard,
          ),
        );
      }
    } else {
      for (final blockNode in tree.blocks) {
        for (final floorNode in blockNode.floors) {
          children.add(
            _AssignedFloorExpansion(
              blockId: blockNode.block.id,
              floorNode: floorNode,
              expandedKeys: expandedKeys,
              onExpansionChanged: onExpansionChanged,
              isHostel: isHostel,
              propertyType: propertyType,
              buildUserCard: buildUserCard,
            ),
          );
        }
      }
    }

    if (tree.unmatchedUsers.isNotEmpty) {
      children.add(
        _AssignedOtherSection(
          users: tree.unmatchedUsers,
          buildUserCard: buildOtherUserCard,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: children,
    );
  }
}

class _AssignedHierarchyCard extends StatelessWidget {
  final Widget child;

  const _AssignedHierarchyCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: child,
        ),
      ),
    );
  }
}

class _AssignedBlockExpansion extends StatelessWidget {
  final AssignedBlockNode blockNode;
  final Set<String> expandedKeys;
  final void Function(String key, bool expanded) onExpansionChanged;
  final bool isHostel;
  final PropertyType? propertyType;
  final Widget Function(UserModel user) buildUserCard;

  const _AssignedBlockExpansion({
    required this.blockNode,
    required this.expandedKeys,
    required this.onExpansionChanged,
    required this.isHostel,
    this.propertyType,
    required this.buildUserCard,
  });

  @override
  Widget build(BuildContext context) {
    final key = assignedBlockExpansionKey(blockNode.block.id);
    final isExpanded = expandedKeys.contains(key);

    return _AssignedHierarchyCard(
      child: ExpansionTile(
        key: ValueKey('$key-$isExpanded'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) => onExpansionChanged(key, expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF13275D).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: Color(0xFF13275D),
            size: 22,
          ),
        ),
        title: Text(
          blockNode.block.name,
          style: GoogleFonts.sora(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          '${blockNode.userCount} user${blockNode.userCount == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8C8C90),
          ),
        ),
        children: blockNode.floors
            .map(
              (floorNode) => _AssignedFloorExpansion(
                blockId: blockNode.block.id,
                floorNode: floorNode,
                expandedKeys: expandedKeys,
                onExpansionChanged: onExpansionChanged,
                isHostel: isHostel,
                propertyType: propertyType,
                buildUserCard: buildUserCard,
                nested: true,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AssignedFloorExpansion extends StatelessWidget {
  final String blockId;
  final AssignedFloorNode floorNode;
  final Set<String> expandedKeys;
  final void Function(String key, bool expanded) onExpansionChanged;
  final bool isHostel;
  final PropertyType? propertyType;
  final Widget Function(UserModel user) buildUserCard;
  final bool nested;

  const _AssignedFloorExpansion({
    required this.blockId,
    required this.floorNode,
    required this.expandedKeys,
    required this.onExpansionChanged,
    required this.isHostel,
    this.propertyType,
    required this.buildUserCard,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final key = assignedFloorExpansionKey(blockId, floorNode.floor.id);
    final isExpanded = expandedKeys.contains(key);
    final roomCount = floorNode.rooms.length;
    final userCount = floorNode.userCount;

    final tile = ExpansionTile(
      key: ValueKey('$key-$isExpanded'),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (expanded) => onExpansionChanged(key, expanded),
      tilePadding: EdgeInsets.fromLTRB(nested ? 10 : 16, 6, 12, 6),
      childrenPadding: EdgeInsets.fromLTRB(nested ? 6 : 10, 0, nested ? 6 : 10, 10),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF13275D).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.layers_rounded,
          color: Color(0xFF13275D),
          size: 20,
        ),
      ),
      title: Text(
        floorNode.floor.number,
        style: GoogleFonts.sora(
          fontWeight: FontWeight.bold,
          fontSize: 14.5,
          color: const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        '$roomCount room${roomCount == 1 ? '' : 's'} · $userCount user${userCount == 1 ? '' : 's'}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF8C8C90),
        ),
      ),
      children: floorNode.rooms
          .map(
            (roomNode) => _AssignedRoomExpansion(
              blockId: blockId,
              floorId: floorNode.floor.id,
              roomNode: roomNode,
              expandedKeys: expandedKeys,
              onExpansionChanged: onExpansionChanged,
              isHostel: isHostel,
              propertyType: propertyType,
              buildUserCard: buildUserCard,
            ),
          )
          .toList(),
    );

    if (nested) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEA)),
        ),
        child: tile,
      );
    }

    return _AssignedHierarchyCard(child: tile);
  }
}

class _AssignedRoomExpansion extends StatelessWidget {
  final String blockId;
  final String floorId;
  final AssignedRoomNode roomNode;
  final Set<String> expandedKeys;
  final void Function(String key, bool expanded) onExpansionChanged;
  final bool isHostel;
  final PropertyType? propertyType;
  final Widget Function(UserModel user) buildUserCard;

  const _AssignedRoomExpansion({
    required this.blockId,
    required this.floorId,
    required this.roomNode,
    required this.expandedKeys,
    required this.onExpansionChanged,
    required this.isHostel,
    this.propertyType,
    required this.buildUserCard,
  });

  @override
  Widget build(BuildContext context) {
    final key = assignedRoomExpansionKey(blockId, floorId, roomNode.room.id);
    final isExpanded = expandedKeys.contains(key);
    final count = roomNode.occupants.length;
    final subtitle = isHostel && count > 0
        ? '$count occupant${count == 1 ? '' : 's'}'
        : roomNode.room.type;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('$key-$isExpanded'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) => onExpansionChanged(key, expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF13275D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              usesHouseNoLabel(propertyType)
                  ? Icons.home_rounded
                  : Icons.door_front_door_rounded,
              size: 18,
              color: const Color(0xFF13275D),
            ),
          ),
          title: Text(
            '${unitLeafShort(propertyType)} ${roomNode.room.number}',
            style: GoogleFonts.sora(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8C8C90),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF059669),
              ),
            ),
          ),
          children: roomNode.occupants.map(buildUserCard).toList(),
        ),
      ),
    );
  }
}

class _AssignedOtherSection extends StatelessWidget {
  final List<UserModel> users;
  final Widget Function(UserModel user) buildUserCard;

  const _AssignedOtherSection({
    required this.users,
    required this.buildUserCard,
  });

  @override
  Widget build(BuildContext context) {
    return _AssignedHierarchyCard(
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: Color(0xFFD97706),
            size: 22,
          ),
        ),
        title: Text(
          'Other assignments',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          '${users.length} user${users.length == 1 ? '' : 's'} not matched to current block data',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF8C8C90),
          ),
        ),
        children: users.map(buildUserCard).toList(),
      ),
    );
  }
}

class _UserListCard extends StatelessWidget {
  final UserModel user;
  final bool isSearchHighlight;
  final bool hasRoom;
  final bool showRoomBadge;
  final bool showUserMobile;
  final PropertyType? propertyType;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  const _UserListCard({
    required this.user,
    required this.isSearchHighlight,
    required this.hasRoom,
    this.showRoomBadge = true,
    required this.showUserMobile,
    this.propertyType,
    required this.onTap,
    required this.onMenuSelected,
  });

  Color _statusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.approved:
        return const Color(0xFF10B981);
      case AccountStatus.pending:
        return const Color(0xFFF59E0B);
      case AccountStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  String _statusLabel(AccountStatus status) {
    switch (status) {
      case AccountStatus.approved:
        return 'Approved';
      case AccountStatus.pending:
        return 'Pending';
      case AccountStatus.rejected:
        return 'Rejected';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<PopupMenuEntry<String>> _menuItems() {
    final items = <PopupMenuItem<String>>[
      const PopupMenuItem(
        value: 'details',
        child: _MenuRow(
          icon: Icons.person_outline_rounded,
          label: 'View details',
          color: Color(0xFF13275D),
        ),
      ),
      const PopupMenuItem(
        value: 'edit',
        child: _MenuRow(
          icon: Icons.edit_rounded,
          label: 'Edit user',
          color: Color(0xFF13275D),
        ),
      ),
    ];
    if (user.status == AccountStatus.pending) {
      items.add(
        PopupMenuItem(
          value: 'approve',
          child: _MenuRow(
            icon: Icons.check_circle_rounded,
            label: approveAndAssignActionLabel(propertyType),
            color: const Color(0xFF10B981),
          ),
        ),
      );
    }
    if (user.status == AccountStatus.approved && hasRoom) {
      items.add(
        PopupMenuItem(
          value: 'reassign',
          child: _MenuRow(
            icon: Icons.swap_horiz_rounded,
            label: reassignActionLabel(propertyType),
            color: const Color(0xFF13275D),
          ),
        ),
      );
    }
    items.add(
      PopupMenuItem(
        value: 'toggle_active',
        child: _MenuRow(
          icon: user.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
          label: user.isActive ? 'Deactivate user' : 'Activate user',
          color: const Color(0xFF13275D),
        ),
      ),
    );
    items.add(
      const PopupMenuItem(
        value: 'delete',
        child: _MenuRow(
          icon: Icons.delete_outline_rounded,
          label: 'Delete user',
          color: Color(0xFFEF4444),
        ),
      ),
    );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(user.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSearchHighlight
              ? const Color(0xFF13275D)
              : const Color(0xFFECECEA),
          width: isSearchHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF13275D).withOpacity(0.12),
                      backgroundImage: user.profilePic != null &&
                              user.profilePic!.isNotEmpty
                          ? NetworkImage(user.profilePic!)
                          : null,
                      child: user.profilePic == null || user.profilePic!.isEmpty
                          ? Text(
                              _initials(user.name),
                              style: GoogleFonts.sora(
                                color: const Color(0xFF13275D),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: GoogleFonts.sora(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: _statusLabel(user.status),
                            color: statusColor,
                          ),
                        ],
                      ),
                      if (user.username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF8C8C90),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        text: user.email,
                      ),
                      if (user.mobileNumber.isNotEmpty && showUserMobile) ...[
                        const SizedBox(height: 4),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          text: user.mobileNumber,
                        ),
                      ],
                      if (hasRoom &&
                          showRoomBadge &&
                          propertyType != PropertyType.college &&
                          propertyType != PropertyType.events) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13275D).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.door_front_door_outlined,
                                size: 14,
                                color: Color(0xFF13275D),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  formatUserUnitAssignment(user),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF13275D),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (user.status == AccountStatus.approved &&
                          showRoomBadge &&
                          propertyType != PropertyType.college &&
                          propertyType != PropertyType.events) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Room not assigned',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFFD97706),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showUserMobile && user.mobileNumber.trim().isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.call,
                        size: 16,
                        color: Color(0xFF13275D),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _launchUserPhone(context, user.mobileNumber),
                      tooltip: 'Call User',
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Color(0xFF8C8C90),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => _menuItems(),
                  onSelected: onMenuSelected,
                ),
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
  final bool onDark;

  const _StatusPill({
    required this.label,
    required this.color,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (onDark) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(36),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
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
        Icon(
          icon,
          size: 14,
          color: AppTheme.textColor.withOpacityCompat(0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textColor.withOpacityCompat(0.65),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  final String addLabel;
  final VoidCallback onAdd;
  final bool showAddButton;

  const _UsersEmptyState({
    required this.addLabel,
    required this.onAdd,
    required this.showAddButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.brandSoftSurfaceGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 56,
                color: AppTheme.primaryColor.withOpacityCompat(0.5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No users yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add residents or companies to start managing approvals and room assignments.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textColor.withOpacityCompat(0.55),
              ),
            ),
            const SizedBox(height: 24),
            if (showAddButton)
              BrandGradientCtaButton(
                label: addLabel,
                icon: Icons.person_add_alt_1_rounded,
                height: 48,
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    );
  }
}

class _UsersNoResultsState extends StatelessWidget {
  final bool isSearch;
  final String query;
  final String tabLabel;

  const _UsersNoResultsState({
    required this.isSearch,
    required this.query,
    required this.tabLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.filter_list_off_rounded,
              size: 48,
              color: AppTheme.textColor.withOpacityCompat(0.25),
            ),
            const SizedBox(height: 14),
            Text(
              isSearch ? 'No matches found' : 'No $tabLabel users',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Nothing matches "$query". Try another name, email, or room.'
                  : 'Users in this category will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textColor.withOpacityCompat(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openEditUser(
  BuildContext context,
  UserModel user, {
  PropertyType? propertyType,
  ApartmentModel? apartment,
  bool reopenDetails = false,
}) {
  Navigator.pushNamed(
    context,
    AppRoutes.editUser,
    arguments: {
      'user': user,
      if (propertyType != null) 'propertyType': propertyType,
    },
  ).then((result) {
    if (!context.mounted) return;
    context.read<AdminBloc>().add(LoadAllUsersEvent());
    if (reopenDetails && result is UserModel) {
      showAdminUserDetails(
        context,
        result,
        propertyType: propertyType,
        apartment: apartment,
      );
    }
  });
}

void showAdminUserDetails(
  BuildContext context,
  UserModel user, {
  PropertyType? propertyType,
  ApartmentModel? apartment,
}) {
  _showUserDetails(
    context,
    user,
    propertyType: propertyType,
    apartment: apartment,
  );
}

void _showUserDetails(
  BuildContext context,
  UserModel user, {
  PropertyType? propertyType,
  ApartmentModel? apartment,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UserDetailsSheet(
      user: user,
      propertyType: propertyType,
      apartment: apartment,
      onEdit: () {
        Navigator.pop(ctx);
        _openEditUser(
          context,
          user,
          propertyType: propertyType,
          apartment: apartment,
          reopenDetails: true,
        );
      },
    ),
  );
}

/// User profile bottom sheet with hero header and grouped info cards.
class _UserDetailsSheet extends StatelessWidget {
  final UserModel user;
  final PropertyType? propertyType;
  final ApartmentModel? apartment;
  final VoidCallback onEdit;

  const _UserDetailsSheet({
    required this.user,
    required this.onEdit,
    this.propertyType,
    this.apartment,
  });

  Color _statusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.approved:
        return AppTheme.secondaryColor;
      case AccountStatus.pending:
        return AppTheme.accentColor;
      case AccountStatus.rejected:
        return AppTheme.errorColor;
    }
  }

  String _statusLabel(AccountStatus status) {
    switch (status) {
      case AccountStatus.approved:
        return 'Approved';
      case AccountStatus.pending:
        return 'Pending';
      case AccountStatus.rejected:
        return 'Rejected';
    }
  }

  String _genderLabel(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }

  String _occupationLabel(OccupationCategory category) {
    switch (category) {
      case OccupationCategory.working:
        return 'Working';
      case OccupationCategory.student:
        return 'Student';
      case OccupationCategory.others:
        return 'Others';
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _callUser(BuildContext context) =>
      _launchUserPhone(context, user.mobileNumber);

  Future<void> _emailUser(BuildContext context) async {
    if (user.email.isEmpty) return;
    final uri = Uri.parse('mailto:${user.email}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  bool get _hasPersonalInfo =>
      user.gender != null ||
      user.familyType != null ||
      user.totalOccupants != null ||
      user.dateOfBirth != null ||
      user.occupationCategory != null ||
      (user.occupationDetails != null && user.occupationDetails!.isNotEmpty) ||
      (user.isNRI != null && user.userType == UserType.user);

  bool get _hasWorkInfo =>
      (user.department != null && user.department!.isNotEmpty) ||
      (user.employeeId != null && user.employeeId!.isNotEmpty);

  bool get _hasHostelInfo =>
      (user.hostelRoom != null && user.hostelRoom!.isNotEmpty) ||
      (user.hostelBed != null && user.hostelBed!.isNotEmpty);

  List<Widget> _buildQuickActions({
    required bool canCall,
    required bool canEmail,
    required VoidCallback onCall,
    required VoidCallback onEmail,
  }) {
    return [
      if (canCall)
        _QuickActionChip(
          icon: Icons.phone_rounded,
          label: 'Call',
          accentColor: AppTheme.primaryColor,
          onTap: onCall,
        ),
      if (canEmail)
        _QuickActionChip(
          icon: Icons.email_rounded,
          label: 'Email',
          accentColor: AppTheme.secondaryColor,
          onTap: onEmail,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(user.status);
    final authState = context.read<AuthBloc>().state;
    final viewer = authState is AuthAuthenticated ? authState.user : null;
    final showMobile = shouldShowUserMobileForViewer(
      showUserMobileSetting: apartment?.showUserMobile ?? true,
      loginRole: viewer?.loginRole,
      isHostel: apartment?.propertyType == PropertyType.hostel,
      viewerUserType: viewer?.userType,
    );
    final canCall = showMobile && user.mobileNumber.trim().isNotEmpty;
    final canEmail = user.email.trim().isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(70),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF13275D),
                            Color(0xFF1E3A8A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF13275D).withAlpha(45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withAlpha(35),
                                  minimumSize: const Size(34, 34),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(200),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(50),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white.withAlpha(40),
                                    backgroundImage: (user.profilePic != null &&
                                            user.profilePic!.isNotEmpty)
                                        ? NetworkImage(user.profilePic!)
                                        : null,
                                    child: (user.profilePic == null ||
                                            user.profilePic!.isEmpty)
                                        ? Text(
                                            _initials(user.name),
                                            style: GoogleFonts.sora(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: user.isActive
                                          ? const Color(0xFF10B981)
                                          : AppTheme.errorColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (user.username.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                '@${user.username}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _StatusPill(
                                  label: _statusLabel(user.status),
                                  color: statusColor,
                                  onDark: true,
                                ),
                                _StatusPill(
                                  label:
                                      user.isActive ? 'Active' : 'Inactive',
                                  color: user.isActive
                                      ? const Color(0xFF10B981)
                                      : AppTheme.errorColor,
                                  onDark: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final chips = _buildQuickActions(
                          canCall: canCall,
                          canEmail: canEmail,
                          onCall: () => _callUser(context),
                          onEmail: () => _emailUser(context),
                        );
                        if (chips.isEmpty) {
                          return const SizedBox(height: 8);
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: chips.length == 1
                              ? Center(
                                  child: SizedBox(
                                    width: 160,
                                    child: chips.first,
                                  ),
                                )
                              : Row(
                                  children: [
                                    for (int i = 0; i < chips.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 10),
                                      Expanded(child: chips[i]),
                                    ],
                                  ],
                                ),
                        );
                      },
                    ),
                    if (propertyType != PropertyType.events)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _AssignmentHighlightCard(
                          user: user,
                          propertyType: propertyType,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoSection(
                            title: 'Contact',
                            icon: Icons.contact_mail_outlined,
                            children: [
                              _InfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: user.email,
                                accentColor: AppTheme.primaryColor,
                                onTap: canEmail
                                    ? () => _emailUser(context)
                                    : null,
                              ),
                              if (showMobile)
                                _InfoTile(
                                  icon: Icons.phone_outlined,
                                  label: 'Mobile',
                                  value: user.mobileNumber,
                                  accentColor: AppTheme.secondaryColor,
                                  onTap: canCall
                                      ? () => _callUser(context)
                                      : null,
                                ),
                              if (user.secondaryMobileNumber != null &&
                                  user.secondaryMobileNumber!.isNotEmpty &&
                                  showMobile)
                                _InfoTile(
                                  icon: Icons.phone_android_outlined,
                                  label: 'Secondary',
                                  value: user.secondaryMobileNumber!,
                                  accentColor: AppTheme.secondaryColor,
                                ),
                            ],
                          ),
                          if (user.address != null && user.address!.isNotEmpty)
                            _InfoSection(
                              title: 'Address',
                              icon: Icons.location_on_outlined,
                              children: [
                                _InfoTile(
                                  icon: Icons.place_outlined,
                                  label: 'Address',
                                  value: user.address!,
                                  accentColor: AppTheme.accentColor,
                                  copyable: true,
                                  onCopy: () => _copyToClipboard(
                                    context,
                                    user.address!,
                                    'Address',
                                  ),
                                ),
                              ],
                            ),
                          if (_hasPersonalInfo)
                            _InfoSection(
                              title: 'Personal',
                              icon: Icons.person_outline_rounded,
                              children: [
                                if (user.gender != null)
                                  _InfoTile(
                                    icon: Icons.wc_outlined,
                                    label: 'Gender',
                                    value: _genderLabel(user.gender!),
                                    accentColor: AppTheme.primaryColor,
                                  ),
                                if (user.dateOfBirth != null)
                                  _InfoTile(
                                    icon: Icons.cake_outlined,
                                    label: 'Date of birth',
                                    value: _formatDate(user.dateOfBirth!),
                                    accentColor: AppTheme.accentColor,
                                  ),
                                if (user.occupationCategory != null)
                                  _InfoTile(
                                    icon: Icons.work_outline_rounded,
                                    label: 'Occupation',
                                    value: _occupationLabel(
                                        user.occupationCategory!),
                                    accentColor: AppTheme.primaryColor,
                                  ),
                                if (user.occupationDetails != null &&
                                    user.occupationDetails!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.description_outlined,
                                    label: 'Occupation details',
                                    value: user.occupationDetails!,
                                    accentColor: AppTheme.primaryColor,
                                  ),
                                if (user.familyType != null)
                                  _InfoTile(
                                    icon: Icons.family_restroom_outlined,
                                    label: 'Family',
                                    value: user.familyType!.name == 'family'
                                        ? 'Family'
                                        : 'Bachelor',
                                    accentColor: AppTheme.secondaryColor,
                                  ),
                                if (user.totalOccupants != null)
                                  _InfoTile(
                                    icon: Icons.people_outline,
                                    label: 'Occupants',
                                    value: user.totalOccupants.toString(),
                                    accentColor: AppTheme.secondaryColor,
                                  ),
                                if (user.isNRI != null &&
                                    user.userType == UserType.user)
                                  _InfoTile(
                                    icon: Icons.public_outlined,
                                    label: 'NRI',
                                    value: user.isNRI == true ? 'Yes' : 'No',
                                    accentColor: AppTheme.accentColor,
                                  ),
                              ],
                            ),
                          if (_hasWorkInfo)
                            _InfoSection(
                              title: 'Work',
                              icon: Icons.business_outlined,
                              children: [
                                if (user.department != null &&
                                    user.department!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.business_outlined,
                                    label: 'Department',
                                    value: user.department!,
                                    accentColor: AppTheme.primaryColor,
                                  ),
                                if (user.employeeId != null &&
                                    user.employeeId!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.badge_outlined,
                                    label: 'Employee ID',
                                    value: user.employeeId!,
                                    accentColor: AppTheme.primaryColor,
                                    copyable: true,
                                    onCopy: () => _copyToClipboard(
                                      context,
                                      user.employeeId!,
                                      'Employee ID',
                                    ),
                                  ),
                              ],
                            ),
                          if (_hasHostelInfo)
                            _InfoSection(
                              title: 'Hostel',
                              icon: Icons.hotel_outlined,
                              children: [
                                if (user.hostelRoom != null &&
                                    user.hostelRoom!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.hotel_outlined,
                                    label: 'Room',
                                    value: user.hostelRoom!,
                                    accentColor: AppTheme.secondaryColor,
                                  ),
                                if (user.hostelBed != null &&
                                    user.hostelBed!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.bed_outlined,
                                    label: 'Bed',
                                    value: user.hostelBed!,
                                    accentColor: AppTheme.secondaryColor,
                                  ),
                              ],
                            ),
                          if (user.linkedOwner != null)
                            _InfoSection(
                              title: 'Linked owner',
                              icon: Icons.link_rounded,
                              children: [
                                _LinkedOwnerCard(owner: user.linkedOwner!),
                              ],
                            ),
                          if (user.aadhaarCard != null ||
                              user.panCard != null ||
                              user.aadhaarCardFrontImage != null ||
                              user.aadhaarCardBackImage != null ||
                              user.panCardImage != null)
                            _InfoSection(
                              title: 'Documents',
                              icon: Icons.folder_outlined,
                              children: [
                                if (user.aadhaarCard != null &&
                                    user.aadhaarCard!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.credit_card_outlined,
                                    label: 'ID number',
                                    value: user.aadhaarCard!,
                                    accentColor: AppTheme.primaryColor,
                                    copyable: true,
                                    onCopy: () => _copyToClipboard(
                                      context,
                                      user.aadhaarCard!,
                                      'ID number',
                                    ),
                                  ),
                                if (user.panCard != null &&
                                    user.panCard!.isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: 'PAN',
                                    value: user.panCard!,
                                    accentColor: AppTheme.secondaryColor,
                                    copyable: true,
                                    onCopy: () => _copyToClipboard(
                                      context,
                                      user.panCard!,
                                      'PAN',
                                    ),
                                  ),
                                if (user.aadhaarCardFrontImage != null ||
                                    user.aadhaarCardBackImage != null) ...[
                                  const SizedBox(height: 8),
                                  IdentityDocumentPair(
                                    frontImageUrl: user.aadhaarCardFrontImage,
                                    backImageUrl: user.aadhaarCardBackImage,
                                    frontLabel: 'Identity card — front',
                                    backLabel: 'Identity card — back',
                                  ),
                                ],
                                if (user.panCardImage != null &&
                                    user.panCardImage!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _DocumentImageCard(
                                    label: 'PAN card',
                                    imageUrl: user.panCardImage!,
                                  ),
                                ],
                              ],
                            ),
                          _UserRequiredDocumentsSection(
                            user: user,
                            apartmentId: apartment?.id ?? user.apartmentId,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.dividerColor.withAlpha(180),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: BrandGradientCtaButton(
                  height: 50,
                  label: 'Edit profile',
                  icon: Icons.edit_rounded,
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.accentColor,
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
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECECEA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentHighlightCard extends StatelessWidget {
  final UserModel user;
  final PropertyType? propertyType;

  const _AssignmentHighlightCard({
    required this.user,
    this.propertyType,
  });

  bool get _isAssigned {
    final block = user.block?.trim() ?? '';
    final floor = user.floor?.trim() ?? '';
    final room = user.roomNumber?.trim() ?? '';
    return block.isNotEmpty || floor.isNotEmpty || room.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final assignmentLine = formatUserAssignmentDisplay(
      user,
      propertyType: propertyType,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Unit assignment',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (user.hostelBed != null &&
                      user.hostelBed!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bed_outlined,
                            size: 12,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bed ${user.hostelBed}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (!_isAssigned)
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.door_sliding_outlined,
                        size: 36,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignmentLine,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  assignmentLine,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedOwnerCard extends StatelessWidget {
  final LinkedOwnerModel owner;

  const _LinkedOwnerCard({required this.owner});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner.name,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (owner.mobileNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    owner.mobileNumber,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECECEA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool copyable;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor = AppTheme.primaryColor,
    this.onTap,
    this.copyable = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (copyable && onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: Icon(
                Icons.copy_rounded,
                size: 18,
                color: accentColor.withAlpha(180),
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Property-required documents uploaded by the resident.
class _UserRequiredDocumentsSection extends StatefulWidget {
  final UserModel user;
  final String? apartmentId;

  const _UserRequiredDocumentsSection({
    required this.user,
    this.apartmentId,
  });

  @override
  State<_UserRequiredDocumentsSection> createState() =>
      _UserRequiredDocumentsSectionState();
}

class _UserRequiredDocumentsSectionState
    extends State<_UserRequiredDocumentsSection> {
  final ApiService _apiService = ApiService();
  List<UserPropertyDocumentItemModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final apartmentId = widget.apartmentId;
    if (apartmentId == null || apartmentId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _apiService.getUserPropertyDocuments(
        userId: widget.user.id,
        apartmentId: apartmentId,
      );
      if (response['success'] == true && mounted) {
        setState(() {
          _documents = (response['documents'] as List? ?? [])
              .map(
                (e) => UserPropertyDocumentItemModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openFileUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_documents.isEmpty) return const SizedBox.shrink();

    return _InfoSection(
      title: 'Required Documents',
      icon: Icons.assignment_outlined,
      children: [
        for (final doc in _documents) ...[
          _RequiredDocumentRow(
            item: doc,
            onOpen: doc.isUploaded
                ? () => _openFileUrl(doc.submission!.fileUrl)
                : null,
            onPreviewImage: doc.isUploaded && doc.isImage
                ? () => showIdentityDocumentFullscreen(
                      context,
                      label: doc.requirementName,
                      imageUrl: doc.submission!.fileUrl,
                    )
                : null,
          ),
          if (doc != _documents.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RequiredDocumentRow extends StatelessWidget {
  final UserPropertyDocumentItemModel item;
  final VoidCallback? onOpen;
  final VoidCallback? onPreviewImage;

  const _RequiredDocumentRow({
    required this.item,
    this.onOpen,
    this.onPreviewImage,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = item.isUploaded;
    final accent = item.isPdf ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_outlined,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.requirementName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: uploaded
                      ? AppTheme.secondaryColor.withAlpha(25)
                      : AppTheme.accentColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  uploaded ? 'Uploaded' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: uploaded
                        ? AppTheme.secondaryColor
                        : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
          if (uploaded) ...[
            const SizedBox(height: 10),
            if (item.isImage)
              GestureDetector(
                onTap: onPreviewImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.submission!.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              )
            else
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.submission!.fileName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: accent.withAlpha(180),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Card that shows a document image with label; tap to view full screen.
class _DocumentImageCard extends StatelessWidget {
  final String label;
  final String imageUrl;

  const _DocumentImageCard({
    required this.label,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showIdentityDocumentFullscreen(
            context,
            label: label,
            imageUrl: imageUrl,
          ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withAlpha(35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[500],
                            size: 32,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Image failed to load',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(180),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white.withAlpha(220),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _roomHasVacancy(
  RoomModel room, {
  required String blockName,
  required String floorNumber,
  required List<UserModel> users,
  String? excludeUserId,
  bool isHostel = false,
}) {
  final capacity = roomBedCapacity(beds: room.beds, type: room.type);
  final occupants = occupantsForRoom(
    users: users,
    blockName: blockName,
    floorNumber: floorNumber,
    room: room,
    isHostel: isHostel,
    excludeUserId: excludeUserId,
  ).length;
  return occupants < capacity;
}

String _roomAssignmentLabel(
  RoomModel room, {
  required String blockName,
  required String floorNumber,
  required List<UserModel> users,
  String? excludeUserId,
  bool isHostel = false,
}) {
  final capacity = roomBedCapacity(beds: room.beds, type: room.type);
  final occupants = occupantsForRoom(
    users: users,
    blockName: blockName,
    floorNumber: floorNumber,
    room: room,
    isHostel: isHostel,
    excludeUserId: excludeUserId,
  ).length;
  final sharingLabel = bedsForHostelSharing(room.type) != null
      ? displayLabelForHostelSharing(room.type)
      : room.type;
  if (capacity > 1) {
    return '${room.number} ($sharingLabel) — $occupants/$capacity beds';
  }
  return occupants > 0
      ? '${room.number} ($sharingLabel) — occupied'
      : '${room.number} ($sharingLabel)';
}

List<BlockModel> _parseBlocksList(dynamic raw) {
  if (raw is! List) return [];
  final blocks = <BlockModel>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      blocks.add(BlockModel.fromJson(Map<String, dynamic>.from(item)));
    } catch (_) {
      // skip malformed block entries
    }
  }
  return blocks;
}

Future<void> _submitRoomAssignment({
  required BuildContext context,
  required ApiService api,
  required String userId,
  required String block,
  required String floor,
  required String roomNumber,
  required String? apartmentId,
  required ValueChanged<bool> onSubmitting,
  required String successMessage,
}) async {
  if (apartmentId == null || apartmentId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No property selected. Open this user from the property dashboard.',
        ),
        backgroundColor: AppTheme.errorColor,
      ),
    );
    return;
  }

  onSubmitting(true);
  try {
    final response = await api.updateUserStatus(
      userId,
      AccountStatus.approved.name,
      block: block,
      floor: floor,
      roomNumber: roomNumber,
      apartmentId: apartmentId,
    );
    if (!context.mounted) return;
    if (response['success'] == true) {
      context.read<AdminBloc>().add(LoadAllUsersEvent());
      context.read<AdminBloc>().add(LoadBlocksEvent());
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error']?.toString() ?? 'Failed to assign room',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to assign room: $e'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  } finally {
    if (context.mounted) onSubmitting(false);
  }
}

String? _resolveApartmentIdForUser({
  required UserModel user,
  String? scopedApartmentId,
  AdminState? adminState,
}) {
  final fromUser = user.apartmentId;
  if (fromUser != null && fromUser.isNotEmpty) return fromUser;
  if (scopedApartmentId != null && scopedApartmentId.isNotEmpty) {
    return scopedApartmentId;
  }
  if (adminState is AdminLoaded &&
      adminState.selectedApartmentId != null &&
      adminState.selectedApartmentId!.isNotEmpty) {
    return adminState.selectedApartmentId;
  }
  return null;
}

/// Bottom sheet for admin to approve a user and assign block/floor/room.
class _ApprovalBottomSheet extends StatefulWidget {
  final UserModel tenant;
  final List<BlockModel> initialBlocks;
  final List<UserModel> assignedUsers;
  final String? scopedApartmentId;
  final PropertyType? propertyType;

  const _ApprovalBottomSheet({
    required this.tenant,
    required this.initialBlocks,
    required this.assignedUsers,
    this.scopedApartmentId,
    this.propertyType,
  });

  @override
  State<_ApprovalBottomSheet> createState() => _ApprovalBottomSheetState();
}

class _ApprovalBottomSheetState extends State<_ApprovalBottomSheet> {
  final ApiService _apiService = ApiService();
  final formKey = GlobalKey<FormState>();

  List<BlockModel> _blocks = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  BlockModel? _selectedBlock;
  FloorModel? _selectedFloor;
  RoomModel? _selectedRoom;
  String? _apartmentId;

  @override
  void initState() {
    super.initState();
    final adminState = context.read<AdminBloc>().state;
    _apartmentId = _resolveApartmentIdForUser(
      user: widget.tenant,
      scopedApartmentId: widget.scopedApartmentId,
      adminState: adminState,
    );
    if (widget.initialBlocks.isNotEmpty) {
      _blocks = List<BlockModel>.from(widget.initialBlocks);
      _isLoading = false;
      _refreshBlocksFromApi();
    } else {
      _loadBlocks();
    }
  }

  Future<void> _refreshBlocksFromApi() async {
    if (_apartmentId == null || _apartmentId!.isEmpty) return;
    try {
      final response = await _apiService.getAllBlocks(apartmentId: _apartmentId);
      if (response['success'] == true && response['blocks'] != null) {
        final fresh = _parseBlocksList(response['blocks']);
        if (mounted && fresh.isNotEmpty) {
          setState(() => _blocks = fresh);
        }
      }
    } catch (_) {
      // Keep initial blocks from dashboard state.
    }
  }

  Future<void> _loadBlocks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    if (_apartmentId == null || _apartmentId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError =
              'No property selected. Open this hostel/apartment from the dashboard first.';
        });
      }
      return;
    }
    try {
      final response = await _apiService.getAllBlocks(apartmentId: _apartmentId);
      if (response['success'] == true && response['blocks'] != null) {
        final parsed = _parseBlocksList(response['blocks']);
        if (mounted) {
          setState(() {
            _blocks = parsed;
            if (parsed.isEmpty) {
              _loadError = 'No blocks found. Add blocks under the Blocks tab first.';
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _loadError = response['error']?.toString() ?? 'Failed to load blocks';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'Error loading blocks: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Approve User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign room details for ${widget.tenant.name}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _loadError!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              )
            else if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No blocks found. Add blocks under the Blocks tab first.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<BlockModel>(
                        value: _selectedBlock,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Block *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: _blocks.map((block) {
                          return DropdownMenuItem<BlockModel>(
                            value: block,
                            child: Text(
                              block.name,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (BlockModel? value) {
                          setState(() {
                            _selectedBlock = value;
                            _selectedFloor = null;
                            _selectedRoom = null;
                          });
                        },
                        validator: (value) {
                          if (value == null) return 'Please select a block';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<FloorModel>(
                        value: _selectedFloor,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Floor *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: _selectedBlock?.floors.map((floor) {
                              return DropdownMenuItem<FloorModel>(
                                value: floor,
                                child: Text(
                                  floor.number,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }).toList() ??
                            [],
                        onChanged: _selectedBlock == null
                            ? null
                            : (FloorModel? value) {
                                setState(() {
                                  _selectedFloor = value;
                                  _selectedRoom = null;
                                });
                              },
                        validator: (value) {
                          if (value == null) return 'Please select a floor';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RoomModel>(
                        value: _selectedRoom,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: InputDecoration(
                          labelText: '${unitLeafLabel(widget.propertyType)} *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: (_selectedBlock != null && _selectedFloor != null
                                ? _selectedFloor!.rooms
                                    .where(
                                      (r) => _roomHasVacancy(
                                        r,
                                        blockName: _selectedBlock!.name,
                                        floorNumber: _selectedFloor!.number,
                                        users: widget.assignedUsers,
                                        excludeUserId: widget.tenant.id,
                                      ),
                                    )
                                    .toList()
                                : [])
                            .map((room) {
                          return DropdownMenuItem<RoomModel>(
                            value: room,
                            child: Text(
                              _roomAssignmentLabel(
                                room,
                                blockName: _selectedBlock!.name,
                                floorNumber: _selectedFloor!.number,
                                users: widget.assignedUsers,
                                excludeUserId: widget.tenant.id,
                              ),
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: _selectedFloor == null
                            ? null
                            : (RoomModel? value) {
                                setState(() => _selectedRoom = value);
                              },
                        validator: (value) {
                          if (value == null) {
                            return usesHouseNoLabel(widget.propertyType)
                                ? 'Please select a house'
                                : 'Please select a room';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _blocks.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              await _submitRoomAssignment(
                                context: context,
                                api: _apiService,
                                userId: widget.tenant.id,
                                block: _selectedBlock!.name,
                                floor: _selectedFloor!.number,
                                roomNumber: _selectedRoom!.number,
                                apartmentId: _apartmentId,
                                onSubmitting: (v) => setState(() => _isSubmitting = v),
                                successMessage:
                                    'User approved and room assigned successfully.',
                              );
                            },
                      style: AppTheme.secondaryElevatedStyle.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

BlockModel? _findBlockByName(List<BlockModel> blocks, String? name) {
  if (name == null || name.isEmpty) return null;
  final target = name.trim().toLowerCase();
  for (final block in blocks) {
    if (block.name.trim().toLowerCase() == target) return block;
  }
  return null;
}

FloorModel? _findFloorByNumber(List<FloorModel> floors, String? number) {
  if (number == null || number.isEmpty) return null;
  final target = number.trim();
  for (final floor in floors) {
    if (floor.number.trim() == target) return floor;
  }
  return null;
}

RoomModel? _findRoomByNumber(List<RoomModel> rooms, String? number) {
  if (number == null || number.isEmpty) return null;
  final target = number.trim();
  for (final room in rooms) {
    if (room.number.trim() == target) return room;
  }
  return null;
}

void _applyCurrentAssignment({
  required UserModel tenant,
  required List<BlockModel> blocks,
  required void Function(
    BlockModel? block,
    FloorModel? floor,
    RoomModel? room,
  ) apply,
}) {
  final block = _findBlockByName(blocks, tenant.block);
  final floor = block == null ? null : _findFloorByNumber(block.floors, tenant.floor);
  final room = floor == null ? null : _findRoomByNumber(floor.rooms, tenant.roomNumber);
  apply(block, floor, room);
}

/// Bottom sheet for admin to reassign an already approved user to a new room.
class _ReassignBottomSheet extends StatefulWidget {
  final UserModel tenant;
  final List<BlockModel> initialBlocks;
  final List<UserModel> assignedUsers;
  final String? scopedApartmentId;
  final PropertyType? propertyType;

  const _ReassignBottomSheet({
    required this.tenant,
    required this.initialBlocks,
    required this.assignedUsers,
    this.scopedApartmentId,
    this.propertyType,
  });

  @override
  State<_ReassignBottomSheet> createState() => _ReassignBottomSheetState();
}

class _ReassignBottomSheetState extends State<_ReassignBottomSheet> {
  final ApiService _apiService = ApiService();
  final formKey = GlobalKey<FormState>();

  List<BlockModel> _blocks = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  BlockModel? _selectedBlock;
  FloorModel? _selectedFloor;
  RoomModel? _selectedRoom;
  String? _apartmentId;

  void _selectCurrentAssignment(List<BlockModel> blocks) {
    _applyCurrentAssignment(
      tenant: widget.tenant,
      blocks: blocks,
      apply: (block, floor, room) {
        _selectedBlock = block;
        _selectedFloor = floor;
        _selectedRoom = room;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final adminState = context.read<AdminBloc>().state;
    _apartmentId = _resolveApartmentIdForUser(
      user: widget.tenant,
      scopedApartmentId: widget.scopedApartmentId,
      adminState: adminState,
    );
    if (widget.initialBlocks.isNotEmpty) {
      _blocks = List<BlockModel>.from(widget.initialBlocks);
      _selectCurrentAssignment(_blocks);
      _isLoading = false;
      _refreshBlocksFromApi();
    } else {
      _loadBlocks();
    }
  }

  Future<void> _refreshBlocksFromApi() async {
    if (_apartmentId == null || _apartmentId!.isEmpty) return;
    try {
      final response = await _apiService.getAllBlocks(apartmentId: _apartmentId);
      if (response['success'] == true && response['blocks'] != null) {
        final fresh = _parseBlocksList(response['blocks']);
        if (mounted && fresh.isNotEmpty) {
          setState(() {
            _blocks = fresh;
            _selectCurrentAssignment(_blocks);
          });
        }
      }
    } catch (_) {
      // Keep dashboard blocks.
    }
  }

  Future<void> _loadBlocks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    if (_apartmentId == null || _apartmentId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'No property selected. Open this hostel/apartment from the dashboard first.';
        });
      }
      return;
    }
    try {
      final response = await _apiService.getAllBlocks(apartmentId: _apartmentId);
      if (response['success'] == true && response['blocks'] != null) {
        final blocks = _parseBlocksList(response['blocks']);
        if (!mounted) return;
        setState(() {
          _blocks = blocks;
          _selectCurrentAssignment(_blocks);
          if (blocks.isEmpty) {
            _loadError = 'No blocks found. Add blocks under the Blocks tab first.';
          }
        });
      } else if (mounted) {
        setState(() {
          _loadError = response['error']?.toString() ?? 'Failed to load blocks';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'Error loading blocks: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAssignment = formatUserUnitAssignment(widget.tenant);

    final availableRooms = (_selectedBlock != null && _selectedFloor != null)
        ? _selectedFloor!.rooms.where((r) {
            final isCurrent = r.number == widget.tenant.roomNumber &&
                _selectedBlock!.name.trim().toLowerCase() ==
                    (widget.tenant.block ?? '').trim().toLowerCase() &&
                _selectedFloor!.number.trim() ==
                    (widget.tenant.floor ?? '').trim();
            if (isCurrent) return true;
            return _roomHasVacancy(
              r,
              blockName: _selectedBlock!.name,
              floorNumber: _selectedFloor!.number,
              users: widget.assignedUsers,
              excludeUserId: widget.tenant.id,
            );
          }).toList()
        : <RoomModel>[];

    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Reassign Room',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: $currentAssignment',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _loadError!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              )
            else if (_blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No blocks found. Add blocks under the Blocks tab first.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<BlockModel>(
                        value: _selectedBlock,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Block *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: _blocks.map((block) {
                          return DropdownMenuItem<BlockModel>(
                            value: block,
                            child: Text(
                              block.name,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (BlockModel? value) {
                          setState(() {
                            _selectedBlock = value;
                            _selectedFloor = null;
                            _selectedRoom = null;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a block' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<FloorModel>(
                        value: _selectedFloor,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: const InputDecoration(
                          labelText: 'Floor *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: _selectedBlock?.floors.map((floor) {
                              return DropdownMenuItem<FloorModel>(
                                value: floor,
                                child: Text(
                                  floor.number,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }).toList() ??
                            [],
                        onChanged: _selectedBlock == null
                            ? null
                            : (FloorModel? value) {
                                setState(() {
                                  _selectedFloor = value;
                                  _selectedRoom = null;
                                });
                              },
                        validator: (value) => value == null ? 'Please select a floor' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RoomModel>(
                        value: _selectedRoom,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: InputDecoration(
                          labelText: '${unitLeafLabel(widget.propertyType)} *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        dropdownColor: Colors.white,
                        items: availableRooms.map((room) {
                          final isCurrent = room.number == widget.tenant.roomNumber &&
                              _selectedBlock?.name.trim().toLowerCase() ==
                                  (widget.tenant.block ?? '').trim().toLowerCase() &&
                              _selectedFloor?.number.trim() ==
                                  (widget.tenant.floor ?? '').trim();
                          final label = _selectedBlock != null && _selectedFloor != null
                              ? _roomAssignmentLabel(
                                  room,
                                  blockName: _selectedBlock!.name,
                                  floorNumber: _selectedFloor!.number,
                                  users: widget.assignedUsers,
                                  excludeUserId: widget.tenant.id,
                                )
                              : '${room.number} (${room.type})';
                          return DropdownMenuItem<RoomModel>(
                            value: room,
                            child: Text(
                              isCurrent ? '$label (current)' : label,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: _selectedFloor == null
                            ? null
                            : (RoomModel? value) {
                                setState(() => _selectedRoom = value);
                              },
                        validator: (value) {
                          if (value == null) {
                            return usesHouseNoLabel(widget.propertyType)
                                ? 'Please select a house'
                                : 'Please select a room';
                          }
                          if (value.number == widget.tenant.roomNumber &&
                              _selectedBlock?.name == widget.tenant.block &&
                              _selectedFloor?.number == widget.tenant.floor) {
                            return 'Please choose a different room';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _blocks.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              await _submitRoomAssignment(
                                context: context,
                                api: _apiService,
                                userId: widget.tenant.id,
                                block: _selectedBlock!.name,
                                floor: _selectedFloor!.number,
                                roomNumber: _selectedRoom!.number,
                                apartmentId: _apartmentId,
                                onSubmitting: (v) => setState(() => _isSubmitting = v),
                                successMessage: 'User reassigned successfully.',
                              );
                            },
                      style: AppTheme.primaryElevatedStyle.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Reassign', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
