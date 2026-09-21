import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/widgets/brand_gradient_extended_fab.dart';
import '../../../../core/widgets/brand_form_bottom_sheet.dart';
import '../../../../core/hostel_sharing.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/block_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../../core/utils/unit_labels.dart';
import '../bloc/admin_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FloorDetailsPage extends StatefulWidget {
  final FloorModel floor;
  final BlockModel block;
  final bool isHostel;
  final PropertyType? propertyType;

  const FloorDetailsPage({
    super.key,
    required this.floor,
    required this.block,
    this.isHostel = false,
    this.propertyType,
  });

  @override
  State<FloorDetailsPage> createState() => _FloorDetailsPageState();
}

// Dialog content widget for adding rooms
class _AddRoomDialogContent extends StatefulWidget {
  final String blockId;
  final String floorId;
  final BuildContext parentContext;
  final bool isHostel;
  final PropertyType? propertyType;

  const _AddRoomDialogContent({
    required this.blockId,
    required this.floorId,
    required this.parentContext,
    this.isHostel = false,
    this.propertyType,
  });

  @override
  State<_AddRoomDialogContent> createState() => _AddRoomDialogContentState();
}

// Dialog content widget for editing rooms
class _EditRoomDialogContent extends StatefulWidget {
  final RoomModel room;
  final String blockId;
  final String floorId;
  final BuildContext parentContext;
  final bool isHostel;
  final PropertyType? propertyType;
  final VoidCallback onSubmitted;

  const _EditRoomDialogContent({
    required this.room,
    required this.blockId,
    required this.floorId,
    required this.parentContext,
    required this.onSubmitted,
    this.isHostel = false,
    this.propertyType,
  });

  @override
  State<_EditRoomDialogContent> createState() => _EditRoomDialogContentState();
}

class _AddRoomDialogContentState extends State<_AddRoomDialogContent> {
  late final TextEditingController _roomNumberController;
  late String _selectedRoomType;

  @override
  void initState() {
    super.initState();
    _roomNumberController = TextEditingController();
    _selectedRoomType = widget.isHostel ? 'single' : '1BHK';
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandFormBottomSheet(
      title: 'Add New Room',
      subtitle: widget.isHostel
          ? 'Enter room number, then select sharing'
          : usesHouseNoLabel(widget.propertyType)
              ? 'Enter house no and type'
              : 'Enter room number and type',
      headerIcon: Icons.add_home_rounded,
      submitLabel: 'Add Room',
      submitIcon: Icons.add_home_rounded,
      onCancel: () => Navigator.pop(context),
      onSubmit: () {
        if (_roomNumberController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter room number'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        widget.parentContext.read<AdminBloc>().add(
              AddRoomEvent(
                blockId: widget.blockId,
                floorId: widget.floorId,
                roomNumber: _roomNumberController.text.trim(),
                roomType: _selectedRoomType,
                beds: widget.isHostel
                    ? bedsForHostelSharing(_selectedRoomType)
                    : null,
              ),
            );

        Navigator.pop(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _roomNumberController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: brandFormInputDecoration(
              label: unitLeafLabel(widget.propertyType),
              icon: Icons.door_front_door_rounded,
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          if (widget.isHostel) ...[
            DropdownButtonFormField<String>(
              decoration: brandFormInputDecoration(
                label: 'Sharing',
                icon: Icons.people_alt_rounded,
              ),
              value: _selectedRoomType,
              items: kHostelSharingOptions
                  .map(
                    (o) => DropdownMenuItem<String>(
                      value: o.apiType,
                      child: Text(o.label),
                    ),
                  )
                  .toList(),
              onChanged: _roomNumberController.text.trim().isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRoomType = value ?? 'single';
                      });
                    },
            ),
            if (_roomNumberController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Beds: ${bedsForHostelSharing(_selectedRoomType) ?? '—'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8C8C90),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ] else
            DropdownButtonFormField<String>(
              decoration: brandFormInputDecoration(
                label: 'Room Type',
                icon: Icons.apartment_rounded,
              ),
              value: _selectedRoomType,
              items: ['1BHK', '2BHK', '3BHK', '4BHK', '5BHK']
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRoomType = value ?? '1BHK';
                });
              },
            ),
        ],
      ),
    );
  }
}

