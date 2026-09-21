import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/widgets/brand_form_bottom_sheet.dart';
import '../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/models/block_model.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/utils/room_occupants.dart';
import '../../../../../core/utils/unit_labels.dart';
import '../../../../../core/utils/floor_spec.dart';
import '../../bloc/admin_bloc.dart';

String? _validateBlockName(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'Please enter block name';
  if (s.length > 20) return 'Block name must be at most 20 characters';
  return null;
}

class BlocksTab extends StatefulWidget {
  final AdminLoaded state;
  final ApartmentModel? apartment;

  const BlocksTab({required this.state, this.apartment});

  @override
  State<BlocksTab> createState() => _BlocksTabState();
}

class _BlocksTabState extends State<BlocksTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _awaitingCreateBlockResult = false;
  int? _blockCountBeforeCreate;

  String _blockBadgeText(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final a = parts[0];
      final b = parts[1];
      return '${a[0]}${b[0]}'.toUpperCase();
    }
    if (trimmed.length >= 2) return trimmed.substring(0, 2).toUpperCase();
    return trimmed[0].toUpperCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showBlockSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  List<BlockModel> _filterBlocks(List<BlockModel> blocks) {
    if (_searchQuery.isEmpty) return blocks;
    final q = _searchQuery.toLowerCase();
    return blocks.where((block) {
      if (block.name.toLowerCase().contains(q)) return true;
      for (final floor in block.floors) {
        if (floor.number.toLowerCase().contains(q)) return true;
        for (final room in floor.rooms) {
          if (room.number.toLowerCase().contains(q)) return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalRooms = widget.state.blocks.fold<int>(
      0,
      (sum, block) => sum + block.floors.fold<int>(0, (s, floor) => s + floor.rooms.length),
    );
    final totalFloors = widget.state.blocks.fold<int>(0, (sum, block) => sum + block.floors.length);
    final filteredBlocks = _filterBlocks(widget.state.blocks);

    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (previous, current) {
        if (!_awaitingCreateBlockResult) return false;
        if (current is AdminError) return true;
        if (current is AdminLoaded && previous is AdminLoaded) {
          final before = _blockCountBeforeCreate;
          if (before != null) {
            return current.blocks.length > before;
          }
          return current.blocks.length > previous.blocks.length;
        }
        return false;
      },
      listener: (context, state) {
        if (!_awaitingCreateBlockResult) return;
        _awaitingCreateBlockResult = false;
        _blockCountBeforeCreate = null;
        if (state is AdminLoaded) {
          _showBlockSnackBar('Block created successfully', isError: false);
        } else if (state is AdminError) {
          _showBlockSnackBar(
            state.message.isNotEmpty
                ? state.message
                : 'Failed to create block',
            isError: true,
          );
        }
      },
      child: Container(
        color: const Color(0xFFFAFAF9),
        child: Column(
          children: [
            // Header with stats and create button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: const Color(0xFFFAFAF9),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.apartment_rounded,
                          label: 'Total Blocks',
                          value: '${widget.state.blocks.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.layers_rounded,
                          label: 'Total Floors',
                          value: '$totalFloors',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.home_rounded,
                          label: 'Total Rooms',
                          value: '$totalRooms',
                        ),
                      ),
                    ],
                  ),
                  if (widget.apartment?.blockCreationEnabled != false) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _showCreateBlockDialog(context),
                      child: Container(
                        height: 48,
                        width: double.infinity,
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
                              'Create New Block',
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
                  ],
                ],
              ),
            ),
            if (widget.state.blocks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by block, floor, room...',
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
                              setState(() => _searchQuery = '');
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
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            // Blocks List
            Expanded(
              child: widget.state.blocks.isEmpty
                  ? _buildEmptyState(context)
                  : filteredBlocks.isEmpty
                      ? Center(
                          child: Text(
                            'No results for "$_searchQuery"',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF8C8C90),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 54),
                          itemCount: filteredBlocks.length,
                          itemBuilder: (context, index) {
                            final block = filteredBlocks[index];
                            return _buildBlockCard(context, block, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF13275D).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.apartment_outlined,
                size: 64,
                color: Color(0xFF13275D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Blocks Created Yet',
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first block to get started',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF8C8C90),
              ),
            ),
            if (widget.apartment?.blockCreationEnabled != false) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showCreateBlockDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                    mainAxisSize: MainAxisSize.min,
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
                        'Create Block',
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(BuildContext context, BlockModel block, int index) {
    final totalRooms = block.floors.fold<int>(0, (sum, floor) => sum + floor.rooms.length);
    final assignedResidents = assignedUserCountForBlock(
      users: widget.state.regularUsers,
      blockName: block.name,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.blockDetails,
              arguments: block,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Block Icon Badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _blockBadgeText(block.name),
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  block.name,
                                  style: GoogleFonts.sora(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: block.isActive
                                      ? const Color(0xFF13275D).withOpacity(0.14)
                                      : const Color(0xFF8C8C90).withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: block.isActive
                                        ? const Color(0xFF13275D).withOpacity(0.3)
                                        : const Color(0xFF8C8C90).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: block.isActive
                                            ? const Color(0xFF13275D)
                                            : const Color(0xFF8C8C90),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      block.isActive ? 'Active' : 'Inactive',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: block.isActive
                                            ? const Color(0xFF13275D)
                                            : const Color(0xFF8C8C90),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Stats Row
                          Row(
                            children: [
                              _buildInfoChip(
                                icon: Icons.layers_rounded,
                                label: '${block.floors.length}',
                                subLabel: 'Floors',
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                icon: Icons.home_rounded,
                                label: '$totalRooms',
                                subLabel: 'Rooms',
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                icon: Icons.person_rounded,
                                label: '$assignedResidents',
                                subLabel: 'Assigned',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Divider
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFECECEA),
                ),
                const SizedBox(height: 10),
                // Action Buttons Row
                Row(
                  children: [
                    // Toggle Switch
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.power_settings_new_rounded,
                            size: 16,
                            color: Color(0xFF8C8C90),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Status',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8C8C90),
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: block.isActive,
                            onChanged: (value) {
                              context.read<AdminBloc>().add(
                                    ToggleBlockActiveEvent(block.id),
                                  );
                            },
                            activeColor: const Color(0xFF13275D),
                            activeTrackColor: const Color(0xFF13275D).withOpacity(0.3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action Buttons
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      isDelete: false,
                      onPressed: () => _showEditBlockDialog(context, block),
                      tooltip: 'Edit Block',
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      isDelete: true,
                      onPressed: () => _showDeleteBlockDialog(context, block),
                      tooltip: 'Delete Block',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF13275D)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            subLabel,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8C8C90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isDelete,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final bg = isDelete
        ? const Color(0xFFEF4444).withOpacity(0.1)
        : const Color(0xFFF2F2F1);
    final border = isDelete
        ? const Color(0xFFEF4444).withOpacity(0.3)
        : const Color(0xFFECECEA);
    final iconColor = isDelete ? const Color(0xFFEF4444) : const Color(0xFF0F172A);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateBlockDialog(BuildContext context) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    final payload = await showModalBottomSheet<_CreateBlockPayload>(
      context: rootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _CreateBlockSheetContent(),
    );

    if (payload == null || !mounted) return;

    // Wait until the modal route is fully removed before touching AdminBloc.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final blocState = context.read<AdminBloc>().state;
    _blockCountBeforeCreate =
        blocState is AdminLoaded ? blocState.blocks.length : null;
    _awaitingCreateBlockResult = true;
    context.read<AdminBloc>().add(
      CreateBlockEvent(
        blockName: payload.blockName,
        floorNumbers: payload.floorNumbers,
      ),
    );
  }

  void _showAddFloorDialog(BuildContext context, BlockModel block) {
    final floorController = TextEditingController();
    final roomNumberController = TextEditingController();
    final companyNameController = TextEditingController();
    final numberOfBedsController = TextEditingController();
    String selectedUnitType = 'individual'; // 'individual' or 'company'
    String selectedRoomType = '1BHK';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Handle bar
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
              // Title
              Text(
                'Add Floor to ${block.name}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter floor and room details',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Unit Type Dropdown (must select first)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Unit Type',
                          prefixIcon: const Icon(Icons.category, color: AppTheme.primaryColor),
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
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        value: selectedUnitType,
                        items: const [
                          DropdownMenuItem(value: 'individual', child: Text('Individual')),
                          DropdownMenuItem(value: 'company', child: Text('Company')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUnitType = value ?? 'individual';
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      // Floor Number Field
                      TextField(
                        controller: floorController,
                        decoration: InputDecoration(
                          labelText: 'Floor Number',
                          hintText: 'e.g., UF, GF, 2, 3, 56',
                          prefixIcon: const Icon(Icons.layers, color: AppTheme.primaryColor),
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
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Individual: House No / Room Number & Room Type
                      if (selectedUnitType == 'individual') ...[
                        TextField(
                          controller: roomNumberController,
                          decoration: InputDecoration(
                            labelText: unitLeafLabel(widget.apartment?.propertyType),
                            hintText: 'e.g., 101, 102, 201',
                            prefixIcon: const Icon(Icons.home, color: AppTheme.primaryColor),
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
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Room Type',
                            prefixIcon: const Icon(Icons.apartment, color: AppTheme.primaryColor),
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
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          value: selectedRoomType,
                          items: ['1BHK', '2BHK', '3BHK', '4BHK', '5BHK', 'Hostel']
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedRoomType = value ?? '1BHK';
                            });
                          },
                        ),
                        if (selectedRoomType == 'Hostel') ...[
                          const SizedBox(height: 20),
                          TextField(
                            controller: numberOfBedsController,
                            decoration: InputDecoration(
                              labelText: 'Number of Beds',
                              hintText: 'e.g., 2, 4, 6',
                              prefixIcon: const Icon(Icons.bed, color: AppTheme.primaryColor),
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
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ] else ...[
                        // Company: Company Name (only after floor, when company type)
                        TextField(
                          controller: companyNameController,
                          decoration: InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'e.g., ABC Corp, XYZ Ltd',
                            prefixIcon: const Icon(Icons.business, color: AppTheme.primaryColor),
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
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Action Buttons (fixed at bottom)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: BrandGradientCtaButton(
                      height: 48,
                      label: selectedUnitType == 'company' ? 'Create Room' : 'Add Floor',
                      icon: Icons.layers_rounded,
                      onPressed: () {
                        final floorLabelError =
                            validateSingleFloorLabel(floorController.text);
                        if (floorLabelError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(floorLabelError),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final floorNumber =
                            singleFloorLabelFromInput(floorController.text)!;
                        
                        if (selectedUnitType == 'company') {
                          if (companyNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter company name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          // Create room with company name as room number, type Company
                          final configs = [
                            {'type': 'Company', 'count': 1},
                          ];
                          context.read<AdminBloc>().add(
                                AddFloorEvent(
                                  blockId: block.id,
                                  floorNumber: floorNumber,
                                  roomConfigurations: configs,
                                  roomNumber: companyNameController.text.trim(),
                                ),
                              );
                        } else {
                          if (roomNumberController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter room number'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (selectedRoomType == 'Hostel') {
                            if (numberOfBedsController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter number of beds'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final beds = int.tryParse(numberOfBedsController.text.trim());
                            if (beds == null || beds <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid number of beds (greater than 0)'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final configs = [
                              {'type': 'Hostel', 'count': beds},
                            ];
                            context.read<AdminBloc>().add(
                                  AddFloorEvent(
                                    blockId: block.id,
                                    floorNumber: floorNumber,
                                    roomConfigurations: configs,
                                    roomNumber: roomNumberController.text.trim(),
                                  ),
                                );
                          } else {
                            final configs = [
                              {'type': selectedRoomType, 'count': 1},
                            ];
                            context.read<AdminBloc>().add(
                                  AddFloorEvent(
                                    blockId: block.id,
                                    floorNumber: floorNumber,
                                    roomConfigurations: configs,
                                    roomNumber: roomNumberController.text.trim(),
                                  ),
                                );
                          }
                        }
                        
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showBlockDetails(BuildContext context, BlockModel block) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${block.name} Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: block.floors.length,
            itemBuilder: (context, index) {
              final floor = block.floors[index];
              return ExpansionTile(
                title: Text(floor.number),
                children: floor.rooms.map((room) {
                  return ListTile(
                    title: Text(room.number),
                    subtitle: Text('Type: ${room.type}'),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditBlockDialog(BuildContext context, BlockModel block) {
    final blockController = TextEditingController(text: block.name);
    // Create controllers for each floor
    final Map<String, TextEditingController> floorControllers = {};
    for (var floor in block.floors) {
      floorControllers[floor.id] = TextEditingController(text: floor.number);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Track deleted floor IDs (persists across rebuilds)
        final Set<String> deletedFloorIds = {};
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter out deleted floors
            final currentFloors = block.floors.where((floor) => !deletedFloorIds.contains(floor.id)).toList();
            
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
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
                child: Column(
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
                'Edit Block',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Update block name and floor numbers',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              // Block Name Field
              TextField(
                controller: blockController,
                decoration: InputDecoration(
                  labelText: 'Block Name',
                  hintText: 'e.g., Tower East, Block 1',
                  prefixIcon: const Icon(Icons.apartment, color: AppTheme.primaryColor),
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
                    borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Floors Section
                      if (currentFloors.isNotEmpty || block.floors.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.layers, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Floors (${currentFloors.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: currentFloors.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      'No floors remaining',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: currentFloors.length,
                                  itemBuilder: (context, index) {
                                    final floor = currentFloors[index];
                                    final floorController = floorControllers[floor.id]!;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: floorController,
                                              decoration: InputDecoration(
                                                labelText: 'Floor Number',
                                                hintText: 'e.g., UF, GF, 2, 56',
                                                prefixIcon: const Icon(Icons.layers, color: AppTheme.primaryColor, size: 20),
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
                                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              keyboardType: TextInputType.text,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 22),
                                            color: Colors.red,
                                            onPressed: () {
                                              // Show confirmation dialog
                                              showDialog(
                                                context: context,
                                                builder: (dialogContext) => AlertDialog(
                                                  title: const Text(
                                                    'Delete Floor?',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  content: Text(
                                                    '${floor.number} (${floor.rooms.length} rooms) will be permanently deleted.\nThis action cannot be undone.',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogContext),
                                                      child: const Text(
                                                        'Cancel',
                                                        style: TextStyle(color: Colors.grey),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        // Delete the floor
                                                        context.read<AdminBloc>().add(
                                                              DeleteFloorEvent(
                                                                blockId: block.id,
                                                                floorId: floor.id,
                                                              ),
                                                            );
                                                        
                                                        // Remove from local state
                                                        setDialogState(() {
                                                          deletedFloorIds.add(floor.id);
                                                          floorControllers[floor.id]?.dispose();
                                                          floorControllers.remove(floor.id);
                                                        });
                                                        
                                                        Navigator.pop(dialogContext);
                                                        
                                                        // Show success message
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('${floor.number} deleted'),
                                                            backgroundColor: Colors.green,
                                                            duration: const Duration(seconds: 2),
                                                          ),
                                                        );
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
                                            },
                                            tooltip: 'Delete Floor',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No floors to edit. Add floors from the block details page.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BrandGradientCtaButton(
                      height: 48,
                      label: 'Update Block',
                      icon: Icons.save_rounded,
                      onPressed: () {
                        final blockNameError = _validateBlockName(blockController.text);
                        if (blockNameError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(blockNameError),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (blockController.text.trim().isNotEmpty) {
                          // Update block name
                          context.read<AdminBloc>().add(
                                EditBlockEvent(
                                  blockId: block.id,
                                  name: blockController.text.trim(),
                                ),
                              );
                          
                          // Update floor numbers if changed (only for floors that still exist)
                          for (var floor in currentFloors) {
                            if (floorControllers.containsKey(floor.id)) {
                              final floorController = floorControllers[floor.id]!;
                              final updatedFloorNumber =
                                  singleFloorLabelFromInput(
                                floorController.text,
                              );
                              if (updatedFloorNumber != null &&
                                  updatedFloorNumber != floor.number) {
                                context.read<AdminBloc>().add(
                                      EditFloorEvent(
                                        blockId: block.id,
                                        floorId: floor.id,
                                        floorNumber: updatedFloorNumber,
                                      ),
                                    );
                              }
                            }
                          }
                          
                          Navigator.pop(context);
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
          },
        );
      },
    );
  }

  void _showDeleteBlockDialog(BuildContext context, BlockModel block) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Delete Block?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${block.name} will be permanently deleted.\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AdminBloc>().add(DeleteBlockEvent(block.id));
                      Navigator.pop(context);
                    },
                    style: AppTheme.errorElevatedStyle,
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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

/// Stateful content for Create Block bottom sheet. Owns [TextEditingController]s
/// and disposes them in [dispose] to avoid "used after disposed" when the
/// route is popped.
class _CreateBlockSheetContent extends StatefulWidget {
  const _CreateBlockSheetContent();

  @override
  State<_CreateBlockSheetContent> createState() =>
      _CreateBlockSheetContentState();
}

class _CreateBlockSheetContentState extends State<_CreateBlockSheetContent> {
  late final TextEditingController _blockController;
  late final TextEditingController _floorsController;

  @override
  void initState() {
    super.initState();
    _blockController = TextEditingController();
    _floorsController = TextEditingController();
  }

  @override
  void dispose() {
    _blockController.dispose();
    _floorsController.dispose();
    super.dispose();
  }

  void _submit() {
    final messenger = ScaffoldMessenger.of(context);

    final blockNameError = _validateBlockName(_blockController.text);
    if (blockNameError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(blockNameError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final floorSpecError = validateFloorSpec(_floorsController.text);
    if (floorSpecError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(floorSpecError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final floorNumbers = parseFloorSpec(_floorsController.text);

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(
      context,
      _CreateBlockPayload(
        blockName: _blockController.text.trim(),
        floorNumbers: floorNumbers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrandFormBottomSheet(
      title: 'Create New Block',
      subtitle: 'Enter block name and floor labels',
      headerIcon: Icons.apartment_rounded,
      submitLabel: 'Create Block',
      submitIcon: Icons.add_business_rounded,
      onCancel: () => Navigator.pop(context),
      onSubmit: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _blockController,
            decoration: brandFormInputDecoration(
              label: 'Block Name',
              icon: Icons.apartment_rounded,
            ).copyWith(hintText: 'e.g., Tower East, Block 1'),
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _floorsController,
            decoration: brandFormInputDecoration(
              label: 'Floors',
              icon: Icons.layers_rounded,
            ).copyWith(
              hintText: 'e.g., UF,GF,2,2,3,4,56,78,9',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
    );
  }
}

class _CreateBlockPayload {
  const _CreateBlockPayload({
    required this.blockName,
    required this.floorNumbers,
  });

  final String blockName;
  final List<String> floorNumbers;
}
