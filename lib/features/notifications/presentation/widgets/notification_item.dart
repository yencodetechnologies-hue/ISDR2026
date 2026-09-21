import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/notification_model.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  Color _getTypeColor() {
    switch (notification.type) {
      case 'maintenance':
        return const Color(0xFF13275D);
      case 'payment':
        return const Color(0xFF10B981);
      case 'complaint':
        return const Color(0xFFDC2626);
      case 'visitor':
        return const Color(0xFFF59E0B);
      case 'notice':
        return const Color(0xFF13275D);
      case 'message':
        return const Color(0xFF10B981);
      case 'kid_exit':
        return const Color(0xFFF59E0B);
      case 'permission':
        return const Color(0xFF13275D);
      case 'user_status':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF13275D);
    }
  }

  IconData _getTypeIcon() {
    switch (notification.type) {
      case 'maintenance':
        return Icons.build_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'complaint':
        return Icons.report_problem_rounded;
      case 'visitor':
        return Icons.person_pin_rounded;
      case 'notice':
        return Icons.campaign_rounded;
      case 'message':
        return Icons.message_rounded;
      case 'kid_exit':
        return Icons.child_care_rounded;
      case 'permission':
        return Icons.lock_rounded;
      case 'user_status':
        return Icons.person_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final typeIcon = _getTypeIcon();
    final isUnread = !notification.read;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFDC2626),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => onDelete?.call(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnread
                      ? const Color(0xFF13275D)
                      : const Color(0xFFECECEA),
                  width: isUnread ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isUnread ? 0.06 : 0.03),
                    blurRadius: isUnread ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 76,
                      color: isUnread
                          ? const Color(0xFF13275D)
                          : typeColor.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(typeIcon, color: typeColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: GoogleFonts.sora(
                                            fontSize: 14.5,
                                            fontWeight: isUnread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.body,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: Color(0xFF8C8C90),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM dd, yyyy • hh:mm a')
                                            .format(notification.createdAt),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8C8C90),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

