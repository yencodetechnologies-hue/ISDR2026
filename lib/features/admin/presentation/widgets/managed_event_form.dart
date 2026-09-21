import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_theme.dart';

/// Create/edit event form fields — mirrors the web "Create Event" modal
/// (`ManagementEventsPage.jsx`) exactly: Title, Venue, Date & time, Description.
class ManagedEventFormData {
  ManagedEventFormData({
    String title = '',
    String venue = '',
    String description = '',
    DateTime? eventDate,
    DateTime? eventEndDate,
  })  : title = TextEditingController(text: title),
        venue = TextEditingController(text: venue),
        description = TextEditingController(text: description),
        eventDate = eventDate ?? DateTime.now().add(const Duration(days: 1)),
        eventEndDate = eventEndDate;

  factory ManagedEventFormData.fromEvent(Map<String, dynamic> event) {
    DateTime date = DateTime.now().add(const Duration(days: 1));
    final rawDate = event['eventDate'];
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString())?.toLocal() ?? date;
    }
    return ManagedEventFormData(
      title: event['title']?.toString() ?? '',
      venue: event['venue']?.toString() ?? '',
      description: event['description']?.toString() ?? '',
      eventDate: date,
      eventEndDate: DateTime.tryParse(event['eventEndDate']?.toString() ?? '')?.toLocal(),
    );
  }

  final TextEditingController title;
  final TextEditingController venue;
  final TextEditingController description;
  DateTime eventDate;
  DateTime? eventEndDate;

  void dispose() {
    title.dispose();
    venue.dispose();
    description.dispose();
  }

  String? validate() {
    if (title.text.trim().isEmpty) return 'Title is required';
    if (eventEndDate != null && eventEndDate!.isBefore(eventDate)) {
      return 'End date must be after the start date';
    }
    return null;
  }
}

class ManagedEventFormBody extends StatelessWidget {
  final ManagedEventFormData data;
  final VoidCallback onChanged;
  final Future<void> Function() onPickDateTime;
  final bool showEndDate;
  final Future<void> Function()? onPickEndDateTime;

  const ManagedEventFormBody({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onPickDateTime,
    this.showEndDate = false,
    this.onPickEndDateTime,
  });

  static final _dateFmt = DateFormat('EEE, d MMM yyyy');
  static final _timeFmt = DateFormat('h:mm a');

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        color: const Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECECEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECECEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECECEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: data.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            decoration: _buildInputDecoration(
              labelText: 'Title *',
              icon: Icons.title_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: data.venue,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            decoration: _buildInputDecoration(
              labelText: 'Venue',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECECEA)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date & time',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_dateFmt.format(data.eventDate)} · ${_timeFmt.format(data.eventDate)}',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showEndDate) ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPickEndDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECECEA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_available_rounded, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End date & time (optional)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.eventEndDate == null
                                  ? 'Not set'
                                  : '${_dateFmt.format(data.eventEndDate!)} · ${_timeFmt.format(data.eventEndDate!)}',
                              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      if (data.eventEndDate != null)
                        InkWell(
                          onTap: () {
                            data.eventEndDate = null;
                            onChanged();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: data.description,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            decoration: _buildInputDecoration(
              labelText: 'Description',
              icon: Icons.description_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> pickManagedEventDateTime(
  BuildContext context,
  DateTime current,
) async {
  final d = await showDatePicker(
    context: context,
    initialDate: current.isBefore(DateTime.now()) ? DateTime.now() : current,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
  if (!context.mounted) return null;
  return DateTime(
    d.year,
    d.month,
    d.day,
    t?.hour ?? current.hour,
    t?.minute ?? current.minute,
  );
}
