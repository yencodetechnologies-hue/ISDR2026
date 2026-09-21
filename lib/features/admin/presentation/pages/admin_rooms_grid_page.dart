import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/hostel_sharing.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/block_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/utils/current_property_context.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/admin_bloc.dart';

/// A single room slot in the rooms grid (block + floor + room).
class _RoomCell {
  final String blockName;
  final String floorNumber;
  final RoomModel room;

  const _RoomCell({
    required this.blockName,
    required this.floorNumber,
    required this.room,
  });
}

/// Full-screen room grid opened from the management "Total Rooms" stat card.
///
/// Each room is rendered as a card with redbus-style bed slots: green = free,
/// red = occupied. Tapping a free bed assigns a user; tapping an occupied bed
/// lets you view, unassign, or reassign the occupant.
class AdminRoomsGridPage extends StatefulWidget {
  final bool isHostel;
  final ApartmentModel? apartment;

  const AdminRoomsGridPage({
    super.key,
    this.isHostel = false,
    this.apartment,
  });

  @override
  State<AdminRoomsGridPage> createState() => _AdminRoomsGridPageState();
}

class _AdminRoomsGridPageState extends State<AdminRoomsGridPage> {
  static const Color _availableColor = AppTheme.secondaryColor; // green
  static const Color _occupiedColor = AppTheme.errorColor; // red

