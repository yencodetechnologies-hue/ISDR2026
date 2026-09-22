import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_theme.dart';

/// Create/edit event form fields — Title, Venue, Date & time, Optional End Date,
/// Optional Photo/Banner, and Description.
class ManagedEventFormData {
  ManagedEventFormData({
    String title = '',
    String venue = '',
    String description = '',
    DateTime? eventDate,
    DateTime? eventEndDate,
    this.existingPhotoUrl,
    this.photoPath,
    this.removePhoto = false,
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
    final rawPhoto = event['photoUrl']?.toString() ?? '';
    return ManagedEventFormData(
      title: event['title']?.toString() ?? '',
      venue: event['venue']?.toString() ?? '',
      description: event['description']?.toString() ?? '',
      eventDate: date,
      eventEndDate: DateTime.tryParse(event['eventEndDate']?.toString() ?? '')?.toLocal(),
      existingPhotoUrl: rawPhoto.isNotEmpty ? rawPhoto : null,
    );
  }

  final TextEditingController title;
  final TextEditingController venue;
  final TextEditingController description;
  DateTime eventDate;
  DateTime? eventEndDate;
  String? existingPhotoUrl;
  String? photoPath;
  bool removePhoto;

  bool get hasPhoto =>
      photoPath != null || (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty && !removePhoto);

  void clearPhoto() {
    photoPath = null;
    removePhoto = true;
  }

  void setPhoto(String path) {
    photoPath = path;
    removePhoto = false;
  }

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

  Future<void> _pickPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Event Photo',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Select an image from device gallery',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.secondaryColor),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Use camera to take a new photo',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null) {
      data.setPhoto(file.path);
      onChanged();
    }
  }

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
          // Event Photo (Optional)
          _buildPhotoSection(context),
          const SizedBox(height: 16),
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

  Widget _buildPhotoSection(BuildContext context) {
    if (data.hasPhoto) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (data.photoPath != null)
                Image.file(
                  File(data.photoPath!),
                  fit: BoxFit.cover,
                )
              else if (data.existingPhotoUrl != null)
                Image.network(
                  data.existingPhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                    ),
                  ),
                ),
              // Gradient shadow
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(70),
                        Colors.transparent,
                        Colors.black.withAlpha(120),
                      ],
                    ),
                  ),
                ),
              ),
              // Top label
              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Event Photo',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Action buttons (Change & Remove)
              Positioned(
                bottom: 10,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _pickPhoto(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Change',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        data.clearPhoto();
                        onChanged();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Remove',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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

    // Unselected state
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _pickPhoto(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add event photo (optional)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to upload cover / banner image',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
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
