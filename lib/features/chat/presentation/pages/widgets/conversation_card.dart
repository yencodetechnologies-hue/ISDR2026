import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/conversation_model.dart';

class ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserType;
  final VoidCallback onTap;
  final String? typingUserName;

  const ConversationCard({
    super.key,
    required this.conversation,
    required this.currentUserType,
    required this.onTap,
    this.typingUserName,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = conversation.getDisplayName(currentUserType);
    final profilePic = conversation.getDisplayProfilePic(currentUserType);
    final subtitle = conversation.getDisplaySubtitle(currentUserType);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? AppTheme.primaryColor.withOpacityCompat(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppTheme.primaryColor.withOpacityCompat(0.2)
                : AppTheme.dividerColor.withOpacityCompat(0.5),
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Profile Picture
            _buildAvatar(profilePic, displayName),
            const SizedBox(width: 12),

            // Name, Subtitle, Last Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and timestamp row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(conversation.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? AppTheme.primaryColor
                              : AppTheme.textColor.withOpacityCompat(0.5),
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),

                  // Subtitle (block/room)
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppTheme.textColor.withOpacityCompat(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textColor.withOpacityCompat(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Last message or typing indicator
                  Row(
                    children: [
                      Expanded(
                        child: typingUserName != null
                            ? _buildTypingIndicator()
                            : Text(
                                conversation.lastMessage.isEmpty
                                    ? 'Start a conversation'
                                    : conversation.lastMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: hasUnread
                                      ? AppTheme.textColor.withOpacityCompat(0.8)
                                      : AppTheme.textColor.withOpacityCompat(0.6),
                                  fontWeight:
                                      hasUnread ? FontWeight.w500 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),

                      // Unread badge
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _buildUnreadBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? profilePic, String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacityCompat(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacityCompat(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: profilePic != null && profilePic.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: profilePic,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitials(name),
                errorWidget: (context, url, error) => _buildInitials(name),
              ),
            )
          : _buildInitials(name),
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withOpacityCompat(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Text(
          'typing',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryColor,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 20,
          child: _TypingDots(),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacityCompat(0.3 + opacity * 0.7),
              ),
            );
          }),
        );
      },
    );
  }
}
