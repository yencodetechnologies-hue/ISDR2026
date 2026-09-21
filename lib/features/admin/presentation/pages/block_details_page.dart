import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/brand_gradient_extended_fab.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/hostel_sharing.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/block_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../../core/utils/unit_labels.dart';
import '../../../../core/utils/floor_spec.dart';
import '../bloc/admin_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'floor_details_page.dart';

class BlockDetailsPage extends StatefulWidget {
  final BlockModel block;

  const BlockDetailsPage({
    super.key,
    required this.block,
  });

  @override
  State<BlockDetailsPage> createState() => _BlockDetailsPageState();
}

class _BlockDetailsPageState extends State<BlockDetailsPage> {
  late BlockModel _currentBlock;
  ApartmentModel? _apartment;
  bool _apartmentLoading = false;
  List<UserModel> _blockAssignedUsers = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.block;
    if (widget.block.apartmentId != null && widget.block.apartmentId!.isNotEmpty) {
      _loadApartment(widget.block.apartmentId!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final apartmentId = widget.block.apartmentId;
      if (apartmentId != null && apartmentId.isNotEmpty) {
        context
            .read<AdminBloc>()
            .add(SelectApartmentEvent(apartmentId: apartmentId));
      }
      _loadBlockAssignedUsers();
    });
  }

  Future<void> _loadBlockAssignedUsers() async {
    final apartmentId = _currentBlock.apartmentId;
    if (apartmentId == null || apartmentId.isEmpty) {
      if (mounted) setState(() => _blockAssignedUsers = []);
      return;
    }
    final result = await _apiService.getAllUsers(
      apartmentId: apartmentId,
      block: _currentBlock.name,
      assignedOnly: true,
    );
    if (!mounted) return;
    if (result['success'] == true && result['users'] is List) {
      final users = (result['users'] as List)
          .whereType<Map>()
          .map((json) => UserModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      setState(() => _blockAssignedUsers = users);
    } else {
      setState(() => _blockAssignedUsers = []);
    }
  }

  Future<void> _loadApartment(String apartmentId) async {
    setState(() => _apartmentLoading = true);
    final result = await _apiService.getApartment(apartmentId);
    if (mounted && result['success'] == true && result['apartment'] != null) {
      setState(() {
        _apartment = ApartmentModel.fromJson(result['apartment'] as Map<String, dynamic>);
        _apartmentLoading = false;
      });
    } else {
      if (mounted) setState(() => _apartmentLoading = false);
    }
  }

  void _refreshBlock() {
    // Reload blocks from backend
    context.read<AdminBloc>().add(LoadBlocksEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (state is AdminLoaded) {
            final updatedBlock = state.blocks.firstWhere(
              (b) => b.id == _currentBlock.id,
              orElse: () => _currentBlock,
            );
            setState(() => _currentBlock = updatedBlock);
          } else if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAF9),
        appBar: buildBrandGradientAppBar(
          title: Text(_currentBlock.name),
        ),
        body: _currentBlock.floors.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 80,
                    color: Color(0xFF8C8C90),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Floors Added',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      color: const Color(0xFF1B1B1D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add floors',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF8C8C90),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Block Summary Banner Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BlockSummaryStat(
                          label: 'TOTAL FLOORS',
                          value: '${_currentBlock.floors.length}',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withOpacity(0.20),
                      ),
                      Expanded(
                        child: _BlockSummaryStat(
                          label: 'TOTAL ROOMS',
                          value:
                              '${_currentBlock.floors.fold<int>(0, (sum, floor) => sum + floor.rooms.length)}',
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ),
                // Floors Grid Section
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      16 + MediaQuery.of(context).padding.bottom + 72,
                    ),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 124,
                      ),
                      itemCount: _currentBlock.floors.length,
                      itemBuilder: (context, index) {
                        final floor = _currentBlock.floors[index];
                        return _FloorCard(
                          cardIndex: index,
                          floor: floor,
                          blockName: _currentBlock.name,
                          blockId: _currentBlock.id,
                          block: _currentBlock,
                          isHostel:
                              _apartment?.propertyType == PropertyType.hostel,
                          blockAssignedUsers: _blockAssignedUsers,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FloorDetailsPage(
                                  floor: floor,
                                  block: _currentBlock,
                                  isHostel: _apartment?.propertyType ==
                                      PropertyType.hostel,
                                  propertyType: _apartment?.propertyType,
                                ),
                              ),
                            );
                            if (mounted) _loadBlockAssignedUsers();
                          },
                          onEdit: () {
                            _showAddFloorDialog(context, editingFloor: floor);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        floatingActionButton: BrandGradientExtendedFab(
          onPressed: () => _showAddFloorDialog(context),
          icon: Icons.add_rounded,
          label: _currentBlock.floors.isEmpty ? 'Add Floor' : 'Update Floors',
        ),
      ),
    );
  }

  void _showAddFloorDialog(BuildContext context, {FloorModel? editingFloor}) {
    final isEditing = editingFloor != null;
    final isUpdatingTotalFloors = !isEditing && _currentBlock.floors.isNotEmpty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddOrEditFloorSheet(
        block: _currentBlock,
        editingFloor: editingFloor,
        isUpdatingTotalFloors: isUpdatingTotalFloors,
      ),
    );
  }

  void _showHostelRoomDetailsSheet(
    BuildContext context,
    RoomModel room,
    BlockModel block,
    FloorModel floor,
  ) {
    final isHostel = _apartment?.propertyType == PropertyType.hostel;
    final floorUsers = assignedUsersForFloor(
      users: _blockAssignedUsers,
      blockName: block.name,
      floorNumber: floor.number,
    );
    final occupants = occupantsForRoom(
      users: floorUsers,
      blockName: block.name,
      floorNumber: floor.number,
      room: room,
      isHostel: isHostel,
    );
    final beds = room.beds ?? 0;
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
                        color: Color(0xFF1B1B1D),
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
                    _buildRoomDetailRow(
                      Icons.door_front_door_rounded,
                      unitLeafLabel(_apartment?.propertyType),
                      room.number,
                    ),
                    const SizedBox(height: 14),
                    _buildRoomDetailRow(Icons.apartment_rounded, 'Room Type', room.type),
                    if (isHostel) ...[
                      const SizedBox(height: 14),
                      _buildRoomDetailRow(
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
                      _buildRoomDetailRow(
                        Icons.event_seat_rounded,
                        'Beds occupancy',
                        '${occupants.length} of $beds beds occupied',
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton(
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
                          color: Color(0xFF1B1B1D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _buildRoomDetailRow(IconData icon, String label, String value) {
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

  void _showFloorDetails(BuildContext context, FloorModel floor, String blockName) {
    final isHostel = _apartment?.propertyType == PropertyType.hostel;
    final floorAssignedUsers = assignedUsersForFloor(
      users: _blockAssignedUsers,
      blockName: blockName,
      floorNumber: floor.number,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FloorDetailsModalSheet(
        floor: floor,
        blockName: blockName,
        currentBlock: _currentBlock,
        isHostel: isHostel,
        propertyType: _apartment?.propertyType,
        floorAssignedUsers: floorAssignedUsers,
        onRefreshBlock: _refreshBlock,
        onHostelRoomTap: (room) => _showHostelRoomDetailsSheet(
          context,
          room,
          _currentBlock,
          floor,
        ),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, FloorModel floor, BlockModel block) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _AddRoomBottomSheet(
          floor: floor,
          block: block,
          isHostel: _apartment?.propertyType == PropertyType.hostel,
          propertyType: _apartment?.propertyType,
          onRefreshBlock: _refreshBlock,
        ),
      );
    });
  }

  void _showEditFloorDialog(BuildContext context, FloorModel floor, BlockModel _) {
    _showAddFloorDialog(context, editingFloor: floor);
  }

  void _showDeleteFloorDialog(BuildContext context, FloorModel floor, BlockModel block) {
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
                'Delete Floor',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B1B1D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${floor.number} (${floor.rooms.length} rooms) will be permanently deleted.\nThis action cannot be undone.',
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
                              DeleteFloorEvent(
                                blockId: block.id,
                                floorId: floor.id,
                              ),
                            );
                        _refreshBlock();
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

class _FloorDetailsModalSheet extends StatefulWidget {
  final FloorModel floor;
  final String blockName;
  final BlockModel currentBlock;
  final bool isHostel;
  final PropertyType? propertyType;
  final List<UserModel> floorAssignedUsers;
  final VoidCallback onRefreshBlock;
  final void Function(RoomModel room) onHostelRoomTap;

  const _FloorDetailsModalSheet({
    required this.floor,
    required this.blockName,
    required this.currentBlock,
    required this.isHostel,
    this.propertyType,
    required this.floorAssignedUsers,
    required this.onRefreshBlock,
    required this.onHostelRoomTap,
  });

  @override
  State<_FloorDetailsModalSheet> createState() =>
      _FloorDetailsModalSheetState();
}

class _FloorDetailsModalSheetState extends State<_FloorDetailsModalSheet> {
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
    final floor = widget.floor;
    final isHostel = widget.isHostel;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.layers,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        floor.number,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.blockName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add New Room',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _roomNumberController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: unitLeafLabel(widget.propertyType),
                    hintText: 'e.g., 101, 102',
                    prefixIcon:
                        const Icon(Icons.home, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 12),
                if (isHostel) ...[
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Sharing',
                      prefixIcon:
                          const Icon(Icons.people, color: AppTheme.primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
                    const SizedBox(height: 8),
                    Text(
                      'Beds: ${bedsForHostelSharing(_selectedRoomType) ?? '—'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 160,
                      child: BrandGradientCtaButton(
                        height: 48,
                        label: 'Add',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          if (_roomNumberController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter room number'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final beds = bedsForHostelSharing(_selectedRoomType);
                          context.read<AdminBloc>().add(
                                AddRoomEvent(
                                  blockId: widget.currentBlock.id,
                                  floorId: floor.id,
                                  roomNumber: _roomNumberController.text.trim(),
                                  roomType: _selectedRoomType,
                                  beds: beds,
                                ),
                              );

                          _roomNumberController.clear();
                          setState(() {
                            _selectedRoomType = 'single';
                          });
                          widget.onRefreshBlock();
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Room Type',
                            prefixIcon: const Icon(Icons.apartment,
                                color: AppTheme.primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
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
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: 120,
                          child: BrandGradientCtaButton(
                            height: 48,
                            label: 'Add',
                            icon: Icons.add_rounded,
                            onPressed: () {
                              if (_roomNumberController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter room number'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              context.read<AdminBloc>().add(
                                    AddRoomEvent(
                                      blockId: widget.currentBlock.id,
                                      floorId: floor.id,
                                      roomNumber:
                                          _roomNumberController.text.trim(),
                                      roomType: _selectedRoomType,
                                    ),
                                  );

                              _roomNumberController.clear();
                              widget.onRefreshBlock();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rooms (${floor.rooms.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (floor.rooms.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rooms added yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...floor.rooms.map((room) {
                      final occupants = occupantsForRoom(
                        users: widget.floorAssignedUsers,
                        blockName: widget.blockName,
                        floorNumber: floor.number,
                        room: room,
                        isHostel: isHostel,
                      );
                      final isOccupied = occupants.isNotEmpty;
                      final roomWidget = Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOccupied
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isOccupied
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.door_front_door,
                                color: isOccupied ? Colors.orange : Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.number,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isHostel
                                        ? 'Type: ${displayLabelForHostelSharing(room.type)}'
                                        : 'Type: ${room.type}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (isHostel &&
                                      room.beds != null &&
                                      room.beds! > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Beds: ${room.beds} • ${isOccupied ? 'Occupied' : 'Free'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isOccupied
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isOccupied ? Colors.orange : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOccupied ? 'Occupied' : 'Free',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isOccupied
                                          ? Colors.orange[700]
                                          : Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onHostelRoomTap(room),
                          borderRadius: BorderRadius.circular(12),
                          child: roomWidget,
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddOrEditFloorSheet extends StatefulWidget {
  final BlockModel block;
  final FloorModel? editingFloor;
  final bool isUpdatingTotalFloors;

  const _AddOrEditFloorSheet({
    required this.block,
    required this.isUpdatingTotalFloors,
    this.editingFloor,
  });

  @override
  State<_AddOrEditFloorSheet> createState() => _AddOrEditFloorSheetState();
}

class _AddOrEditFloorSheetState extends State<_AddOrEditFloorSheet> {
  late final List<TextEditingController> _floorControllers;

  @override
  void initState() {
    super.initState();
    if (widget.isUpdatingTotalFloors) {
      if (widget.block.floors.isNotEmpty) {
        _floorControllers = widget.block.floors
            .map((floor) => TextEditingController(text: floor.number))
            .toList();
      } else {
        _floorControllers = [
          TextEditingController(text: 'First Floor'),
          TextEditingController(text: 'Second Floor'),
        ];
      }
    } else {
      _floorControllers = [
        TextEditingController(text: widget.editingFloor?.number ?? '')
      ];
    }
  }

  @override
  void dispose() {
    for (final controller in _floorControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addFloorRow() {
    setState(() {
      _floorControllers.add(TextEditingController());
    });
  }

  void _removeFloorRow(int index) {
    if (_floorControllers.length <= 1) return;
    setState(() {
      final removed = _floorControllers.removeAt(index);
      removed.dispose();
    });
  }

  void _confirmAndRemoveFloorRow(int index) {
    if (_floorControllers.length <= 1) return;
    final floorName = _floorControllers[index].text.trim();
    final displayName = floorName.isEmpty ? 'Floor ${index + 1}' : floorName;

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
                'Remove Floor',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to remove "$displayName"?\nThis action cannot be undone.',
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
                        Navigator.pop(dialogContext);
                        _removeFloorRow(index);
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
                        'Remove',
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingFloor != null;
    final isUpdatingTotalFloors = widget.isUpdatingTotalFloors;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEditing
                    ? 'Edit ${widget.editingFloor!.number}'
                    : (isUpdatingTotalFloors
                        ? 'Update Floors for ${widget.block.name}'
                        : 'Add Floor to ${widget.block.name}'),
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEditing
                    ? 'Update floor name or number'
                    : (isUpdatingTotalFloors
                        ? 'Modify floor names or add new floors individually below.'
                        : 'Enter floor name (e.g., Ground Floor, 1, 2)'),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF8C8C90),
                ),
              ),
              const SizedBox(height: 20),
              if (isUpdatingTotalFloors) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(_floorControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13275D).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.sora(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF13275D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _floorControllers[index],
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Floor ${index + 1}',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFFA0A0A0),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.layers_outlined,
                                      size: 20,
                                      color: Color(0xFF13275D),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFECECEA),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFECECEA),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF13275D),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_floorControllers.length > 1) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _confirmAndRemoveFloorRow(index),
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  tooltip: 'Remove Floor',
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addFloorRow,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Color(0xFF13275D),
                    ),
                    label: Text(
                      'Add Another Floor',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF13275D),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      side: const BorderSide(
                        color: Color(0xFF13275D),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _floorControllers.first,
                  autofocus: true,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B1B1D),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Floor Name',
                    hintText: 'e.g. Ground Floor, 1, 2',
                    prefixIcon: const Icon(
                      Icons.layers_outlined,
                      size: 20,
                      color: Color(0xFF13275D),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                      borderSide: const BorderSide(
                        color: Color(0xFF13275D),
                        width: 1.5,
                      ),
                    ),
                  ),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFECECEA)),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (isEditing) {
                          final text = _floorControllers.first.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a floor name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          context.read<AdminBloc>().add(
                                EditFloorEvent(
                                  blockId: widget.block.id,
                                  floorId: widget.editingFloor!.id,
                                  floorNumber: text,
                                ),
                              );
                          Navigator.pop(context);
                        } else if (isUpdatingTotalFloors) {
                          final desiredFloors = _floorControllers
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();

                          if (desiredFloors.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter at least one floor'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final plan = planFloorListSync(
                            widget.block.floors,
                            desiredFloors,
                          );

                          if (!plan.hasChanges) {
                            Navigator.pop(context);
                            return;
                          }

                          if (plan.floorsToRemove.isNotEmpty) {
                            final deletedNames = plan.floorsToRemove
                                .map((f) => f.number)
                                .join(', ');
                            final confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                backgroundColor: const Color(0xFFFAFAF9),
                                surfaceTintColor: Colors.transparent,
                                insetPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 24,
                                ),
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
                                        'Delete Floors',
                                        style: GoogleFonts.sora(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1B1B1D),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'The following floor(s) will be permanently deleted:\n"$deletedNames"\n\nThis action cannot be undone.',
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
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, false),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
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
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFDC2626),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
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

                            if (confirmDelete != true) return;
                          }

                          for (final rename in plan.renames) {
                            context.read<AdminBloc>().add(
                                  EditFloorEvent(
                                    blockId: widget.block.id,
                                    floorId: rename.floorId,
                                    floorNumber: rename.newNumber,
                                  ),
                                );
                          }
                          for (final floor in plan.floorsToRemove) {
                            context.read<AdminBloc>().add(
                                  DeleteFloorEvent(
                                    blockId: widget.block.id,
                                    floorId: floor.id,
                                  ),
                                );
                          }
                          for (final floorNumber in plan.floorsToAdd) {
                            context.read<AdminBloc>().add(
                                  AddFloorEvent(
                                    blockId: widget.block.id,
                                    floorNumber: floorNumber,
                                    roomConfigurations: const [],
                                  ),
                                );
                          }
                          Navigator.pop(context);
                        } else {
                          final text = _floorControllers.first.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a floor name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          context.read<AdminBloc>().add(
                                AddFloorEvent(
                                  blockId: widget.block.id,
                                  floorNumber: text,
                                  roomConfigurations: const [],
                                ),
                              );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.layers_rounded, size: 18),
                      label: Text(
                        isEditing
                            ? 'Update Floor'
                            : (isUpdatingTotalFloors
                                ? 'Update Floors'
                                : 'Add Floor'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13275D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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

class _AddRoomBottomSheet extends StatefulWidget {
  final FloorModel floor;
  final BlockModel block;
  final bool isHostel;
  final PropertyType? propertyType;
  final VoidCallback onRefreshBlock;

  const _AddRoomBottomSheet({
    required this.floor,
    required this.block,
    this.isHostel = false,
    this.propertyType,
    required this.onRefreshBlock,
  });

  @override
  State<_AddRoomBottomSheet> createState() => _AddRoomBottomSheetState();
}

class _AddRoomBottomSheetState extends State<_AddRoomBottomSheet> {
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
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
            Text(
              'Add Room to ${widget.floor.number}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.block.name} - ${widget.floor.number}',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _roomNumberController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: unitLeafLabel(widget.propertyType),
                hintText: 'e.g., 101, 102, 201',
                prefixIcon:
                    const Icon(Icons.numbers, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.isHostel) ...[
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Sharing',
                  prefixIcon:
                      const Icon(Icons.people, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
                const SizedBox(height: 12),
                Text(
                  'Beds: ${bedsForHostelSharing(_selectedRoomType) ?? '—'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ] else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Room Type',
                  prefixIcon:
                      const Icon(Icons.home, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: BrandGradientCtaButton(
                    height: 48,
                    label: 'Add Room',
                    icon: Icons.meeting_room_rounded,
                    onPressed: () {
                      if (_roomNumberController.text.isNotEmpty) {
                        context.read<AdminBloc>().add(
                              AddRoomEvent(
                                blockId: widget.block.id,
                                floorId: widget.floor.id,
                                roomNumber: _roomNumberController.text.trim(),
                                roomType: _selectedRoomType,
                                beds: widget.isHostel
                                    ? bedsForHostelSharing(_selectedRoomType)
                                    : null,
                              ),
                            );
                        widget.onRefreshBlock();
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a room number'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FloorCard extends StatefulWidget {
  final int cardIndex;
  final FloorModel floor;
  final String blockName;
  final String blockId;
  final BlockModel block;
  final bool isHostel;
  final List<UserModel> blockAssignedUsers;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _FloorCard({
    required this.cardIndex,
    required this.floor,
    required this.blockName,
    required this.blockId,
    required this.block,
    required this.isHostel,
    required this.blockAssignedUsers,
    required this.onTap,
    this.onEdit,
  });

  @override
  State<_FloorCard> createState() => _FloorCardState();
}

class _FloorCardState extends State<_FloorCard> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0, // Initialize at normal scale
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomCount = widget.floor.rooms.length;
    final floorUsers = assignedUsersForFloor(
      users: widget.blockAssignedUsers,
      blockName: widget.blockName,
      floorNumber: widget.floor.number,
    );
    final assignedCount = floorUsers.length;
    final vacantCount = vacantRoomCountForFloor(
      users: widget.blockAssignedUsers,
      blockName: widget.blockName,
      floorNumber: widget.floor.number,
      rooms: widget.floor.rooms,
      isHostel: widget.isHostel,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) => _animationController.reverse(),
          onTapCancel: () => _animationController.reverse(),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFECECEA),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.floor.number,
                            style: GoogleFonts.sora(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.onEdit != null)
                          GestureDetector(
                            onTap: widget.onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          _FloorMetric(
                            value: '$roomCount',
                            label: 'Rooms',
                            color: const Color(0xFF0F172A),
                          ),
                          const _FloorMetricDivider(),
                          _FloorMetric(
                            value: '$assignedCount',
                            label: 'Assigned',
                            color: const Color(0xFF13275D),
                          ),
                          const _FloorMetricDivider(),
                          _FloorMetric(
                            value: '$vacantCount',
                            label: 'Vacant',
                            color: const Color(0xFF0F172A),
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
      ),
    );
  }
}

class _BlockSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _BlockSummaryStat({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.65),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.sora(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FloorMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _FloorMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8C8C90),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FloorMetricDivider extends StatelessWidget {
  const _FloorMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0xFFECECEA),
    );
  }
}

