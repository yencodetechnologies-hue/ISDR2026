import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/app_theme.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../../../core/models/event_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/widgets/delete_event_confirm_sheet.dart';
import '../../bloc/admin_bloc.dart';
import '../widgets/add_event_dialog.dart';

class NoticesTab extends StatefulWidget {
  final AdminLoaded state;
  const NoticesTab({required this.state, super.key});

  @override
  State<NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<NoticesTab> {
  final ApiService _apiService = ApiService();
  List<EventModel> _events = [];
  bool _isLoading = false;
  String _searchQuery = '';

  String? get _apartmentId {
    final sel = widget.state.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didUpdateWidget(covariant NoticesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedApartmentId != widget.state.selectedApartmentId) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAllNotices(
        type: 'event',
        apartmentId: _apartmentId,
      );
      if (response['success'] == true && response['notices'] != null) {
        setState(() {
          _events = (response['notices'] as List)
              .map((e) => EventModel.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addEvent(String title, String subtitle, String content, DateTime eventDate) async {
    try {
      final response = await _apiService.createNotice(
        title: title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        content: content,
        type: 'event',
        targetAudience: 'all',
        eventDate: eventDate.toIso8601String(),
        apartmentId: _apartmentId,
      );
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notice published successfully'),
              backgroundColor: Color(0xFF13275D),
            ),
          );
          _loadEvents();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to add notice'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent(EventModel event) async {
    DeleteEventConfirmSheet.showDeleteEventConfirmSheet(
      context,
      onDelete: () async {
        try {
          final response = await _apiService.deleteNotice(event.id);
          if (mounted) {
            if (response['success'] == true) {
              await _loadEvents();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notice deleted successfully'),
                  backgroundColor: Color(0xFF13275D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response['error'] ?? 'Failed to delete notice'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  List<EventModel> get _filteredEvents {
    if (_searchQuery.trim().isEmpty) return _events;
    final query = _searchQuery.toLowerCase();
    return _events.where((e) {
      return e.title.toLowerCase().contains(query) ||
          (e.subtitle != null && e.subtitle!.toLowerCase().contains(query)) ||
          e.content.toLowerCase().contains(query);
    }).toList();
  }

  IconData _getEventIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('diwali') || lowerTitle.contains('holi') || lowerTitle.contains('festival')) return Icons.celebration_rounded;
    if (lowerTitle.contains('meeting') || lowerTitle.contains('agm')) return Icons.groups_rounded;
    if (lowerTitle.contains('maintenance') || lowerTitle.contains('water') || lowerTitle.contains('power')) return Icons.build_circle_rounded;
    if (lowerTitle.contains('security') || lowerTitle.contains('gate')) return Icons.shield_rounded;
    return Icons.campaign_rounded;
  }

  Widget _buildEventCard(EventModel event, int index) {
    final icon = _getEventIcon(event.title);
    final dateStr = event.eventDate.toString().split(' ')[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF13275D).withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13275D).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF13275D), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (event.subtitle != null && event.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 20),
                  onPressed: () => _deleteEvent(event),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Text(
              event.content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF334155),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_rounded, size: 14, color: Color(0xFF13275D)),
                  const SizedBox(width: 6),
                  Text(
                    'Target Date: $dateStr',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF13275D),
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

  @override
  Widget build(BuildContext context) {
    final totalCount = _events.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notices & Announcements',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF13275D),
                            ),
                          ),
                          Text(
                            'Broadcast official updates to property residents',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 135,
                      child: BrandGradientCtaButton(
                        height: 42,
                        icon: Icons.add_rounded,
                        label: 'Add Notice',
                        onPressed: () {
                          AddEventDialog.show(context, _addEvent);
                        },
                      ),
                    ),
                  ],
                ),
                if (_events.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Search Bar
                  SizedBox(
                    height: 42,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search notices by title or keywords...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF13275D)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Main list content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF13275D),
                    ),
                  )
                : _filteredEvents.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadEvents,
                        color: const Color(0xFF13275D),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.55,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF13275D).withValues(alpha: 0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.campaign_outlined,
                                    size: 56,
                                    color: Color(0xFF13275D),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _events.isEmpty
                                      ? 'No notices published yet'
                                      : 'No matching notices found',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _events.isEmpty
                                      ? 'Publish society circulars, maintenance alerts, or upcoming community meeting agendas.'
                                      : 'Try searching with a different title or keyword.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        color: const Color(0xFF13275D),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                            return _buildEventCard(_filteredEvents[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
