import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';

class _Colors {
  static const ink = Color(0xFF0F172A);
  static const primaryBlue = Color(0xFF2563EB);
  static const bg = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8C8C90);
  static const line = Color(0xFFECECEA);
  static const green = Color(0xFF16A34A);
}

/// Full details of one speaker/program — opened from the live-show card or
/// the schedule list.
class ScheduleDetailPage extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic> event;

  const ScheduleDetailPage({
    super.key,
    required this.schedule,
    required this.event,
  });

  ({DateTime start, DateTime end})? _window() {
    final d = DateTime.tryParse(schedule['date']?.toString() ?? '')?.toUtc();
    if (d == null) return null;
    DateTime at(String hhmm) {
      final p = hhmm.split(':');
      return DateTime(d.year, d.month, d.day, int.tryParse(p[0]) ?? 0,
          p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
    }
    return (
      start: at(schedule['fromTime']?.toString() ?? '0:0'),
      end: at(schedule['toTime']?.toString() ?? '0:0'),
    );
  }

  String _fmtTime(DateTime t) => DateFormat('h:mm a').format(t);

  @override
  Widget build(BuildContext context) {
    final scheduleName = schedule['scheduleName']?.toString() ?? '';
    final speakerName = schedule['speakerName']?.toString() ?? '';
    final speakerPhoto = schedule['speakerPhoto']?.toString() ?? '';
    final description = schedule['description']?.toString() ?? '';
    final eventTitle = event['title']?.toString() ?? '';
    final venue = event['venue']?.toString() ?? '';

    final window = _window();
    final now = DateTime.now();
    final isLive = window != null &&
        !now.isBefore(window.start) &&
        now.isBefore(window.end);
    final isPast = window != null && now.isAfter(window.end);
    final statusLabel = isLive ? 'LIVE NOW' : (isPast ? 'ENDED' : 'UPCOMING');
    final statusColor = isLive
        ? _Colors.green
        : (isPast ? _Colors.muted : _Colors.primaryBlue);

    final dateStr = window != null
        ? DateFormat('EEEE, d MMM yyyy').format(window.start)
        : '';
    final timeStr = window != null
        ? '${_fmtTime(window.start)} - ${_fmtTime(window.end)}'
        : '';
    final scheduleId = schedule['id']?.toString() ?? scheduleName;

    return Scaffold(
      backgroundColor: _Colors.bg,
      appBar: buildBrandGradientAppBar(
        title: Text(
          'Program Details',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          _ReminderBellIconButton(scheduleId: scheduleId),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _Colors.primaryBlue.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: _Colors.line, width: 2),
                  ),
                  child: speakerPhoto.isNotEmpty
                      ? Image.network(
                          speakerPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: _Colors.primaryBlue,
                            size: 46,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: _Colors.primaryBlue,
                          size: 46,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  speakerName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _Colors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _Colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _Colors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduleName,
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _Colors.ink,
                  ),
                ),
                if (eventTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    eventTitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _Colors.primaryBlue,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (dateStr.isNotEmpty)
                  _InfoRow(icon: Icons.calendar_today_rounded, label: dateStr),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.access_time_rounded, label: timeStr),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoRow(icon: Icons.location_on_rounded, label: venue),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'ABOUT THIS SESSION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                      color: _Colors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: _Colors.ink,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual-only "notify me" toggle in the app bar — fills in when tapped.
/// Not yet wired to real notification scheduling.
class _ReminderBellIconButton extends StatefulWidget {
  final String scheduleId;
  const _ReminderBellIconButton({required this.scheduleId});

  @override
  State<_ReminderBellIconButton> createState() => _ReminderBellIconButtonState();
}

class _ReminderBellIconButtonState extends State<_ReminderBellIconButton> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      icon: Icon(
        _on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
        color: _on ? const Color(0xFFFBBF24) : Colors.white,
      ),
      onPressed: () => setState(() => _on = !_on),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _Colors.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: _Colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