class _EditRoomDialogContentState extends State<_EditRoomDialogContent> {
  late final TextEditingController _roomNumberController;
  late String _selectedRoomType;

  @override
  void initState() {
    super.initState();
    _roomNumberController = TextEditingController(text: widget.room.number);
    if (widget.isHostel) {
      _selectedRoomType = normalizeHostelSharingTypeForUi(widget.room.type);
    } else {
      const bhk = ['1BHK', '2BHK', '3BHK', '4BHK', '5BHK'];
      _selectedRoomType =
          bhk.contains(widget.room.type) ? widget.room.type : '1BHK';
    }
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandFormBottomSheet(
      title: 'Edit Room',
      subtitle: widget.isHostel
          ? 'Update room number and sharing'
          : usesHouseNoLabel(widget.propertyType)
              ? 'Update house no and type'
              : 'Update room number and type',
      headerIcon: Icons.edit_note_rounded,
      submitLabel: 'Update Room',
      submitIcon: Icons.save_rounded,
      onCancel: () => Navigator.pop(context),
      onSubmit: () {
        if (_roomNumberController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter room number'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        widget.parentContext.read<AdminBloc>().add(
              EditRoomEvent(
                blockId: widget.blockId,
                floorId: widget.floorId,
                roomId: widget.room.id,
                roomNumber: _roomNumberController.text.trim(),
                roomType: _selectedRoomType,
                beds: widget.isHostel
                    ? bedsForHostelSharing(_selectedRoomType)
                    : null,
              ),
            );

        widget.onSubmitted();
        Navigator.pop(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _roomNumberController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: brandFormInputDecoration(
              label: unitLeafLabel(widget.propertyType),
              icon: Icons.door_front_door_rounded,
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          if (widget.isHostel) ...[
            DropdownButtonFormField<String>(
              decoration: brandFormInputDecoration(
                label: 'Sharing',
                icon: Icons.people_alt_rounded,
              ),
              value: _selectedRoomType,
              items: kHostelSharingOptions
                  .map(
                    (o) => DropdownMenuItem<String>(
                      value: o.apiType,
                      child: Text(o.label),
                    ),
                  )
                  .toList(),
              onChanged: _roomNumberController.text.trim().isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedRoomType = value ?? 'single';
                      });
                    },
            ),
            if (_roomNumberController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Beds: ${bedsForHostelSharing(_selectedRoomType) ?? '—'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8C8C90),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ] else
            DropdownButtonFormField<String>(
              decoration: brandFormInputDecoration(
                label: 'Room Type',
                icon: Icons.apartment_rounded,
              ),
              value: _selectedRoomType,
              items: ['1BHK', '2BHK', '3BHK', '4BHK', '5BHK']
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRoomType = value ?? '1BHK';
                });
              },
            ),
        ],
      ),
    );
  }
}

