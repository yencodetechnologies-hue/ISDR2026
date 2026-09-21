import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/utils/room_occupants.dart';
import '../../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../admin_apartment_filter_list_page.dart';
import '../admin_rooms_grid_page.dart';
import '../admin_users_list_page.dart';
import '../admin_vacancies_list_page.dart';
import '../create_apartment_page.dart';
import '../../widgets/property_list/property_list_widgets.dart';
import '../../widgets/management_module_grid.dart';
import '../../bloc/admin_bloc.dart';

class OverviewTab extends StatelessWidget {
  final AdminLoaded state;
  final bool isApartmentAccount;
  final ApartmentModel? apartment;
  final String? selectedApartmentId;
  final VoidCallback? onPropertyUpdated;
  final ValueChanged<String>? onTabNavigate;
  final List<String> moduleLabels;
  final bool showModuleGrid;
  final int managedEventsCount;

  const OverviewTab({
    required this.state,
    this.isApartmentAccount = false,
    this.apartment,
    this.selectedApartmentId,
    this.onPropertyUpdated,
    this.onTabNavigate,
    this.moduleLabels = const [],
    this.showModuleGrid = true,
    this.managedEventsCount = 0,
    super.key,
  });

  void _openCreateApartment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateApartmentPage(),
      ),
    );
  }

  void _openViewProperties(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminApartmentFilterListPage(),
      ),
    );
  }

  void _openUsersList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUsersListPage(
          propertyType: apartment?.propertyType,
          apartment: apartment,
        ),
      ),
    );
  }

  void _openRoomsGrid(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminRoomsGridPage(
          isHostel: true,
          apartment: apartment,
        ),
      ),
    );
  }

  void _openVacanciesList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminVacanciesListPage(
          propertyType: apartment?.propertyType,
        ),
      ),
    );
  }



  Widget _buildPropertyHeroCard(BuildContext context) {
    final apt = apartment;
    final aptName = apt?.name ?? 'Test Apartment';

    final totalUsers = state.regularUsers.length;
    final isHostel = apt?.propertyType == PropertyType.hostel;
    final totalRooms = totalRoomCountForProperty(blocks: state.blocks);
    final totalVacancies = vacantRoomCountForProperty(
      users: state.regularUsers,
      blocks: state.blocks,
      isHostel: isHostel,
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF13275D).withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aptName,
                            style: GoogleFonts.sora(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildHeroIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notifications')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildHeroIconButton(
                          icon: Icons.logout_rounded,
                          onTap: () {
                            LogoutConfirmSheet.showLogoutConfirmSheet(
                              context,
                              onLogout: () {
                                context.read<AuthBloc>().add(LogoutEvent());
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x40FFFFFF),
                              blurRadius: 3,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'All systems online',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (apt?.propertyType != PropertyType.college) ...[
                      Expanded(
                        child: _buildHeroStatCard(
                          number: '$totalVacancies',
                          label: 'Vacancies',
                          isWarn: totalVacancies > 0,
                          onTap: () => _openVacanciesList(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _buildHeroStatCard(
                        number: '$totalUsers',
                        label: apt?.propertyType == PropertyType.college
                            ? 'Staffs'
                            : 'Users',
                        isWarn: false,
                        onTap: () => _openUsersList(context),
                      ),
                    ),
                    if (apt?.propertyType == PropertyType.college) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeroStatCard(
                          number: '${state.securityStaff.length}',
                          label: 'Security',
                          isWarn: false,
                          onTap: onTabNavigate != null
                              ? () => onTabNavigate!('Security')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeroStatCard(
                          number: '0',
                          label: 'Visitors Inside',
                          isWarn: false,
                          onTap: onTabNavigate != null
                              ? () => onTabNavigate!('Visitors')
                              : null,
                        ),
                      ),
                    ],
                    if (apt?.propertyType != PropertyType.college) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHeroStatCard(
                          number: '$totalRooms',
                          label: 'Rooms',
                          isWarn: false,
                          onTap: isHostel
                              ? () => _openRoomsGrid(context)
                              : (onTabNavigate != null
                                  ? () => onTabNavigate!('Blocks')
                                  : null),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildHeroStatCard({
    required String number,
    required String label,
    required bool isWarn,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }

  Widget _buildHeroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap,
      {bool useFilledStyle = false}) {
    final isFilled = useFilledStyle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFilled ? color : color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFilled ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isFilled ? Colors.white : color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFilled ? Colors.white : AppTheme.textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopedApartmentId = selectedApartmentId;
    final bool showApartmentScopedOverview =
        scopedApartmentId != null && scopedApartmentId.isNotEmpty;

    final globalActions = <Widget>[
      _buildActionCard(
        'Create Property',
        Icons.add_home_work,
        AppTheme.primaryColor,
        () => _openCreateApartment(context),
        useFilledStyle: true,
      ),
      _buildActionCard(
        'View Property',
        Icons.list_alt,
        AppTheme.secondaryColor,
        () => _openViewProperties(context),
        useFilledStyle: true,
      ),
    ];

    return ColoredBox(
      color: const Color(0xFFFAFAF9),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (!showApartmentScopedOverview) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PropertyStatsOverviewSection(),
                    const SizedBox(height: 24),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: globalActions.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.75,
                          ),
                          itemBuilder: (context, index) => globalActions[index],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildPropertyHeroCard(context),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAF9),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Head & Quick Actions
                      Text(
                        'Quick actions',
                        style: GoogleFonts.sora(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B1B1D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _openUsersList(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF13275D), Color(0xFF111827)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD9820A).withOpacity(0.28),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '＋ ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      apartment?.propertyType == PropertyType.college
                                          ? 'Add Staff'
                                          : 'Add resident',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: onTabNavigate != null
                                  ? () => onTabNavigate!('Security')
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFECECEA)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.security_rounded,
                                      size: 16,
                                      color: Color(0xFF1B1B1D),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Security check',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1B1B1D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: onTabNavigate != null
                                  ? () => onTabNavigate!('Notices')
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFECECEA)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.campaign_rounded,
                                      size: 16,
                                      color: Color(0xFF1B1B1D),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Post Notice',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1B1B1D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Categorized Grouped Module Grid (OVERVIEW, COMMUNITY, OPERATIONS, ACCOUNT)
                      if (showModuleGrid && moduleLabels.isNotEmpty) ...[
                        ManagementModuleGrid(
                          moduleLabels: moduleLabels,
                          onModuleTap: onTabNavigate ?? (_) {},
                        ),
                      ],

                      if (apartment != null &&
                          context.read<AuthBloc>().state is AuthAuthenticated &&
                          (context.read<AuthBloc>().state as AuthAuthenticated).user.userType == UserType.apartment &&
                          (context.read<AuthBloc>().state as AuthAuthenticated).user.loginRole == 'owner' &&
                          apartment!.propertyType == PropertyType.hostel) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Controls',
                          style: GoogleFonts.sora(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure features and visibility settings for this hostel',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF8C8C90),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PropertyOwnerControlsSection(
                          apartment: apartment!,
                          onPropertyUpdated: onPropertyUpdated,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertyOwnerControlsSection extends StatefulWidget {
  final ApartmentModel apartment;
  final VoidCallback? onPropertyUpdated;

  const _PropertyOwnerControlsSection({
    required this.apartment,
    this.onPropertyUpdated,
  });

  @override
  State<_PropertyOwnerControlsSection> createState() =>
      __PropertyOwnerControlsSectionState();
}

class __PropertyOwnerControlsSectionState
    extends State<_PropertyOwnerControlsSection> {
  final ApiService _apiService = ApiService();
  bool _updating = false;

  Future<void> _toggleFeature(
    String name,
    bool currentVal, {
    bool? securityEnabled,
    bool? assignPaymentEnabled,
    bool? complaintsEnabled,
    bool? showUserMobile,
    bool? addUserEnabled,
    bool? wardenFacilityEnabled,
    bool? supportEnabled,
    bool? adsEnabled,
  }) async {
    setState(() => _updating = true);
    final res = await _apiService.updateApartment(
      id: widget.apartment.id,
      securityEnabled: securityEnabled,
      assignPaymentEnabled: assignPaymentEnabled,
      complaintsEnabled: complaintsEnabled,
      showUserMobile: showUserMobile,
      addUserEnabled: addUserEnabled,
      wardenFacilityEnabled: wardenFacilityEnabled,
      supportEnabled: supportEnabled,
      adsEnabled: adsEnabled,
    );
    if (!mounted) return;
    setState(() => _updating = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name updated successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      if (widget.onPropertyUpdated != null) {
        widget.onPropertyUpdated!();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to update $name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _buildControlTile(
                    title: 'User Mobile Number',
                    subtitle:
                        'Hide resident mobile numbers from warden when turned off',
                    icon: Icons.phone_outlined,
                    value: widget.apartment.showUserMobile,
                    color: Colors.blue,
                    onChanged: (v) => _toggleFeature(
                      'User Mobile Visibility',
                      widget.apartment.showUserMobile,
                      showUserMobile: v,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildControlTile(
                    title: 'Add User Button',
                    subtitle: 'Allow adding users/residents to this property',
                    icon: Icons.person_add_outlined,
                    value: widget.apartment.addUserEnabled,
                    color: Colors.green,
                    onChanged: (v) => _toggleFeature(
                      'Add User permission',
                      widget.apartment.addUserEnabled,
                      addUserEnabled: v,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildControlTile(
                    title: 'Facility for Warden',
                    subtitle: 'Let warden access the Facility tab',
                    icon: Icons.build_outlined,
                    value: widget.apartment.wardenFacilityEnabled,
                    color: Colors.orange,
                    onChanged: (v) => _toggleFeature(
                      'Facility for Warden',
                      widget.apartment.wardenFacilityEnabled,
                      wardenFacilityEnabled: v,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildControlTile(
                    title: 'Help & Support',
                    subtitle: 'Let warden access the Support tab to manage hostel tickets',
                    icon: Icons.support_agent_outlined,
                    value: widget.apartment.supportEnabled,
                    color: Colors.purple,
                    onChanged: (v) => _toggleFeature(
                      'Help & Support',
                      widget.apartment.supportEnabled,
                      supportEnabled: v,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildControlTile(
                    title: 'Ads',
                    subtitle: 'Show promotional ads to residents',
                    icon: Icons.campaign_outlined,
                    value: widget.apartment.adsEnabled,
                    color: Colors.teal,
                    onChanged: (v) => _toggleFeature(
                      'Ads',
                      widget.apartment.adsEnabled,
                      adsEnabled: v,
                    ),
                  ),
                ],
              ),
            ),
            if (_updating)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.55),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textColor.withOpacity(0.55),
        ),
      ),
      trailing: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: value,
          onChanged: _updating ? null : onChanged,
          activeColor: AppTheme.secondaryColor,
        ),
      ),
    );
  }
}
