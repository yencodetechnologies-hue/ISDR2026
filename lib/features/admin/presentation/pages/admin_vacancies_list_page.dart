import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/hostel_sharing.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/utils/room_occupants.dart';
import '../../../../core/utils/unit_labels.dart';
import '../bloc/admin_bloc.dart';

/// Full-screen vacant unit list opened from Overview "Vacancies" stat card.
class AdminVacanciesListPage extends StatefulWidget {
  final PropertyType? propertyType;

  const AdminVacanciesListPage({
    super.key,
    this.propertyType,
  });

  bool get isHostel => propertyType == PropertyType.hostel;

  @override
  State<AdminVacanciesListPage> createState() => _AdminVacanciesListPageState();
}

class _AdminVacanciesListPageState extends State<AdminVacanciesListPage> {
  static const Color _accentColor = Color(0xFF0D9488);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<AdminBloc>().add(LoadAllUsersEvent());
    context.read<AdminBloc>().add(LoadBlocksEvent());
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  bool _matchesSearch(VacantRoomEntry entry) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return entry.blockName.toLowerCase().contains(q) ||
        entry.floorNumber.toLowerCase().contains(q) ||
        entry.room.number.toLowerCase().contains(q) ||
        entry.assignmentLabel.toLowerCase().contains(q) ||
        entry.room.type.toLowerCase().contains(q);
  }

  String _roomSubtitle(VacantRoomEntry entry) {
    if (widget.isHostel) {
      final sharingLabel = bedsForHostelSharing(entry.room.type) != null
          ? displayLabelForHostelSharing(entry.room.type)
          : entry.room.type;
      final capacity =
          roomBedCapacity(beds: entry.room.beds, type: entry.room.type);
      if (capacity > 1) {
        return '$sharingLabel · $capacity beds available';
      }
      return sharingLabel;
    }
    return entry.room.type;
  }

  @override
  Widget build(BuildContext context) {
    final propertyType = widget.propertyType;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Vacancies'),
        elevation: 0,
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (previous, current) =>
            current is AdminLoaded || previous is AdminLoaded,
        builder: (context, state) {
          if (state is! AdminLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final allVacancies = vacantRoomsForProperty(
            users: state.regularUsers,
            blocks: state.blocks,
            isHostel: widget.isHostel,
          );
          final vacancies = allVacancies.where(_matchesSearch).toList();
          final totalCount = allVacancies.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: _accentColor,
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
                          vacantUnitsPhrase(totalCount, propertyType),
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
                            hintText: vacantUnitsSearchHint(propertyType),
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
                                    icon: const Icon(Icons.close_rounded,
                                        size: 20),
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
                              borderSide: const BorderSide(
                                  color: AppTheme.dividerColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppTheme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _accentColor,
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
                            '${vacancies.length} result${vacancies.length == 1 ? '' : 's'}',
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
                if (vacancies.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              usesHouseNoLabel(propertyType)
                                  ? Icons.home_outlined
                                  : Icons.meeting_room_outlined,
                              size: 48,
                              color: AppTheme.textColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              noVacantUnitsMessage(
                                propertyType,
                                forSearch: _searchQuery.isNotEmpty,
                              ),
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
                        (context, index) => _VacantRoomCard(
                          entry: vacancies[index],
                          subtitle: _roomSubtitle(vacancies[index]),
                          propertyType: propertyType,
                        ),
                        childCount: vacancies.length,
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

class _VacantRoomCard extends StatelessWidget {
  final VacantRoomEntry entry;
  final String subtitle;
  final PropertyType? propertyType;

  const _VacantRoomCard({
    required this.entry,
    required this.subtitle,
    this.propertyType,
  });

  static const Color _accentColor = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final isApartment = usesHouseNoLabel(propertyType);
    final title = isApartment
        ? '${unitLeafLabel(propertyType)} ${entry.room.number}'
        : entry.room.number;
    final locationLine = isApartment
        ? 'Block ${entry.blockName} · Floor ${entry.floorNumber}'
        : entry.assignmentLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isApartment ? Icons.home_outlined : Icons.meeting_room_outlined,
                color: _accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    locationLine,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: _accentColor.withOpacity(0.85),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _accentColor.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withOpacity(0.35)),
              ),
              child: const Text(
                'Vacant',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