class _FloorDetailsPageState extends State<FloorDetailsPage> {
  FloorModel? _currentFloor;
  BlockModel? _currentBlock;
  int _previousRoomCount = 0; // Track previous room count for success message
  bool _awaitingEditRoomResult = false;
  List<UserModel> _floorAssignedUsers = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _currentFloor = widget.floor;
    _currentBlock = widget.block;
    _previousRoomCount = widget.floor.rooms.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final apartmentId = widget.block.apartmentId;
      if (apartmentId != null && apartmentId.isNotEmpty) {
        context
            .read<AdminBloc>()
            .add(SelectApartmentEvent(apartmentId: apartmentId));
      }
      _loadFloorAssignedUsers();
    });
  }

  Future<void> _loadFloorAssignedUsers() async {
    final block = _currentBlock ?? widget.block;
    final floor = _currentFloor ?? widget.floor;
    final apartmentId = block.apartmentId;
    if (apartmentId == null || apartmentId.isEmpty) {
      if (mounted) setState(() => _floorAssignedUsers = []);
      return;
    }
    final result = await _apiService.getAllUsers(
      apartmentId: apartmentId,
      block: block.name,
      floor: floor.number,
      assignedOnly: true,
    );
    if (!mounted) return;
    if (result['success'] == true && result['users'] is List) {
      final users = (result['users'] as List)
          .whereType<Map>()
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      setState(() => _floorAssignedUsers = users);
    } else {
      setState(() => _floorAssignedUsers = []);
    }
  }

  void _showAddRoomDialog(BuildContext context) {
    // Store parent context to use for bloc operations
    final parentContext = this.context;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _AddRoomDialogContent(
        blockId: _currentBlock!.id,
        floorId: _currentFloor!.id,
        parentContext: parentContext,
        isHostel: widget.isHostel,
        propertyType: widget.propertyType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        // Use addPostFrameCallback to delay state updates until after current frame
        // This prevents the InheritedWidget assertion error during widget tree updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (state is AdminLoaded) {
            final block = state.blocks.firstWhere(
              (b) => b.id == widget.block.id,
              orElse: () => widget.block,
            );
            final floor = block.floors.firstWhere(
              (f) => f.id == widget.floor.id,
              orElse: () => widget.floor,
            );
            
            if (mounted) {
              final previousCount = _currentFloor?.rooms.length ?? _previousRoomCount;
              setState(() {
                _currentBlock = block;
                _currentFloor = floor;
                _previousRoomCount = floor.rooms.length;
              });
              // Show success message if room count increased
              if (floor.rooms.length > previousCount && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room added successfully!'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              // Show success message if room count decreased
              if (floor.rooms.length < previousCount && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room deleted successfully!'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              // Show success message if room details were updated
              if (_awaitingEditRoomResult && mounted) {
                _awaitingEditRoomResult = false;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room updated successfully!'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              _loadFloorAssignedUsers();
            }
          } else if (state is AdminError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAF9),
        appBar: buildBrandGradientAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Floor Details'),
        ),
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            final floor = _currentFloor ?? widget.floor;
            final block = _currentBlock ?? widget.block;

            final assignedCount = _floorAssignedUsers.length;
            final vacantCount = vacantRoomCountForFloor(
              users: _floorAssignedUsers,
              blockName: block.name,
              floorNumber: floor.number,
              rooms: floor.rooms,
              isHostel: widget.isHostel,
            );

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.layers_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  floor.number,
                                  style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Block: ${block.name}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Floor View',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _FloorDetailsSummaryStat(
                              label: 'Rooms',
                              value: '${floor.rooms.length}',
                              icon: Icons.door_front_door_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          Expanded(
                            child: _FloorDetailsSummaryStat(
                              label: 'Assigned',
                              value: '$assignedCount',
                              icon: Icons.people_alt_rounded,
                              isHighlight: true,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          Expanded(
                            child: _FloorDetailsSummaryStat(
                              label: 'Vacant',
                              value: '$vacantCount',
                              icon: Icons.meeting_room_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: floor.rooms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_outlined,
                                size: 56,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No rooms added yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap + to add a room',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            14,
                            10,
                            14,
                            12 + MediaQuery.of(context).padding.bottom + 72,
                          ),
                          itemCount: floor.rooms.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final room = floor.rooms[index];
                            final roomOccupants = occupantsForRoom(
                              users: _floorAssignedUsers,
                              blockName: block.name,
                              floorNumber: floor.number,
                              room: room,
                              isHostel: widget.isHostel,
                            );
                            return _RoomCard(
                              cardIndex: index,
                              room: room,
                              isHostel: widget.isHostel,
                              occupants: roomOccupants,
                              onEdit: () =>
                                  _showEditRoomDialog(context, room, block, floor),
                              onDelete: () =>
                                  _showDeleteRoomDialog(context, room, block, floor),
                              onRoomTap: () => _showRoomDetailsSheet(
                                    context,
                                    room,
                                    block,
                                    floor,
                                    roomOccupants,
                                  ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: BrandGradientExtendedFab(
          onPressed: () => _showAddRoomDialog(context),
          icon: Icons.add_home_work_rounded,
          label: 'Add Room',
        ),
      ),
    );
  }

  Future<void> _showRoomDetailsSheet(
    BuildContext context,
    RoomModel room,
    BlockModel block,
    FloorModel floor,
    List<UserModel> initialOccupants,
  ) async {
    await _loadFloorAssignedUsers();
    final occupants = occupantsForRoom(
      users: _floorAssignedUsers,
      blockName: block.name,
      floorNumber: floor.number,
      room: room,
      isHostel: widget.isHostel,
    );
    final beds = room.beds ?? 0;
    final isHostel = widget.isHostel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'Room Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${block.name} • ${floor.number}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8C8C90),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _detailRow(
                      Icons.door_front_door_rounded,
                      unitLeafLabel(widget.propertyType),
                      room.number,
                    ),
                    const SizedBox(height: 14),
                    _detailRow(Icons.apartment_rounded, 'Room Type', room.type),
                    if (isHostel) ...[
                      const SizedBox(height: 14),
                      _detailRow(
                        Icons.hotel_rounded,
                        'Number of Beds',
                        beds > 0 ? beds.toString() : '—',
                      ),
                    ],
                    const SizedBox(height: 14),
                    buildAssignedUsersSection(
                      occupants: occupants,
                      isHostel: isHostel,
                    ),
                    if (isHostel && beds > 0) ...[
                      const SizedBox(height: 14),
                      _detailRow(
                        Icons.event_seat_rounded,
                        'Beds occupancy',
                        '${occupants.length} of $beds beds occupied',
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFFECECEA)),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BrandGradientCtaButton(
                            height: 48,
                            label: 'Edit Room',
                            icon: Icons.edit_rounded,
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditRoomDialog(context, room, block, floor);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF13275D).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF13275D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8C8C90),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditRoomDialog(BuildContext context, RoomModel room, BlockModel block, FloorModel floor) {
    // Store parent context to use for bloc operations
    final parentContext = this.context;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => _EditRoomDialogContent(
        room: room,
        blockId: _currentBlock!.id,
        floorId: _currentFloor!.id,
        parentContext: parentContext,
        isHostel: widget.isHostel,
        propertyType: widget.propertyType,
        onSubmitted: () {
          setState(() {
            _awaitingEditRoomResult = true;
          });
        },
      ),
    );
  }

  void _showDeleteRoomDialog(BuildContext context, RoomModel room, BlockModel block, FloorModel floor) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: const Color(0xFFFAFAF9),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 28,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Room',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete ${room.number}?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8C8C90),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<AdminBloc>().add(
                              DeleteRoomEvent(
                                blockId: block.id,
                                floorId: floor.id,
                                roomId: room.id,
                              ),
                            );
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

class _FloorDetailsSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlight;

  const _FloorDetailsSummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(width: 5),
            Text(
              value,
              style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final int cardIndex;
  final RoomModel room;
  final bool isHostel;
  final List<UserModel> occupants;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRoomTap;

  const _RoomCard({
    required this.cardIndex,
    required this.room,
    required this.isHostel,
    required this.occupants,
    required this.onEdit,
    required this.onDelete,
    this.onRoomTap,
  });

  String _roomTypeLabel(RoomModel room) {
    if (isHostel && room.beds != null && room.beds! > 0) {
      return '${room.type} · ${room.beds} beds';
    }
    return room.type;
  }

  @override
  Widget build(BuildContext context) {
    final isOccupied = occupants.isNotEmpty;
    final statusColor =
        isOccupied ? const Color(0xFF13275D) : const Color(0xFF8C8C90);
    final statusBg = isOccupied
        ? const Color(0xFF13275D).withOpacity(0.14)
        : const Color(0xFF0F172A).withOpacity(0.06);
    final statusLabel = isOccupied ? 'Occupied (${occupants.length})' : 'Vacant';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFECECEA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onRoomTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF13275D).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOccupied ? Icons.person : Icons.meeting_room_outlined,
                        size: 20,
                        color: const Color(0xFF13275D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Room ${room.number}',
                                style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _roomTypeLabel(room),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8C8C90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFECECEA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            color: const Color(0xFF0F172A),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: onEdit,
                            tooltip: 'Edit Room',
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            color: const Color(0xFFECECEA),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            color: Colors.red[600],
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: onDelete,
                            tooltip: 'Delete Room',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (occupants.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFECECEA)),
                  const SizedBox(height: 10),
                  Text(
                    'Assigned Occupants',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8C8C90),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: occupants.map((u) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAF9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFECECEA),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              occupantDisplayLabel(u, isHostel),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