  Future<void> _refresh() async {
    context.read<AdminBloc>().add(LoadAllUsersEvent());
    context.read<AdminBloc>().add(LoadBlocksEvent());
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  List<_RoomCell> _allRooms(AdminLoaded state) {
    final cells = <_RoomCell>[];
    for (final block in state.blocks) {
      for (final floor in block.floors) {
        for (final room in floor.rooms) {
          cells.add(
            _RoomCell(
              blockName: block.name,
              floorNumber: floor.number,
              room: room,
            ),
          );
        }
      }
    }
    return cells;
  }

  String? _apartmentId(AdminLoaded state) =>
      widget.apartment?.id ?? state.selectedApartmentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rooms'),
        elevation: 0,
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (previous, current) =>
            current is AdminLoaded || previous is AdminLoaded,
        builder: (context, state) {
          if (state is! AdminLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = _allRooms(state);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: rooms.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No rooms found.\nAdd blocks and rooms first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: _Legend()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverToBoxAdapter(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = 10.0;
                              final cardWidth = (constraints.maxWidth - gap) / 2;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: rooms
                                    .map((r) => SizedBox(
                                          width: cardWidth,
                                          child: _buildRoomCard(state, r),
                                        ))
                                    .toList(),
                              );
                            },
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

  Widget _buildRoomCard(AdminLoaded state, _RoomCell cell) {
    final occupants = occupantsForRoom(
      users: state.regularUsers,
      blockName: cell.blockName,
      floorNumber: cell.floorNumber,
      room: cell.room,
      isHostel: widget.isHostel,
    );
    final capacity = roomBedCapacity(beds: cell.room.beds, type: cell.room.type);
    final unitLabel = formatUnitAssignment(
      block: cell.blockName,
      floor: cell.floorNumber,
      roomNumber: cell.room.number,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Room ${cell.room.number}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              unitLabel.isEmpty ? cell.room.type : unitLabel,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textColor.withOpacity(0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${occupants.length}/$capacity beds occupied',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textColor.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(capacity, (i) {
                    final isOccupied = i < occupants.length;
                    final occupant = isOccupied ? occupants[i] : null;
                    return _BedSlot(
                      bedNumber: i + 1,
                      isOccupied: isOccupied,
                      occupiedColor: _occupiedColor,
                      availableColor: _availableColor,
                      onTap: () {
                        if (isOccupied) {
                          _showOccupantDialog(state, occupant!);
                        } else {
                          _showAssignDialog(state, cell);
                        }
                      },
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }

  // --- Assign a user to a free bed -----------------------------------------

  void _showAssignDialog(AdminLoaded state, _RoomCell cell) {
    final bloc = context.read<AdminBloc>();
    final apartmentId = _apartmentId(state);
    final allUsers = [...state.regularUsers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    String query = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = allUsers.where((u) {
              if (query.trim().isEmpty) return true;
              final q = query.trim().toLowerCase();
              return u.name.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  u.mobileNumber.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign to Room ${cell.room.number}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatUnitAssignment(
                              block: cell.blockName,
                              floor: cell.floorNumber,
                              roomNumber: cell.room.number,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textColor.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        autofocus: false,
                        onChanged: (v) => setSheetState(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Search users by name, email, phone',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No users found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final user = filtered[index];
                                final assignment =
                                    formatUserAssignmentDisplay(user);
                                final isAssigned = isUserAssigned(user);
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppTheme.primaryColor.withOpacity(0.12),
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isAssigned
                                        ? 'Currently: $assignment'
                                        : (user.status == AccountStatus.pending
                                            ? 'Pending approval'
                                            : 'Unassigned'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppTheme.secondaryColor,
                                  ),
                                  onTap: () {
                                    bloc.add(
                                      UpdateUserStatusEvent(
                                        userId: user.id,
                                        status: AccountStatus.approved,
                                        block: cell.blockName,
                                        floor: cell.floorNumber,
                                        roomNumber: cell.room.number,
                                        apartmentId: apartmentId,
                                      ),
                                    );
                                    Navigator.pop(sheetContext);
                                    _showSnack(
                                      '${user.name} assigned to room ${cell.room.number}',
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Occupied bed: view / unassign / reassign ----------------------------

  void _showOccupantDialog(AdminLoaded state, UserModel occupant) {
    final bloc = context.read<AdminBloc>();
    final apartmentId = _apartmentId(state);

    final authState = context.read<AuthBloc>().state;
    final viewer = authState is AuthAuthenticated ? authState.user : null;
    final showMobile = shouldShowUserMobileForViewer(
      showUserMobileSetting: widget.apartment?.showUserMobile ?? true,
      loginRole: viewer?.loginRole,
      isHostel: widget.apartment?.propertyType == PropertyType.hostel,
      viewerUserType: viewer?.userType,
    );
    final canCall = showMobile && occupant.mobileNumber.trim().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with gradient banner + avatar.
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandHeaderGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          occupant.name.isNotEmpty
                              ? occupant.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              occupant.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Occupied',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Detail tiles.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.apartment_rounded,
                        label: 'Unit',
                        value: formatUserAssignmentDisplay(occupant),
                        color: AppTheme.primaryColor,
                      ),
                      if (canCall)
                        _infoTile(
                          icon: Icons.phone_rounded,
                          label: 'Mobile',
                          value: occupant.mobileNumber,
                          color: AppTheme.secondaryColor,
                          onTap: () => _callNumber(occupant.mobileNumber),
                          trailing: const Icon(
                            Icons.call_rounded,
                            color: AppTheme.secondaryColor,
                            size: 20,
                          ),
                        ),
                      if (occupant.email.trim().isNotEmpty)
                        _infoTile(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: occupant.email,
                          color: AppTheme.accentColor,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Action buttons.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: [
                      if (canCall) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Call'),
                            onPressed: () => _callNumber(occupant.mobileNumber),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: const Text('Reassign'),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _showReassignPicker(state, occupant);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _occupiedColor,
                                side: const BorderSide(color: _occupiedColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.person_remove_rounded),
                              label: const Text('Unassign'),
                              onPressed: () {
                                bloc.add(
                                  UpdateUserStatusEvent(
                                    userId: occupant.id,
                                    status: AccountStatus.pending,
                                    apartmentId: apartmentId,
                                  ),
                                );
                                Navigator.pop(sheetContext);
                                _showSnack(
                                  '${occupant.name} unassigned (moved to pending)',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReassignPicker(AdminLoaded state, UserModel occupant) {
    final bloc = context.read<AdminBloc>();
    final apartmentId = _apartmentId(state);

    // Rooms that still have a free bed, excluding the occupant being moved.
    final available = <_RoomCell>[];
    for (final cell in _allRooms(state)) {
      final occ = occupantsForRoom(
        users: state.regularUsers,
        blockName: cell.blockName,
        floorNumber: cell.floorNumber,
        room: cell.room,
        isHostel: widget.isHostel,
        excludeUserId: occupant.id,
      );
      final capacity =
          roomBedCapacity(beds: cell.room.beds, type: cell.room.type);
      if (occ.length < capacity) {
        available.add(cell);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reassign ${occupant.name} to…',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: available.isEmpty
                    ? const Center(
                        child: Text(
                          'No rooms with free beds available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cell = available[index];
                          final occ = occupantsForRoom(
                            users: state.regularUsers,
                            blockName: cell.blockName,
                            floorNumber: cell.floorNumber,
                            room: cell.room,
                            isHostel: widget.isHostel,
                            excludeUserId: occupant.id,
                          ).length;
                          final capacity = roomBedCapacity(
                            beds: cell.room.beds,
                            type: cell.room.type,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.meeting_room_outlined,
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(
                              'Room ${cell.room.number}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${formatUnitAssignment(block: cell.blockName, floor: cell.floorNumber, roomNumber: cell.room.number)} · $occ/$capacity beds',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${capacity - occ} free',
                              style: const TextStyle(
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              bloc.add(
                                UpdateUserStatusEvent(
                                  userId: occupant.id,
                                  status: AccountStatus.approved,
                                  block: cell.blockName,
                                  floor: cell.floorNumber,
                                  roomNumber: cell.room.number,
                                  apartmentId: apartmentId,
                                ),
                              );
                              Navigator.pop(sheetContext);
                              _showSnack(
                                '${occupant.name} reassigned to room ${cell.room.number}',
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textColor.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: tile,
    );
  }

  Future<void> _callNumber(String mobileNumber) async {
    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not open dialer');
      }
    } catch (e) {
      _showSnack('Could not place call: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _BedSlot extends StatelessWidget {
  final int bedNumber;
  final bool isOccupied;
  final Color occupiedColor;
  final Color availableColor;
  final VoidCallback onTap;

  const _BedSlot({
    required this.bedNumber,
    required this.isOccupied,
    required this.occupiedColor,
    required this.availableColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOccupied ? occupiedColor : availableColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.single_bed_outlined, size: 18, color: color),
            const SizedBox(height: 1),
            Text(
              '$bedNumber',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _LegendDot(color: AppTheme.secondaryColor, label: 'Available'),
          SizedBox(width: 16),
          _LegendDot(color: AppTheme.errorColor, label: 'Occupied'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
