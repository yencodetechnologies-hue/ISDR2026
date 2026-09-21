import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/guard_message_model.dart';

class MessageBubble extends StatelessWidget {
  final GuardMessageModel message;
  final bool isMe;
  final bool showTimestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTimestamp = true,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.75;
    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              decoration: BoxDecoration(
              gradient: isMe ? AppTheme.brandHeaderGradient : null,
              color: isMe ? null : AppTheme.dividerColor.withOpacityCompat(0.65),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : (isLastInGroup ? 4 : 18)),
                bottomRight: Radius.circular(isMe ? (isLastInGroup ? 4 : 18) : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMe ? AppTheme.primaryColor : Colors.black).withOpacityCompat(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Message text
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 15,
                    color: isMe ? Colors.white : AppTheme.textColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Timestamp and read status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white.withOpacityCompat(0.7)
                            : AppTheme.textColor.withOpacityCompat(0.5),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead
                            ? Colors.lightBlueAccent
                            : Colors.white.withOpacityCompat(0.7),
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
}

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppTheme.dividerColor.withOpacityCompat(0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor.withOpacityCompat(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textColor.withOpacityCompat(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppTheme.dividerColor.withOpacityCompat(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

class TypingIndicator extends StatefulWidget {
  final String userName;

  const TypingIndicator({super.key, required this.userName});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 48, top: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.dividerColor.withOpacityCompat(0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = ((_controller.value + delay) % 1.0);
                    final bounce = value < 0.5
                        ? value * 2
                        : 2 - value * 2;
                    return Transform.translate(
                      offset: Offset(0, -bounce * 4),
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacityCompat(0.6),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.userName} is typing...',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textColor.withOpacityCompat(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
