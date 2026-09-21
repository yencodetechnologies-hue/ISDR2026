import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/conversation_model.dart';
import '../bloc/guard_chat_bloc.dart';
import '../bloc/guard_chat_event.dart';
import '../bloc/guard_chat_state.dart';

class SelectRecipientPage extends StatefulWidget {
  final String currentUserType;
  final Function(ChatParticipant) onRecipientSelected;

  const SelectRecipientPage({
    super.key,
    required this.currentUserType,
    required this.onRecipientSelected,
  });

  @override
  State<SelectRecipientPage> createState() => _SelectRecipientPageState();
}

class _SelectRecipientPageState extends State<SelectRecipientPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  void _loadRecipients() {
    context.read<GuardChatBloc>().add(const LoadRecipientList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Recipients list
          Expanded(
            child: BlocBuilder<GuardChatBloc, GuardChatState>(
              builder: (context, state) {
                if (state.isLoadingRecipients) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF13275D)),
                    ),
                  );
                }

                if (state.recipientsError != null) {
                  return _buildErrorState(state.recipientsError!);
                }

                final filteredRecipients = _filterRecipients(state.recipients);

                if (filteredRecipients.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildRecipientsList(filteredRecipients);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF13275D),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.currentUserType == 'security'
            ? 'Select Resident'
            : 'Select Security Guard',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF13275D),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF0F172A),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
            // For security users, search on server
            if (widget.currentUserType == 'security' && value.length >= 2) {
              context.read<GuardChatBloc>().add(LoadRecipientList(searchQuery: value));
            }
          },
          decoration: InputDecoration(
            hintText: widget.currentUserType == 'security'
                ? 'Search by name, block, or room...'
                : 'Search security guards...',
            hintStyle: GoogleFonts.outfit(
              fontSize: 13.5,
              color: const Color(0xFF94A3B8),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _loadRecipients();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  List<ChatParticipant> _filterRecipients(List<ChatParticipant> recipients) {
    if (_searchQuery.isEmpty) {
      return recipients;
    }

    return recipients.where((recipient) {
      final nameMatch = recipient.name.toLowerCase().contains(_searchQuery);
      final blockMatch =
          recipient.block?.toLowerCase().contains(_searchQuery) ?? false;
      final roomMatch =
          recipient.roomNumber?.toLowerCase().contains(_searchQuery) ?? false;
      return nameMatch || blockMatch || roomMatch;
    }).toList();
  }

  Widget _buildRecipientsList(List<ChatParticipant> recipients) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: recipients.length,
      itemBuilder: (context, index) {
        final recipient = recipients[index];
        return _RecipientCard(
          recipient: recipient,
          onTap: () => widget.onRecipientSelected(recipient),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13275D).withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 44,
                color: Color(0xFF13275D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No Results Found' : 'No Contacts Available',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term or room number'
                  : widget.currentUserType == 'security'
                      ? 'No registered residents found'
                      : 'No security guards found',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRecipients,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13275D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final ChatParticipant recipient;
  final VoidCallback onTap;

  const _RecipientCard({
    required this.recipient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 14),

                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recipient.displaySubtitle != null &&
                          recipient.displaySubtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13275D).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: Color(0xFF13275D),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipient.displaySubtitle!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF13275D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron icon badge
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF13275D),
            const Color(0xFF13275D).withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13275D).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: recipient.profilePic != null && recipient.profilePic!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: recipient.profilePic!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitials(),
                errorWidget: (context, url, error) => _buildInitials(),
              ),
            )
          : _buildInitials(),
    );
  }

  Widget _buildInitials() {
    final initials = recipient.name.isNotEmpty
        ? recipient.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}
